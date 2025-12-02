#!/usr/bin/env bash
# Build image -> export OCI -> load into rootful -> create ISO -> verify
set -euo pipefail

# Config (override via env or flags)
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_DIR="$ROOT_DIR/image"
TAG="${TAG:-localhost/scvu-bootc:kde}"
OCI_DIR="$ROOT_DIR/oci-image"
OCI_PATH="${OCI_PATH:-$OCI_DIR/scvu-bootc-kde.oci}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
BUILDER_IMG="${BUILDER_IMG:-quay.io/centos-bootc/bootc-image-builder:latest}"
ROOTFS="${ROOTFS:-btrfs}"
TMPDIR_DEFAULT="$HOME/tmpbuild"
TMPDIR="${TMPDIR:-$TMPDIR_DEFAULT}"
FETCH_OFFLINE="${FETCH_OFFLINE:-false}"
FETCH_PACKAGES="${FETCH_PACKAGES:-all}"
SKIP_EXISTING="${SKIP_EXISTING:-true}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options (env or flags):
  -t, --tag TAG                 Image tag (default: $TAG)
  -i, --image-dir DIR           Build context (default: $IMAGE_DIR)
  -o, --output-dir DIR          Output directory (default: $OUTPUT_DIR)
  -a, --oci-path PATH           OCI archive path (default: $OCI_PATH)
  -r, --rootfs TYPE             Rootfs type for ISO (default: $ROOTFS)
  -b, --builder-image IMAGE     bootc-image-builder image (default: $BUILDER_IMG)
  -f, --fetch-offline           Fetch offline packages before build
  -p, --packages PACKAGES       Packages to fetch (default: all, or: vscode,nvidia,docker-desktop,etc)
  -s, --skip-existing           Skip fetching if packages already exist (default: true)
  -h, --help                    Show this help

Environment overrides are honored: TAG, OUTPUT_DIR, OCI_PATH, ROOTFS, BUILDER_IMG, TMPDIR, FETCH_OFFLINE, FETCH_PACKAGES, SKIP_EXISTING

Examples:
  # Basic build with online fallback
  $(basename "$0")

  # Build with automatic offline package fetching
  $(basename "$0") --fetch-offline

  # Fetch specific packages only
  $(basename "$0") --fetch-offline --packages vscode,nvidia,docker-desktop

  # Custom tag and rootfs
  $(basename "$0") --tag myimage:latest --rootfs ext4 --fetch-offline
EOF
}

# Parse flags
while [[ ${1:-} ]]; do
  case "$1" in
    -t|--tag) TAG="$2"; shift 2;;
    -i|--image-dir) IMAGE_DIR="$2"; shift 2;;
    -o|--output-dir) OUTPUT_DIR="$2"; shift 2;;
    -a|--oci-path) OCI_PATH="$2"; shift 2;;
    -r|--rootfs) ROOTFS="$2"; shift 2;;
    -b|--builder-image) BUILDER_IMG="$2"; shift 2;;
    -f|--fetch-offline) FETCH_OFFLINE="true"; shift;;
    -p|--packages) FETCH_PACKAGES="$2"; shift 2;;
    -s|--skip-existing) SKIP_EXISTING="true"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

summary() {
  echo ""
  echo "== Summary =="
  echo "Image tag:        $TAG"
  echo "OCI archive:      $OCI_PATH"
  echo "Output directory: $OUTPUT_DIR"
  if [[ -n "${ISO_PATH:-}" && -f "$ISO_PATH" ]]; then
    ls -lh "$ISO_PATH" || true
    file "$ISO_PATH" || true
    echo ""
    echo "== Next Steps =="
    echo "Burn ISO to USB using one of these methods:"
    echo "  • Linux:   sudo dd if=$ISO_PATH of=/dev/sdX bs=4M status=progress && sync"
    echo "  • Ventoy:  Copy ISO to Ventoy USB partition"
    echo "  • Etcher:  balenaEtcher (cross-platform GUI)"
    echo "  • Windows: Rufus or balenaEtcher"
    echo ""
    echo "⚠️  DO NOT use Fedora Media Writer (incompatible with bootc/ostree ISOs)"
    echo ""
    echo "For detailed instructions, see README.md section 'Burning ISO to USB'"
  fi
}
trap summary EXIT

# Prepare directories and ensure a clean output area before build
mkdir -p "$TMPDIR" "$OCI_DIR"
echo "[prep] Removing output directory $OUTPUT_DIR (if present) ..."
if ! rm -rf "$OUTPUT_DIR" 2>/dev/null; then
  echo "[prep] rm without sudo failed; retrying with sudo ..."
  sudo rm -rf "$OUTPUT_DIR" || true
fi
mkdir -p "$OUTPUT_DIR"

# 0) Fetch offline packages (optional)
if [[ "$FETCH_OFFLINE" == "true" ]]; then
  FETCH_SCRIPT="$ROOT_DIR/fetch_offline_rpms.sh"
  if [[ ! -x "$FETCH_SCRIPT" ]]; then
    echo "[0/4] Error: fetch_offline_rpms.sh not found or not executable at $FETCH_SCRIPT" >&2
    exit 1
  fi
  
  echo "[0/4] Fetching offline packages: $FETCH_PACKAGES ..."
  FETCH_ARGS=""
  
  # Parse FETCH_PACKAGES into arguments
  if [[ "$FETCH_PACKAGES" == "all" ]]; then
    FETCH_ARGS="--all"
  else
    IFS=',' read -ra PACKAGES <<< "$FETCH_PACKAGES"
    for pkg in "${PACKAGES[@]}"; do
      FETCH_ARGS="$FETCH_ARGS --${pkg}"
    done
  fi
  
  # Add skip-existing flag if enabled
  if [[ "$SKIP_EXISTING" == "true" ]]; then
    FETCH_ARGS="$FETCH_ARGS --skip-existing"
  fi
  
  echo "[0/4] Running: $FETCH_SCRIPT $FETCH_ARGS"
  "$FETCH_SCRIPT" $FETCH_ARGS || {
    echo "[0/4] Warning: Some packages failed to fetch, continuing with online fallback..." >&2
  }
fi

# 1) Build image (rootless)
echo "[1/4] Building image $TAG from $IMAGE_DIR ..."
TMPDIR="$TMPDIR" podman build --pull=always -t "$TAG" "$IMAGE_DIR"

echo "[2/4] Saving OCI archive to $OCI_PATH ..."
podman save --format oci-archive -o "$OCI_PATH" "$TAG"

# 3) Load into rootful
echo "[3/4] Loading image into rootful Podman ..."
sudo podman load -i "$OCI_PATH"
sudo podman images | grep -E "^$TAG[[:space:]]" || true

# 4) Build ISO with bootc-image-builder
echo "[4/4] Creating ISO via $BUILDER_IMG ..."
sudo podman run --rm -it --privileged \
  --security-opt label=type:unconfined_t \
  -v "$OUTPUT_DIR:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage:rw \
  "$BUILDER_IMG" \
  --type iso --rootfs "$ROOTFS" "$TAG" | tee "$OUTPUT_DIR/iso-build.log"

# Verify ISO path (single bootiso first, fallback to double)
CANDIDATE1="$OUTPUT_DIR/bootiso/install.iso"
CANDIDATE2="$OUTPUT_DIR/bootiso/bootiso/install.iso"
if [[ -f "$CANDIDATE1" ]]; then
  ISO_PATH="$CANDIDATE1"
elif [[ -f "$CANDIDATE2" ]]; then
  ISO_PATH="$CANDIDATE2"
else
  echo "ISO not found in expected locations:" >&2
  echo "  - $CANDIDATE1" >&2
  echo "  - $CANDIDATE2" >&2
  exit 1
fi

echo ""
echo "ISO created: $ISO_PATH"
ls -lh "$ISO_PATH"
file "$ISO_PATH"
