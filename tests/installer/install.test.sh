#!/usr/bin/env bash
# Self-check for tools/installer/install.sh using synthetic fixture files —
# never touches a real Steam install or a real SWF.
# Run directly: bash tests/installer/install.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$ROOT_DIR/tools/installer/install.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAKE_ORIGINAL="$WORK/Gazillionaire.swf"
FAKE_MODDED="$WORK/build/output/gazillionaire-modded.swf"
FAKE_MANIFEST_DIR="$WORK/engine"

echo "original swf bytes" > "$FAKE_ORIGINAL"
mkdir -p "$WORK/build/output"
echo "modded swf bytes" > "$FAKE_MODDED"
mkdir -p "$FAKE_MANIFEST_DIR"

ORIGINAL_HASH="$(shasum -a 256 "$FAKE_ORIGINAL" | awk '{print $1}')"
cat > "$FAKE_MANIFEST_DIR/engine.manifest.json" <<EOF
{"engineVersion":"0.0.0-test","officialSwfVersion":"0.0.0","officialSwfSha256":"$ORIGINAL_HASH"}
EOF

# A private, isolated copy of the script pointed at the fixture root instead
# of the real repo layout (ROOT_DIR is hardcoded relative to the script's
# own location, so run it from a symlinked fixture root).
FIXTURE_ROOT="$WORK/repo"
mkdir -p "$FIXTURE_ROOT/tools/installer" "$FIXTURE_ROOT/build/output" "$FIXTURE_ROOT/engine"
cp "$INSTALL_SH" "$FIXTURE_ROOT/tools/installer/install.sh"
cp "$FAKE_MANIFEST_DIR/engine.manifest.json" "$FIXTURE_ROOT/engine/engine.manifest.json"
cp "$FAKE_MODDED" "$FIXTURE_ROOT/build/output/gazillionaire-modded.swf"

pass=0
fail=0
check() {
    if [ "$1" = "$2" ]; then
        pass=$((pass + 1))
    else
        echo "FAIL: $3 (expected [$2], got [$1])" >&2
        fail=$((fail + 1))
    fi
}

# 1. Hash-verified install succeeds, backs up, and patches.
bash "$FIXTURE_ROOT/tools/installer/install.sh" install --target "$FAKE_ORIGINAL"
check "$(cat "$FAKE_ORIGINAL.original-backup")" "original swf bytes" "backup preserves original bytes"
check "$(cat "$FAKE_ORIGINAL")" "modded swf bytes" "target patched with modded bytes"

# 2. A second install refuses to clobber the existing backup.
if bash "$FIXTURE_ROOT/tools/installer/install.sh" install --target "$FAKE_ORIGINAL" 2>/dev/null; then
    echo "FAIL: second install should have refused to overwrite existing backup" >&2
    fail=$((fail + 1))
else
    pass=$((pass + 1))
fi

# 3. Restore reverses the patch and re-verifies the hash.
bash "$FIXTURE_ROOT/tools/installer/install.sh" restore --target "$FAKE_ORIGINAL"
check "$(cat "$FAKE_ORIGINAL")" "original swf bytes" "restore returns original bytes"
check "$(test -e "$FAKE_ORIGINAL.original-backup" && echo yes || echo no)" "no" "restore removes the backup file"

# 4. A hash mismatch (tampered/wrong target) refuses to install.
echo "some unrelated file" > "$FAKE_ORIGINAL"
if bash "$FIXTURE_ROOT/tools/installer/install.sh" install --target "$FAKE_ORIGINAL" 2>/dev/null; then
    echo "FAIL: install should refuse on hash mismatch" >&2
    fail=$((fail + 1))
else
    pass=$((pass + 1))
fi

echo ""
echo "install.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
