#!/usr/bin/env bash
# Full-feature headless test battery for the mod framework: every override
# kind (class, new class, asset, data), both merge outcomes (disjoint
# stacking, key-level data merge) and both guard rails (touches validation,
# engineCompat), plus cache reuse. Runs the real build.js end to end against
# the real engine — not synthetic fixtures standing in for it.
# Mutates mods/enabled.json and build/ (gitignored scratch); restores
# enabled.json on exit. Run directly: bash tests/modloader/full-feature.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

ENABLED_JSON="$ROOT_DIR/mods/enabled.json"
ENABLED_BACKUP=""
if [ -f "$ENABLED_JSON" ]; then
    ENABLED_BACKUP="$(cat "$ENABLED_JSON")"
fi

# Temp fixture mods all live under mods/_examples/_* (leading underscore —
# no real example mod is named that way) so cleanup can be a single glob
# instead of tracking an array across subshells (mktempmod's mkdir runs in
# a command-substitution subshell, so an array it appended to wouldn't be
# visible here anyway).
cleanup() {
    local status=$?
    if [ -n "$ENABLED_BACKUP" ]; then
        printf '%s' "$ENABLED_BACKUP" > "$ENABLED_JSON"
    else
        rm -f "$ENABLED_JSON"
    fi
    rm -rf mods/_examples/_*
    exit "$status"
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

mktempmod() {
    local dir="$ROOT_DIR/mods/_examples/$1"
    mkdir -p "$dir"
    echo "$dir"
}

# 1. Full stack: class override + new class + asset override + two disjoint
#    data mods, all enabled together, must build clean in one pass.
rm -rf build/output build/merged-src
echo '["hello-world-example","third-example","fourth-example","fifth-example","sixth-example"]' > "$ENABLED_JSON"
if node tools/modloader/build.js > /tmp/gaz-full-stack.log 2>&1; then
    pass=$((pass + 1))
else
    echo "FAIL: full 5-mod stack should have built" >&2
    cat /tmp/gaz-full-stack.log >&2
    fail=$((fail + 1))
fi
MERGED_DIR="$(find build/merged-src -mindepth 1 -maxdepth 1 -type d | head -1)"
check "$(test -f build/output/gazillionaire-modded.swf && echo yes || echo no)" "yes" "full stack produced an output swf"
check "$(test -f "$MERGED_DIR/ModWelcomeBanner.as" && echo yes || echo no)" "yes" "new class landed in merged tree"
check "$(cmp -s "$MERGED_DIR/assets/109.png" mods/_examples/fourth-example-asset-override/assets/109.png && echo yes || echo no)" "yes" "asset override landed in merged tree"
check "$(python3 -c "import json;d=json.load(open('$MERGED_DIR/data/balance.json'));print('yes' if d.get('fuelPriceMultiplier')==0.75 and d.get('startingCash')==10000 else 'no')")" "yes" "disjoint data keys merged into one file"

# 2. Cache hit: rebuilding the identical mod set reuses the merged tree.
# (Captured to a file rather than piped to grep — under pipefail, a broken
# pipe from grep -q's early exit would otherwise fail the pipeline even
# when the match succeeds.)
node tools/modloader/build.js > /tmp/gaz-cache-hit.log 2>&1
check "$(grep -q "Cache hit" /tmp/gaz-cache-hit.log && echo yes || echo no)" "yes" "second identical build reports a cache hit"

# 3. Data key conflict: two mods setting the SAME key, equal priority, must
#    hard-fail (the key-level exception to full-file conflict still conflicts
#    when the key itself actually overlaps).
A="$(mktempmod _data-conflict-a)"; B="$(mktempmod _data-conflict-b)"
for d in "$A" "$B"; do mkdir -p "$d/data"; done
cat > "$A/mod.json" <<'EOF'
{"id":"_data-conflict-a","name":"a","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":[],"data":["balance.json"],"assets":[]},"priority":0}
EOF
cat > "$B/mod.json" <<'EOF'
{"id":"_data-conflict-b","name":"b","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":[],"data":["balance.json"],"assets":[]},"priority":0}
EOF
echo '{"fuelPriceMultiplier": 0.5}' > "$A/data/balance.json"
echo '{"fuelPriceMultiplier": 0.9}' > "$B/data/balance.json"
echo '["_data-conflict-a","_data-conflict-b"]' > "$ENABLED_JSON"
set +e
OUT="$(node tools/modloader/build.js 2>&1)"; STATUS=$?
set -e
check "$STATUS" "1" "same-key equal-priority data conflict aborts the build"
check "$(echo "$OUT" | grep -q "fuelPriceMultiplier" && echo yes || echo no)" "yes" "conflict output names the overlapping key"

# 4. Priority suppression via a REAL build (not just the pure-logic unit
#    test): two mods override the same class at different priority; the
#    build must succeed and the higher-priority mod's file must win.
LOW="$(mktempmod _priority-low)"; HIGH="$(mktempmod _priority-high)"
mkdir -p "$LOW/src" "$HIGH/src"
cat > "$LOW/mod.json" <<'EOF'
{"id":"_priority-low","name":"low","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":["ModWelcomeBanner"],"data":[],"assets":[]},"priority":0}
EOF
cat > "$HIGH/mod.json" <<'EOF'
{"id":"_priority-high","name":"high","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":["ModWelcomeBanner"],"data":[],"assets":[]},"priority":5}
EOF
sed 's/third-example mod loaded/LOW PRIORITY LOST/' mods/_examples/third-example-new-class/src/ModWelcomeBanner.as > "$LOW/src/ModWelcomeBanner.as"
sed 's/third-example mod loaded/HIGH PRIORITY WON/' mods/_examples/third-example-new-class/src/ModWelcomeBanner.as > "$HIGH/src/ModWelcomeBanner.as"
rm -rf build/output build/merged-src
echo '["_priority-low","_priority-high"]' > "$ENABLED_JSON"
if node tools/modloader/build.js > /tmp/gaz-priority.log 2>&1; then
    pass=$((pass + 1))
else
    echo "FAIL: differing-priority overlap should build with a warning, not fail" >&2
    cat /tmp/gaz-priority.log >&2
    fail=$((fail + 1))
fi
check "$(grep -q "suppresses" /tmp/gaz-priority.log && echo yes || echo no)" "yes" "suppression warning printed"
PRIORITY_MERGED="$(find build/merged-src -mindepth 1 -maxdepth 1 -type d | head -1)"
check "$(grep -q "HIGH PRIORITY WON" "$PRIORITY_MERGED/ModWelcomeBanner.as" && echo yes || echo no)" "yes" "higher-priority mod's file wins in the merged tree"
check "$(grep -q "LOW PRIORITY LOST" "$PRIORITY_MERGED/ModWelcomeBanner.as" && echo yes || echo no)" "no" "lower-priority mod's file does not survive"

# 5. Touches validation: a mod with an undeclared extra file must be rejected
#    before compiling, not silently built.
LIAR="$(mktempmod _touches-liar)"
mkdir -p "$LIAR/src"
cat > "$LIAR/mod.json" <<'EOF'
{"id":"_touches-liar","name":"liar","version":"1.0.0","engineCompat":">=0.1.0","touches":{"classes":[],"data":[],"assets":[]},"priority":0}
EOF
echo 'package { public class Sneaky {} }' > "$LIAR/src/Sneaky.as"
echo '["_touches-liar"]' > "$ENABLED_JSON"
set +e
OUT="$(node tools/modloader/build.js 2>&1)"; STATUS=$?
set -e
check "$STATUS" "1" "undeclared file in a mod aborts the build"
check "$(echo "$OUT" | grep -q "Sneaky" && echo yes || echo no)" "yes" "validation output names the undeclared file"

# 6. engineCompat: a mod requiring a newer engine than we have must be
#    rejected before compiling.
FUTURE="$(mktempmod _future-mod)"
mkdir -p "$FUTURE/src"
cat > "$FUTURE/mod.json" <<'EOF'
{"id":"_future-mod","name":"future","version":"1.0.0","engineCompat":">=99.0.0","touches":{"classes":[],"data":[],"assets":[]},"priority":0}
EOF
echo '["_future-mod"]' > "$ENABLED_JSON"
set +e
OUT="$(node tools/modloader/build.js 2>&1)"; STATUS=$?
set -e
check "$STATUS" "1" "engineCompat violation aborts the build"
check "$(echo "$OUT" | grep -q "engineCompat" && echo yes || echo no)" "yes" "engineCompat output names the mismatch"

echo ""
echo "full-feature.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
