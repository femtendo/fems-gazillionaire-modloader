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
# restore: copies the backup back over the target, reverts the Info.plist
#   and application.xml patches applied by install, and re-verifies the
#   restored SWF's hash against the manifest.
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

# Patching a file inside a signed .app bundle invalidates the bundle's
# code signature (macOS seals every file's hash at sign time). On an
# unsigned/ad-hoc-signed seal like this game ships with, that doesn't
# block the process from launching, but the AIR captive runtime silently
# refuses to render its content window once the seal doesn't match — the
# app appears to run (visible in Activity Monitor / the Dock) with no
# window ever appearing. Re-sign ad hoc after patching so the seal covers
# the new bytes. Only relevant on macOS (Windows targets are unaffected —
# no code-signing seal to break).
resign_app_bundle_if_macos() {
    local target="$1"
    [ "$(uname)" = "Darwin" ] || return 0
    command -v codesign >/dev/null 2>&1 || return 0

    local dir
    dir="$(dirname "$target")"
    while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        case "$dir" in
            *.app)
                codesign --force --deep --sign - "$dir" 2>/dev/null || true
                return 0
                ;;
        esac
        dir="$(dirname "$dir")"
    done
}

# AIR creates the native content window (correct geometry, visible in
# CGWindowList) but macOS's own Automatic Termination feature doesn't
# recognize it as a real, open window — confirmed via the unified log
# (`_kLSApplicationWouldBeTerminatedByTALKey=1`, "No windows open yet")
# — and kills the app a few seconds after launch as a result, well before
# any AVM2/AS3-level explanation was ever the cause. Setting
# NSSupportsAutomaticTermination/NSSupportsSuddenTermination to false in
# Info.plist opts the whole app out of that OS-level idle-kill mechanism.
# Needs a resign after, same as the SWF patch. Only relevant on macOS.
patch_info_plist_if_macos() {
    local target="$1"
    [ "$(uname)" = "Darwin" ] || return 0
    command -v /usr/libexec/PlistBuddy >/dev/null 2>&1 || return 0

    local dir
    dir="$(dirname "$target")"
    while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        case "$dir" in
            *.app)
                local plist="$dir/Contents/Info.plist"
                [ -f "$plist" ] || return 0
                for key in NSSupportsAutomaticTermination NSSupportsSuddenTermination; do
                    if ! /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
                        /usr/libexec/PlistBuddy -c "Add :$key bool false" "$plist" 2>/dev/null || true
                    fi
                done
                return 0
                ;;
        esac
        dir="$(dirname "$dir")"
    done
}

# Reverses patch_info_plist_if_macos: removes the two keys it adds. Neither
# key exists in the original shipped Info.plist (verified against the
# pristine backup), so unconditionally deleting them on restore is safe —
# there's no pre-existing value to preserve.
unpatch_info_plist_if_macos() {
    local target="$1"
    [ "$(uname)" = "Darwin" ] || return 0
    command -v /usr/libexec/PlistBuddy >/dev/null 2>&1 || return 0

    local dir
    dir="$(dirname "$target")"
    while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        case "$dir" in
            *.app)
                local plist="$dir/Contents/Info.plist"
                [ -f "$plist" ] || return 0
                for key in NSSupportsAutomaticTermination NSSupportsSuddenTermination; do
                    /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" 2>/dev/null || true
                done
                return 0
                ;;
        esac
        dir="$(dirname "$dir")"
    done
}

# application.xml's <initialWindow><visible> is false by design — AIR's
# contract is that AS3 code flips it true once the app is ready. That
# handshake doesn't complete reliably in this environment: a class-level
# static-initializer diagLog probe (the earliest possible hook — fires
# before any constructor, independent of stage/window state) never fires
# across repeated relaunches, meaning the ActionScript VM doesn't get to
# start executing the SWF at all before AIR's own native code gives up.
# Forcing `nativeWindow.visible = true` from CustomPreloader.as (see that
# file) is therefore a no-op — that code never runs. The only thing that
# has been verified to actually work is flipping <visible> to true in the
# descriptor itself, sidestepping the broken AS3-never-runs handshake
# entirely: confirmed via CGWindowListCopyWindowInfo(.optionOnScreenOnly)
# actually containing the window (kCGWindowIsOnscreen: 1), not just
# .optionAll (which a hidden window also satisfies).
# IMPORTANT: this only works with a plain ad-hoc signature. Signing with
# the com.apple.security.get-task-allow entitlement (added for lldb
# debugging during development) was found to make this NOT work — the
# app cleanly self-terminates within ~80ms instead
# (applicationShouldTerminate: -> NSTerminateNow). Never add that
# entitlement to a real install/distribution build.
patch_visible_if_macos() {
    local target="$1"
    [ "$(uname)" = "Darwin" ] || return 0

    local dir
    dir="$(dirname "$target")"
    while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        case "$dir" in
            *.app)
                local descriptor="$dir/Contents/Resources/META-INF/AIR/application.xml"
                [ -f "$descriptor" ] || return 0
                sed -i '' 's|<visible>false</visible>|<visible>true</visible>|' "$descriptor" 2>/dev/null || true
                return 0
                ;;
        esac
        dir="$(dirname "$dir")"
    done
}

# Reverses patch_visible_if_macos: flips <visible> back to false, matching
# the original shipped descriptor.
unpatch_visible_if_macos() {
    local target="$1"
    [ "$(uname)" = "Darwin" ] || return 0

    local dir
    dir="$(dirname "$target")"
    while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        case "$dir" in
            *.app)
                local descriptor="$dir/Contents/Resources/META-INF/AIR/application.xml"
                [ -f "$descriptor" ] || return 0
                sed -i '' 's|<visible>true</visible>|<visible>false</visible>|' "$descriptor" 2>/dev/null || true
                return 0
                ;;
        esac
        dir="$(dirname "$dir")"
    done
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
LOOSE_ASSETS_DIR="$ROOT_DIR/build/output/loose-assets"
LOOSE_ASSETS_MANIFEST="$LOOSE_ASSETS_DIR/manifest.json"
RESOURCES_DIR="$(dirname "$TARGET")"

install_loose_assets() {
    [ -f "$LOOSE_ASSETS_MANIFEST" ] || return 0
    node -e "JSON.parse(require('fs').readFileSync('$LOOSE_ASSETS_MANIFEST','utf8')).forEach(p=>console.log(p))" | \
    while IFS= read -r rel; do
        local dest="$RESOURCES_DIR/$rel"
        local backup="${dest}.original-backup"
        [ -f "$dest" ] || { echo "Warning: loose asset target not found, skipping: $dest" >&2; continue; }
        if [ -e "$backup" ]; then
            echo "Loose-asset backup already exists at $backup — refusing to overwrite it." >&2
            exit 1
        fi
        cp "$dest" "$backup"
        cp "$LOOSE_ASSETS_DIR/$rel" "$dest"
    done
}

restore_loose_assets() {
    if [ -f "$LOOSE_ASSETS_MANIFEST" ]; then
        node -e "JSON.parse(require('fs').readFileSync('$LOOSE_ASSETS_MANIFEST','utf8')).forEach(p=>console.log(p))" | \
        while IFS= read -r rel; do
            local dest="$RESOURCES_DIR/$rel"
            local backup="${dest}.original-backup"
            [ -f "$backup" ] || continue
            cp "$backup" "$dest"
            rm "$backup"
        done
    fi

    # The current build's manifest reflects the mod set enabled *now*, which
    # can differ from what was actually installed (mods added/removed/
    # reordered between install and restore). Sweep the three loose-asset
    # target folders directly for any leftover *.original-backup files so a
    # mod-set change between install and restore can never orphan a modded
    # file with its original permanently un-recoverable.
    for sub in SWF PNG MP3; do
        local dir="$RESOURCES_DIR/$sub"
        [ -d "$dir" ] || continue
        find "$dir" -maxdepth 1 -type f -name '*.original-backup' | while IFS= read -r backup; do
            local dest="${backup%.original-backup}"
            cp "$backup" "$dest"
            rm "$backup"
        done
    done
}

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
        patch_info_plist_if_macos "$TARGET"
        patch_visible_if_macos "$TARGET"
        install_loose_assets
        resign_app_bundle_if_macos "$TARGET"
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
        unpatch_info_plist_if_macos "$TARGET"
        unpatch_visible_if_macos "$TARGET"
        restore_loose_assets
        resign_app_bundle_if_macos "$TARGET"
        echo "Restored original SWF to $TARGET, reverted Info.plist/application.xml patches, and removed the backup."
        ;;

    *)
        usage
        ;;
esac
