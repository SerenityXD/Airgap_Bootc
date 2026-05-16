#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

scripts=(
  "$ROOT_DIR/fetch_all_offline.sh"
  "$ROOT_DIR/build-scripts/verify_iso_contents.sh"
  "$ROOT_DIR/image/scripts/fetch_drawio.sh"
  "$ROOT_DIR/image/scripts/fetch_gimp.sh"
  "$ROOT_DIR/image/scripts/fetch_krita.sh"
  "$ROOT_DIR/image/scripts/fetch_davinci_resolve.sh"
  "$ROOT_DIR/image/scripts/fetch_k3s_images.sh"
  "$ROOT_DIR/image/scripts/fetch_obs.sh"
  "$ROOT_DIR/image/scripts/fetch_offline_rpms.sh"
  "$ROOT_DIR/image/scripts/fetch_unreal_engine.sh"
  "$ROOT_DIR/image/scripts/fetch_openshift_tools.sh"
  "$ROOT_DIR/image/scripts/fetch_triton_server.sh"
  "$ROOT_DIR/image/scripts/pull-vscode-extensions.sh"
  "$ROOT_DIR/image/scripts/create-npm-tarballs.sh"
  "$ROOT_DIR/image/scripts/lib/common.sh"
)

for script in "${scripts[@]}"; do
  echo "Checking syntax: $script"
  bash -n "$script"
done

echo "All shell syntax checks passed."
