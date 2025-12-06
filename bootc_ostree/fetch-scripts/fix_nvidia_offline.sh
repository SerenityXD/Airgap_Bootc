#!/bin/bash
# Fix NVIDIA offline repository by downloading missing dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIDIA_DIR="${SCRIPT_DIR}/../image/offline-repo/nvidia"

echo "================================================================"
echo "Fixing NVIDIA offline repository"
echo "================================================================"

# Create directory if it doesn't exist
mkdir -p "${NVIDIA_DIR}"
cd "${NVIDIA_DIR}"

echo ""
echo "Current NVIDIA packages in offline repo:"
ls -1 *.rpm 2>/dev/null | wc -l || echo "0"

echo ""
echo "Checking for missing critical NVIDIA packages..."

# Enable RPM Fusion nonfree repository
if ! dnf repolist | grep -q rpmfusion-nonfree; then
    echo "Adding RPM Fusion nonfree repository..."
    sudo dnf install -y \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
fi

# Download the complete NVIDIA driver package set with all dependencies
# Note: nvidia-kmod-common is a virtual package provided by xorg-x11-drv-nvidia
echo ""
echo "Downloading complete NVIDIA driver package set..."
dnf download --resolve --alldeps \
    akmod-nvidia \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda \
    xorg-x11-drv-nvidia-cuda-libs \
    nvidia-settings \
    nvidia-persistenced \
    nvidia-modprobe \
    xorg-x11-drv-nvidia-libs \
    xorg-x11-drv-nvidia-kmodsrc \
    2>&1 | tee /tmp/nvidia_download.log

echo ""
echo "Verifying critical packages are present..."
MISSING=()

# Note: nvidia-kmod-common is a virtual package provided by xorg-x11-drv-nvidia
for pkg in \
    "akmod-nvidia" \
    "xorg-x11-drv-nvidia-[0-9]" \
    "xorg-x11-drv-nvidia-cuda-[0-9]" \
    "xorg-x11-drv-nvidia-cuda-libs" \
    "nvidia-settings" \
    "nvidia-persistenced" \
    "nvidia-modprobe" \
    "xorg-x11-drv-nvidia-libs" \
    "xorg-x11-drv-nvidia-kmodsrc"
do
    if ! ls ${pkg}*.rpm 1>/dev/null 2>&1; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: The following packages are still missing:"
    printf '  - %s\n' "${MISSING[@]}"
    echo ""
    echo "You may need to download them manually from:"
    echo "  https://download1.rpmfusion.org/nonfree/fedora/releases/$(rpm -E %fedora)/Everything/x86_64/os/Packages/"
    exit 1
fi

echo ""
echo "================================================================"
echo "NVIDIA offline repository fixed successfully!"
echo "Total packages: $(ls -1 *.rpm 2>/dev/null | wc -l)"
echo "================================================================"
