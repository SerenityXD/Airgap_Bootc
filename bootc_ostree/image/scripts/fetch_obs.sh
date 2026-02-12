#!/bin/bash
# Fetch OBS Studio and dependencies for offline installation
# Usage: ./fetch_obs.sh
#
# Note: OBS is only available from RPM Fusion.
# This script uses your locally configured RPM Fusion repos.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/image/offline-repo/obs"

echo "================================"
echo "Fetching OBS Studio"
echo "================================"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if RPM Fusion repos are available
if ! dnf repolist 2>/dev/null | grep -q rpmfusion; then
    echo "ERROR: RPM Fusion repositories not found."
    echo ""
    echo "OBS Studio is only available from RPM Fusion."
    echo "Please install RPM Fusion first:"
    echo ""
    echo "  sudo dnf install -y \\\n+    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release\$(rpm -E %fedora).noarch.rpm \\\n+    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release\$(rpm -E %fedora).noarch.rpm"
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
    echo "ERROR: Could not download OBS Studio."
    echo ""
    echo "Possible reasons:"
    echo "1. Qt6 library conflicts with KDE Plasma on your system"
    echo "   - dnf download will fail if dependencies conflict with installed packages"
    echo "2. Network connectivity issue"
    echo "3. Insufficient disk space"
    echo ""
    echo "Workaround:"
    echo "Since Qt6 conflicts prevent downloading on KDE systems, OBS will be"
    echo "configured for online installation in the bootc image (requires internet)."
    echo ""
    echo "The ISO build will proceed without offline OBS packages."
    exit 1
}

# Verify download
if [ -n "$(ls -A "$OUTPUT_DIR"/*.rpm 2>/dev/null)" ]; then
    echo ""
    echo "================================"
    echo "Success! OBS packages downloaded:"
    echo "================================"
    ls -lh "$OUTPUT_DIR"/*.rpm
    echo ""
    echo "Total size: $(du -sh "$OUTPUT_DIR" | awk '{print $1}')"
    echo ""
    echo "Packages are ready at: $OUTPUT_DIR"
    echo "They will be automatically included in the next ISO build."
else
    echo ""
    echo "ERROR: No packages were downloaded."
    exit 1
fi
