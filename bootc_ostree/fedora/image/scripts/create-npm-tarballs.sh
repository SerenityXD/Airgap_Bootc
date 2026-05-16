#!/usr/bin/env bash
set -euo pipefail

# create-npm-tarballs.sh
# Usage: ./create-npm-tarballs.sh [--dest DIR]
# This script reads package names (optionally with pinned versions) from
# image/offline-repo/npm-packages/package-versions.txt and runs `npm pack`
# to produce .tgz tarballs suitable for offline installation. Tarballs are
# moved into the destination directory (default: image/offline-repo/npm-packages/).

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$HERE/scripts/package-versions.txt"
DEFAULT_DEST="$HERE/offline-repo/npm-packages"
DEST="${1:-$DEFAULT_DEST}"

if ! command -v npm >/dev/null 2>&1; then
    echo "Error: npm not found in PATH. Run this script on an internet-enabled machine with npm installed." >&2
    exit 2
fi

if [ ! -f "$MANIFEST" ]; then
    echo "Manifest $MANIFEST not found. Create it with package[@version] per-line." >&2
    exit 1
fi

mkdir -p "$DEST"
chmod 0755 "$DEST"

while IFS= read -r line || [ -n "$line" ]; do
    # skip comments and blank lines
    line="${line%%#*}"
    line="$(echo -n "$line" | tr -d '\r' | xargs)"
    [ -z "$line" ] && continue

    pkg="$line"
    echo "Packing $pkg..."
    # npm pack writes tarball into CWD; use a temp dir then move
    tmpd=$(mktemp -d)
    pushd "$tmpd" >/dev/null
    if npm pack "$pkg" >/dev/null 2>&1; then
        tgz=$(ls *.tgz 2>/dev/null | head -n1)
        if [ -n "$tgz" ]; then
            mv -f "$tgz" "$DEST/"
            echo "  -> $DEST/$tgz"
        else
            echo "  Warning: npm pack produced no tarball for $pkg"
        fi
    else
        echo "  Warning: npm pack failed for $pkg" >&2
    fi
    popd >/dev/null
    rm -rf "$tmpd"
done < "$MANIFEST"

echo "Done. Tarballs placed in: $DEST"
