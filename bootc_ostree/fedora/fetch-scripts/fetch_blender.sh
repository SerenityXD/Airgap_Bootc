#!/usr/bin/env bash
# Fetch Blender 4.2 LTS portable tarball from blender.org for offline installation.
# Blender 4.2.x was never packaged for Fedora 43 (only up to fc42), so we use
# the official portable Linux release which works on any modern glibc system.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

OFFLINE_DIR="$(get_offline_dir "blender" "${SCRIPT_PATH}")"
# Blender 4.2 LTS version to pin — update this to the latest 4.2.x LTS patch
BLENDER_VERSION="${BLENDER_VERSION:-4.2.9}"
BLENDER_BASE_URL="https://download.blender.org/release/Blender4.2"

print_section "Fetch Blender 4.2"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo "Version:          ${BLENDER_VERSION}"
echo ""

require_cmd curl

mkdir -p "${OFFLINE_DIR}"
# Remove any previous download for a clean fetch
find "${OFFLINE_DIR}" -maxdepth 1 -type f \( -name 'blender-*.tar.xz' -o -name 'blender-*.md5' \) -delete

TARBALL="blender-${BLENDER_VERSION}-linux-x64.tar.xz"
DOWNLOAD_URL="${BLENDER_BASE_URL}/${TARBALL}"
MD5_URL="${BLENDER_BASE_URL}/${TARBALL}.md5"
DEST="${OFFLINE_DIR}/${TARBALL}"

log_info "Downloading Blender ${BLENDER_VERSION} from blender.org..."
curl -fL --progress-bar --output "${DEST}" "${DOWNLOAD_URL}"

log_info "Verifying checksum..."
if curl -fsSL "${MD5_URL}" -o "${DEST}.md5" 2>/dev/null; then
    # md5 file contains "hash  filename" — verify against downloaded file
    (cd "${OFFLINE_DIR}" && md5sum -c "${TARBALL}.md5") || {
        log_error "Checksum verification failed for ${TARBALL}"
        exit 1
    }
    log_info "Checksum OK"
else
    log_info "No .md5 file available; skipping checksum check"
fi

if [[ ! -f "${DEST}" ]]; then
    log_error "Download failed: ${DEST} not found"
    exit 1
fi

log_info "Downloaded $(du -sh "${DEST}" | cut -f1) to ${OFFLINE_DIR}"
du -sh "${OFFLINE_DIR}"
