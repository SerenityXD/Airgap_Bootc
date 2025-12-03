#!/usr/bin/env bash
# Fetch offline RPMs for third-party packages
# Run this on an internet-connected machine before building the ISO

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OFFLINE_REPO_DIR="$SCRIPT_DIR/image/offline-repo"

# Target Fedora version (should match bootc base image)
FEDORA_VERSION="${FEDORA_VERSION:-43}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Fetch offline RPMs for third-party packages (RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop)

Options:
  --all                 Fetch all packages (default)
  --rpmfusion          Fetch RPM Fusion packages only
  --nvidia             Fetch NVIDIA packages only
  --vscode             Fetch VS Code only
  --winehq             Fetch WineHQ packages only
  --docker-desktop     Fetch Docker Desktop only
  --skip-existing      Skip downloads if files already exist
  -h, --help           Show this help

Environment Variables:
  FEDORA_VERSION       Target Fedora version (default: 43, must match bootc base image)

Examples:
  $(basename "$0") --all
  $(basename "$0") --vscode --docker-desktop
  $(basename "$0") --nvidia --skip-existing
  FEDORA_VERSION=43 $(basename "$0") --nvidia

Note: This script requires internet access and runs 'dnf download' and 'curl'.
      Downloaded packages must match the Fedora version of the bootc base image.
EOF
}

# Parse arguments
FETCH_ALL=true
FETCH_RPMFUSION=false
FETCH_NVIDIA=false
FETCH_VSCODE=false
FETCH_WINEHQ=false
FETCH_DOCKER=false
SKIP_EXISTING=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) FETCH_ALL=true; shift ;;
        --rpmfusion) FETCH_ALL=false; FETCH_RPMFUSION=true; shift ;;
        --nvidia) FETCH_ALL=false; FETCH_NVIDIA=true; shift ;;
        --vscode) FETCH_ALL=false; FETCH_VSCODE=true; shift ;;
        --winehq) FETCH_ALL=false; FETCH_WINEHQ=true; shift ;;
        --docker-desktop) FETCH_ALL=false; FETCH_DOCKER=true; shift ;;
        --skip-existing) SKIP_EXISTING=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Apply --all logic
if [[ "$FETCH_ALL" == "true" ]]; then
    FETCH_RPMFUSION=true
    FETCH_NVIDIA=true
    FETCH_VSCODE=true
    FETCH_WINEHQ=true
    FETCH_DOCKER=true
fi

# Create directories
mkdir -p "$OFFLINE_REPO_DIR"/{rpmfusion,nvidia,vscode,winehq,docker-desktop}

# Check for required tools
for cmd in dnf curl wget; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done

#=============================================================================
# RPM Fusion
#=============================================================================
fetch_rpmfusion() {
    log_info "Fetching RPM Fusion packages..."
    
    local target_dir="$OFFLINE_REPO_DIR/rpmfusion"
    
    if [[ "$SKIP_EXISTING" == "true" && -n "$(ls "$target_dir"/*.rpm 2>/dev/null)" ]]; then
        log_warn "RPM Fusion packages already exist, skipping."
        return
    fi
    
    # Enable RPM Fusion repos temporarily
    sudo dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm \
        2>/dev/null || log_warn "RPM Fusion repos may already be enabled"
    
    # Download multimedia codecs and tools
    cd "$target_dir"
    dnf download --resolve \
        --releasever=$FEDORA_VERSION \
        ffmpeg ffmpeg-libs \
        mpv vlc \
        obs-studio \
        x264 x265 \
        || log_warn "Some RPM Fusion packages failed to download"
    
    log_info "RPM Fusion packages saved to: $target_dir"
}

#=============================================================================
# NVIDIA
#=============================================================================
fetch_nvidia() {
    log_info "Fetching NVIDIA packages..."
    
    local target_dir="$OFFLINE_REPO_DIR/nvidia"
    
    if [[ "$SKIP_EXISTING" == "true" && -n "$(ls "$target_dir"/*.rpm 2>/dev/null)" ]]; then
        log_warn "NVIDIA packages already exist, skipping."
        return
    fi
    
    # Enable RPM Fusion for NVIDIA drivers
    sudo dnf install -y \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm \
        2>/dev/null || true
    
    cd "$target_dir"
    
    # Download NVIDIA driver packages
    log_info "Downloading NVIDIA drivers (this may take a while)..."
    dnf download --resolve \
        --releasever=$FEDORA_VERSION \
        --setopt=install_weak_deps=False \
        akmod-nvidia \
        xorg-x11-drv-nvidia \
        xorg-x11-drv-nvidia-cuda \
        nvidia-settings \
        || log_warn "Some NVIDIA packages failed to download"
    
    log_info "NVIDIA packages saved to: $target_dir"
    log_warn "Note: NVIDIA drivers require kernel-devel matching your target kernel version"
}

#=============================================================================
# VS Code
#=============================================================================
fetch_vscode() {
    log_info "Fetching VS Code..."
    
    local target_dir="$OFFLINE_REPO_DIR/vscode"
    
    if [[ "$SKIP_EXISTING" == "true" && -n "$(ls "$target_dir"/*.rpm 2>/dev/null)" ]]; then
        log_warn "VS Code already exists, skipping."
        return
    fi
    
    cd "$target_dir"
    
    # Import Microsoft GPG key
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    
    # Add VS Code repo
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    
    # Download VS Code (force x86_64 by specifying arch in package name)
    dnf download --resolve \
        --releasever=$FEDORA_VERSION \
        --setopt=install_weak_deps=False \
        code.x86_64 \
        || log_error "Failed to download VS Code"
    
    log_info "VS Code saved to: $target_dir"
}

#=============================================================================
# WineHQ
#=============================================================================
fetch_winehq() {
    log_info "Fetching WineHQ packages..."
    
    local target_dir="$OFFLINE_REPO_DIR/winehq"
    
    if [[ "$SKIP_EXISTING" == "true" && -n "$(ls "$target_dir"/*.rpm 2>/dev/null)" ]]; then
        log_warn "WineHQ packages already exist, skipping."
        return
    fi
    
    # Add WineHQ repository
    sudo dnf config-manager --add-repo https://dl.winehq.org/wine-builds/fedora/${FEDORA_VERSION}/winehq.repo || true
    
    cd "$target_dir"
    
    # Download Wine stable
    dnf download --resolve \
        --releasever=$FEDORA_VERSION \
        --setopt=install_weak_deps=False \
        winehq-stable \
        || log_warn "Failed to download WineHQ packages (conflicts with wine-desktop? Try: sudo dnf remove -y wine-desktop)"
    
    log_info "WineHQ packages saved to: $target_dir"
}

#=============================================================================
# Docker Desktop
#=============================================================================
fetch_docker_desktop() {
    log_info "Fetching Docker Desktop..."
    
    local target_dir="$OFFLINE_REPO_DIR/docker-desktop"
    
    if [[ "$SKIP_EXISTING" == "true" && -n "$(ls "$target_dir"/*.rpm 2>/dev/null)" ]]; then
        log_warn "Docker Desktop already exists, skipping."
        return
    fi
    
    cd "$target_dir"
    
    # Detect architecture
    local arch=$(uname -m)
    
    # Download Docker Desktop for Fedora
    log_info "Downloading Docker Desktop for $arch..."
    
    # Get latest version from Docker's download page
    local download_url="https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64.rpm"
    
    if [[ "$arch" == "aarch64" ]]; then
        download_url="https://desktop.docker.com/linux/main/arm64/docker-desktop-aarch64.rpm"
    fi
    
    wget -O docker-desktop-latest.rpm "$download_url" || {
        log_error "Failed to download Docker Desktop"
        log_warn "You can manually download from: https://docs.docker.com/desktop/install/linux/"
        return 1
    }
    
    log_info "Docker Desktop saved to: $target_dir"
}

#=============================================================================
# Main execution
#=============================================================================

log_info "Starting offline RPM fetch..."
log_info "Target directory: $OFFLINE_REPO_DIR"

[[ "$FETCH_RPMFUSION" == "true" ]] && fetch_rpmfusion
[[ "$FETCH_NVIDIA" == "true" ]] && fetch_nvidia
[[ "$FETCH_VSCODE" == "true" ]] && fetch_vscode
[[ "$FETCH_WINEHQ" == "true" ]] && fetch_winehq
[[ "$FETCH_DOCKER" == "true" ]] && fetch_docker_desktop

log_info "Offline RPM fetch complete!"
log_info ""
log_info "Summary of downloaded packages:"
for dir in rpmfusion nvidia vscode winehq docker-desktop; do
    count=$(find "$OFFLINE_REPO_DIR/$dir" -name "*.rpm" 2>/dev/null | wc -l)
    size=$(du -sh "$OFFLINE_REPO_DIR/$dir" 2>/dev/null | awk '{print $1}')
    printf "  %-20s %3d RPMs  (%s)\n" "$dir:" "$count" "$size"
done

log_info ""
log_info "Next steps:"
log_info "1. Review downloaded packages in: $OFFLINE_REPO_DIR"
log_info "2. Run the build script: ./bootc_ostree/build_export_iso.sh"
