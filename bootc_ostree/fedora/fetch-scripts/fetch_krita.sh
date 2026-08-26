#!/usr/bin/env bash
# Fetch Krita and its Fedora dependencies for offline installation.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

OFFLINE_DIR="$(get_offline_dir "krita" "${SCRIPT_PATH}")"
FEDORA_VERSION="${FEDORA_VERSION:-43}"
REPO_TMP="$(mktemp -d)"

cleanup() {
    rm -rf "${REPO_TMP}"
}
trap cleanup EXIT

DNF_BASE_OPTS=(
    --releasever="${FEDORA_VERSION}"
    --setopt=gpgcheck=0
    --setopt=repo_gpgcheck=0
    --setopt=install_weak_deps=False
    --setopt=cachedir="${REPO_TMP}/cache"
)

print_section "Fetch Krita"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

require_cmd dnf

mkdir -p "${OFFLINE_DIR}"
find "${OFFLINE_DIR}" -maxdepth 1 -type f -name '*.rpm' -delete

log_info "Downloading Krita and dependencies from Fedora ${FEDORA_VERSION}..."
dnf download \
    --resolve \
    --alldeps \
    "${DNF_BASE_OPTS[@]}" \
    --setopt=reposdir=/etc/yum.repos.d \
    --destdir="${OFFLINE_DIR}" \
    krita

count=$(find "${OFFLINE_DIR}" -maxdepth 1 -type f -name '*.rpm' | wc -l)
if [[ "${count}" -eq 0 ]]; then
    log_error "No Krita RPMs were downloaded"
    exit 1
fi

log_info "Downloaded ${count} RPMs to ${OFFLINE_DIR}"
du -sh "${OFFLINE_DIR}"
