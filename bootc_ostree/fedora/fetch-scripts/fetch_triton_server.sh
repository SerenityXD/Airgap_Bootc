#!/bin/bash
# Download NVIDIA Triton Inference Server container image for offline use
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_DIR="$(get_offline_dir "triton" "${SCRIPT_PATH}")"
TRITON_VERSION="${TRITON_VERSION:-24.11}"  # Update as needed
TRITON_IMAGE="nvcr.io/nvidia/tritonserver:${TRITON_VERSION}-py3"

print_section "Fetch NVIDIA Triton Inference Server"
echo ""
echo "Version: ${TRITON_VERSION}"
echo "Image: ${TRITON_IMAGE}"
echo "Target directory: ${OFFLINE_DIR}"
echo ""
echo "Note: Triton Server container is ~8-10 GB"
echo ""

mkdir -p "${OFFLINE_DIR}"

# Check if podman is available
if ! require_cmd podman; then
    echo "✗ Error: podman is required to pull container images"
    echo "  Install: sudo dnf install -y podman"
    exit 1
fi

# Pull Triton Server image
echo "Pulling Triton Server image (this may take several minutes)..."
if podman pull "${TRITON_IMAGE}"; then
    echo "  ✓ Image pulled successfully"
else
    echo "  ✗ Failed to pull image"
    echo ""
    echo "  Manual pull:"
    echo "    podman pull ${TRITON_IMAGE}"
    exit 1
fi

# Save to OCI archive
ARCHIVE_NAME="tritonserver-${TRITON_VERSION}.tar"
echo ""
echo "Saving image to OCI archive: ${ARCHIVE_NAME}"
echo "(This may take several minutes...)"
if podman save -o "${OFFLINE_DIR}/${ARCHIVE_NAME}" "${TRITON_IMAGE}"; then
    echo "  ✓ Image saved successfully"
    
    # Get archive size
    ARCHIVE_SIZE=$(du -h "${OFFLINE_DIR}/${ARCHIVE_NAME}" | cut -f1)
    echo "  Archive size: ${ARCHIVE_SIZE}"
else
    echo "  ✗ Failed to save image"
    exit 1
fi

echo ""
print_section "Download Complete!"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "The Triton Server image will be automatically loaded on the target system."
echo ""
echo "After installing the OS, load the image:" 
echo "  podman load -i ~/.local/share/triton/${ARCHIVE_NAME}"
echo "  podman run --rm --gpus all -p 8000:8000 -p 8001:8001 -p 8002:8002 \\\"
echo "    -v /path/to/models:/models \\\"
echo "    ${TRITON_IMAGE} tritonserver --model-repository=/models"
echo ""
echo "To rebuild ISO with Triton Server:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build-scripts/build_export_iso.sh --iso-name BOOTC.iso"
echo ""
