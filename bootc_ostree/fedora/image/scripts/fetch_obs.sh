#!/bin/bash
# Fetch OBS Studio and dependencies for offline installation
# Usage: ./fetch_obs.sh
#
# Note: OBS is only available from RPM Fusion.
# This script uses your locally configured RPM Fusion repos.

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OUTPUT_DIR="$(get_offline_dir "obs" "${SCRIPT_PATH}")"

print_section "Fetching OBS Studio"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Remove stale RPMs so the offline bundle does not accumulate mixed Fedora update levels.
find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.rpm' -delete

# Check if RPM Fusion repos are available
if ! dnf repolist 2>/dev/null | grep -q rpmfusion; then
    log_error "RPM Fusion repositories not found."
    echo ""
    echo "OBS Studio is only available from RPM Fusion."
    echo "Please install RPM Fusion first:"
    echo ""
        cat <<'EOF'
    sudo dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release$(rpm -E %fedora).noarch.rpm
EOF
    echo ""
    exit 1
fi

echo "Attempting to download OBS Studio and dependencies..."
echo "Using your locally configured RPM Fusion repos..."
echo "This may take a few minutes..."
echo ""

# Download OBS Studio with dependencies using local repos
dnf download \
    --enablerepo=rpmfusion-free \
    --enablerepo=rpmfusion-free-updates \
    --resolve \
    --alldeps \
    --destdir="$OUTPUT_DIR" \
    obs-studio 2>&1 || {
    echo ""
    log_error "Could not download OBS Studio."
    echo ""
    echo "Possible reasons:"
    echo "1. Qt6 library conflicts with your host desktop stack"
    echo "   - dnf download will fail if dependencies conflict with installed packages"
    echo "2. Network connectivity issue"
    echo "3. Insufficient disk space"
    echo ""
    echo "Workaround:"
    echo "Since Qt6 conflicts can prevent downloading on some systems, OBS will be"
    echo "configured for online installation in the bootc image (requires internet)."
    echo ""
    echo "The ISO build will proceed without offline OBS packages."
    exit 1
}

# Verify download
if [ -n "$(ls -A "$OUTPUT_DIR"/*.rpm 2>/dev/null)" ]; then
    echo ""
    print_section "Success! OBS packages downloaded:"
    ls -lh "$OUTPUT_DIR"/*.rpm
    echo ""
    echo "Total size: $(du -sh "$OUTPUT_DIR" | awk '{print $1}')"
    echo ""
    echo "Packages are ready at: $OUTPUT_DIR"
    echo "They will be automatically included in the next ISO build."
else
    echo ""
    log_error "No packages were downloaded."
    exit 1
fi
