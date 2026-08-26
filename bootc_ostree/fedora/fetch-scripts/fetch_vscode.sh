#!/bin/bash
# Download VS Code RPM package for offline inclusion.
# Uses dnf download to avoid complex URL construction and potential 404 errors.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

OFFLINE_DIR="$(get_offline_dir "vscode" "${SCRIPT_PATH}")"
ARCH="$(uname -m)"
FEDORA_VERSION="${FEDORA_VERSION:-43}"

usage() {
    cat <<'USAGE'
Usage: fetch_vscode.sh [OPTIONS]

Download the latest VS Code RPM for offline inclusion.

Options:
  -h, --help    Show this help message

The script will download the VS Code RPM to ./offline-repo/vscode/
and skip if a file already exists.

Environment Variables:
  FEDORA_VERSION    Target Fedora version (default: 43)
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

require_cmd dnf

print_section "Fetch VS Code"
echo ""
echo "Architecture: ${ARCH}"
echo "Fedora Version: ${FEDORA_VERSION}"
echo "Target: ${OFFLINE_DIR}"
echo ""

mkdir -p "$OFFLINE_DIR"

# Check if a package already exists in the directory
if [[ -n "$(find "${OFFLINE_DIR}" -maxdepth 1 -name "code-*.rpm" 2>/dev/null)" ]]; then
    log_info "VS Code RPM already exists in ${OFFLINE_DIR}"
    echo "Saved to: ${OFFLINE_DIR}"
    exit 0
fi

# Create a temporary directory for clean dnf operations
REPO_TMP=$(mktemp -d)
cleanup() {
    rm -rf "$REPO_TMP"
}
trap cleanup EXIT

log_info "Downloading VS Code using dnf..."

cd "$OFFLINE_DIR"

# Use dnf download with Microsoft's VS Code repository
# The --resolve flag ensures dependencies are also downloaded if needed
if dnf download --resolve \
    --releasever="${FEDORA_VERSION}" \
    --setopt=cachedir="$REPO_TMP/cache" \
    --setopt=reposdir=/etc/yum.repos.d \
    --repofrompath=vscode-repo,https://packages.microsoft.com/yumrepos/vscode \
    --setopt=vscode-repo.skip_if_unavailable=True \
    --setopt=vscode-repo.gpgcheck=0 \
    --setopt=vscode-repo.repo_gpgcheck=0 \
    --repo=vscode-repo \
    "code.${ARCH}" \
    2>&1 | grep -v "no package matches" || true; then
    
    # Check if any file was downloaded
    if [[ -n "$(find . -maxdepth 1 -name "code-*.rpm" 2>/dev/null)" ]]; then
        VSCODE_RPM=$(find . -maxdepth 1 -name "code-*.rpm" -printf '%f\n' | sort -V | tail -1)
        log_info "VS Code downloaded successfully: ${VSCODE_RPM}"
        
        FILE_SIZE=$(stat -c%s "${VSCODE_RPM}" 2>/dev/null || echo "0")
        log_info "File size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes")"
        
        echo ""
        log_info "VS Code fetch complete!"
        exit 0
    fi
fi

# If dnf download didn't work, report error
log_error "Failed to download VS Code package"
exit 1
