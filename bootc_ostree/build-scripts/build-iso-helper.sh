#!/usr/bin/env bash
# Helper script to build ISOs (interactive or non-interactive)
# Makes it easy to switch between modes (interactive is now DEFAULT)

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_SCRIPT="$ROOT_DIR/build_export_iso.sh"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [interactive|non-interactive|compare] [OPTIONS]

Modes:
  interactive         Build interactive Anaconda installer ISO (DEFAULT when running no args)
  non-interactive     Build standard non-interactive ISO (pre-configured)
  compare             Build both interactive and non-interactive side-by-side

Global OPTIONS:
  --iso-name NAME     Custom ISO filename (default: auto-generated)
  --tag TAG           Image tag (default: localhost/scvu-bootc:kde)
  --fetch-offline     Fetch offline packages before build
  --packages PKG      Specific packages to fetch (comma-separated)
  -h, --help          Show this help

Examples:
  # Build interactive installer (DEFAULT mode)
  $(basename "$0") interactive

  # Also builds interactive (no args defaults to interactive)
  $(basename "$0")

  # Build non-interactive with custom name
  $(basename "$0") non-interactive --iso-name SCVU-Std.iso

  # Build both versions for comparison
  $(basename "$0") compare

  # Build interactive with offline packages
  $(basename "$0") interactive --fetch-offline --iso-name SCVU-Interactive-Offline.iso
EOF
}

# Check if build script exists
if [[ ! -x "$BUILD_SCRIPT" ]]; then
  echo "Error: Build script not found or not executable: $BUILD_SCRIPT" >&2
  exit 1
fi

# Check if config file exists for interactive mode
CONFIG_FILE="$ROOT_DIR/config-interactive.toml"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  echo "Create it with:" >&2
  echo "  [customizations.installer]" >&2
  echo "  contents = \"\"" >&2
  exit 1
fi

# Parse mode and options
MODE="${1:-interactive}"
shift || true

# Build options
BUILD_OPTS=()
ISO_TYPE=""
ISO_NAME=""
TAG=""
FETCH_OFFLINE=false
FETCH_PACKAGES="all"

# Parse remaining options
while [[ ${1:-} ]]; do
  case "$1" in
    --iso-name) ISO_NAME="$2"; BUILD_OPTS+=(--iso-name "$ISO_NAME"); shift 2;;
    --tag) TAG="$2"; BUILD_OPTS+=(--tag "$TAG"); shift 2;;
    --fetch-offline) FETCH_OFFLINE=true; BUILD_OPTS+=(--fetch-offline); shift;;
    --packages) FETCH_PACKAGES="$2"; BUILD_OPTS+=(--packages "$FETCH_PACKAGES"); shift 2;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown option: $1"; print_usage; exit 2;;
  esac
done

# Validate mode
case "$MODE" in
  interactive)
    echo "=== Building Interactive Anaconda Installer ISO ==="
    echo "Config: $CONFIG_FILE"
    echo ""
    
    # Generate default ISO name if not provided
    if [[ -z "$ISO_NAME" ]]; then
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      ISO_NAME="SCVU-Interactive-${TIMESTAMP}.iso"
    fi
    
    echo "Starting interactive build..."
    echo "Output ISO: $ISO_NAME"
    echo ""
    
    "$BUILD_SCRIPT" \
      --iso-type anaconda-iso \
      --config "$CONFIG_FILE" \
      --iso-name "$ISO_NAME" \
      "${BUILD_OPTS[@]}"
    
    echo ""
    echo "✓ Interactive ISO build completed!"
    ;;
    
  non-interactive)
    echo "=== Building Non-Interactive Standard ISO ==="
    echo ""
    
    # Generate default ISO name if not provided
    if [[ -z "$ISO_NAME" ]]; then
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      ISO_NAME="SCVU-Standard-${TIMESTAMP}.iso"
    fi
    
    echo "Starting non-interactive build..."
    echo "Output ISO: $ISO_NAME"
    echo ""
    
    "$BUILD_SCRIPT" \
      --iso-type iso \
      --iso-name "$ISO_NAME" \
      "${BUILD_OPTS[@]}"
    
    echo ""
    echo "✓ Non-interactive ISO build completed!"
    ;;
    
  compare)
    echo "=== Building Both Interactive and Non-Interactive ISOs ==="
    echo "This will create two ISOs for side-by-side comparison"
    echo ""
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    INTERACTIVE_ISO="SCVU-Interactive-${TIMESTAMP}.iso"
    STANDARD_ISO="SCVU-Standard-${TIMESTAMP}.iso"
    
    # Build interactive
    echo "[1/2] Building interactive installer..."
    "$BUILD_SCRIPT" \
      --iso-type anaconda-iso \
      --config "$CONFIG_FILE" \
      --iso-name "$INTERACTIVE_ISO" \
      "${BUILD_OPTS[@]}" || {
      echo "Error: Interactive build failed" >&2
      exit 1
    }
    
    echo ""
    echo "[2/2] Building non-interactive standard..."
    "$BUILD_SCRIPT" \
      --iso-type iso \
      --iso-name "$STANDARD_ISO" \
      "${BUILD_OPTS[@]}" || {
      echo "Error: Non-interactive build failed" >&2
      exit 1
    }
    
    echo ""
    echo "=== Comparison Build Complete ==="
    echo ""
    OUTPUT_DIR="$ROOT_DIR/output/bootiso"
    echo "Files created:"
    echo "  Interactive:     $OUTPUT_DIR/$INTERACTIVE_ISO"
    echo "  Non-interactive: $OUTPUT_DIR/$STANDARD_ISO"
    echo ""
    echo "File sizes:"
    ls -lh "$OUTPUT_DIR/$INTERACTIVE_ISO" "$OUTPUT_DIR/$STANDARD_ISO" 2>/dev/null || true
    ;;
    
  *)
    echo "Error: Unknown mode '$MODE'" >&2
    print_usage
    exit 2
    ;;
esac
