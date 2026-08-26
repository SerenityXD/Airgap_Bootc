#!/usr/bin/env bash
# Fetch CUDA Toolkit and associated packages for offline installation
# Usage: ./fetch_cuda_toolkit.sh
#
# Downloads CUDA Toolkit, CUDA Runtime, nvcc compiler, and cuDNN if available.
# This script uses the NVIDIA CUDA repository and attempts to cache packages
# for air-gapped or offline builds.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OUTPUT_DIR="$(get_offline_dir "cuda" "${SCRIPT_PATH}")"

# CUDA repository URLs
FEDORA_VERSION="${FEDORA_VERSION:-44}"
CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/fedora${FEDORA_VERSION}/x86_64"
CUDA_REPO_RPM="${CUDA_REPO_URL}/cuda-fedora${FEDORA_VERSION}.repo"

print_section "Fetching CUDA Toolkit"
echo ""
echo "CUDA Repository Setup:"
echo "  • This script requires NVIDIA CUDA repository to be configured"
echo "  • Option 1: Run with sudo: sudo ./fetch_cuda_toolkit.sh"
echo "  • Option 2: Setup once (sudoless), then run without sudo:"
echo "      sudo dnf config-manager addrepo --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora${FEDORA_VERSION}/cuda-fedora${FEDORA_VERSION}.repo"
echo "      ./fetch_cuda_toolkit.sh"
echo "  • See ../README.md for more details"
echo ""
echo "Target directory: ${OUTPUT_DIR}"
echo "Fedora version:   ${FEDORA_VERSION}"
echo "CUDA repo URL:    ${CUDA_REPO_URL}"
echo ""

require_cmd curl
require_cmd dnf

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Remove stale RPMs so the offline bundle does not accumulate mixed versions
find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.rpm' -delete

echo "Step 1: Downloading CUDA repository configuration..."
echo ""

# Download the .repo configuration file
REPO_CONF_PATH="$OUTPUT_DIR/$(basename "$CUDA_REPO_RPM")"

if curl -fsSL --retry 3 --retry-delay 2 -o "$REPO_CONF_PATH" "$CUDA_REPO_RPM" 2>/dev/null; then
    log_info "Downloaded CUDA repo configuration: $(basename "$REPO_CONF_PATH")"
else
    log_warn "Could not download CUDA repo config from ${CUDA_REPO_RPM}"
    REPO_CONF_PATH=""
fi

echo ""
echo "Step 2: Configuring CUDA repository for download..."
echo ""

CUDA_REPO_CONFIGURED=0

# Try to install the .repo file to system for dnf to use
if [ -n "$REPO_CONF_PATH" ] && [ -f "$REPO_CONF_PATH" ]; then
    # Copy repo file to system repos directory (requires sudo)
    if sudo cp "$REPO_CONF_PATH" /etc/yum.repos.d/ 2>/dev/null; then
        log_info "CUDA repository configured in system"
        CUDA_REPO_CONFIGURED=1
    elif [ -w /etc/yum.repos.d/ ]; then
        # Try without sudo if directory is writable
        cp "$REPO_CONF_PATH" /etc/yum.repos.d/ 2>/dev/null && CUDA_REPO_CONFIGURED=1
    fi
    
    if [ "$CUDA_REPO_CONFIGURED" -ne 1 ]; then
        log_warn "Could not install repo configuration to /etc/yum.repos.d/ (requires root/sudo)"
        log_warn "Install CUDA repo manually with:"
        log_warn "  sudo dnf install -y ${CUDA_REPO_RPM}"
    fi
else
    log_warn "Repo configuration file not available"
fi

# Verify repo is available
if [ "$CUDA_REPO_CONFIGURED" -eq 1 ]; then
    if dnf repolist 2>/dev/null | grep -qi "cuda"; then
        log_info "CUDA repository verified in dnf"
    else
        log_warn "CUDA repository not found in dnf repolist; trying with wildcard..."
    fi
fi

echo ""
echo "Step 3: Downloading CUDA Toolkit with all dependencies..."
echo "   (This will include cuda-cudart, cuda-nvcc, cuda-libraries, and all other CUDA components)"
echo ""

DOWNLOADED=0
NOT_FOUND=0

# Download cuda-toolkit with all dependencies
# The --resolve --alldeps flags ensure all CUDA components are included:
#   cuda-cudart, cuda-nvcc, cuda-libraries, cuda-libraries-devel, etc.
echo "Downloading: cuda-toolkit (with all dependencies)"
if dnf download \
    --enablerepo='cuda*' \
    --resolve \
    --alldeps \
    --destdir="$OUTPUT_DIR" \
    cuda-toolkit 2>&1 | tail -10; then
    DOWNLOADED=$((DOWNLOADED + 1))
    log_info "CUDA Toolkit with dependencies downloaded successfully"
else
    NOT_FOUND=$((NOT_FOUND + 1))
    log_warn "Failed to download cuda-toolkit package"
fi

echo ""
echo "Attempting optional packages (cuDNN, etc.)..."
echo ""

# Optional packages (attempts to download but continues if not found)
OPTIONAL_PACKAGES=(
    "libcudnn8"
    "libcudnn8-devel"
)

# Download optional packages (non-blocking)
for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    echo "  Attempting optional download: $pkg"
    if dnf download \
        --enablerepo='cuda*' \
        --enablerepo='nvidia*' \
        --resolve \
        --alldeps \
        --destdir="$OUTPUT_DIR" \
        "$pkg" 2>&1 | grep -q "Downloaded"; then
        log_info "Optional package downloaded: $pkg"
    else
        log_warn "Optional package not available: $pkg (this is non-critical)"
    fi
done

echo ""
echo "========================================"
echo "Summary"
echo "========================================"

# Count downloaded files
TOTAL_RPMS=$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.rpm' 2>/dev/null | wc -l)
if [ "$TOTAL_RPMS" -gt 0 ]; then
    TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
    log_info "Downloaded $TOTAL_RPMS RPM files (${TOTAL_SIZE}) to ${OUTPUT_DIR}"
    echo ""
    echo "Files downloaded:"
    find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.rpm' -exec basename {} \; | sort
    echo ""
    log_info "CUDA packages cached successfully for offline builds"
else
    log_warn "No CUDA packages were downloaded"
    echo ""
    echo "This can happen because:"
    echo "1. CUDA repo was not properly configured (may need sudo permissions)"
    echo "2. NVIDIA repository is unreachable or doesn't have packages for Fedora ${FEDORA_VERSION}"
    echo "3. Internet connectivity issue"
    echo ""
    echo "To fix this, try:"
    echo "  1. Run with sudo: sudo ./fetch_cuda_toolkit.sh"
    echo "  2. Or manually install CUDA repo first:"
    echo "     sudo dnf config-manager addrepo --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora${FEDORA_VERSION}/cuda-fedora${FEDORA_VERSION}.repo"
    echo "     then run this script again"
    echo ""
    echo "For air-gapped builds without CUDA packages:"
    echo "1. Skip CUDA in the build: podman build --build-arg EXCLUDE_CUDA_TOOLKIT=yes"
    echo "2. Or install CUDA post-deployment on the target system"
    echo ""
    log_warn "CUDA Toolkit fetch completed with no packages (this is non-critical)"
fi
