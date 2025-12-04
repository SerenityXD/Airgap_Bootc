#!/bin/bash
# Download Prism Launcher for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
OFFLINE_DIR="${SCRIPT_DIR}/image/offline-repo/prismlauncher"

echo "========================================"
echo "Fetch Prism Launcher"
echo "========================================"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

# Create offline directory
mkdir -p "$OFFLINE_DIR"

# Get latest release info
echo "Fetching latest Prism Launcher release info..."
RELEASE_INFO=$(curl -s https://api.github.com/repos/PrismLauncher/PrismLauncher/releases/latest)

# Extract tag name and build download URL
TAG_NAME=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$TAG_NAME" ]; then
    echo "Error: Could not find latest release"
    exit 1
fi

DOWNLOAD_URL="https://github.com/PrismLauncher/PrismLauncher/releases/download/${TAG_NAME}/PrismLauncher-Linux-x86_64.AppImage"

echo "Release: $TAG_NAME"
echo "Download URL: $DOWNLOAD_URL"
echo ""

# Download
echo "Downloading Prism Launcher..."
cd "$OFFLINE_DIR"
curl -L -o prism-launcher.AppImage "$DOWNLOAD_URL"
chmod +x prism-launcher.AppImage
ls -lh prism-launcher.AppImage
echo ""
echo "✓ Prism Launcher downloaded successfully"
echo ""
echo "Prism Launcher saved to: $OFFLINE_DIR"

