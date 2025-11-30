#!/usr/bin/env bash
set -euo pipefail

# Compose an offline installer ISO embedding the bootc image

IMAGE_NAME=${IMAGE_NAME:-localhost/scvu-bootc:kde-nvidia}
OUT_DIR=${OUT_DIR:-$PWD/../artifacts}
ISO_PATH=${ISO_PATH:-$OUT_DIR/scvu-bootc-installer.iso}

mkdir -p "$OUT_DIR"

echo "Composing installer ISO with image $IMAGE_NAME"
if command -v bootc-image-builder >/dev/null 2>&1; then
  bootc-image-builder installer --image "$IMAGE_NAME" --output "$ISO_PATH"
else
  echo "bootc-image-builder not found. Install it or use coreos-installer with embed args."
  exit 2
fi

echo "Installer ISO: $ISO_PATH"
