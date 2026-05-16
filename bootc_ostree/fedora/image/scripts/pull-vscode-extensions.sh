#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
LIB_DIR="$(cd "$(dirname "${SCRIPT_PATH}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

# pull-vscode-extensions.sh
# Downloads selected VS Code extensions (.vsix) into image/offline-repo/vscode
# and copies them into image/vscode-extensions so Docker builds that expect
# `vscode-extensions/*.vsix` will have files available.

SCRIPT_DIR="$(get_fedora_root "${SCRIPT_PATH}")"
OFFLINE_DIR="$(get_offline_dir "vscode-extensions" "${SCRIPT_PATH}")"

require_cmd curl
require_cmd unzip
require_cmd gzip

mkdir -p "$OFFLINE_DIR" 

is_valid_vsix() {
  local file="$1"
  unzip -tqq "$file" >/dev/null 2>&1
}

normalize_gzip_vsix_if_needed() {
  local file="$1"
  local magic
  magic="$(LC_ALL=C head -c 2 "$file" | od -An -tx1 | tr -d '[:space:]')"

  if [ "$magic" != "1f8b" ]; then
    return 0
  fi

  local tmp_zip
  tmp_zip="${file}.tmp"

  if gzip -dc "$file" > "$tmp_zip" && is_valid_vsix "$tmp_zip"; then
    mv -f "$tmp_zip" "$file"
    echo "Normalized gzip-wrapped VSIX: $file"
    return 0
  fi

  rm -f "$tmp_zip" || true
  return 1
}

# Extensions to fetch: publisher.extension
EXTS=(
  "ms-python.python"
  "ms-toolsai.jupyter"
  "ms-kubernetes-tools.vscode-kubernetes-tools"
  "ms-azuretools.vscode-docker"
  "redhat.vscode-yaml"
  "ms-vscode.makefile-tools"
  "eamodio.gitlens"
)

FORCE=false
while getopts "f" opt; do
  case "$opt" in
    f) FORCE=true ;;
    *) echo "Usage: $0 [-f]"; exit 1 ;;
  esac
done

for ext in "${EXTS[@]}"; do
  publisher="${ext%%.*}"
  name="${ext#*.}"
  out="$OFFLINE_DIR/${publisher}.${name}.vsix"
  url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${name}/latest/vspackage"

  needs_download=true

  if [ -f "$out" ] && [ "$FORCE" = false ]; then
    if is_valid_vsix "$out"; then
      echo "Skipping existing valid VSIX: $out"
      needs_download=false
    elif normalize_gzip_vsix_if_needed "$out" && is_valid_vsix "$out"; then
      echo "Recovered existing VSIX by ungzipping: $out"
      needs_download=false
    else
      echo "Existing VSIX is invalid, re-downloading: $out"
      rm -f "$out" || true
    fi
  fi

  if [ "$needs_download" = true ]; then
    echo "Downloading $ext -> $out"
    if curl -fSL --compressed -o "$out" "$url"; then
      if normalize_gzip_vsix_if_needed "$out" && is_valid_vsix "$out"; then
        echo "Downloaded and validated: $out"
      else
        echo "Error: downloaded VSIX is invalid for $ext: $out" >&2
        rm -f "$out" || true
      fi
    else
      echo "Error: failed to download $ext from $url" >&2
      rm -f "$out" || true
      continue
    fi
  fi
done

printf 'Done. VSIX files present in:\n - %s\n' "$OFFLINE_DIR"
exit 0
