#!/bin/bash
# Download Claude Code CLI for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_DIR="$(get_offline_dir "claude" "${SCRIPT_PATH}")"
CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-2.1.196}"
CLAUDE_CODE_URL="${CLAUDE_CODE_URL:-https://github.com/nancheung/cc-releases/releases/download/v${CLAUDE_CODE_VERSION}/claude-${CLAUDE_CODE_VERSION}-linux-x64}"
OUTPUT_NAME="${CLAUDE_CODE_OUTPUT:-claude}"

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

print_section "Fetch Claude Code CLI"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"
cd "${OFFLINE_DIR}"

find_candidate_binary() {
    local search_root="$1"
    local candidate

    if [ -f "${search_root}/${OUTPUT_NAME}" ] && [ -x "${search_root}/${OUTPUT_NAME}" ]; then
        printf '%s\n' "${search_root}/${OUTPUT_NAME}"
        return 0
    fi

    if [ -f "${search_root}/claude-code" ] && [ -x "${search_root}/claude-code" ]; then
        printf '%s\n' "${search_root}/claude-code"
        return 0
    fi

    while IFS= read -r candidate; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(find "${search_root}" -type f \( -name 'claude' -o -name 'claude-code' -o -name '*claude*' \) 2>/dev/null | sort)

    return 1
}

stage_artifact() {
    local source_path="$1"
    local extracted_root="$2"

    if [ -f "$source_path" ] && [ ! -s "$source_path" ]; then
        echo "  ✗ Downloaded artifact is empty"
        return 1
    fi

    if [ -f "$source_path" ]; then
        case "$source_path" in
            *.tar.gz|*.tgz)
                mkdir -p "$extracted_root"
                tar -xzf "$source_path" -C "$extracted_root"
                ;;
            *.zip)
                mkdir -p "$extracted_root"
                unzip -q "$source_path" -d "$extracted_root"
                ;;
            *)
                install -m 0755 "$source_path" "${OFFLINE_DIR}/${OUTPUT_NAME}"
                echo "  ✓ Claude Code CLI staged from direct file"
                return 0
                ;;
        esac

        local binary_path
        binary_path="$(find_candidate_binary "$extracted_root")" || true
        if [ -n "$binary_path" ]; then
            install -m 0755 "$binary_path" "${OFFLINE_DIR}/${OUTPUT_NAME}"
            echo "  ✓ Claude Code CLI staged from archive"
            return 0
        fi

        echo "  ✗ No Claude Code CLI binary was found inside the downloaded archive"
        return 1
    fi

    echo "  ✗ Downloaded artifact not found"
    return 1
}

echo "[1/1] Downloading Claude Code artifact from ${CLAUDE_CODE_URL}"
local_archive="${TMP_DIR}/claude-code-download"
if download_file "${CLAUDE_CODE_URL}" "${local_archive}"; then
    stage_artifact "${local_archive}" "${TMP_DIR}/extracted"
else
    echo "  ✗ Failed to download Claude Code artifact"
    exit 1
fi

echo ""
print_section "Download Complete!"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "This binary will be automatically included in the next ISO build."
echo ""
