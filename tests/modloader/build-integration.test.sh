#!/usr/bin/env bash
# End-to-end checks for tools/modloader/build.js against the real engine
# source and real mxmlc — not the pure-logic unit tests in conflicts.test.js.
# Mutates mods/enabled.json and build/ (both gitignored/scratch) and
# restores enabled.json when done. Requires tools/fetch-sdk.sh to have run.
# Run directly: bash tests/modloader/build-integration.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

ENABLED_JSON="$ROOT_DIR/mods/enabled.json"
ENABLED_BACKUP=""
if [ -f "$ENABLED_JSON" ]; then
    ENABLED_BACKUP="$(cat "$ENABLED_JSON")"
fi

CONFLICT_A="$ROOT_DIR/mods/_examples/_conflict-test-a"
CONFLICT_B="$ROOT_DIR/mods/_examples/_conflict-test-b"

cleanup() {
    if [ -n "$ENABLED_BACKUP" ]; then
        printf '%s' "$ENABLED_BACKUP" > "$ENABLED_JSON"
    else
        rm -f "$ENABLED_JSON"
    fi
    rm -rf "$CONFLICT_A" "$CONFLICT_B"
}
trap cleanup EXIT

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

# 1. Stacking: two disjoint example mods enabled together build cleanly and
#    both overrides land in the merged source tree.
rm -rf build/output build/merged-src
echo '["hello-world-example", "second-example"]' > "$ENABLED_JSON"
if node tools/modloader/build.js > /tmp/gaz-build-stack.log 2>&1; then
    pass=$((pass + 1))
else
    echo "FAIL: stacking build should have succeeded" >&2
    cat /tmp/gaz-build-stack.log >&2
    fail=$((fail + 1))
fi
check "$(test -f build/output/gazillionaire-modded.swf && echo yes || echo no)" "yes" "stacking build produced an output swf"
MERGED_DIR="$(find build/merged-src -mindepth 1 -maxdepth 1 -type d | head -1)"
check "$(grep -l "HELLO WORLD MOD ACTIVE" "$MERGED_DIR/GameStrings.as" >/dev/null 2>&1 && echo yes || echo no)" "yes" "merged tree has hello-world-example's override"
check "$(grep -l "new Timer(10)" "$MERGED_DIR/LoadScreen.as" >/dev/null 2>&1 && echo yes || echo no)" "yes" "merged tree has second-example's override"
check "$(grep -c "HELLO WORLD MOD ACTIVE" engine/src/GameStrings.as || true)" "0" "engine/src stays untouched by the build"

# 2. Real hard conflict: two mods, equal priority, overlapping touches.classes
#    must abort the build before compiling, naming both mods and the overlap.
mkdir -p "$CONFLICT_A/src" "$CONFLICT_B/src"
cat > "$CONFLICT_A/mod.json" <<'EOF'
{"id":"_conflict-test-a","name":"Conflict Test A","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":["LoadScreen"],"data":[],"assets":[]},"priority":0}
EOF
cat > "$CONFLICT_B/mod.json" <<'EOF'
{"id":"_conflict-test-b","name":"Conflict Test B","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":["LoadScreen"],"data":[],"assets":[]},"priority":0}
EOF
cp engine/src/LoadScreen.as "$CONFLICT_A/src/LoadScreen.as"
cp engine/src/LoadScreen.as "$CONFLICT_B/src/LoadScreen.as"
echo '["_conflict-test-a", "_conflict-test-b"]' > "$ENABLED_JSON"

set +e
CONFLICT_OUT="$(node tools/modloader/build.js 2>&1)"
CONFLICT_STATUS=$?
set -e
check "$CONFLICT_STATUS" "1" "conflicting build exits non-zero"
check "$(echo "$CONFLICT_OUT" | grep -q "_conflict-test-a" && echo yes || echo no)" "yes" "conflict output names mod a"
check "$(echo "$CONFLICT_OUT" | grep -q "_conflict-test-b" && echo yes || echo no)" "yes" "conflict output names mod b"
check "$(echo "$CONFLICT_OUT" | grep -q "LoadScreen" && echo yes || echo no)" "yes" "conflict output names the overlapping class"

echo ""
echo "build-integration.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
