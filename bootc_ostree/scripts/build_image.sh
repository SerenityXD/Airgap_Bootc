#!/usr/bin/env bash
set -euo pipefail

# Build a bootc-compatible OCI image with KDE, NVIDIA/CUDA, Docker Desktop, VS Code, and extras.
# Requires: podman, bootc-image-builder (or use podman build with bootc labels)

IMAGE_NAME=${IMAGE_NAME:-localhost/scvu-bootc:kde-nvidia}
CONTEXT_DIR=${CONTEXT_DIR:-./image}

echo "Building image $IMAGE_NAME from $CONTEXT_DIR"

if command -v bootc-image-builder >/dev/null 2>&1; then
  bootc-image-builder build --image "$IMAGE_NAME" --rootfs ext4 "$CONTEXT_DIR"
else
  podman build -t "$IMAGE_NAME" "$CONTEXT_DIR"
fi

echo "Image built: $IMAGE_NAME"
