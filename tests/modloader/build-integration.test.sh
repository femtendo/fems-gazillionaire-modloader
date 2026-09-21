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
CONVERT_TEST="$ROOT_DIR/mods/_examples/_convert-test"

cleanup() {
    if [ -n "$ENABLED_BACKUP" ]; then
        printf '%s' "$ENABLED_BACKUP" > "$ENABLED_JSON"
    else
        rm -f "$ENABLED_JSON"
    fi
    rm -rf "$CONFLICT_A" "$CONFLICT_B" "$CONVERT_TEST"
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

# 3. Loose-asset override of a fixture SWF-shaped [Embed] asset via a PNG
#    input must be converted (a real SWF, not a plain copy of the PNG
#    bytes) rather than copied byte-for-byte. engine/src/assets/127.bin is
#    a real (tiny, uncompressed "FWS") SWF-shaped [Embed] asset already
#    present in the engine source tree.
rm -rf build/output build/merged-src
mkdir -p "$CONVERT_TEST/assets"
cat > "$CONVERT_TEST/mod.json" <<'EOF'
{"id":"_convert-test","name":"Convert Test","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":[],"data":[],"assets":["127.bin"]},"priority":0}
EOF
# A minimal valid 1x1 PNG (same known-good byte literal used by
# tests/modloader/loose-assets.test.js) standing in for a modder's raster
# replacement of the SWF-shaped asset above.
node -e "
require('fs').writeFileSync(
    '$CONVERT_TEST/assets/127.bin',
    Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c63f8ffffff7f0009fb03fd2a86e38a0000000049454e44ae426082', 'hex')
);
"
echo '["_convert-test"]' > "$ENABLED_JSON"

set +e
CONVERT_OUT="$(node tools/modloader/build.js 2>&1)"
CONVERT_STATUS=$?
set -e
if [ "$CONVERT_STATUS" -ne 0 ]; then
    echo "FAIL: convert-test build should have succeeded" >&2
    echo "$CONVERT_OUT" >&2
    fail=$((fail + 1))
else
    pass=$((pass + 1))
fi
CONVERT_MERGED_DIR="$(find build/merged-src -mindepth 1 -maxdepth 1 -type d | head -1)"
CONVERTED_ASSET="$CONVERT_MERGED_DIR/assets/127.bin"
check "$(test -f "$CONVERTED_ASSET" && echo yes || echo no)" "yes" "converted asset was written to the merged tree"
ASSET_SIG="$(node -e "console.log(require('fs').readFileSync('$CONVERTED_ASSET').toString('ascii', 0, 3))" 2>/dev/null || true)"
case "$ASSET_SIG" in
    FWS|CWS|ZWS) check "yes" "yes" "PNG-replacing-SWF asset is converted to a real SWF (signature $ASSET_SIG), not copied byte-for-byte" ;;
    *) check "$ASSET_SIG" "FWS/CWS/ZWS" "PNG-replacing-SWF asset is converted to a real SWF, not copied byte-for-byte" ;;
esac

echo ""
echo "build-integration.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
