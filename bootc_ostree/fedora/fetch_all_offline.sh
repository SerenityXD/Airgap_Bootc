#!/bin/bash
# Fetch all offline packages and binaries for bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH_SCRIPTS_DIR="${SCRIPT_DIR}/image/scripts"

echo "========================================"
echo "Fetch All Offline Packages"
echo "========================================"
echo ""
echo "⚠️  NOTE: CUDA Toolkit requires NVIDIA repository setup"
echo "   For sudoless setup, run once:"
echo "     sudo dnf install -y https://developer.download.nvidia.com/compute/cuda/repos/fedora43/x86_64/cuda-fedora43.repo"
echo "   Then run this script normally."
echo "   See image/scripts/README.md for alternatives."
echo ""
echo "This script will download:"
echo "  - VS Code (via dedicated fetch script)"
echo "  - VS Code Extensions (Python, Jupyter, Kubernetes, Docker, YAML, Makefile, GitLens)"
echo "  - RPM packages (WineHQ, Docker Desktop; RPM Fusion installed online during build)"
echo "  - GIMP and Krita from Fedora repos"  
echo "  - Blender 4.2 from Fedora repos"
echo "  - draw.io (diagrams.net)"
echo "  - OBS Studio (with offline dependencies)"
echo "  - CUDA Toolkit and associated packages (NVIDIA CUDA)"
echo "  - OpenShift/Kubernetes CLI tools (oc, kubectl)"
echo "  - Claude Code CLI"
echo "  - Helm package manager"
echo "  - k3s binary and offline images (air-gap image archive)"
echo "  - Lutris runners (Dw Proton, DXVK, VKD3D-Proton, Proton-GE)"

echo ""

# Target Fedora version for all offline fetch scripts
FEDORA_VERSION="44"
export FEDORA_VERSION

# Track what succeeded/failed
FAILED=()
SUCCEEDED=()
INCLUDE_OPTIONAL_FETCH="${INCLUDE_OPTIONAL_FETCH:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Unified runner for fetch scripts (supports optional script arguments)
run_fetch_entry() {
    local script_name="$1"
    local description="$2"
    shift 2

    echo ""
    echo "========================================"
    echo "Fetching: ${description}"
    echo "========================================"
    echo ""

    if [ "$DRY_RUN" = "true" ]; then
        if [ -f "${FETCH_SCRIPTS_DIR}/${script_name}" ]; then
            SUCCEEDED+=("${description}")
        else
            FAILED+=("${description}")
        fi
        return
    fi

    if [ ! -f "${FETCH_SCRIPTS_DIR}/${script_name}" ]; then
        echo "⚠ Script not found: ${script_name}"
        FAILED+=("${description}")
        return
    fi

    if "${FETCH_SCRIPTS_DIR}/${script_name}" "$@"; then
        SUCCEEDED+=("${description}")
    else
        FAILED+=("${description}")
        echo "⚠ ${description} fetch failed (non-critical, continuing...)"
    fi
}

# Format: script|description|optional args
FETCH_TASKS=(
    "fetch_vscode.sh|VS Code|"
    "fetch_offline_rpms.sh|RPM Packages (WineHQ, Docker Desktop)|--all --skip-existing"
    "fetch_gimp.sh|GIMP|"
    "fetch_krita.sh|Krita|"
    "fetch_blender.sh|Blender 4.2|"
    "fetch_drawio.sh|draw.io|"
    "fetch_obs.sh|OBS Studio|"
    "fetch_cuda_toolkit.sh|CUDA Toolkit|"
    "fetch_openshift_tools.sh|OpenShift/Kubernetes CLI|"
    "fetch_claude_code.sh|Claude Code CLI|"
    "fetch_helm.sh|Helm Package Manager|"
    "fetch_k3s_binary.sh|k3s Binary|"
    "fetch_k3s_images.sh|k3s offline images|"
    "fetch_lutris_runners.sh|Lutris Runners (Dw Proton, DXVK, VKD3D, Proton-GE)|"
)

for task in "${FETCH_TASKS[@]}"; do
    IFS='|' read -r script_name description args <<< "$task"
    if [ -n "$args" ]; then
        # shellcheck disable=SC2086
        run_fetch_entry "$script_name" "$description" $args
    else
        run_fetch_entry "$script_name" "$description"
    fi
done

if [ "$INCLUDE_OPTIONAL_FETCH" = "true" ]; then
    run_fetch_entry "pull-vscode-extensions.sh" "VS Code Extensions"

    if command -v npm >/dev/null 2>&1; then
        run_fetch_entry "create-npm-tarballs.sh" "npm Tarballs"
    else
        echo ""
        echo "⚠ npm not found; skipping npm tarball generation"
        FAILED+=("npm Tarballs")
    fi
fi

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
echo "  ./build-scripts/build_export_iso.sh --iso-name BOOTC.iso"
echo ""

# Exit with success even if some fetches failed (non-critical)
exit 0
