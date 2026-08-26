#!/bin/bash
# Download k3s binary for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_DIR="$(get_offline_dir "k3s" "${SCRIPT_PATH}")"
K3S_VERSION="${K3S_VERSION:-stable}"  # Can set to specific version like "v1.29.0"

print_section "Fetch k3s Binary"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"
cd "${OFFLINE_DIR}"

# Download k3s binary
echo "[1/1] Downloading k3s binary..."
if [ "${K3S_VERSION}" = "stable" ]; then
    K3S_VERSION=$(curl -fsSL https://api.github.com/repos/k3s-io/k3s/releases/latest | \
        sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    if [ -z "${K3S_VERSION}" ]; then
        echo "  ✗ Failed to resolve stable k3s version from GitHub API"
        echo "  Hint: GitHub API may be rate-limited. Retry later or set GH_TOKEN for authenticated API access."
        exit 1
    fi
fi

# Ensure version has 'v' prefix
[[ "$K3S_VERSION" == v* ]] || K3S_VERSION="v${K3S_VERSION}"

K3S_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s"

if download_file "${K3S_URL}" k3s; then
    chmod +x k3s
    echo "  ✓ k3s binary downloaded: ${K3S_VERSION}"
    
    # Verify it's executable
    if ./k3s --version >/dev/null 2>&1; then
        echo "  ✓ k3s verified: $(./k3s --version 2>&1 | head -1)"
    else
        echo "  ⚠ Warning: k3s version check failed (may require network at runtime)"
    fi
else
    echo "  ✗ Failed to download k3s binary"
    echo "  Manual download: https://github.com/k3s-io/k3s/releases"
    exit 1
fi

echo ""
print_section "Download Complete!"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "These binaries will be automatically included in the next ISO build."
echo "To rebuild with offline k3s:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build-scripts/build_export_iso.sh --iso-name BOOTC.iso"
echo ""
