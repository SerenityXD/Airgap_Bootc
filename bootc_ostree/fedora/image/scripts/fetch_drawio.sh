#!/bin/bash
# Download draw.io (diagrams.net) for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_DIR="$(get_offline_dir "drawio" "${SCRIPT_PATH}")"
DRAWIO_VERSION="${DRAWIO_VERSION:-29.3.6}"

print_section "Fetch draw.io (diagrams.net)"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"
cd "${OFFLINE_DIR}"

# Download draw.io RPM for Fedora
echo "Downloading draw.io ${DRAWIO_VERSION}..."
DRAWIO_URL="https://github.com/jgraph/drawio-desktop/releases/download/v${DRAWIO_VERSION}/drawio-x86_64-${DRAWIO_VERSION}.rpm"

if download_file "${DRAWIO_URL}" "drawio-${DRAWIO_VERSION}.rpm"; then
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
print_section "Download Complete!"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "This RPM will be automatically included in the next ISO build."
echo "To rebuild with offline draw.io:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build-scripts/build_export_iso.sh --iso-name BOOTC.iso"
echo ""
