#!/usr/bin/env bash

# Shared helpers for fetch scripts.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

print_section() {
    local title="$1"
    echo "========================================"
    echo "$title"
    echo "========================================"
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}

# Given a script path under bootc_ostree/fedora/image/scripts, resolve bootc_ostree/fedora.
get_fedora_root() {
    local source_file="${1:-${BASH_SOURCE[1]}}"
    local source_dir
    source_dir="$(cd "$(dirname "$source_file")" && pwd)"
    cd "$source_dir/../../" && pwd
}

get_offline_dir() {
    local vendor="$1"
    local source_file="${2:-${BASH_SOURCE[1]}}"
    local fedora_root
    fedora_root="$(get_fedora_root "$source_file")"
    printf '%s/image/offline-repo/%s\n' "$fedora_root" "$vendor"
}

download_file() {
    local url="$1"
    local output_file="$2"
    curl -fL --retry 3 --retry-delay 2 "$url" -o "$output_file"
}