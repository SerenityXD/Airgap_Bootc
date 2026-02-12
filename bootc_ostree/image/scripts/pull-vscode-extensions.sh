#!/usr/bin/env bash
set -euo pipefail

# pull-vscode-extensions.sh
# Downloads selected VS Code extensions (.vsix) into image/offline-repo/vscode
# and copies them into image/vscode-extensions so Docker builds that expect
# `vscode-extensions/*.vsix` will have files available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE_DIR="$SCRIPT_DIR/../offline-repo/vscode-extensions"

mkdir -p "$OFFLINE_DIR" 

# Extensions to fetch: publisher.extension
EXTS=(
  "ms-python.python"
  "ms-toolsai.jupyter"
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

  if [ -f "$out" ] && [ "$FORCE" = false ]; then
    echo "Skipping existing: $out"
  else
    echo "Downloading $ext -> $out"
    if curl -fSL -o "$out" "$url"; then
      echo "Downloaded: $out"
    else
      echo "Error: failed to download $ext from $url" >&2
      rm -f "$out" || true
      continue
    fi
  fi
done

echo "Done. VSIX files present in:\n - $OFFLINE_DIR"
exit 0
