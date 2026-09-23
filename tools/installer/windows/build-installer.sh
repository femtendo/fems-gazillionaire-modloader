#!/usr/bin/env bash
# Packages build/output/gazillionaire-modded.swf, install.ps1, and their
# dependencies into a double-clickable Windows installer/uninstaller
# (GazillionaireOnlineSetup.exe), via NSIS (makensis). Cross-compiles fine
# on macOS/Linux — `brew install nsis` (or apt install nsis) — no Windows
# machine needed to produce the .exe.
#
# Run tools/modloader/build.js first to produce the SWF this packages.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUT_DIR="$ROOT_DIR/build/output/windows-installer"
PAYLOAD_DIR="$OUT_DIR/payload"
BUILT_SWF="$ROOT_DIR/build/output/gazillionaire-modded.swf"

command -v makensis >/dev/null 2>&1 || {
    echo "makensis not found — install NSIS first (macOS: brew install nsis; Debian/Ubuntu: apt install nsis)" >&2
    exit 1
}
[ -f "$BUILT_SWF" ] || {
    echo "No built SWF at $BUILT_SWF — run tools/modloader/build.js first" >&2
    exit 1
}

rm -rf "$OUT_DIR"
mkdir -p "$PAYLOAD_DIR/engine" \
         "$PAYLOAD_DIR/build/output/loose-assets" \
         "$PAYLOAD_DIR/tools/installer"

cp "$ROOT_DIR/engine/engine.manifest.json" "$PAYLOAD_DIR/engine/"
cp "$BUILT_SWF" "$PAYLOAD_DIR/build/output/"
# Empty manifest if no mod enabled loose-asset overrides — install.ps1
# handles a missing or empty one as a no-op either way.
cp "$ROOT_DIR/build/output/loose-assets/manifest.json" "$PAYLOAD_DIR/build/output/loose-assets/" 2>/dev/null || echo '[]' > "$PAYLOAD_DIR/build/output/loose-assets/manifest.json"
cp "$ROOT_DIR/tools/installer/install.ps1" "$PAYLOAD_DIR/tools/installer/"

cp "$SCRIPT_DIR/gazillionaire-online-setup.nsi" "$OUT_DIR/"
(cd "$OUT_DIR" && makensis gazillionaire-online-setup.nsi)

echo "Built: $OUT_DIR/GazillionaireOnlineSetup.exe"
