#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/fetch_all_offline.sh"

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

DRY_RUN=true INCLUDE_OPTIONAL_FETCH=true "$SCRIPT" >"$output_file"

grep -q "Fetch Summary" "$output_file"
grep -q "All Fetch Operations Complete" "$output_file"
grep -q "GIMP" "$output_file"
grep -q "Krita" "$output_file"
grep -q "VS Code Extensions" "$output_file"
grep -q "npm Tarballs" "$output_file"

echo "Dry-run workflow test passed."
