#!/bin/bash
# Download Lutris runner packages for offline inclusion.
# Includes: Dw Proton, DXVK, VKD3D-Proton, and Proton-GE

set -uo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

OFFLINE_DIR="$(get_offline_dir "lutris-runners" "${SCRIPT_PATH}")"
DRY_RUN=false
ARCH="x86_64"
DW_PROTON_VERSION="11.0-1"
DXVK_VERSION="2.7.1"
VKD3D_PROTON_VERSION="3.0.1"
PROTON_GE_VERSION="GE-Proton10-34"

# Parse arguments
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
elif [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage: fetch_lutris_runners.sh [OPTIONS]

Download the latest Lutris runners for offline inclusion.
Includes: Dw Proton, DXVK, VKD3D-Proton, and Proton-GE.

Options:
  --dry-run       Show what would be downloaded without actually downloading
  -h, --help      Show this help message

Downloads will be placed in ../image/offline-repo/lutris-runners/
USAGE
    exit 0
fi

require_cmd curl

print_section "Fetch Lutris Runners (Dw Proton, DXVK, VKD3D-Proton, Proton-GE)"
echo ""

# Create offline directory
mkdir -p "$OFFLINE_DIR"

success_count=0
fail_count=0

# Define the runners to fetch (name and download URL)
declare -A RUNNERS=(
    ["dwproton"]="https://dawn.wine/dawn-winery/dwproton/releases/download/dwproton-$DW_PROTON_VERSION/dwproton-$DW_PROTON_VERSION-x86_64.tar.xz"
    ["dxvk"]="https://github.com/doitsujin/dxvk/releases/download/v$DXVK_VERSION/dxvk-$DXVK_VERSION.tar.gz"
    ["vkd3d-proton"]="https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v$VKD3D_PROTON_VERSION/vkd3d-proton-$VKD3D_PROTON_VERSION.tar.zst"
    ["proton-ge"]="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$PROTON_GE_VERSION/$PROTON_GE_VERSION.tar.gz"
)


log_info "Starting fetch of Lutris runners... ${#RUNNERS[@]}"

for runner in "${!RUNNERS[@]}"; do

    log_info "Processing runner: $runner"
    download_url="${RUNNERS[$runner]}"        
    
    filename=$(basename "$download_url")
    
    # Check if already exists
    if [[ -f "$OFFLINE_DIR/$filename" ]]; then
         filesize=$(stat -c%s "$OFFLINE_DIR/$filename" 2>/dev/null || echo "0")
        log_info "  ✓ Already exists: $filename ($filesize bytes)"
        ((success_count++))
        echo ""
        continue
    fi
    
    # Download the file
    log_info "  Downloading: $filename..."
    if curl -L --progress-bar --max-time 600 "$download_url" -o "$OFFLINE_DIR/$filename" < /dev/null 2>/dev/null; then
        log_info "  ✓ Downloaded: $filename"
        ((success_count++))
    else
        log_error "  Failed to download: $filename"
        rm -f "$OFFLINE_DIR/$filename"
        ((fail_count++))
    fi
    
    echo ""
done

echo ""
log_info "Fetch complete: $success_count successful, $fail_count failed"
echo ""
echo "Downloaded runners stored in: $OFFLINE_DIR"
echo "During image build, these will be extracted to: /opt/lutris-runners/"
echo ""
log_info "After boot, run: sudo /usr//bin/bootc/bootc-post-install.sh"
