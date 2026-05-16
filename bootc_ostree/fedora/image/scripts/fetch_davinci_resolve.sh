#!/usr/bin/env bash
# Stage a DaVinci Resolve installer into the offline repo.
# Supported inputs:
#   DAVINCI_RESOLVE_FILE=/path/to/vendor-installer.zip|rpm|run
#   DAVINCI_RESOLVE_URL=https://official.vendor.example/path

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

OFFLINE_DIR="$(get_offline_dir "davinci-resolve" "${SCRIPT_PATH}")"
INPUT_FILE="${DAVINCI_RESOLVE_FILE:-}"
INPUT_URL="${DAVINCI_RESOLVE_URL:-}"

print_section "Fetch DaVinci Resolve"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"

if [[ -z "${INPUT_FILE}" && -z "${INPUT_URL}" ]]; then
    log_warn "No DaVinci Resolve source provided."
    echo ""
    echo "Set one of the following before running this script:"
    echo "  DAVINCI_RESOLVE_FILE=/path/to/DaVinci_Resolve_Linux.zip ./$(basename "$0")"
    echo "  DAVINCI_RESOLVE_URL=https://official-blackmagic-download-url ./$(basename "$0")"
    echo ""
    echo "This script stages the official vendor installer under ${OFFLINE_DIR}."
    exit 0
fi

find "${OFFLINE_DIR}" -maxdepth 1 -type f \( -name '*.rpm' -o -name '*.run' -o -name '*.zip' \) -delete

if [[ -n "${INPUT_FILE}" ]]; then
    if [[ ! -f "${INPUT_FILE}" ]]; then
        log_error "DaVinci Resolve file not found: ${INPUT_FILE}"
        exit 1
    fi

    output_name="$(basename "${INPUT_FILE}")"
    cp -f "${INPUT_FILE}" "${OFFLINE_DIR}/${output_name}"
    log_info "Copied ${output_name} into ${OFFLINE_DIR}"
else
    require_cmd curl

    output_name="${DAVINCI_RESOLVE_OUTPUT_NAME:-$(basename "${INPUT_URL%%\?*}")}"
    if [[ -z "${output_name}" || "${output_name}" == "/" ]]; then
        output_name="davinci-resolve-installer.bin"
    fi

    download_file "${INPUT_URL}" "${OFFLINE_DIR}/${output_name}"
    log_info "Downloaded ${output_name} into ${OFFLINE_DIR}"
fi

find "${OFFLINE_DIR}" -maxdepth 1 -type f | sort
