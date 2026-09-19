#!/usr/bin/env bash
# Downloads the Apache Flex SDK and overlays the HARMAN AIR SDK on top of it
# (Apache Flex distributions don't bundle AIR since Adobe donated Flex to
# Apache — Adobe kept AIR, now stewarded by HARMAN). Caches under
# tools/.sdk/. Safe to re-run; skips work if already fetched.
#
# Requires: curl, tar, java (for ant + adt), ant (`brew install ant`).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_DIR="$PROJECT_DIR/tools/.sdk"
FLEX_DIR="$SDK_DIR/flex"

mkdir -p "$SDK_DIR"

# Apache Flex SDK 4.16.1 — this is the actual version the shipped game was
# built with (confirmed via swfdump's ProductInfo tag on the real SWF: Adobe
# Flex "4.16" build 20171115). Use archive.apache.org, not www.apache.org/dist
# — the latter only serves current releases and 404s (redirects, technically)
# for anything superseded; 4.16.1 has been archived since 4.16.2/4.17 shipped.
FLEX_URL="https://archive.apache.org/dist/flex/4.16.1/binaries/apache-flex-sdk-4.16.1-bin.tar.gz"
FLEX_ARCHIVE="$SDK_DIR/apache-flex-sdk-4.16.1-bin.tar.gz"

# HARMAN AIR SDK, "Flex" overlay variant (no ActionScript compiler, meant to
# be merged into an existing Flex SDK). Picked 33.1.1.935 as the closest
# available match to the captive runtime this game actually ships
# (Contents/Frameworks/Adobe AIR.framework reports 32.0.0.116) — HARMAN's
# download API 500s for most releases older than the 33.x line, so an exact
# 32.0.0.116 match isn't available; 33.1.1.935 is the nearest confirmed-
# working one. If a build problem ever traces back to an AIR API/runtime
# mismatch, try a different 33.x build via AIR_SDK_VERSION below.
AIR_SDK_VERSION="${AIR_SDK_VERSION:-33.1.1.935}"
AIR_ARCHIVE="$SDK_DIR/AIRSDK_Flex_MacOS.zip"
HARMAN_INSTALLER_URL="https://raw.githubusercontent.com/joshtynjala/setup-apache-flex-action/master/harman-installer.xml"
HARMAN_INSTALLER="$SDK_DIR/harman-installer.xml"

echo "=== Gazillionaire SDK Fetch Script ===" >&2
echo "Target directory: $SDK_DIR" >&2

# Already fetched and overlaid — air-config.xml only resolves once the AIR
# overlay has actually run, so checking for its libs/air dir (not just
# mxmlc) is what tells us the overlay step already succeeded.
if [ -x "$FLEX_DIR/bin/mxmlc" ] && [ -d "$FLEX_DIR/frameworks/libs/air" ]; then
    echo "Flex SDK + AIR overlay already present at $FLEX_DIR, skipping." >&2
    exit 0
fi

command -v ant >/dev/null 2>&1 || {
    echo "ERROR: 'ant' is required to overlay the AIR SDK onto Flex (brew install ant)." >&2
    exit 1
}

echo "Downloading Apache Flex SDK 4.16.1..." >&2
[ -f "$FLEX_ARCHIVE" ] || curl -fL -o "$FLEX_ARCHIVE" "$FLEX_URL"

echo "Extracting Apache Flex SDK..." >&2
rm -rf "$FLEX_DIR"
mkdir -p "$FLEX_DIR"
tar xzf "$FLEX_ARCHIVE" -C "$FLEX_DIR" --strip-components=1

[ -x "$FLEX_DIR/bin/mxmlc" ] || {
    echo "ERROR: Apache Flex SDK extracted but mxmlc not found at $FLEX_DIR/bin/mxmlc" >&2
    exit 1
}

echo "Downloading HARMAN AIR SDK $AIR_SDK_VERSION (Flex overlay variant)..." >&2
[ -f "$AIR_ARCHIVE" ] || curl -fL -o "$AIR_ARCHIVE" \
    "https://airsdk.harman.com/api/versions/$AIR_SDK_VERSION/sdks/AIRSDK_Flex_MacOS.zip?license=accepted"
file "$AIR_ARCHIVE" | grep -q "Zip archive" || {
    echo "ERROR: downloaded AIR SDK archive isn't a zip (HARMAN's API sometimes" >&2
    echo "500s or serves an HTML error page for a given version) — try a" >&2
    echo "different AIR_SDK_VERSION= and re-run." >&2
    rm -f "$AIR_ARCHIVE"
    exit 1
}

echo "Downloading harman-installer.xml (Apache Flex + AIR overlay script)..." >&2
curl -fL -o "$HARMAN_INSTALLER" "$HARMAN_INSTALLER_URL"

echo "Overlaying AIR SDK onto Flex SDK (this runs mxmlc/adt/playerglobal setup via ant)..." >&2
cp "$AIR_ARCHIVE" "$FLEX_DIR/AIRSDK_Flex_MacOS.zip"
cp "$HARMAN_INSTALLER" "$FLEX_DIR/harman-installer.xml"
(cd "$FLEX_DIR" && ant -f harman-installer.xml "-Dair.sdk.version=${AIR_SDK_VERSION%.*.*}")
rm -f "$FLEX_DIR/AIRSDK_Flex_MacOS.zip" "$FLEX_DIR/harman-installer.xml"

[ -d "$FLEX_DIR/frameworks/libs/air" ] || {
    echo "ERROR: AIR overlay ran but frameworks/libs/air wasn't created — check the ant output above." >&2
    exit 1
}

# The AIR overlay merges the AIR SDK's files into $FLEX_DIR but leaves
# air-config.xml's {airHome} tokens unresolved — mxmlc's launch script only
# substitutes {airHome} from an AIR_HOME env var, or an env.AIR_HOME
# property in $FLEX_HOME/env.properties (see env-template.properties).
# Without this, every AIR-targeted compile fails with
# "unable to open '{airHome}/frameworks/libs/air'".
echo "env.AIR_HOME=$FLEX_DIR" > "$FLEX_DIR/env.properties"

echo "Done. mxmlc: $FLEX_DIR/bin/mxmlc (Apache Flex 4.16.1 + AIR $AIR_SDK_VERSION)" >&2
