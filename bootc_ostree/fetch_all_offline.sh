#!/bin/bash
# Fetch all offline packages and binaries for bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH_SCRIPTS_DIR="${SCRIPT_DIR}/fetch-scripts"

echo "========================================"
echo "Fetch All Offline Packages"
echo "========================================"
echo ""
echo "This script will download:"
echo "  - RPM packages (RPM Fusion, VS Code, WineHQ, Docker Desktop)"
echo "  - draw.io (diagrams.net)"
echo "  - OBS Studio (with offline dependencies)"
echo "  - OpenShift/Kubernetes CLI tools (oc, kubectl)"
echo "  - CodeReady Containers (CRC)"
echo "  - NVIDIA Triton Inference Server (~8-10 GB container)"
echo "  - Prism Launcher (Minecraft launcher)"
echo ""

# Track what succeeded/failed
FAILED=()
SUCCEEDED=()

# Function to run a script and track results
run_fetch() {
    local script_name="$1"
    local description="$2"
    
    echo ""
    echo "========================================"
    echo "Fetching: ${description}"
    echo "========================================"
    echo ""
    
    if [ -f "${FETCH_SCRIPTS_DIR}/${script_name}" ]; then
        if "${FETCH_SCRIPTS_DIR}/${script_name}"; then
            SUCCEEDED+=("${description}")
        else
            FAILED+=("${description}")
            echo "⚠ ${description} fetch failed (non-critical, continuing...)"
        fi
    else
        echo "⚠ Script not found: ${script_name}"
        FAILED+=("${description}")
    fi
}

# Fetch RPM packages (with --all flag)
echo ""
echo "========================================"
echo "Fetching: RPM Packages"
echo "========================================"
echo ""
if [ -f "${FETCH_SCRIPTS_DIR}/fetch_offline_rpms.sh" ]; then
    if "${FETCH_SCRIPTS_DIR}/fetch_offline_rpms.sh" --all --skip-existing; then
        SUCCEEDED+=("RPM Packages")
    else
        FAILED+=("RPM Packages")
        echo "⚠ RPM packages fetch failed (non-critical, continuing...)"
    fi
else
    echo "⚠ Script not found: fetch_offline_rpms.sh"
    FAILED+=("RPM Packages")
fi

# Fetch draw.io
run_fetch "fetch_drawio.sh" "draw.io"

# Fetch OBS Studio
run_fetch "fetch_obs.sh" "OBS Studio"

# Fetch OpenShift tools
run_fetch "fetch_openshift_tools.sh" "OpenShift/Kubernetes CLI"

# Fetch CRC
run_fetch "fetch_crc.sh" "CodeReady Containers"

# Fetch Triton Server
run_fetch "fetch_triton_server.sh" "NVIDIA Triton Inference Server"

# Fetch Prism Launcher
run_fetch "fetch_prismlauncher.sh" "Prism Launcher"

# Summary
echo ""
echo "========================================"
echo "Fetch Summary"
echo "========================================"
echo ""

if [ ${#SUCCEEDED[@]} -gt 0 ]; then
    echo "✓ Successfully fetched:"
    for item in "${SUCCEEDED[@]}"; do
        echo "  - ${item}"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "✗ Failed to fetch:"
    for item in "${FAILED[@]}"; do
        echo "  - ${item}"
    done
    echo ""
    echo "Note: You can still build the ISO. Missing packages will use online"
    echo "      fallback during image build (if available) or be skipped."
    echo ""
fi

echo "========================================"
echo "All Fetch Operations Complete"
echo "========================================"
echo ""
echo "Offline packages saved to:"
echo "  ${SCRIPT_DIR}/image/offline-repo/"
echo ""
echo "Next step: Build the ISO"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build_export_iso.sh --iso-name SCVU.iso"
echo ""

# Exit with success even if some fetches failed (non-critical)
exit 0
