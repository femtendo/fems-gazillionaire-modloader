#!/usr/bin/env bash
# Installer/patcher for the Gazillionaire mod build.
#
# Usage:
#   install.sh install [--target <path-to-Gazillionaire.swf>]
#   install.sh restore [--target <path-to-Gazillionaire.swf>]
#
# install: hash-verifies the target SWF against engine/engine.manifest.json,
#   backs it up (refusing to clobber an existing backup), then copies
#   build/output/gazillionaire-modded.swf into place.
# restore: copies the backup back over the target and re-verifies its hash
#   against the manifest.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$ROOT_DIR/engine/engine.manifest.json"
BUILT_SWF="$ROOT_DIR/build/output/gazillionaire-modded.swf"
DEFAULT_TARGET="$HOME/Library/Application Support/Steam/steamapps/common/Gazillionaire/Gazillionaire.app/Contents/Resources/Gazillionaire.swf"

usage() {
    echo "Usage: $0 {install|restore} [--target <path>]" >&2
    exit 1
}

sha256_of() {
    shasum -a 256 "$1" | awk '{print $1}'
}

read_manifest_hash() {
    node -e "console.log(require('$MANIFEST').officialSwfSha256)"
}

[ $# -ge 1 ] || usage
COMMAND="$1"
shift

TARGET="$DEFAULT_TARGET"
while [ $# -gt 0 ]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

BACKUP="${TARGET}.original-backup"

case "$COMMAND" in
    install)
        [ -f "$TARGET" ] || { echo "Target SWF not found: $TARGET" >&2; exit 1; }
        [ -f "$BUILT_SWF" ] || { echo "No built SWF at $BUILT_SWF — run tools/modloader/build.js first" >&2; exit 1; }

        EXPECTED_HASH="$(read_manifest_hash)"
        ACTUAL_HASH="$(sha256_of "$TARGET")"
        if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
            echo "Hash mismatch — refusing to patch." >&2
            echo "  expected: $EXPECTED_HASH" >&2
            echo "  actual:   $ACTUAL_HASH" >&2
            exit 1
        fi

        if [ -e "$BACKUP" ]; then
            echo "Backup already exists at $BACKUP — refusing to overwrite it." >&2
            echo "(If you want to re-install from a clean state, restore first.)" >&2
            exit 1
        fi

        cp "$TARGET" "$BACKUP"
        cp "$BUILT_SWF" "$TARGET"
        echo "Installed. Original backed up to $BACKUP"
        ;;

    restore)
        [ -f "$BACKUP" ] || { echo "No backup found at $BACKUP — nothing to restore." >&2; exit 1; }

        EXPECTED_HASH="$(read_manifest_hash)"
        BACKUP_HASH="$(sha256_of "$BACKUP")"
        if [ "$BACKUP_HASH" != "$EXPECTED_HASH" ]; then
            echo "Backup hash does not match the known-good manifest hash — refusing to restore a corrupt backup." >&2
            echo "  expected: $EXPECTED_HASH" >&2
            echo "  backup:   $BACKUP_HASH" >&2
            exit 1
        fi

        cp "$BACKUP" "$TARGET"
        rm "$BACKUP"
        echo "Restored original SWF to $TARGET and removed the backup."
        ;;

    *)
        usage
        ;;
esac
