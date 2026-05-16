#!/usr/bin/env bash
# Backward-compatible shim.
# Main implementation now lives in build_export_iso.sh.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build_export_iso.sh"

if [[ ! -x "$BUILD_SCRIPT" ]]; then
  echo "Error: Build script not found or not executable: $BUILD_SCRIPT" >&2
  exit 1
fi

echo "Notice: $(basename "$0") is now a compatibility wrapper."
echo "        Use $(basename "$BUILD_SCRIPT") directly for all modes."
exec "$BUILD_SCRIPT" "$@"
