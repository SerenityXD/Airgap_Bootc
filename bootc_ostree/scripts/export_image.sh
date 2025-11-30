#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-localhost/scvu-bootc:kde-nvidia}
OUT_DIR=${OUT_DIR:-$PWD/../artifacts}
TARBALL=${TARBALL:-$OUT_DIR/scvu-bootc-kde-nvidia.oci.tar}

mkdir -p "$OUT_DIR"

echo "Exporting $IMAGE_NAME to $TARBALL"
podman save -o "$TARBALL" "$IMAGE_NAME"

echo "Export complete: $TARBALL"
