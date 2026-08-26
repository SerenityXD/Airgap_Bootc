#!/usr/bin/env bash
# Stage an Unreal Engine installed-build archive into the offline repo.
# Supported inputs:
#   UNREAL_ENGINE_FILE=/path/to/UnrealEngine.tar.xz
#   UNREAL_ENGINE_URL=https://signed.epic.example/path

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

OFFLINE_DIR="$(get_offline_dir "unreal-engine" "${SCRIPT_PATH}")"
INPUT_FILE="${UNREAL_ENGINE_FILE:-}"
INPUT_URL="${UNREAL_ENGINE_URL:-}"

print_section "Fetch Unreal Engine Add-On"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"

if [[ -z "${INPUT_FILE}" && -z "${INPUT_URL}" ]]; then
    log_warn "No Unreal Engine source provided."
    echo ""
    echo "Set one of the following before running this script:"
    echo "  UNREAL_ENGINE_FILE=/path/to/UnrealEngine-Linux.tar.xz ./$(basename "$0")"
    echo "  UNREAL_ENGINE_URL=https://official-epic-download-url ./$(basename "$0")"
    echo ""
    echo "This script stages a vendor-supplied installed-build archive under ${OFFLINE_DIR}."
    exit 0
fi

find "${OFFLINE_DIR}" -maxdepth 1 -type f \( -name '*.tar' -o -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.xz' -o -name '*.zip' \) -delete

if [[ -n "${INPUT_FILE}" ]]; then
    if [[ ! -f "${INPUT_FILE}" ]]; then
        log_error "Unreal Engine file not found: ${INPUT_FILE}"
        exit 1
    fi

    output_name="$(basename "${INPUT_FILE}")"
    cp -f "${INPUT_FILE}" "${OFFLINE_DIR}/${output_name}"
    log_info "Copied ${output_name} into ${OFFLINE_DIR}"
else
    require_cmd curl

    output_name="${UNREAL_ENGINE_OUTPUT_NAME:-$(basename "${INPUT_URL%%\?*}")}"
    if [[ -z "${output_name}" || "${output_name}" == "/" ]]; then
        output_name="unreal-engine-offline-archive.bin"
    fi

    download_file "${INPUT_URL}" "${OFFLINE_DIR}/${output_name}"
    log_info "Downloaded ${output_name} into ${OFFLINE_DIR}"
fi

find "${OFFLINE_DIR}" -maxdepth 1 -type f | sort
