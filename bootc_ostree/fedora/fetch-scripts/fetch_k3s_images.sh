#!/bin/bash
# Download k3s air-gap image archive for offline use
# Run this on an internet-connected machine before building the ISO

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_DIR="$(get_offline_dir "k3s" "${SCRIPT_PATH}")"
K3S_VERSION="${K3S_VERSION:-latest}"

print_section "Fetch k3s Offline Images"
echo ""
echo "Version: ${K3S_VERSION}"
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) K3S_ARCH="amd64" ;;
    aarch64) K3S_ARCH="arm64" ;;
    armv7l) K3S_ARCH="arm" ;;
    *)
        echo "✗ Unsupported architecture: ${ARCH}"
        echo "  Supported: x86_64, aarch64, armv7l"
        exit 1
        ;;
esac

if [ "$K3S_VERSION" = "latest" ]; then
    BASE_URL="https://github.com/k3s-io/k3s/releases/latest/download"
else
    BASE_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}"
fi

IMAGE_FILE="k3s-airgap-images-${K3S_ARCH}.tar.zst"
IMAGES_URL="${BASE_URL}/${IMAGE_FILE}"
CHECKSUMS_URL="${BASE_URL}/sha256sum-${K3S_ARCH}.txt"

echo "Downloading ${IMAGE_FILE}..."
if download_file "${IMAGES_URL}" "${OFFLINE_DIR}/${IMAGE_FILE}"; then
    echo "  ✓ Downloaded: ${OFFLINE_DIR}/${IMAGE_FILE}"
else
    echo "  ✗ Failed to download ${IMAGE_FILE}"
    echo "  Manual download URL: ${IMAGES_URL}"
    exit 1
fi

echo "Downloading checksums (optional)..."
if download_file "${CHECKSUMS_URL}" "${OFFLINE_DIR}/sha256sum-${K3S_ARCH}.txt"; then
    echo "  ✓ Downloaded checksums"
else
    echo "  ⚠ Could not download checksum file, continuing"
fi

echo ""
print_section "Download Complete!"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "Use these files for k3s air-gap installs with:"
echo "  sudo cp ${OFFLINE_DIR}/${IMAGE_FILE} /var/lib/rancher/k3s/agent/images/"
echo ""
