#!/usr/bin/env bash
# Packages build/output/gazillionaire-modded.swf, install.ps1, and their
# dependencies into a plain .bat + PowerShell bundle
# (GazillionaireOnline-Windows.zip) — no compiled .exe. Prefer this over
# build-installer.sh's NSIS .exe if antivirus/Google Drive flags the
# unsigned exe as a false positive (common for unsigned NSIS installers);
# a .bat/.ps1 zip has no binary for a heuristic scanner to flag.
#
# Run tools/modloader/build.js first to produce the SWF this packages.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUT_DIR="$ROOT_DIR/build/output/windows-portable"
PAYLOAD_DIR="$OUT_DIR/GazillionaireOnline"
BUILT_SWF="$ROOT_DIR/build/output/gazillionaire-modded.swf"

command -v zip >/dev/null 2>&1 || {
    echo "zip not found on PATH" >&2
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
cp "$ROOT_DIR/build/output/loose-assets/manifest.json" "$PAYLOAD_DIR/build/output/loose-assets/" 2>/dev/null || echo '[]' > "$PAYLOAD_DIR/build/output/loose-assets/manifest.json"
cp "$ROOT_DIR/tools/installer/install.ps1" "$PAYLOAD_DIR/tools/installer/"
cp "$SCRIPT_DIR/Install.bat" "$SCRIPT_DIR/Uninstall.bat" "$PAYLOAD_DIR/"

(cd "$OUT_DIR" && rm -f GazillionaireOnline-Windows.zip && zip -rq GazillionaireOnline-Windows.zip GazillionaireOnline)

echo "Built: $OUT_DIR/GazillionaireOnline-Windows.zip"
