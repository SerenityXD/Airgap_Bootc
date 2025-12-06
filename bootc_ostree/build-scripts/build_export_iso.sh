#!/usr/bin/env bash
# Build image -> export OCI -> load into rootful -> create ISO -> verify
set -euo pipefail

# Start timer
BUILD_START_TIME=$(date +%s)

# Setup logging
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"

# Log both to file and console
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "Build started: $(date)"
echo "Log file: $LOG_FILE"
echo "========================================"
echo ""

# Validate sudo access early and start keep-alive
echo "Checking sudo access..."
if ! sudo -n true 2>/dev/null; then
    echo "This script requires sudo access for rootful Podman operations."
    echo "You may be prompted for your password."
    sudo -v
fi

# Start sudo keep-alive in background
# Refreshes sudo timestamp every 60 seconds until this script exits
(
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done
) &
SUDO_KEEPALIVE_PID=$!
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null || true" EXIT

# Config (override via env or flags)
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
ISO_NAME="${ISO_NAME:-}"  # Optional custom ISO name
ISO_TYPE="${ISO_TYPE:-anaconda-iso}"  # anaconda-iso (interactive, DEFAULT) or iso (non-interactive)
CONFIG_FILE="${CONFIG_FILE:-config-interactive.toml}"  # TOML config file for Anaconda customization

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
  --iso-name NAME               Custom output ISO filename (default: install.iso)
  --iso-type TYPE               ISO type: 'anaconda-iso' (interactive, DEFAULT) or 'iso' (non-interactive)
                                (default: anaconda-iso)
  --config FILE                 TOML config file for bootc-image-builder customizations
                                (default: config-interactive.toml)
  -h, --help                    Show this help

Environment overrides are honored: TAG, OUTPUT_DIR, OCI_PATH, ROOTFS, BUILDER_IMG, TMPDIR, FETCH_OFFLINE, FETCH_PACKAGES, SKIP_EXISTING, ISO_NAME, ISO_TYPE, CONFIG_FILE

Examples:
  # Build interactive installer ISO (DEFAULT)
  $(basename "$0")

  # Build with custom ISO name
  $(basename "$0") --iso-name SCVU-Custom.iso

  # Build non-interactive (pre-configured) ISO
  $(basename "$0") --iso-type iso
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
    --iso-name) ISO_NAME="$2"; shift 2;;
    --iso-type) ISO_TYPE="$2"; shift 2;;
    --config) CONFIG_FILE="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

# Prepare directories and ensure a clean output area before build
mkdir -p "$TMPDIR" "$OCI_DIR"
echo "[prep] Removing output directory $OUTPUT_DIR (if present) ..."
if ! rm -rf "$OUTPUT_DIR" 2>/dev/null; then
  echo "[prep] rm without sudo failed; retrying with sudo ..."
  sudo rm -rf "$OUTPUT_DIR" || true
fi
mkdir -p "$OUTPUT_DIR"

# Validate mode configuration
if [[ "$ISO_TYPE" == "anaconda-iso" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[prep] Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
  fi
  
  echo "[prep] Using anaconda-iso (interactive installer) mode - DEFAULT"
  echo "[prep] Config file: $CONFIG_FILE"
elif [[ "$ISO_TYPE" == "iso" ]]; then
  echo "[prep] Using iso (non-interactive, pre-configured) mode"
else
  echo "[prep] Error: Unknown ISO_TYPE '$ISO_TYPE'. Use 'anaconda-iso' (DEFAULT) or 'iso'" >&2
  exit 1
fi

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
STEP_START=$(date +%s)
TMPDIR="$TMPDIR" podman build --pull=always -t "$TAG" "$IMAGE_DIR"
STEP_END=$(date +%s)
echo "[1/4] Build completed in $((STEP_END - STEP_START))s"

echo "[2/4] Saving OCI archive to $OCI_PATH ..."
STEP_START=$(date +%s)
podman save --format oci-archive -o "$OCI_PATH" "$TAG"
STEP_END=$(date +%s)
echo "[2/4] OCI save completed in $((STEP_END - STEP_START))s"

# 3) Load into rootful
echo "[3/4] Loading image into rootful Podman ..."
STEP_START=$(date +%s)
sudo podman load -i "$OCI_PATH"
sudo podman images | grep -E "^$TAG[[:space:]]" || true
STEP_END=$(date +%s)
echo "[3/4] Rootful load completed in $((STEP_END - STEP_START))s"

# 4) Build ISO with bootc-image-builder
echo "[4/4] Creating ISO via $BUILDER_IMG ..."
echo "[4/4] ISO Type: $ISO_TYPE"
STEP_START=$(date +%s)

# Build the podman run command
PODMAN_CMD=(
  sudo podman run --rm -it --privileged
  --security-opt label=type:unconfined_t
  -v "$OUTPUT_DIR:/output"
  -v /var/lib/containers/storage:/var/lib/containers/storage:rw
)

# Add config file volume mount if provided
if [[ -n "$CONFIG_FILE" ]]; then
  CONFIG_BASENAME=$(basename "$CONFIG_FILE")
  PODMAN_CMD+=("-v" "$CONFIG_FILE:/config/$CONFIG_BASENAME:ro")
fi

# Add the builder image and arguments
PODMAN_CMD+=("$BUILDER_IMG" "--type" "$ISO_TYPE" "--rootfs" "$ROOTFS")

# Add config file reference if provided (for anaconda-iso mode)
if [[ -n "$CONFIG_FILE" ]]; then
  CONFIG_BASENAME=$(basename "$CONFIG_FILE")
  PODMAN_CMD+=("--config" "/config/$CONFIG_BASENAME")
fi

PODMAN_CMD+=("$TAG")

# Execute the build
"${PODMAN_CMD[@]}" | tee "$OUTPUT_DIR/iso-build.log"
STEP_END=$(date +%s)
echo "[4/4] ISO creation completed in $((STEP_END - STEP_START))s"

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

# After ISO creation and verification
if [[ -n "$ISO_NAME" && -f "$ISO_PATH" ]]; then
  TARGET_ISO="$OUTPUT_DIR/bootiso/$ISO_NAME"
  if mv -v "$ISO_PATH" "$TARGET_ISO" 2>/dev/null; then
    ISO_PATH="$TARGET_ISO"
  else
    echo "[rename] mv without sudo failed; retrying with sudo ..."
    if sudo -n mv -v "$ISO_PATH" "$TARGET_ISO"; then
      # Attempt to change ownership back to invoking user so the file is accessible
      sudo -n chown "$(id -u)":"$(id -g)" "$TARGET_ISO" || true
      ISO_PATH="$TARGET_ISO"
    else
      echo "[rename] Warning: sudo requires a password; run manually:" >&2
      echo "         sudo mv \"$ISO_PATH\" \"$TARGET_ISO\" && sudo chown $(id -u):$(id -g) \"$TARGET_ISO\"" >&2
      echo "         Or rerun script with: sudo \"$0\" --iso-name \"$ISO_NAME\"" >&2
    fi
  fi
fi

echo ""
echo "ISO created: $ISO_PATH"
ls -lh "$ISO_PATH"
file "$ISO_PATH"
BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
BUILD_MINUTES=$((BUILD_DURATION / 60))
BUILD_SECONDS=$((BUILD_DURATION % 60))

echo ""
echo "========================================"
echo "== Summary =="
echo "========================================"
echo "Image tag:        $TAG"
echo "OCI archive:      $OCI_PATH"
echo "Output directory: $OUTPUT_DIR"
echo "ISO type:         $ISO_TYPE"
if [[ -n "$CONFIG_FILE" ]]; then
  echo "Config file:      $CONFIG_FILE"
fi
echo "Build time:       $(printf "%02d:%02d" $BUILD_MINUTES $BUILD_SECONDS)"
echo "Log file:         $LOG_FILE"
echo "========================================"
echo "Build completed: $(date)"
echo "========================================"
ls -lh "$ISO_PATH"
