#!/bin/bash
# Download CodeReady Containers (CRC) for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO
#
# Note: CRC requires a Red Hat account and pull secret to use
# Get pull secret from: https://cloud.redhat.com/openshift/create/local

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
OFFLINE_DIR="${SCRIPT_DIR}/image/offline-repo/crc"
CRC_VERSION="${CRC_VERSION:-2.42.0}"  # Update as needed

echo "========================================"
echo "Fetch CodeReady Containers (CRC)"
echo "========================================"
echo ""
echo "Version: ${CRC_VERSION}"
echo "Target directory: ${OFFLINE_DIR}"
echo ""
echo "Note: CRC requires:"
echo "  - Red Hat account (free at https://developers.redhat.com)"
echo "  - Pull secret (https://cloud.redhat.com/openshift/create/local)"
echo "  - 9 GB RAM minimum on target machine"
echo "  - 35 GB free disk space on target machine"
echo ""

mkdir -p "${OFFLINE_DIR}"
cd "${OFFLINE_DIR}"

# Download CRC binary
echo "[1/2] Downloading CRC ${CRC_VERSION}..."
CRC_URL="https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/${CRC_VERSION}/crc-linux-amd64.tar.xz"

if curl -fL "${CRC_URL}" -o crc-linux-amd64.tar.xz; then
    echo "  Extracting..."
    tar -xf crc-linux-amd64.tar.xz
    
    # Find the extracted directory (contains version in name)
    CRC_DIR=$(tar -tf crc-linux-amd64.tar.xz | head -1 | cut -f1 -d"/")
    
    if [ -d "${CRC_DIR}" ] && [ -f "${CRC_DIR}/crc" ]; then
        mv "${CRC_DIR}/crc" ./crc
        chmod +x crc
        rm -rf "${CRC_DIR}" crc-linux-amd64.tar.xz
        echo "  ✓ CRC binary downloaded: $(./crc version 2>/dev/null | head -1 || echo ${CRC_VERSION})"
    else
        echo "  ✗ Failed to extract CRC binary"
        exit 1
    fi
else
    echo "  ✗ Failed to download CRC"
    echo ""
    echo "  You may need to download manually:"
    echo "  1. Visit: https://developers.redhat.com/products/openshift-local/download"
    echo "  2. Download: crc-linux-amd64.tar.xz (version ${CRC_VERSION})"
    echo "  3. Extract and copy 'crc' binary to: ${OFFLINE_DIR}/crc"
    exit 1
fi

# Note about the OpenShift bundle
echo ""
echo "[2/2] OpenShift Bundle:"
echo "  The CRC OpenShift bundle (~9 GB) cannot be pre-downloaded for offline use"
echo "  without additional steps. Options:"
echo ""
echo "  A) Internet access on target (recommended):"
echo "     - CRC will download the bundle on first 'crc start'"
echo ""
echo "  B) Manual offline bundle (advanced):"
echo "     1. Run 'crc setup' and 'crc start' on an internet-connected machine"
echo "     2. Locate bundle: ~/.crc/cache/crc_*.crcbundle"
echo "     3. Copy bundle to target machine's ~/.crc/cache/"
echo "     4. Run 'crc start' on target (will use cached bundle)"
echo ""

echo "========================================"
echo "Download Complete!"
echo "========================================"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "The CRC binary will be automatically included in the next ISO build."
echo ""
echo "IMPORTANT: After installing the OS from ISO:"
echo "  1. Ensure target machine has internet OR pre-staged bundle"
echo "  2. Get pull secret: https://cloud.redhat.com/openshift/create/local"
echo "  3. Run: crc setup"
echo "  4. Run: crc start (will prompt for pull secret)"
echo ""
echo "To rebuild ISO with CRC:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build_export_iso.sh --iso-name SCVU.iso"
echo ""
