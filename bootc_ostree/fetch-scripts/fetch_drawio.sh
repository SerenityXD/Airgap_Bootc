#!/bin/bash
# Download draw.io (diagrams.net) for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE_DIR="${SCRIPT_DIR}/image/offline-repo/drawio"
DRAWIO_VERSION="${DRAWIO_VERSION:-latest}"

echo "========================================"
echo "Fetch draw.io (diagrams.net)"
echo "========================================"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"
cd "${OFFLINE_DIR}"

# Get latest version if not specified
if [ "${DRAWIO_VERSION}" = "latest" ]; then
    echo "Fetching latest draw.io version..."
    DRAWIO_VERSION=$(curl -sL https://api.github.com/repos/jgraph/drawio-desktop/releases/latest | grep -Po '"tag_name": "v\K[^"]*' || echo "24.7.17")
    echo "  Latest version: ${DRAWIO_VERSION}"
fi

# Download draw.io RPM for Fedora
echo "Downloading draw.io ${DRAWIO_VERSION}..."
DRAWIO_URL="https://github.com/jgraph/drawio-desktop/releases/download/v${DRAWIO_VERSION}/drawio-x86_64-${DRAWIO_VERSION}.rpm"

if curl -fL "${DRAWIO_URL}" -o "drawio-${DRAWIO_VERSION}.rpm"; then
    echo "  ✓ draw.io downloaded: drawio-${DRAWIO_VERSION}.rpm"
    
    # Verify it's a valid RPM
    if rpm -qp "drawio-${DRAWIO_VERSION}.rpm" &>/dev/null; then
        echo "  ✓ RPM verified"
    else
        echo "  ⚠ RPM verification failed (may still work)"
    fi
else
    echo "  ✗ Failed to download draw.io"
    echo ""
    echo "  Manual download:"
    echo "  1. Visit: https://github.com/jgraph/drawio-desktop/releases"
    echo "  2. Download: drawio-x86_64-*.rpm"
    echo "  3. Save to: ${OFFLINE_DIR}/"
    exit 1
fi

echo ""
echo "========================================"
echo "Download Complete!"
echo "========================================"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "This RPM will be automatically included in the next ISO build."
echo "To rebuild with offline draw.io:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build_export_iso.sh --iso-name SCVU.iso"
echo ""
