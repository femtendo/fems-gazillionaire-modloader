#!/usr/bin/env bash
# Downloads the Apache Flex SDK and AIR SDK needed to build the game,
# merges them per the standard AIR overlay procedure, and caches the
# result under tools/.sdk/. Safe to re-run; skips work if already fetched.
set -euo pipefail

SDK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/.sdk"
mkdir -p "$SDK_DIR"

echo "TODO: download Apache Flex SDK and AIR SDK into $SDK_DIR" >&2
exit 1
