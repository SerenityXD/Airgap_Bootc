#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$SCRIPT_DIR/lib"
IMAGE_DIR="$ROOT_DIR/image"
OFFLINE_REPO="$IMAGE_DIR/offline-repo"

# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"

OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
OCI_PATH="${OCI_PATH:-$OUTPUT_DIR/oci-image/bootc-gnome.oci}"
ISO_PATH="${ISO_PATH:-}"
IMAGE_REF="${IMAGE_REF:-}"
BUILD_LOG_PATH="${BUILD_LOG_PATH:-$OUTPUT_DIR/iso-build.log}"
# DESKTOP_ENV="${DESKTOP_ENV:-}"
EXPECT_DOCKER_DESKTOP=true
EXPECT_GIMP_KRITA=true
EXPECT_RATIONS=true
EXPECT_BLENDER=true
EXPECT_CUDA_TOOLKIT=true
EXPECT_NVIDIA=false
EXPECT_WINE=false
EXPECT_LUTRIS=true

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Verifies that the built ISO output exists and that the bootc image delivered by
the ISO contains the core scripts, staged offline assets, and optional content
you expect this repo to ship.

By default, expects all optional packages to be present (Docker Desktop, GIMP/Krita,
Blender, rations/portablemc, CUDA Toolkit, Lutris). Use --no-expect-* flags to
disable expectations for minimal or custom builds.

By default the script inspects:
  - $OUTPUT_DIR
  - $OCI_PATH
  - the newest ISO under $OUTPUT_DIR/bootiso/

Options:
  -o, --output-dir DIR              Build output directory (default: $OUTPUT_DIR)
  -a, --oci-path PATH               OCI archive to inspect (default: $OCI_PATH)
  --iso-path PATH                   ISO file to verify explicitly
  --image-ref REF                   Use an already-loaded Podman image instead of loading the OCI archive
  --no-expect-docker-desktop        Do not require Docker Desktop (default: expected)
  --no-expect-gimp-krita            Do not require GIMP and Krita (default: expected)
  --no-expect-rations               Do not require rations/portablemc (default: expected)
  --no-expect-blender               Do not require Blender (default: expected)
  --no-expect-cuda-toolkit          Do not require CUDA Toolkit + cuDNN (default: expected)
  --no-expect-nvidia                Do not require NVIDIA kernel modules (default: not expected)
  --no-expect-wine                  Do not require Wine (default: not expected)
  --no-expect-lutris                Do not require Lutris (default: expected)
  --expect-nvidia                   Require NVIDIA kernel module(s) to be present
  --expect-wine                     Require Wine to be present
  -h, --help                        Show this help

Examples:
  $(basename "$0")                                                    # Verify full build (all packages)
  $(basename "$0") --no-expect-blender --no-expect-gimp-krita --no-expect-docker-desktop --no-expect-rations  # Verify minimal build
EOF
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "[PASS] $1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  echo "[WARN] $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "[FAIL] $1"
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ -f "$path" ]]; then
    pass "$label found: $path"
  else
    fail "$label missing: $path"
  fi
}

count_files() {
  local dir="$1"
  shift

  if [[ ! -d "$dir" ]]; then
    echo 0
    return 0
  fi

  find "$dir" -maxdepth 1 -type f "$@" | wc -l | tr -d '[:space:]'
}

detect_iso_path() {
  local bootiso_dir="$OUTPUT_DIR/bootiso"

  if [[ ! -d "$bootiso_dir" ]]; then
    return 1
  fi

  find "$bootiso_dir" -maxdepth 2 -type f -name '*.iso' -printf '%T@ %p\n' 2>/dev/null | \
    sort -nr | head -n 1 | cut -d' ' -f2-
}

while [[ ${1:-} ]]; do
  case "$1" in
    -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -a|--oci-path) OCI_PATH="$2"; shift 2 ;;
    --iso-path) ISO_PATH="$2"; shift 2 ;;
    --image-ref) IMAGE_REF="$2"; shift 2 ;;
    # --desktop-env) DESKTOP_ENV="$2"; shift 2 ;;
    --no-expect-docker-desktop) EXPECT_DOCKER_DESKTOP=false; shift ;;
    --no-expect-gimp-krita) EXPECT_GIMP_KRITA=false; shift ;;
    --no-expect-rations) EXPECT_RATIONS=false; shift ;;
    --no-expect-blender) EXPECT_BLENDER=false; shift ;;
    --no-expect-cuda-toolkit) EXPECT_CUDA_TOOLKIT=false; shift ;;
    --no-expect-nvidia) EXPECT_NVIDIA=false; shift ;;
    --no-expect-wine) EXPECT_WINE=false; shift ;;
    --no-expect-lutris) EXPECT_LUTRIS=false; shift ;;
    --expect-nvidia) EXPECT_NVIDIA=true; shift ;;
    --expect-wine) EXPECT_WINE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_cmd podman
require_cmd file

OUTPUT_DIR=$(resolve_path "$OUTPUT_DIR" 2>/dev/null || echo "$OUTPUT_DIR")
if [[ -n "$OCI_PATH" ]]; then
  OCI_PATH=$(resolve_path "$OCI_PATH" 2>/dev/null || echo "$OCI_PATH")
fi

if [[ -z "$ISO_PATH" ]]; then
  ISO_PATH=$(detect_iso_path || true)
fi

if [[ -n "$ISO_PATH" ]]; then
  ISO_PATH=$(resolve_path "$ISO_PATH" 2>/dev/null || echo "$ISO_PATH")
fi

echo "=== Verifying BOOTC ISO Delivery ==="
echo "Output directory: $OUTPUT_DIR"
echo "OCI archive:      $OCI_PATH"
if [[ -n "$ISO_PATH" ]]; then
  echo "ISO path:         $ISO_PATH"
else
  echo "ISO path:         <not found>"
fi
echo

if [[ -d "$OUTPUT_DIR" ]]; then
  pass "Output directory found: $OUTPUT_DIR"
else
  fail "Output directory missing: $OUTPUT_DIR"
fi

require_file "$OCI_PATH" "OCI archive"

if [[ -n "$ISO_PATH" ]]; then
  require_file "$ISO_PATH" "ISO"

  if [[ -f "$ISO_PATH" ]]; then
    ISO_FILE_INFO=$(file -b "$ISO_PATH")
    if grep -Eq 'ISO 9660|UDF filesystem data' <<<"$ISO_FILE_INFO"; then
      pass "ISO file type looks correct: $ISO_FILE_INFO"
    else
      fail "ISO file type is unexpected: $ISO_FILE_INFO"
    fi

    ISO_SIZE=$(stat -c '%s' "$ISO_PATH")
    if [[ "$ISO_SIZE" -gt 0 ]]; then
      pass "ISO size is non-zero: ${ISO_SIZE} bytes"
    else
      fail "ISO size is zero bytes"
    fi
  fi
else
  fail "No ISO found under $OUTPUT_DIR/bootiso and no --iso-path was provided"
fi

MANIFEST_COUNT=$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name 'manifest-*.json' | wc -l | tr -d '[:space:]')
if [[ "$MANIFEST_COUNT" -gt 0 ]]; then
  pass "Found $MANIFEST_COUNT manifest file(s) in output directory"
else
  warn "No manifest-*.json file found in $OUTPUT_DIR"
fi

if [[ -f "$OUTPUT_DIR/iso-build.log" ]]; then
  pass "Found ISO build log: $OUTPUT_DIR/iso-build.log"
else
  warn "ISO build log missing: $OUTPUT_DIR/iso-build.log"
fi

BUILD_ARGS_SUMMARY=""
BLENDER_WAS_REQUESTED=true
CUDA_WAS_REQUESTED=true
if [[ -f "$BUILD_LOG_PATH" ]]; then
  BUILD_ARGS_SUMMARY=$(sed -n -E 's/^Build args:[[:space:]]*(.*)$/\1/p' "$BUILD_LOG_PATH" | tail -n 1)
  if [[ -n "$BUILD_ARGS_SUMMARY" ]] && grep -Eq '(^|[[:space:]])EXCLUDE_BLENDER=yes($|[[:space:]])' <<<"$BUILD_ARGS_SUMMARY"; then
    BLENDER_WAS_REQUESTED=false
  fi
  if [[ -n "$BUILD_ARGS_SUMMARY" ]] && grep -Eq '(^|[[:space:]])EXCLUDE_CUDA_TOOLKIT=yes($|[[:space:]])' <<<"$BUILD_ARGS_SUMMARY"; then
    CUDA_WAS_REQUESTED=false
  fi
fi

if [[ -z "$IMAGE_REF" ]]; then
  if [[ ! -f "$OCI_PATH" ]]; then
    fail "Cannot load OCI archive because it is missing"
  else
    echo
    echo "Loading OCI archive into Podman for inspection..."
    LOAD_OUTPUT=$(podman load -i "$OCI_PATH")
    echo "$LOAD_OUTPUT"
    IMAGE_REF=$(printf '%s\n' "$LOAD_OUTPUT" | sed -n -E 's/^Loaded image(s)?: (.+)$/\2/p' | tail -n 1)
    if [[ -z "$IMAGE_REF" ]]; then
      IMAGE_REF=$(printf '%s\n' "$LOAD_OUTPUT" | sed -n -E 's/^Loaded image ID: (.+)$/\1/p' | tail -n 1)
    fi
    if [[ -n "$IMAGE_REF" ]]; then
      pass "Loaded image for verification: $IMAGE_REF"
    else
      fail "Unable to determine the image reference returned by podman load"
    fi
  fi
else
  if podman image exists "$IMAGE_REF"; then
    pass "Using existing Podman image: $IMAGE_REF"
  else
    fail "Provided image reference not found in Podman storage: $IMAGE_REF"
  fi
fi

HOST_VSIX_COUNT=$(count_files "$OFFLINE_REPO/vscode-extensions" -name '*.vsix')
HOST_NPM_TGZ_COUNT=$(count_files "$OFFLINE_REPO/npm-packages" -name '*.tgz')
HOST_WALLPAPER_COUNT=$(find "$OFFLINE_REPO/wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) 2>/dev/null | wc -l | tr -d '[:space:]')
HOST_K3S_AIRGAP_COUNT=$(count_files "$OFFLINE_REPO/k3s" -name 'k3s-airgap-images-*.tar.zst')
HOST_K3S_SHA_COUNT=$(count_files "$OFFLINE_REPO/k3s" -name 'sha256sum-*.txt')
HOST_HAS_OC=$([[ -f "$OFFLINE_REPO/openshift/oc" ]] && echo yes || echo no)
HOST_HAS_KUBECTL=$([[ -f "$OFFLINE_REPO/openshift/kubectl" ]] && echo yes || echo no)
HOST_HAS_HELM=$([[ -f "$OFFLINE_REPO/helm/helm" ]] && echo yes || echo no)
HOST_HAS_K3S_BIN=$([[ -f "$OFFLINE_REPO/k3s/k3s" ]] && echo yes || echo no)
HOST_HAS_WINEHQ_RPM=$([[ $(count_files "$OFFLINE_REPO/winehq" -name '*.rpm') -gt 0 ]] && echo yes || echo no)
HOST_HAS_FFMPEG_RPM=$([[ $(count_files "$OFFLINE_REPO/rpmfusion" -name 'ffmpeg*.rpm') -gt 0 ]] && echo yes || echo no)
HOST_HAS_VLC_PLUGINS_FREEWORLD_RPM=$([[ $(count_files "$OFFLINE_REPO/rpmfusion" -name 'vlc-plugins-freeworld*.rpm') -gt 0 ]] && echo yes || echo no)
HOST_HAS_CLAUDE_BIN=$([[ -f "$OFFLINE_REPO/claude/claude" || -f "$OFFLINE_REPO/claude/claude-code" ]] && echo yes || echo no)
HOST_HAS_CLAUDE_SYSTEM_BIN=$([[ -f "/opt/claude/claude" ]] && echo yes || echo no)
HOST_HAS_RATIONS_ZIP=$([[ -f "$OFFLINE_REPO/rations/rations.zip" ]] && echo yes || echo no)
HOST_HAS_PORTABLEMC_BIN=$([[ -f "$OFFLINE_REPO/rations/portablemc" ]] && echo yes || echo no)
HOST_HAS_RATIONS_META_A=$([[ -f "$OFFLINE_REPO/rations/8d52f11f50b848c491fb17b27bff394ff6ffbd16" ]] && echo yes || echo no)
HOST_HAS_RATIONS_META_A_CACHE=$([[ -f "$OFFLINE_REPO/rations/8d52f11f50b848c491fb17b27bff394ff6ffbd16.cache" ]] && echo yes || echo no)
HOST_HAS_RATIONS_META_B=$([[ -f "$OFFLINE_REPO/rations/a534ae8e05490b581e8f7ca18018cd586b225eaf" ]] && echo yes || echo no)
HOST_HAS_RATIONS_META_B_CACHE=$([[ -f "$OFFLINE_REPO/rations/a534ae8e05490b581e8f7ca18018cd586b225eaf.cache" ]] && echo yes || echo no)
HOST_HAS_RATIONS_META_C=$([[ -f "$OFFLINE_REPO/rations/a1e08b188d5e8f632b6ba4b6b5691f9e26a703c4" ]] && echo yes || echo no)
HOST_HAS_RATIONS_META_C_CACHE=$([[ -f "$OFFLINE_REPO/rations/a1e08b188d5e8f632b6ba4b6b5691f9e26a703c4.cache" ]] && echo yes || echo no)
HOST_HAS_MPV_RPM=$([[ $(count_files "$OFFLINE_REPO/rpmfusion" -name 'mpv*.rpm') -gt 0 ]] && echo yes || echo no)
HOST_HAS_VLC_RPM=$([[ $(count_files "$OFFLINE_REPO/rpmfusion" -name 'vlc*.rpm') -gt 0 ]] && echo yes || echo no)
HOST_HAS_NVIDIA_RPM=$([[ $(count_files "$OFFLINE_REPO/rpmfusion" -name '*nvidia*.rpm') -gt 0 ]] && echo yes || echo no)
HOST_BLENDER_TARBALL_COUNT=$(count_files "$OFFLINE_REPO/blender" -name 'blender-*.tar.xz')

INVENTORY_SCRIPT=$(cat <<'EOF'
set -euo pipefail

count_dir_files() {
  local dir="$1"
  local pattern="$2"
  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 1 -type f -name "$pattern" | wc -l | tr -d '[:space:]'
  else
    echo 0
  fi
}

bool_path() {
  if [[ -e "$1" ]]; then
    echo yes
  else
    echo no
  fi
}

bool_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    echo yes
  else
    echo no
  fi
}

bool_rpm() {
  if rpm -q "$1" >/dev/null 2>&1; then
    echo yes
  else
    echo no
  fi
}

# Detect desktop environment (GNOME only for now)
detect_desktop_env() {
  if command -v gnome-shell >/dev/null 2>&1; then
    echo gnome
  else
    echo unknown
  fi
}

printf 'desktop_env=%s\n' "$(detect_desktop_env)"
printf 'has_bootc_readme=%s\n' "$(bool_path /usr/local/bin/bootc/BOOTC-README.md)"
printf 'has_bootc_post_install=%s\n' "$(bool_path /usr/local/bin/bootc/bootc-post-install.sh)"
printf 'has_js_verifier=%s\n' "$(bool_path /usr/local/bin/bootc/install-js-frameworks.sh)"
printf 'has_automount_script=%s\n' "$(bool_path /usr/local/bin/bootc/automount-drive.sh)"
printf 'has_k3s_distribute_script=%s\n' "$(bool_path /usr/local/bin/bootc/k3s-distribute-kubeconfig.sh)"
printf 'has_k3s_pre_start=%s\n' "$(bool_path /usr/local/bin/bootc/k3s-pre-start.sh)"
printf 'has_k3s_service=%s\n' "$(bool_path /usr/lib/systemd/system/k3s.service)"
printf 'has_k3s_kubeconfig_service=%s\n' "$(bool_path /usr/lib/systemd/system/k3s-kubeconfig-distribute.service)"
printf 'has_k3s_route_service=%s\n' "$(bool_path /usr/lib/systemd/system/k3s-route-setup.service)"
printf 'has_k3s_route_service_enabled=%s\n' "$(bool_path /etc/systemd/system/k3s.service.wants/k3s-route-setup.service)"
printf 'has_k3s_sysctl=%s\n' "$(bool_path /etc/sysctl.d/99-k3s.conf)"
printf 'k3s_sysctl_ip_forward=%s\n' "$(grep -qs 'net.ipv4.ip_forward' /etc/sysctl.d/99-k3s.conf && echo yes || echo no)"
printf 'has_k3s_modules_load=%s\n' "$(bool_path /etc/modules-load.d/k3s.conf)"
printf 'has_k3s_bashrc=%s\n' "$(bool_path /etc/bashrc.d/k3s-kubectl.sh)"
printf 'has_k3s_profile=%s\n' "$(bool_path /etc/profile.d/k3s-kubectl.sh)"
printf 'has_k3s_config=%s\n' "$(bool_path /etc/rancher/k3s/config.yaml)"

# GNOME packages
printf 'has_gnome_shell=%s\n' "$(bool_rpm gnome-shell)"
printf 'has_gnome_session=%s\n' "$(bool_rpm gnome-session)"
printf 'has_gdm=%s\n' "$(bool_rpm gdm)"
printf 'has_gnome_control_center=%s\n' "$(bool_rpm gnome-control-center)"
printf 'has_gnome_terminal=%s\n' "$(bool_rpm gnome-terminal)"
printf 'has_gnome_text_editor=%s\n' "$(bool_rpm gnome-text-editor)"
printf 'has_nautilus=%s\n' "$(bool_rpm nautilus)"
printf 'has_gnome_system_monitor=%s\n' "$(bool_rpm gnome-system-monitor)"
printf 'has_gnome_disk_utility=%s\n' "$(bool_rpm gnome-disk-utility)"
printf 'has_gnome_tweaks=%s\n' "$(bool_rpm gnome-tweaks)"
printf 'has_gnome_connections=%s\n' "$(bool_rpm gnome-connections)"
printf 'has_gnome_shell_appindicator=%s\n' "$(bool_rpm gnome-shell-extension-appindicator)"
printf 'has_gvfs_fuse=%s\n' "$(bool_rpm gvfs-fuse)"
printf 'has_evince=%s\n' "$(bool_rpm evince)"
printf 'has_eog=%s\n' "$(bool_rpm eog)"
printf 'has_file_roller=%s\n' "$(bool_rpm file-roller)"

printf 'has_code=%s\n' "$(bool_cmd code)"
printf 'has_chrome=%s\n' "$(bool_cmd google-chrome-stable)"
printf 'has_wine=%s\n' "$(bool_cmd wine)"
printf 'has_lutris=%s\n' "$(bool_cmd lutris)"
printf 'has_drawio=%s\n' "$(bool_cmd drawio)"
printf 'has_obs=%s\n' "$(bool_cmd obs)"
printf 'has_ffmpeg=%s\n' "$(bool_cmd ffmpeg)"
printf 'has_mpv=%s\n' "$(bool_cmd mpv)"
printf 'has_vlc=%s\n' "$(bool_cmd vlc)"
printf 'has_vlc_plugins_freeworld=%s\n' "$(bool_rpm vlc-plugins-freeworld)"
printf 'has_claude_system_bin=%s\n' "$(bool_path /opt/claude/claude)"

printf 'has_oc=%s\n' "$(bool_path /usr/local/bin/bootc/oc)"
printf 'has_oc_path=%s\n' "$(bool_cmd oc)"
printf 'has_kubectl=%s\n' "$(bool_path /usr/local/bin/bootc/kubectl)"
printf 'has_kubectl_path=%s\n' "$(bool_cmd kubectl)"
printf 'has_k_alias=%s\n' "$(bool_path /usr/local/bin/k)"
printf 'has_helm=%s\n' "$(bool_cmd helm)"
printf 'has_k3s=%s\n' "$(bool_cmd k3s)"

printf 'vsix_count=%s\n' "$(count_dir_files /opt/vscode-extensions '*.vsix')"
printf 'npm_tgz_count=%s\n' "$(count_dir_files /opt/npm-packages '*.tgz')"
printf 'wallpaper_count=%s\n' "$(count_dir_files /usr/share/backgrounds/bootc '*')"
printf 'has_wallpaper_xml=%s\n' "$(bool_path /usr/share/gnome-background-properties/bootc-wallpapers.xml)"
printf 'k3s_airgap_count=%s\n' "$(count_dir_files /usr/share/k3s 'k3s-airgap-images-*.tar.zst')"
printf 'k3s_sha_count=%s\n' "$(count_dir_files /usr/share/k3s 'sha256sum-*.txt')"

printf 'has_docker_desktop=%s\n' "$(bool_rpm docker-desktop)"
printf 'has_gimp=%s\n' "$(bool_cmd gimp)"
printf 'has_krita=%s\n' "$(bool_cmd krita)"
printf 'has_portablemc=%s\n' "$(bool_path /usr/local/bin/portablemc)"
printf 'has_minecraft_wrapper=%s\n' "$(bool_path /usr/local/bin/minecraft)"
printf 'has_rations_dir=%s\n' "$(bool_path /opt/rations)"
printf 'has_rations_meta_a=%s\n' "$(bool_path /opt/rations/8d52f11f50b848c491fb17b27bff394ff6ffbd16)"
printf 'has_rations_meta_a_cache=%s\n' "$(bool_path /opt/rations/8d52f11f50b848c491fb17b27bff394ff6ffbd16.cache)"
printf 'has_rations_meta_b=%s\n' "$(bool_path /opt/rations/a534ae8e05490b581e8f7ca18018cd586b225eaf)"
printf 'has_rations_meta_b_cache=%s\n' "$(bool_path /opt/rations/a534ae8e05490b581e8f7ca18018cd586b225eaf.cache)"
printf 'has_rations_meta_c=%s\n' "$(bool_path /opt/rations/a1e08b188d5e8f632b6ba4b6b5691f9e26a703c4)"
printf 'has_rations_meta_c_cache=%s\n' "$(bool_path /opt/rations/a1e08b188d5e8f632b6ba4b6b5691f9e26a703c4.cache)"
printf 'has_java_rations=%s\n' "$(rpm -q java-25-openjdk-headless >/dev/null 2>&1 && echo yes || echo no)"
printf 'has_blender=%s\n' "$(bool_cmd blender)"
printf 'has_blender_opt_dir=%s\n' "$(bool_path /opt/blender-4.2/blender)"
printf 'has_blender_desktop=%s\n' "$(bool_path /usr/share/applications/blender.desktop)"
printf 'has_nvcc=%s\n' "$(bool_path /usr/local/cuda/bin/nvcc)"
printf 'has_libcudnn=%s\n' "$(bool_rpm libcudnn)"
printf 'has_libcuda_so=%s\n' "$(bool_path /usr/lib64/libcuda.so)"
printf 'has_watermark_ext=%s\n' "$(bool_path /usr/share/gnome-shell/extensions/screen-watermark@bootc.local/extension.js)"
printf 'has_watermark_metadata=%s\n' "$(bool_path /usr/share/gnome-shell/extensions/screen-watermark@bootc.local/metadata.json)"
printf 'has_watermark_dconf=%s\n' "$(bool_path /etc/dconf/db/local.d/01-bootc-extensions)"
printf 'has_watermark_autostart=%s\n' "$(bool_path /etc/xdg/autostart/bootc-watermark-enable.desktop)"
printf 'nvidia_ko_count=%s\n' "$(find /usr/lib/modules -type f \( -name 'nvidia.ko' -o -name 'nvidia.ko.xz' -o -name 'nvidia.ko.zst' \) 2>/dev/null | wc -l | tr -d '[:space:]')"
printf 'has_blacklist_nouveau=%s\n' "$(bool_path /etc/modprobe.d/blacklist-nouveau.conf)"
printf 'has_nvidia_pm_conf=%s\n' "$(bool_path /etc/modprobe.d/nvidia-pm.conf)"
printf 'has_ntpdate=%s\n' "$(bool_rpm ntpdate)"
printf 'has_ntpdate_service=%s\n' "$(bool_path /usr/lib/systemd/system/ntpdate-sync.service)"
printf 'has_ntpdate_service_enabled=%s\n' "$(bool_path /etc/systemd/system/multi-user.target.wants/ntpdate-sync.service)"
printf 'has_chronyd=%s\n' "$(bool_rpm chrony)"
printf 'has_chronyd_service=%s\n' "$(bool_path /usr/lib/systemd/system/chronyd.service)"
printf 'has_chronyd_service_enabled=%s\n' "$(bool_path /etc/systemd/system/multi-user.target.wants/chronyd.service)"
printf 'has_intel_audio_firmware=%s\n' "$(bool_rpm intel-audio-firmware)"
printf 'has_alsa_sof_firmware=%s\n' "$(bool_rpm alsa-sof-firmware)"
printf 'has_pipewire_alsa=%s\n' "$(bool_rpm pipewire-alsa)"
printf 'has_pipewire_pulseaudio=%s\n' "$(bool_rpm pipewire-pulseaudio)"
printf 'has_wireplumber=%s\n' "$(bool_rpm wireplumber)"
printf 'has_alsa_utils=%s\n' "$(bool_rpm alsa-utils)"
EOF
)

INVENTORY_FILE=$(mktemp)
trap 'rm -f "$INVENTORY_FILE"' EXIT

if [[ -n "$IMAGE_REF" ]] && podman image exists "$IMAGE_REF"; then
  podman run --rm --entrypoint /bin/bash "$IMAGE_REF" -lc "$INVENTORY_SCRIPT" > "$INVENTORY_FILE"
fi

declare -A INVENTORY=()
while IFS='=' read -r key value; do
  INVENTORY["$key"]="$value"
done < "$INVENTORY_FILE"

expect_yes() {
  local key="$1"
  local label="$2"
  if [[ "${INVENTORY[$key]:-no}" == yes ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

compare_count() {
  local host_count="$1"
  local image_count="$2"
  local label="$3"

  if [[ "$host_count" == "$image_count" ]]; then
    pass "$label count matches ($image_count)"
  else
    fail "$label count mismatch: host=$host_count image=$image_count"
  fi
}

compare_count_min() {
  local host_count="$1"
  local image_count="$2"
  local label="$3"

  if [[ "$image_count" =~ ^[0-9]+$ ]] && [[ "$host_count" =~ ^[0-9]+$ ]] && [[ "$image_count" -ge "$host_count" ]]; then
    pass "$label count is sufficient (host=$host_count image=$image_count)"
  else
    fail "$label count insufficient: host=$host_count image=$image_count"
  fi
}

expect_count_gt_zero() {
  local count="$1"
  local label="$2"
  if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -gt 0 ]]; then
    pass "$label ($count found)"
  else
    fail "$label (none found)"
  fi
}

echo
echo "Inspecting delivered image contents..."

if [[ -n "$BUILD_ARGS_SUMMARY" ]]; then
  echo "Recorded build args: $BUILD_ARGS_SUMMARY"
fi

# # Auto-detect desktop environment if not specified (depreciated)
# if [[ -z "$DESKTOP_ENV" ]]; then
#   DESKTOP_ENV="${INVENTORY[desktop_env]:-unknown}"
#   if [[ "$DESKTOP_ENV" != "unknown" ]]; then
#     echo "Detected desktop environment: $DESKTOP_ENV"
#   fi
# fi

expect_yes has_bootc_readme "BOOTC README is embedded in the image"
expect_yes has_bootc_post_install "bootc-post-install.sh is present"
expect_yes has_js_verifier "install-js-frameworks.sh is present"
expect_yes has_automount_script "automount-drive.sh is present"
expect_yes has_k3s_distribute_script "k3s-distribute-kubeconfig.sh is present"
expect_yes has_k3s_pre_start "k3s-pre-start.sh is present"
expect_yes has_k3s_service "k3s.service is installed"
expect_yes has_k3s_kubeconfig_service "k3s-kubeconfig-distribute.service is installed"
expect_yes has_k3s_route_service "k3s-route-setup.service is installed"
expect_yes has_k3s_route_service_enabled "k3s-route-setup.service is enabled (wanted by k3s.service)"
expect_yes has_k3s_sysctl "k3s sysctl config /etc/sysctl.d/99-k3s.conf is present"
expect_yes k3s_sysctl_ip_forward "k3s sysctl config enables ip_forward"
expect_yes has_k3s_modules_load "k3s kernel modules config /etc/modules-load.d/k3s.conf is present"
expect_yes has_k3s_bashrc "k3s KUBECONFIG fallback present for non-login shells (/etc/bashrc.d/k3s-kubectl.sh)"
expect_yes has_k3s_profile "k3s kubeconfig profile is present"
expect_yes has_k3s_config "k3s config.yaml is present"

# Desktop environment verification
# if [[ "${DESKTOP_ENV,,}" == "gnome" ]]; then
  echo
  echo "Verifying GNOME desktop environment packages..."
  expect_yes has_gnome_shell "GNOME Shell is installed"
  expect_yes has_gnome_session "GNOME Session is installed"
  expect_yes has_gdm "GDM (GNOME Display Manager) is installed"
  expect_yes has_gnome_control_center "GNOME Control Center is installed"
  expect_yes has_gnome_terminal "GNOME Terminal is installed"
  expect_yes has_gnome_text_editor "GNOME Text Editor is installed"
  expect_yes has_nautilus "Nautilus (file manager) is installed"
  expect_yes has_gnome_system_monitor "GNOME System Monitor is installed"
  expect_yes has_gnome_disk_utility "GNOME Disk Utility is installed"
  expect_yes has_gnome_tweaks "GNOME Tweaks is installed"
  expect_yes has_gnome_connections "GNOME Connections is installed"
  expect_yes has_gnome_shell_appindicator "GNOME Shell AppIndicator extension is installed"
  expect_yes has_gvfs_fuse "gvfs-fuse (FUSE support for GNOME) is installed"
  expect_yes has_evince "Evince (PDF viewer) is installed"
  expect_yes has_eog "Eye of GNOME (image viewer) is installed"
  expect_yes has_file_roller "File Roller (archive manager) is installed"
  expect_yes has_watermark_ext "Screen watermark extension (extension.js) is present"
  expect_yes has_watermark_metadata "Screen watermark extension metadata.json is present"
  expect_yes has_watermark_dconf "Screen watermark dconf system override is present"
  expect_yes has_watermark_autostart "Screen watermark XDG autostart entry is present"
  expect_yes has_wallpaper_xml "GNOME wallpaper metadata is present"
# else
#   warn "Unknown or undetected desktop environment; skipping desktop-specific checks"
# fi

echo

expect_yes has_code "VS Code is installed"
expect_yes has_chrome "Google Chrome is installed"

if [[ "$EXPECT_WINE" == true ]]; then
  expect_yes has_wine "Wine is installed as requested"
else
  if [[ "${INVENTORY[has_wine]:-no}" == yes ]]; then
    pass "Wine is installed"
  elif [[ "$HOST_HAS_WINEHQ_RPM" == yes ]]; then
    warn "Wine is not installed (offline WineHQ RPMs are present; use --expect-wine to enforce)"
  else
    warn "Wine is not installed (use --expect-wine to enforce)"
  fi
fi

if [[ "$EXPECT_LUTRIS" == true ]]; then
  expect_yes has_lutris "Lutris is installed as requested"
else
  if [[ "${INVENTORY[has_lutris]:-no}" == yes ]]; then
    pass "Lutris is installed"
  elif [[ "$HOST_HAS_WINEHQ_RPM" == yes ]]; then
    warn "Lutris is not installed (offline WineHQ RPMs are present; use --expect-lutris to enforce)"
  else
    warn "Lutris is not installed (use --expect-lutris to enforce)"
  fi
fi

expect_yes has_drawio "draw.io is installed"
expect_yes has_obs "OBS Studio is installed"

if [[ "$HOST_HAS_OC" == yes ]]; then
  expect_yes has_oc "Offline oc binary is staged in the image"
  expect_yes has_oc_path "oc is available in PATH"
fi

if [[ "$HOST_HAS_KUBECTL" == yes ]]; then
  expect_yes has_kubectl "Offline kubectl binary is staged in the image"
  expect_yes has_kubectl_path "kubectl is available in PATH"
  expect_yes has_k_alias "kubectl short alias 'k' is present"
fi

if [[ "$HOST_HAS_HELM" == yes ]]; then
  expect_yes has_helm "helm is available in PATH"
fi

if [[ "$HOST_HAS_K3S_BIN" == yes ]]; then
  expect_yes has_k3s "k3s is available in PATH"
fi

if [[ "$HOST_HAS_FFMPEG_RPM" == yes ]]; then
  expect_yes has_ffmpeg "ffmpeg is available in PATH"
fi

if [[ "$HOST_HAS_MPV_RPM" == yes ]]; then
  expect_yes has_mpv "mpv is available in PATH"
fi

if [[ "$HOST_HAS_VLC_RPM" == yes ]]; then
  expect_yes has_vlc "vlc is available in PATH"
fi

if [[ "$HOST_HAS_VLC_PLUGINS_FREEWORLD_RPM" == yes ]]; then
  expect_yes has_vlc_plugins_freeworld "vlc-plugins-freeworld is installed"
elif [[ "${INVENTORY[has_vlc_plugins_freeworld]:-no}" == yes ]]; then
  pass "vlc-plugins-freeworld is installed"
else
  warn "vlc-plugins-freeworld is not installed"
fi

if [[ "$HOST_HAS_CLAUDE_BIN" == yes ]]; then
  expect_yes has_claude_system_bin "Claude Code CLI binary is present at /opt/claude/claude"
elif [[ "${INVENTORY[has_claude_system_bin]:-no}" == yes ]]; then
  pass "Claude Code CLI binary is present at /opt/claude/claude"
else
  warn "Claude Code CLI binary is not present at /opt/claude/claude"
fi

compare_count "$HOST_VSIX_COUNT" "${INVENTORY[vsix_count]:-0}" "VS Code extension"
compare_count_min "$HOST_NPM_TGZ_COUNT" "${INVENTORY[npm_tgz_count]:-0}" "Offline npm tarball"
compare_count "$HOST_WALLPAPER_COUNT" "${INVENTORY[wallpaper_count]:-0}" "Wallpaper"

# if [[ "${DESKTOP_ENV,,}" == "gnome" ]]; then
  expect_yes has_wallpaper_xml "GNOME wallpaper metadata is present"
# fi

compare_count "$HOST_K3S_AIRGAP_COUNT" "${INVENTORY[k3s_airgap_count]:-0}" "k3s air-gap image"
compare_count "$HOST_K3S_SHA_COUNT" "${INVENTORY[k3s_sha_count]:-0}" "k3s checksum"

# Time sync (accept either ntpdate or chronyd)
if [[ "${INVENTORY[has_ntpdate]:-no}" == yes ]]; then
  expect_yes has_ntpdate "ntpdate is installed for initial time sync"
  expect_yes has_ntpdate_service "ntpdate-sync.service is installed"
  expect_yes has_ntpdate_service_enabled "ntpdate-sync.service is enabled"
elif [[ "${INVENTORY[has_chronyd]:-no}" == yes ]]; then
  pass "chronyd (from chrony) is installed for time synchronization (ntpdate not required)"
  expect_yes has_chronyd_service "chronyd.service is installed"
  expect_yes has_chronyd_service_enabled "chronyd.service is enabled"
else
  fail "Neither ntpdate nor chronyd (from chrony) is installed for time synchronization"
fi

# Audio stack (Intel firmware + PipeWire ALSA/PulseAudio bridges)
expect_yes has_intel_audio_firmware "intel-audio-firmware is installed (Intel audio controller firmware)"
expect_yes has_alsa_sof_firmware "alsa-sof-firmware is installed (Tiger Lake SOF DSP firmware)"
expect_yes has_pipewire_alsa "pipewire-alsa is installed (ALSA API to PipeWire bridge)"
expect_yes has_pipewire_pulseaudio "pipewire-pulseaudio is installed (PulseAudio API to PipeWire bridge)"
expect_yes has_wireplumber "wireplumber is installed (PipeWire session manager)"
expect_yes has_alsa_utils "alsa-utils is installed (aplay/amixer utilities)"

if [[ "$EXPECT_DOCKER_DESKTOP" == true ]]; then
  expect_yes has_docker_desktop "Docker Desktop is installed as requested"
fi

if [[ "$EXPECT_GIMP_KRITA" == true ]]; then
  expect_yes has_gimp "GIMP is installed as requested"
  expect_yes has_krita "Krita is installed as requested"
fi

if [[ "$EXPECT_RATIONS" == true ]]; then
  expect_yes has_portablemc "portablemc binary is present at /usr/local/bin/portablemc"
  expect_yes has_minecraft_wrapper "minecraft wrapper script is present at /usr/local/bin/minecraft"
  expect_yes has_rations_dir "rations game files are staged at /opt/rations"
  if [[ "$HOST_HAS_RATIONS_META_A" == yes ]]; then
    expect_yes has_rations_meta_a "rations metadata file 8d52... is staged at /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_A_CACHE" == yes ]]; then
    expect_yes has_rations_meta_a_cache "rations metadata cache 8d52....cache is staged at /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_B" == yes ]]; then
    expect_yes has_rations_meta_b "rations metadata file a534... is staged at /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_B_CACHE" == yes ]]; then
    expect_yes has_rations_meta_b_cache "rations metadata cache a534....cache is staged at /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_C" == yes ]]; then
    expect_yes has_rations_meta_c "rations metadata file a1e0... is staged at /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_C_CACHE" == yes ]]; then
    expect_yes has_rations_meta_c_cache "rations metadata cache a1e0....cache is staged at /opt/rations"
  fi
  expect_yes has_java_rations "java-25-openjdk-headless is installed for portablemc"
elif [[ "${INVENTORY[has_portablemc]:-no}" == yes ]]; then
  pass "portablemc is installed"
  if [[ "$HOST_HAS_RATIONS_META_A" == yes ]] && [[ "${INVENTORY[has_rations_meta_a]:-no}" != yes ]]; then
    warn "rations metadata file 8d52... is present in offline-repo but missing in /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_A_CACHE" == yes ]] && [[ "${INVENTORY[has_rations_meta_a_cache]:-no}" != yes ]]; then
    warn "rations metadata cache 8d52....cache is present in offline-repo but missing in /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_B" == yes ]] && [[ "${INVENTORY[has_rations_meta_b]:-no}" != yes ]]; then
    warn "rations metadata file a534... is present in offline-repo but missing in /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_B_CACHE" == yes ]] && [[ "${INVENTORY[has_rations_meta_b_cache]:-no}" != yes ]]; then
    warn "rations metadata cache a534....cache is present in offline-repo but missing in /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_C" == yes ]] && [[ "${INVENTORY[has_rations_meta_c]:-no}" != yes ]]; then
    warn "rations metadata file a1e0... is present in offline-repo but missing in /opt/rations"
  fi
  if [[ "$HOST_HAS_RATIONS_META_C_CACHE" == yes ]] && [[ "${INVENTORY[has_rations_meta_c_cache]:-no}" != yes ]]; then
    warn "rations metadata cache a1e0....cache is present in offline-repo but missing in /opt/rations"
  fi
  if [[ "${INVENTORY[has_minecraft_wrapper]:-no}" != yes ]]; then
    warn "portablemc is present but /usr/local/bin/minecraft wrapper is missing"
  fi
  if [[ "${INVENTORY[has_java_rations]:-no}" != yes ]]; then
    warn "portablemc is present but java-25-openjdk-headless may not be installed — Minecraft may fail to launch"
  fi
elif [[ "$HOST_HAS_PORTABLEMC_BIN" == yes ]] || [[ "$HOST_HAS_RATIONS_ZIP" == yes ]]; then
  warn "rations offline artifacts are present but portablemc was not found in the image (use --expect-rations to enforce)"
fi

if [[ "$EXPECT_BLENDER" == true ]]; then
  expect_yes has_blender "Blender is installed as requested"
  expect_yes has_blender_opt_dir "Blender payload is staged under /opt/blender-4.2"
  expect_yes has_blender_desktop "Blender desktop launcher is installed"
else
  if [[ "${INVENTORY[has_blender]:-no}" == yes ]]; then
    pass "Blender is installed"
    if [[ "${INVENTORY[has_blender_opt_dir]:-no}" == yes ]]; then
      pass "Blender payload is staged under /opt/blender-4.2"
    else
      warn "Blender command exists but /opt/blender-4.2/blender was not found"
    fi
    if [[ "${INVENTORY[has_blender_desktop]:-no}" == yes ]]; then
      pass "Blender desktop launcher is installed"
    else
      warn "Blender is installed but /usr/share/applications/blender.desktop is missing"
    fi
  elif [[ "$BLENDER_WAS_REQUESTED" == true ]]; then
    fail "Blender is not installed even though the recorded build args requested it"
  elif [[ "$HOST_BLENDER_TARBALL_COUNT" -gt 0 ]]; then
    warn "Blender offline tarball is present, but this build did not request Blender"
  else
    warn "Blender is not installed (use --expect-blender to enforce)"
  fi
fi

if [[ "$EXPECT_CUDA_TOOLKIT" == true ]]; then
  expect_yes has_nvcc "nvcc compiler is installed (CUDA Toolkit)"
  if [[ "${INVENTORY[has_libcudnn]:-no}" == yes ]]; then
    pass "libcudnn package is installed"
  else
    warn "libcudnn package is not installed (separate NVIDIA developer download, not part of cuda-toolkit)"
  fi
  expect_yes has_libcuda_so "libcuda.so is present (/usr/lib64/libcuda.so)"
else
  if [[ "${INVENTORY[has_nvcc]:-no}" == yes ]]; then
    pass "CUDA Toolkit (nvcc compiler) is installed"
    if [[ "${INVENTORY[has_libcudnn]:-no}" == yes ]]; then
      pass "libcudnn package is installed"
    else
      warn "CUDA Toolkit is installed but libcudnn package appears missing"
    fi
    if [[ "${INVENTORY[has_libcuda_so]:-no}" == yes ]]; then
      pass "libcuda.so is present (/usr/lib64/libcuda.so)"
    else
      warn "CUDA Toolkit is installed but libcuda.so was not found"
    fi
  elif [[ "$CUDA_WAS_REQUESTED" == true ]]; then
    fail "CUDA Toolkit is not installed even though the recorded build args requested it"
  else
    warn "CUDA Toolkit is not installed (use --expect-cuda-toolkit to enforce, or exclude with --build-arg EXCLUDE_CUDA_TOOLKIT=yes)"
  fi
fi

if [[ "$EXPECT_NVIDIA" == true ]] || [[ "$HOST_HAS_NVIDIA_RPM" == yes ]]; then
  expect_count_gt_zero "${INVENTORY[nvidia_ko_count]:-0}" "NVIDIA kernel modules are present in /usr/lib/modules"
  expect_yes has_blacklist_nouveau "nouveau blacklist config is present (/etc/modprobe.d/blacklist-nouveau.conf)"
  expect_yes has_nvidia_pm_conf "NVIDIA power-management config is present (/etc/modprobe.d/nvidia-pm.conf)"
else
  if [[ "${INVENTORY[nvidia_ko_count]:-0}" =~ ^[0-9]+$ ]] && [[ "${INVENTORY[nvidia_ko_count]:-0}" -gt 0 ]]; then
    pass "NVIDIA kernel modules detected (${INVENTORY[nvidia_ko_count]} found)"
    expect_yes has_blacklist_nouveau "nouveau blacklist config is present (/etc/modprobe.d/blacklist-nouveau.conf)"
    expect_yes has_nvidia_pm_conf "NVIDIA power-management config is present (/etc/modprobe.d/nvidia-pm.conf)"
  else
    warn "NVIDIA kernel modules not found (use --expect-nvidia to enforce)"
  fi
fi

echo
echo "Summary: ${PASS_COUNT} passed, ${WARN_COUNT} warned, ${FAIL_COUNT} failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0