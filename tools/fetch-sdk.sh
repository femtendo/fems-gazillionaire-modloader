#!/usr/bin/env bash
# Downloads the Apache Flex SDK (with AIR support) and caches it under
# tools/.sdk/. Safe to re-run; skips work if already fetched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_DIR="$PROJECT_DIR/tools/.sdk"
FLEX_DIR="$SDK_DIR/flex"

mkdir -p "$SDK_DIR"

# Apache Flex SDK 4.16.1 (open-source reimplementation)
# Note: This may not include full AIR support. The Adobe Flex SDK 4.6.0
# is the original with AIR support, but is no longer officially distributed.
FLEX_URL="https://www.apache.org/dist/flex/4.16.1/binaries/apache-flex-sdk-4.16.1-bin.tar.gz"
FLEX_ARCHIVE="$SDK_DIR/apache-flex-sdk-4.16.1-bin.tar.gz"

# Adobe Flex SDK 4.6.0 (includes AIR support) - legacy URL
# This is the version that originally shipped with AIR SDK overlay
ADOBE_FLEX_URL="http://download.macromedia.com/pub/flex/sdk/builds/flex4.6/flex_sdk_4.6.0.23201B.zip"
ADOBE_FLEX_ARCHIVE="$SDK_DIR/adobe-flex-sdk-4.6.0.zip"

echo "=== Gazillionaire SDK Fetch Script ===" >&2
echo "Target directory: $SDK_DIR" >&2

# Check if mxmlc already exists and is executable
if [ -x "$FLEX_DIR/bin/mxmlc" ]; then
    echo "mxmlc already exists at $FLEX_DIR/bin/mxmlc, skipping download." >&2
    exit 0
fi

# Try Apache Flex SDK first
echo "Attempting to download Apache Flex SDK 4.16.1..." >&2
echo "URL: $FLEX_URL" >&2

if curl -sI "$FLEX_URL" | grep -q "200 OK"; then
    echo "Apache Flex SDK URL is valid." >&2
    
    if [ ! -f "$FLEX_ARCHIVE" ]; then
        echo "Downloading Apache Flex SDK..." >&2
        curl -L -o "$FLEX_ARCHIVE" "$FLEX_URL"
        if [ $? -ne 0 ]; then
            echo "Failed to download Apache Flex SDK." >&2
            exit 1
        fi
    else
        echo "Apache Flex SDK archive already exists, skipping download." >&2
    fi
    
    # Extract
    echo "Extracting Apache Flex SDK..." >&2
    mkdir -p "$FLEX_DIR"
    tar xzf "$FLEX_ARCHIVE" -C "$FLEX_DIR" --strip-components=1
    
    # Check for mxmlc
    if [ -x "$FLEX_DIR/bin/mxmlc" ]; then
        echo "Successfully extracted Apache Flex SDK." >&2
        echo "mxmlc location: $FLEX_DIR/bin/mxmlc" >&2
        exit 0
    else
        echo "Apache Flex SDK extracted but mxmlc not found." >&2
        echo "This SDK may not have full AIR support." >&2
    fi
else
    echo "Apache Flex SDK URL is not accessible." >&2
fi

# Try Adobe Flex SDK 4.6.0 (includes AIR support)
echo "Attempting to download Adobe Flex SDK 4.6.0 (with AIR support)..." >&2
echo "URL: $ADOBE_FLEX_URL" >&2

if curl -sI "$ADOBE_FLEX_URL" | grep -q "200 OK"; then
    echo "Adobe Flex SDK URL is valid." >&2
    
    if [ ! -f "$ADOBE_FLEX_ARCHIVE" ]; then
        echo "Downloading Adobe Flex SDK 4.6.0..." >&2
        curl -L -o "$ADOBE_FLEX_ARCHIVE" "$ADOBE_FLEX_URL"
        if [ $? -ne 0 ]; then
            echo "Failed to download Adobe Flex SDK." >&2
            exit 1
        fi
    else
        echo "Adobe Flex SDK archive already exists, skipping download." >&2
    fi
    
    # Extract
    echo "Extracting Adobe Flex SDK 4.6.0..." >&2
    mkdir -p "$FLEX_DIR"
    unzip -q "$ADOBE_FLEX_ARCHIVE" -d "$FLEX_DIR"
    
    # Check for mxmlc
    if [ -x "$FLEX_DIR/bin/mxmlc" ]; then
        echo "Successfully extracted Adobe Flex SDK 4.6.0." >&2
        echo "mxmlc location: $FLEX_DIR/bin/mxmlc" >&2
        exit 0
    else
        echo "Adobe Flex SDK extracted but mxmlc not found." >&2
    fi
else
    echo "Adobe Flex SDK URL is not accessible." >&2
fi

echo "ERROR: Could not download or extract Flex SDK with mxmlc." >&2
echo "Both download URLs failed or the extracted SDK is incomplete." >&2
exit 1
