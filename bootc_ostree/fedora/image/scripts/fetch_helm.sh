#!/bin/bash
# Download Helm package manager for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_DIR="$(get_offline_dir "helm" "${SCRIPT_PATH}")"
HELM_VERSION="${HELM_VERSION:-stable}"  # Can set to specific version like "v3.14.0"

print_section "Fetch Helm Package Manager"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"
cd "${OFFLINE_DIR}"

# Download helm
echo "[1/1] Downloading helm..."
if [ "${HELM_VERSION}" = "stable" ]; then
    HELM_VERSION=$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | grep -oP '"tag_name": "\K[^"]*')
fi

HELM_URL="https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"

if download_file "${HELM_URL}" helm.tar.gz; then
    echo "  Extracting..."
    tar -xzf helm.tar.gz
    rm -f helm.tar.gz
    if [ -f linux-amd64/helm ]; then
        mv linux-amd64/helm ./helm
        chmod +x helm
        rmdir linux-amd64 2>/dev/null || true
    fi
    
    if [ -f helm ]; then
        echo "  ✓ helm downloaded: $(./helm version --short 2>/dev/null | head -1 || echo 'version check skipped')"
    fi
else
    echo "  ✗ Failed to download helm"
    echo "  Manual download: https://github.com/helm/helm/releases"
    exit 1
fi

echo ""
print_section "Download Complete!"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "These binaries will be automatically included in the next ISO build."
echo "To rebuild with offline helm:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build-scripts/build_export_iso.sh --iso-name BOOTC.iso"
echo ""
