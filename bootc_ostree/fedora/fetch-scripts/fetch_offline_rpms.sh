#!/usr/bin/env bash
# Fetch offline RPMs for third-party packages
# Run this on an internet-connected machine before building the ISO

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_REPO_DIR="$SCRIPT_DIR/image/offline-repo"
ARCH="$(uname -m)"
BASE_IMAGE_VERSION="43"

# Target Fedora version (should match bootc base image)
FEDORA_VERSION="${FEDORA_VERSION:-43}"

# Temporary repos/cachedir to avoid touching host config
REPO_TMP=$(mktemp -d)
cleanup() {
    rm -rf "$REPO_TMP"
}
trap cleanup EXIT

DNF_BASE_OPTS=(
    --releasever="$FEDORA_VERSION"
    --setopt=gpgcheck=0
    --setopt=repo_gpgcheck=0
    --setopt=install_weak_deps=False
    --setopt=cachedir="$REPO_TMP/cache"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Fetch offline RPMs for third-party packages (VS Code, Docker Desktop)

RPM Fusion packages are intentionally excluded from --all and installed online during
the container build. Use --rpmfusion only if you need to explicitly pre-cache them.

Options:
  --all                 Fetch all packages except RPM Fusion (default)
  --rpmfusion          Fetch RPM Fusion packages only (advanced; usually not needed)
  --vscode             Fetch VS Code only
  --docker-desktop     Fetch Docker Desktop only
  --skip-existing      Skip downloads if files already exist
  -h, --help           Show this help

Environment Variables:
  FEDORA_VERSION       Target Fedora version (default: 43, must match bootc base image)

Examples:
  $(basename "$0") --all
  $(basename "$0") --vscode --docker-desktop
  $(basename "$0") --rpmfusion --skip-existing
  FEDORA_VERSION=43 $(basename "$0") --vscode

Note: This script requires internet access and runs 'dnf download' and 'curl'.
      Downloaded packages must match the Fedora version of the bootc base image.
EOF
}

# Parse arguments
FETCH_ALL=true
FETCH_VSCODE=false
FETCH_DOCKER=false
SKIP_EXISTING=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) FETCH_ALL=true; shift ;;
        --rpmfusion) FETCH_ALL=false; FETCH_RPMFUSION=true; shift ;;
        --vscode) FETCH_ALL=false; FETCH_VSCODE=true; shift ;;
        --docker-desktop) FETCH_ALL=false; FETCH_DOCKER=true; shift ;;
        --skip-existing) SKIP_EXISTING=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Apply --all logic (RPM Fusion excluded: installed online during container build)
if [[ "$FETCH_ALL" == "true" ]]; then
    FETCH_VSCODE=true
    FETCH_DOCKER=true
fi

# Create directories
mkdir -p "$OFFLINE_REPO_DIR"/{vscode,docker-desktop}

# Check for required tools
for cmd in dnf curl wget; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done

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
    
    mkdir -p "${REPO_TMP}/repos"
    cd "$target_dir"
    
    local code_repo="https://packages.microsoft.com/yumrepos/vscode"

    dnf download --resolve \
        "${DNF_BASE_OPTS[@]}" \
        --setopt=reposdir="${REPO_TMP}/repos" \
        --repofrompath=code,${code_repo} \
        --enablerepo=code \
        code.x86_64 \
        || log_error "Failed to download VS Code"
    
    log_info "VS Code saved to: $target_dir"
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

[[ "$FETCH_VSCODE" == "true" ]] && fetch_vscode
[[ "$FETCH_DOCKER" == "true" ]] && fetch_docker_desktop

log_info "Offline RPM fetch complete!"
log_info ""
log_info "Summary of downloaded packages:"
for dir in vscode docker-desktop; do
    count=$(find "$OFFLINE_REPO_DIR/$dir" -name "*.rpm" 2>/dev/null | wc -l)
    size=$(du -sh "$OFFLINE_REPO_DIR/$dir" 2>/dev/null | awk '{print $1}')
    printf "  %-20s %3d RPMs  (%s)\n" "$dir:" "$count" "$size"
done

log_info ""
log_info "Next steps:"
log_info "1. Review downloaded packages in: $OFFLINE_REPO_DIR"
log_info "2. Run the build script: ./bootc_ostree/build_export_iso.sh"
