#!/usr/bin/env bash
# Build image -> export OCI -> load into rootful -> create ISO -> verify
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"

# Positional mode support (replaces build-iso-helper.sh wrapper):
#   interactive (default), non-interactive, compare
MODE="interactive"
if [[ ${1:-} && ${1:0:1} != "-" ]]; then
  case "$1" in
    interactive|non-interactive|compare)
      MODE="$1"
      shift
      ;;
    *)
      echo "Error: Unknown mode '$1'" >&2
      echo "Valid modes: interactive, non-interactive, compare" >&2
      exit 2
      ;;
  esac
fi


if ! command -v podman >/dev/null 2>&1; then
  echo "Error: podman is required on the host." >&2
  exit 1
fi

# Start timer
BUILD_START_TIME=$(date +%s)

# Setup logging
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
TAG="${TAG:-localhost/bootc-gnome:v1.0}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
OCI_DIR="$OUTPUT_DIR/oci-image"
OCI_PATH="${OCI_PATH:-$OCI_DIR/bootc-gnome.oci}"
BUILDER_IMG="${BUILDER_IMG:-quay.io/centos-bootc/bootc-image-builder:latest}"
PROFILE="${PROFILE:-full}"  # full or bare
CONTAINERFILE="${CONTAINERFILE:-}"  # resolved after profile selection
BUILD_ARTIFACT="${BUILD_ARTIFACT:-both}"  # both, iso, or oci
ROOTFS="${ROOTFS:-btrfs}"
TMPDIR_DEFAULT="$HOME/tmpbuild"
TMPDIR="${TMPDIR:-$TMPDIR_DEFAULT}"
FETCH_OFFLINE="${FETCH_OFFLINE:-false}"
FETCH_PACKAGES="${FETCH_PACKAGES:-all}"
SKIP_EXISTING="${SKIP_EXISTING:-true}"
ISO_NAME="${ISO_NAME:-}"  # Optional custom ISO name
ISO_TYPE="${ISO_TYPE:-anaconda-iso}"  # anaconda-iso (interactive, DEFAULT) or iso (non-interactive)
ISO_TYPE_SET="false"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config-interactive.toml}"  # TOML config file for Anaconda customization
CONFIG_FILE_SET="false"
IMAGE_PRUNE="${IMAGE_PRUNE:-true}"  # Remove intermediate images after build (default: true). Use --no-image-prune to disable
BUILD_ARGS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [interactive|non-interactive|compare] [options]

Modes:
  interactive         Build interactive Anaconda installer ISO (DEFAULT)
  non-interactive     Build standard non-interactive ISO
  compare             Build both interactive and non-interactive ISOs

Options (env or flags):
  -t, --tag TAG                 Image tag (default: $TAG)
  -i, --image-dir DIR           Build context (default: $IMAGE_DIR)
  -o, --output-dir DIR          Output directory (default: $OUTPUT_DIR)
  -a, --oci-path PATH           OCI archive path (default: $OCI_PATH)
  -P, --profile NAME            Build profile: full | bare (default: $PROFILE)
  -F, --containerfile PATH      Containerfile path override (default from profile)
  --artifact TYPE               Build artifact: both | iso | oci (default: $BUILD_ARTIFACT)
  -r, --rootfs TYPE             Rootfs type for ISO (default: $ROOTFS)
  -b, --builder-image IMAGE     bootc-image-builder image (default: $BUILDER_IMG)
  -f, --fetch-offline           Fetch offline packages before build
  -p, --packages PACKAGES       Packages to fetch (default: all, or: vscode,docker-desktop,etc)
  -s, --skip-existing           Skip fetching if packages already exist (default: true)
  --no-image-prune              Skip removing intermediate Podman images after build
  --build-arg KEY=VALUE         Forward build argument(s) to podman build (repeatable)
  --iso-name NAME               Custom output ISO filename (default: install.iso)
  --iso-type TYPE               ISO type: 'anaconda-iso' (interactive, DEFAULT) or 'iso' (non-interactive)
                                (default: anaconda-iso)
  --config FILE                 TOML config file for bootc-image-builder customizations
                                (default: config-interactive.toml)
  -h, --help                    Show this help

Environment overrides are honored: TAG, OUTPUT_DIR, OCI_PATH, PROFILE, CONTAINERFILE, BUILD_ARTIFACT, ROOTFS, BUILDER_IMG, TMPDIR, FETCH_OFFLINE, FETCH_PACKAGES, SKIP_EXISTING, ISO_NAME, ISO_TYPE, CONFIG_FILE

Examples:
  # Build interactive installer ISO (DEFAULT)
  $(basename "$0")
  $(basename "$0") interactive

  # Build with custom ISO name
  $(basename "$0") --iso-name BOOTC-Custom.iso

  # Build non-interactive (pre-configured) ISO
  $(basename "$0") non-interactive

  # Build both variants for side-by-side comparison
  $(basename "$0") compare
EOF
}

# Parse flags
while [[ ${1:-} ]]; do
  case "$1" in
    -t|--tag) TAG="$2"; shift 2;;
    -i|--image-dir) IMAGE_DIR="$2"; shift 2;;
    -o|--output-dir) OUTPUT_DIR="$2"; shift 2;;
    -a|--oci-path) OCI_PATH="$2"; shift 2;;
    -P|--profile) PROFILE="$2"; shift 2;;
    -F|--containerfile) CONTAINERFILE="$2"; shift 2;;
    --artifact) BUILD_ARTIFACT="$2"; shift 2;;
    -r|--rootfs) ROOTFS="$2"; shift 2;;
    -b|--builder-image) BUILDER_IMG="$2"; shift 2;;
    -f|--fetch-offline) FETCH_OFFLINE="true"; shift;;
    -p|--packages) FETCH_PACKAGES="$2"; shift 2;;
    -s|--skip-existing) SKIP_EXISTING="true"; shift;;
    --iso-name) ISO_NAME="$2"; shift 2;;
    --iso-type) ISO_TYPE="$2"; ISO_TYPE_SET="true"; shift 2;;
    --config) CONFIG_FILE="$2"; CONFIG_FILE_SET="true"; shift 2;;
    --no-image-prune) IMAGE_PRUNE="false"; shift;;
    --build-arg) BUILD_ARGS+=("$2"); shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ "$PROFILE" != "full" && "$PROFILE" != "bare" ]]; then
  echo "[prep] Error: Unknown profile '$PROFILE'. Use 'full' or 'bare'." >&2
  exit 2
fi

if [[ "$BUILD_ARTIFACT" != "both" && "$BUILD_ARTIFACT" != "iso" && "$BUILD_ARTIFACT" != "oci" ]]; then
  echo "[prep] Error: Unknown artifact type '$BUILD_ARTIFACT'. Use 'both', 'iso', or 'oci'." >&2
  exit 2
fi

if [[ -z "$CONTAINERFILE" ]]; then
  if [[ "$PROFILE" == "bare" ]]; then
    CONTAINERFILE="$IMAGE_DIR/Containerfile.bare"
  else
    CONTAINERFILE="$IMAGE_DIR/Containerfile"
  fi
fi

CONTAINERFILE=$(resolve_path "$CONTAINERFILE" 2>/dev/null || echo "$CONTAINERFILE")
if [[ ! -f "$CONTAINERFILE" ]]; then
  echo "[prep] Error: Containerfile not found: $CONTAINERFILE" >&2
  exit 1
fi

# Resolve mode to iso behavior unless explicitly overridden by --iso-type.
if [[ "$ISO_TYPE_SET" != "true" ]]; then
  if [[ "$MODE" == "non-interactive" ]]; then
    ISO_TYPE="iso"
  else
    ISO_TYPE="anaconda-iso"
  fi
else
  if [[ "$MODE" == "interactive" && "$ISO_TYPE" == "iso" ]]; then
    echo "[prep] Warning: mode is interactive but --iso-type iso was provided; honoring --iso-type iso" >&2
  fi
  if [[ "$MODE" == "non-interactive" && "$ISO_TYPE" == "anaconda-iso" ]]; then
    echo "[prep] Warning: mode is non-interactive but --iso-type anaconda-iso was provided; honoring --iso-type anaconda-iso" >&2
  fi
fi

# Compare mode builds both variants by recursively invoking this script.
if [[ "$MODE" == "compare" ]]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  INTERACTIVE_ISO="BOOTC-Interactive-${TIMESTAMP}.iso"
  STANDARD_ISO="BOOTC-Standard-${TIMESTAMP}.iso"
  COMPARE_BASE_OUTPUT="$OUTPUT_DIR"
  INTERACTIVE_OUTPUT_DIR="${COMPARE_BASE_OUTPUT}.compare-interactive-${TIMESTAMP}"
  STANDARD_OUTPUT_DIR="${COMPARE_BASE_OUTPUT}.compare-standard-${TIMESTAMP}"

  COMMON_ARGS=(
    --tag "$TAG"
    --image-dir "$IMAGE_DIR"
    --oci-path "$OCI_PATH"
    --profile "$PROFILE"
    --containerfile "$CONTAINERFILE"
    --artifact iso
    --rootfs "$ROOTFS"
    --builder-image "$BUILDER_IMG"
    --packages "$FETCH_PACKAGES"
  )

  if [[ "$FETCH_OFFLINE" == "true" ]]; then
    COMMON_ARGS+=(--fetch-offline)
  fi
  if [[ "$SKIP_EXISTING" == "true" ]]; then
    COMMON_ARGS+=(--skip-existing)
  fi
  if [[ "$IMAGE_PRUNE" == "false" ]]; then
    COMMON_ARGS+=(--no-image-prune)
  fi
  for build_arg in "${BUILD_ARGS[@]}"; do
    COMMON_ARGS+=(--build-arg "$build_arg")
  done
  if [[ "$CONFIG_FILE_SET" == "true" ]]; then
    COMMON_ARGS+=(--config "$CONFIG_FILE")
  fi

  echo "=== Building Both Interactive and Non-Interactive ISOs ==="
  echo "[1/2] Building interactive installer..."
  "$0" interactive "${COMMON_ARGS[@]}" --output-dir "$INTERACTIVE_OUTPUT_DIR" --iso-name "$INTERACTIVE_ISO"

  echo ""
  echo "[2/2] Building non-interactive standard..."
  "$0" non-interactive "${COMMON_ARGS[@]}" --output-dir "$STANDARD_OUTPUT_DIR" --iso-name "$STANDARD_ISO"

  FINAL_BOOTISO_DIR="$COMPARE_BASE_OUTPUT/bootiso"
  mkdir -p "$FINAL_BOOTISO_DIR"

  if [[ -f "$INTERACTIVE_OUTPUT_DIR/bootiso/$INTERACTIVE_ISO" ]]; then
    mv -f "$INTERACTIVE_OUTPUT_DIR/bootiso/$INTERACTIVE_ISO" "$FINAL_BOOTISO_DIR/$INTERACTIVE_ISO"
  fi
  if [[ -f "$STANDARD_OUTPUT_DIR/bootiso/$STANDARD_ISO" ]]; then
    mv -f "$STANDARD_OUTPUT_DIR/bootiso/$STANDARD_ISO" "$FINAL_BOOTISO_DIR/$STANDARD_ISO"
  fi

  rm -rf "$INTERACTIVE_OUTPUT_DIR" "$STANDARD_OUTPUT_DIR" 2>/dev/null || true

  echo ""
  echo "=== Comparison Build Complete ==="
  echo "Output directory: $FINAL_BOOTISO_DIR"
  ls -lh "$FINAL_BOOTISO_DIR/$INTERACTIVE_ISO" "$FINAL_BOOTISO_DIR/$STANDARD_ISO" 2>/dev/null || true
  exit 0
fi

# Non-interactive mode should not use an interactive config unless user explicitly requested one.
if [[ "$ISO_TYPE" == "iso" && "$CONFIG_FILE_SET" != "true" ]]; then
  CONFIG_FILE=""
fi

# Prepare output directories without rotating backups.
mkdir -p "$TMPDIR"
mkdir -p "$OUTPUT_DIR" "$OUTPUT_DIR/bootiso" "$OCI_DIR"

# Validate mode configuration
if [[ "$ISO_TYPE" == "anaconda-iso" ]]; then
  if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    echo "[prep] Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
  fi

  CONFIG_FILE=$(resolve_path "$CONFIG_FILE" 2>/dev/null || echo "$CONFIG_FILE")

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
  FETCH_SCRIPT="$ROOT_DIR/image/scripts/fetch_offline_rpms.sh"
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
BUILD_CMD=(podman build --format docker --pull=always -t "$TAG")
for build_arg in "${BUILD_ARGS[@]}"; do
  BUILD_CMD+=(--build-arg "$build_arg")
done
BUILD_CMD+=(-f "$CONTAINERFILE" "$IMAGE_DIR")

if TMPDIR="$TMPDIR" "${BUILD_CMD[@]}"; then
  STEP_END=$(date +%s)
  echo "[1/4] Build completed in $((STEP_END - STEP_START))s"
else
  STEP_END=$(date +%s)
  echo "[1/4] Build failed after $((STEP_END - STEP_START))s" >&2
  exit 1
fi

ISO_PATH=""
ROOTFUL_LOAD_SOURCE=""
TMP_OCI_PATH="$TMPDIR/bootc-image-builder-$(date +%s).oci"

if [[ "$BUILD_ARTIFACT" == "both" || "$BUILD_ARTIFACT" == "oci" ]]; then
  echo "[2/4] Saving OCI archive to $OCI_PATH ..."
  STEP_START=$(date +%s)
  if podman save --format oci-archive -o "$OCI_PATH" "$TAG"; then
    STEP_END=$(date +%s)
    echo "[2/4] OCI save completed in $((STEP_END - STEP_START))s"
  else
    STEP_END=$(date +%s)
    echo "[2/4] OCI save failed after $((STEP_END - STEP_START))s" >&2
    exit 1
  fi
fi

if [[ "$BUILD_ARTIFACT" == "both" || "$BUILD_ARTIFACT" == "iso" ]]; then
  if [[ "$BUILD_ARTIFACT" == "both" ]]; then
    ROOTFUL_LOAD_SOURCE="$OCI_PATH"
  else
    echo "[2/4] Creating temporary OCI archive for ISO build ..."
    STEP_START=$(date +%s)
    if podman save --format oci-archive -o "$TMP_OCI_PATH" "$TAG"; then
      STEP_END=$(date +%s)
      echo "[2/4] Temporary OCI save completed in $((STEP_END - STEP_START))s"
      ROOTFUL_LOAD_SOURCE="$TMP_OCI_PATH"
    else
      STEP_END=$(date +%s)
      echo "[2/4] Temporary OCI save failed after $((STEP_END - STEP_START))s" >&2
      exit 1
    fi
  fi

  # 3) Load into rootful
  echo "[3/4] Loading image into rootful Podman ..."
  STEP_START=$(date +%s)
  if sudo podman load -i "$ROOTFUL_LOAD_SOURCE"; then
    sudo podman images | grep -E "^$TAG[[:space:]]" || true
    STEP_END=$(date +%s)
    echo "[3/4] Rootful load completed in $((STEP_END - STEP_START))s"
  else
    STEP_END=$(date +%s)
    echo "[3/4] Rootful load failed after $((STEP_END - STEP_START))s" >&2
    exit 1
  fi

  # 4) Build ISO with bootc-image-builder
  echo "[4/4] Creating ISO via $BUILDER_IMG ..."
  echo "[4/4] ISO Type: $ISO_TYPE"
  STEP_START=$(date +%s)

  # Build the podman run command
  PODMAN_CMD=(
    sudo podman run --rm -it --privileged
    --security-opt label=type:unconfined_t
    --network host
    -v /etc/resolv.conf:/etc/resolv.conf:ro
    -e http_proxy -e https_proxy -e no_proxy
    -e HTTP_PROXY -e HTTPS_PROXY -e NO_PROXY
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

    if [[ "$ISO_PATH" == "$TARGET_ISO" ]]; then
      echo "[rename] ISO already has target name: $TARGET_ISO"
    else
      if [[ -e "$TARGET_ISO" ]]; then
        echo "[rename] Target exists and will be replaced: $TARGET_ISO"
      fi

      # Use -f to avoid interactive overwrite prompts that can stall unattended runs.
      if mv -fv "$ISO_PATH" "$TARGET_ISO" 2>/dev/null; then
        ISO_PATH="$TARGET_ISO"
      else
        echo "[rename] mv without sudo failed; retrying with sudo ..."
        if sudo -n mv -fv "$ISO_PATH" "$TARGET_ISO"; then
          # Attempt to change ownership back to invoking user so the file is accessible
          sudo -n chown "$(id -u)":"$(id -g)" "$TARGET_ISO" || true
          ISO_PATH="$TARGET_ISO"
        else
          echo "[rename] Warning: sudo requires a password; run manually:" >&2
          echo "         sudo mv -f \"$ISO_PATH\" \"$TARGET_ISO\" && sudo chown $(id -u):$(id -g) \"$TARGET_ISO\"" >&2
          echo "         Or rerun script with: sudo \"$0\" --iso-name \"$ISO_NAME\"" >&2
        fi
      fi
    fi
  fi
fi

rm -f "$TMP_OCI_PATH" 2>/dev/null || true

# Remove images to save drive space (optional)
if [[ "$IMAGE_PRUNE" == "true" ]]; then
  echo "Cleaning up images to save drive space..."
  sudo podman image prune -f || true
else
  echo "Skipping image cleanup (IMAGE_PRUNE=false or --no-image-prune supplied)"
fi

echo ""
if [[ -n "$ISO_PATH" ]]; then
  echo "ISO created: $ISO_PATH"
  ls -lh "$ISO_PATH"
  file "$ISO_PATH"
fi
BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
BUILD_MINUTES=$((BUILD_DURATION / 60))
BUILD_SECONDS=$((BUILD_DURATION % 60))

echo ""
echo "========================================"
echo "== Summary =="
echo "========================================"
echo "Image tag:        $TAG"
if [[ "$BUILD_ARTIFACT" == "both" || "$BUILD_ARTIFACT" == "oci" ]]; then
  echo "OCI archive:      $OCI_PATH"
fi
echo "Output directory: $OUTPUT_DIR"
echo "Profile:          $PROFILE"
echo "Containerfile:    $CONTAINERFILE"
echo "Artifact:         $BUILD_ARTIFACT"
echo "ISO type:         $ISO_TYPE"
if (( ${#BUILD_ARGS[@]} > 0 )); then
  echo "Build args:       ${BUILD_ARGS[*]}"
fi
if [[ -n "$CONFIG_FILE" ]]; then
  echo "Config file:      $CONFIG_FILE"
fi
echo "Build time:       $(printf "%02d:%02d" $BUILD_MINUTES $BUILD_SECONDS)"
echo "Log file:         $LOG_FILE"
echo "========================================"
echo "Build completed: $(date)"
echo "========================================"
if [[ -n "$ISO_PATH" ]]; then
  ls -lh "$ISO_PATH"
fi
