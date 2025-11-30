#!/bin/bash
# Script to prepare air-gapped package repository for bootc ISO
# This version uses reposync to mirror entire repos for group support

set -e

# Prompt for sudo privileges upfront and keep them alive
if [[ $EUID -ne 0 ]]; then
  echo "Requesting sudo privileges for air-gap prep..."
  sudo -v
  # Keep sudo alive while the script runs
  while true; do sudo -n true; sleep 60; done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
fi

REPO_DIR="${REPO_DIR:-airgap-packages-full}"
FEDORA_RELEASE="43"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Slim mode: mirror only required RPMs based on kickstart allowlist
SLIM_MODE=${SLIM_MODE:-0}
# Toggle controls (set env vars to 1 to skip)
# Example: SKIP_STEP_1=1 ./kickstart/prepare_airgap_repo.sh
SKIP_STEP_1=${SKIP_STEP_1:-0}

# Speed options for dnf downloads
# DNF tuning (note: dnf download does not accept --best)
DNF_DOWNLOAD_OPTS=(
  "--setopt=install_weak_deps=False"
  "--setopt=max_parallel_downloads=20"
  "--setopt=fastestmirror=True"
)

if [[ "$SLIM_MODE" == "1" ]]; then
  echo "=== Preparing Air-Gapped Package Repository (Slim Mode) ==="
  echo "Only packages required by kickstart (and selected extras) will be downloaded."
else
  echo "=== Preparing Air-Gapped Package Repository (Full Mirror) ==="
  echo "This will mirror Fedora repos and download third-party packages"
  echo "WARNING: This will download several GB of data!"
  echo "Select 's' to skip Fedora base repo sync (if already done), or 'y' to continue."
fi
echo ""
read -p "Continue? (y/N/s) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[YySs]$ ]]; then
    exit 0
elif [[ $REPLY =~ ^[Ss]$ ]]; then
    SKIP_STEP_1=1

fi

# Ensure createrepo_c is available
if ! command -v createrepo_c >/dev/null 2>&1; then
  echo "createrepo_c not found. Installing..."
  sudo dnf -y install createrepo_c || {
    echo "Failed to install createrepo_c. Please install it manually (dnf install createrepo_c) and rerun.";
    exit 1;
  }
fi

# Create directory structure
mkdir -p "$REPO_DIR"/{fedora,fedora-updates,nvidia,vscode,rpmfusion-free,rpmfusion-nonfree,docker-desktop,winehq,nodejs}

if [[ "$SLIM_MODE" == "1" ]]; then
  echo "[1/11] Building allowlist from kickstart packages..."
  ALLOWLIST_DIR="$REPO_DIR/allowlist"
  mkdir -p "$ALLOWLIST_DIR"
  ALLOW_PKGS="$ALLOWLIST_DIR/pkg-allowlist.txt"
  # Extract package list from kickstart %packages section
  grep -A999 '%packages' "$SCRIPT_DIR/bootc-airgap.ks" | sed -n '/%packages/,/%end/p' | \
    grep -v '^%\|^@\|^-' | awk '{print $1}' | sed '/^$/d' > "$ALLOW_PKGS"
  echo "  Base packages: $(wc -l < "$ALLOW_PKGS")"

  echo "[2/11] Resolving dependencies against Fedora/Updates..."
  # Use remote repos to compute dependency closure; we only download results locally
  FEDORA_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Everything/x86_64/os/"
  UPDATES_URL="https://download.fedoraproject.org/pub/fedora/linux/updates/$FEDORA_RELEASE/Everything/x86_64/"
  RESOLVED_PKGS="$ALLOWLIST_DIR/pkg-closure.txt"
  dnf --disablerepo='*' \
    --repofrompath="fedora,$FEDORA_URL" \
    --repofrompath="updates,$UPDATES_URL" \
    repoquery --resolve --requires --alldeps $(cat "$ALLOW_PKGS") | sort -u > "$RESOLVED_PKGS" || true
  sort -u "$ALLOW_PKGS" "$RESOLVED_PKGS" > "$ALLOWLIST_DIR/pkg-final.txt"
  echo "  Total allowlisted + deps: $(wc -l < "$ALLOWLIST_DIR/pkg-final.txt")"

  echo "[3/11] Downloading allowlisted RPMs (Fedora/Updates) locally..."
  # Create minimal local repos by downloading only the resolved package set
  mkdir -p "$REPO_DIR/fedora" "$REPO_DIR/fedora-updates"
  # Download from fedora URL
  dnf --disablerepo='*' --repofrompath="fedora,$FEDORA_URL" \
    download --resolve --destdir="$REPO_DIR/fedora" $(cat "$ALLOWLIST_DIR/pkg-final.txt") || true
  # Attempt updates first for newer builds, then fill remaining from fedora
  dnf --disablerepo='*' --repofrompath="updates,$UPDATES_URL" \
    download --resolve --destdir="$REPO_DIR/fedora-updates" $(cat "$ALLOWLIST_DIR/pkg-final.txt") || true
  echo "  Creating local metadata for slim Fedora repos..."
  createrepo_c "$REPO_DIR/fedora" || true
  createrepo_c "$REPO_DIR/fedora-updates" || true
else
  if [[ "$SKIP_STEP_1" != "1" ]]; then
    echo "[1/11] Syncing Fedora base repository (Everything, newest x86_64 only)..."
    sudo dnf reposync \
      --repoid=fedora \
      --releasever=$FEDORA_RELEASE \
      --arch=x86_64 \
      --newest-only \
      --download-metadata \
      --download-path="$REPO_DIR" || true
  else
    echo "[1/11] Skipped Fedora base repository sync as per user request."
  fi

  echo "[2/11] Syncing Fedora updates repository (newest x86_64 only)..."
  sudo dnf reposync \
    --repoid=updates \
    --releasever=$FEDORA_RELEASE \
    --arch=x86_64 \
    --newest-only \
    --download-metadata \
    --download-path="$REPO_DIR" || true
fi

echo "[3/11] Downloading RPM Fusion packages..."
cd "$REPO_DIR/rpmfusion-free"
# Fetch release RPMs directly to avoid resolving system-release(43) dependency
curl -LO "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_RELEASE.noarch.rpm" || true
# Multimedia packages from RPM Fusion (mpv, ffmpeg, codecs, obs-studio)
sudo dnf "${DNF_DOWNLOAD_OPTS[@]}" download --resolve \
  --repofrompath="airgap-rpmfusion-free,https://download1.rpmfusion.org/free/fedora/releases/$FEDORA_RELEASE/Everything/x86_64/os/" \
  ffmpeg ffmpeg-libs libplacebo \
  gstreamer1-plugins-{bad,good,ugly,base} \
  mpv || true
cd -

cd "$REPO_DIR/rpmfusion-nonfree"
curl -LO "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_RELEASE.noarch.rpm" || true
cd -

echo "[4/11] Downloading NVIDIA/CUDA packages..."
cd "$REPO_DIR/nvidia"
# Some CUDA repos are not published per Fedora release; prefer generic Fedora path
CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/fedora/x86_64"
# First attempt: NVIDIA official repo
if ! sudo dnf "${DNF_DOWNLOAD_OPTS[@]}" download --resolve --skip-unavailable \
  --repofrompath="airgap-nvidia-cuda,${CUDA_REPO_URL}" \
  xorg-x11-drv-nvidia xorg-x11-drv-nvidia-libs cuda-toolkit \
  nvidia-settings nvidia-modprobe; then
  echo "  NVIDIA repo failed or unavailable. Falling back to RPM Fusion nonfree for NVIDIA/CUDA..."
  # Fallback: RPM Fusion nonfree provides NVIDIA drivers and CUDA toolkit
  RPMF_NONFREE_URL="https://download1.rpmfusion.org/nonfree/fedora/releases/$FEDORA_RELEASE/Everything/x86_64/os/"
  sudo dnf "${DNF_DOWNLOAD_OPTS[@]}" download --resolve --skip-unavailable \
    --repofrompath="airgap-rpmfusion-nonfree,${RPMF_NONFREE_URL}" \
    akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs \
    nvidia-settings nvidia-modprobe cuda-toolkit || true
fi
cd -

echo "[5/11] Downloading VS Code..."
cd "$REPO_DIR/vscode"
sudo dnf --disablerepo='*' --enablerepo=airgap-vscode --forcearch=x86_64 "${DNF_DOWNLOAD_OPTS[@]}" download --resolve \
  --repofrompath="airgap-vscode,https://packages.microsoft.com/yumrepos/vscode" \
  code.x86_64 || true
cd -

echo "[6/11] Downloading Docker Desktop (latest stable)..."
cd "$REPO_DIR/docker-desktop"
# Stable URL sometimes returns 403; try with browser-like headers, then fallback
DOCKER_URL_PRIMARY="https://desktop.docker.com/linux/main/amd64/docker-desktop-latest.x86_64.rpm"
OUT_RPM="docker-desktop-latest.x86_64.rpm"
echo "  Attempting primary Docker Desktop URL..."
curl -fL -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" \
  -H "Accept: */*" -H "Referer: https://desktop.docker.com/" -o "$OUT_RPM" "$DOCKER_URL_PRIMARY" || {
  echo "  Primary URL failed (likely 403). Trying fallback URL..."
  DOCKER_URL_FALLBACK="https://desktop.docker.com/linux/main/amd64/docker-desktop.rpm"
  curl -fL -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" \
    -H "Accept: */*" -H "Referer: https://desktop.docker.com/" -o "$OUT_RPM" "$DOCKER_URL_FALLBACK" || {
    echo "  Fallback URL also failed. Skipping Docker Desktop download."
    echo "  You can manually download the RPM via a browser and place it here: $REPO_DIR/docker-desktop/$OUT_RPM"
  }
}
cd -

echo "[7/11] Downloading Node.js and JavaScript development tools..."
cd "$REPO_DIR/nodejs"

# Node.js, npm, yarn
dnf download "${DNF_DOWNLOAD_OPTS[@]}" --resolve --destdir="$PWD" nodejs npm yarn 2>/dev/null || true

# Blender for 3D graphics
dnf download "${DNF_DOWNLOAD_OPTS[@]}" --resolve --destdir="$PWD" blender 2>/dev/null || true

cd -

echo "[8/11] Downloading WineHQ stable and Bottles..."
cd "$REPO_DIR/winehq"
# WineHQ repo provides winehq-stable meta package
sudo dnf --disablerepo='*' --enablerepo=airgap-winehq \
  "${DNF_DOWNLOAD_OPTS[@]}" download --resolve \
  --repofrompath="airgap-winehq,https://dl.winehq.org/wine-builds/fedora/$FEDORA_RELEASE" \
  winehq-stable || true
# Bottles is available in Fedora repositories
sudo dnf --disablerepo='*' --enablerepo=airgap-fedora-base \
  "${DNF_DOWNLOAD_OPTS[@]}" download --resolve \
  --repofrompath="airgap-fedora-base,https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Everything/x86_64/os/" \
  bottles || true
cd -

echo "[9/11] Downloading ML/AI Python wheels..."
mkdir -p "$REPO_DIR/ml-wheels"
cd "$REPO_DIR/ml-wheels"

download_wheels_for_version() {
  local pyver="$1"      # e.g., 3.10
  local destdir="py${pyver//.}"
  mkdir -p "$destdir"

  # Try native interpreter first
  if command -v python${pyver} >/dev/null 2>&1; then
    echo "    Using python${pyver} interpreter"
    # Ensure pip is available for this interpreter; try ensurepip then package install
    if ! python${pyver} -m pip --version >/dev/null 2>&1; then
      python${pyver} -m ensurepip --upgrade >/dev/null 2>&1 || true
    fi
    if ! python${pyver} -m pip --version >/dev/null 2>&1; then
      sudo dnf -y install python${pyver/./}-pip >/dev/null 2>&1 || true
    fi
    # Compose package list; skip tensorflow for 3.13 (no wheels yet)
    local pkgs=(
      transformers datasets huggingface-hub accelerate diffusers tokenizers sentencepiece
      opencv-python albumentations
      wandb mlflow
      optuna lightgbm xgboost catboost
    )
    if [[ "$pyver" != "3.13" ]]; then
      pkgs+=(tensorflow)
    fi
    # Download general packages
    python${pyver} -m pip download --dest "$destdir" "${pkgs[@]}" || true
    # Download PyTorch CPU wheels from dedicated index
    python${pyver} -m pip download --dest "$destdir" \
      --index-url https://download.pytorch.org/whl/cpu \
      torch torchvision torchaudio || true
    # xformers best-effort
    python${pyver} -m pip download --dest "$destdir" xformers || true
    return
  fi

  # Fallback: use host python/pip to download manylinux wheels by targeting version and platform
  if command -v python3 >/dev/null 2>&1; then
    echo "    python${pyver} not available, attempting targeted wheel download via python3/pip..."
    # Determine CP ABI tag from version
    local cpabi="cp${pyver/./}"
    # Use manylinux2014 x86_64 as default platform target
    local platform="manylinux2014_x86_64"
    # Download only binary wheels to avoid sdists
    # Compose list without tensorflow for 3.13
    local base_pkgs=(
      transformers datasets huggingface-hub accelerate diffusers tokenizers sentencepiece
      opencv-python albumentations
      wandb mlflow
      optuna lightgbm xgboost catboost
    )
    if [[ "$pyver" != "3.13" ]]; then
      base_pkgs+=(tensorflow)
    fi
    python3 -m pip download --only-binary=:all: \
      --python-version "${pyver}" \
      --platform "$platform" \
      --abi "$cpabi" \
      --dest "$destdir" \
      "${base_pkgs[@]}" || true

    # PyTorch via CPU index (manylinux wheels)
    python3 -m pip download --only-binary=:all: \
      --python-version "${pyver}" \
      --platform "$platform" \
      --abi "$cpabi" \
      --dest "$destdir" \
      --index-url https://download.pytorch.org/whl/cpu \
      torch torchvision torchaudio || true

    # xformers wheels are version/platform limited; attempt best-effort
    python3 -m pip download --only-binary=:all: \
      --python-version "${pyver}" \
      --platform "$platform" \
      --abi "$cpabi" \
      --dest "$destdir" xformers || true
    return
  fi

  echo "    Neither python${pyver} nor python3 available; skipping $pyver"
}

echo "  Targeting Python versions: 3.9 3.10 3.11 3.12 3.13"
for PY_VER in 3.9 3.10 3.11 3.12 3.13; do
  echo "  Downloading ML wheels for Python $PY_VER..."
  download_wheels_for_version "$PY_VER"
done

cd -

echo "[10/11] Downloading VS Code extensions..."
mkdir -p "$REPO_DIR/vscode-extensions"
cd "$REPO_DIR/vscode-extensions"

# Download VS Code extensions as .vsix files
curl -fL -o ms-python.python.vsix \
  "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/python/latest/vspackage" || true
curl -fL -o ms-toolsai.jupyter.vsix \
  "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-toolsai/vsextensions/jupyter/latest/vspackage" || true
curl -fL -o ms-toolsai.jupyter-keymap.vsix \
  "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-toolsai/vsextensions/jupyter-keymap/latest/vspackage" || true
curl -fL -o ms-toolsai.jupyter-renderers.vsix \
  "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-toolsai/vsextensions/jupyter-renderers/latest/vspackage" || true
curl -fL -o ms-python.vscode-pylance.vsix \
  "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/vscode-pylance/latest/vspackage" || true

cd -

# Copy README documentation to repository root
echo "Copying README_AirGap.md to repository..."
if [ -f "$SCRIPT_DIR/README_AirGap.md" ]; then
  cp -v "$SCRIPT_DIR/README_AirGap.md" "$REPO_DIR/" || true
fi

echo "[11/11] Creating repository metadata..."
for repo in fedora fedora-updates nvidia vscode rpmfusion-free rpmfusion-nonfree docker-desktop winehq nodejs; do
  if [ -d "$REPO_DIR/$repo" ] && [ "$(ls -A $REPO_DIR/$repo)" ]; then
    echo "  Creating metadata for $repo..."
    createrepo_c "$REPO_DIR/$repo/" || true
  fi
done

# Ensure slim-mode critical repos have repodata even if currently empty, to satisfy Anaconda preflights
for req in fedora fedora-updates; do
  if [ -d "$REPO_DIR/$req" ] && [ ! -d "$REPO_DIR/$req/repodata" ]; then
    echo "  Initializing empty metadata for $req (no RPMs yet)."
    createrepo_c "$REPO_DIR/$req/" || true
  fi
done

echo ""
echo "=== Air-Gapped Repository Preparation Complete ==="
echo "Repository location: $PWD/$REPO_DIR/"
echo ""
echo "Total size:"
du -sh "$REPO_DIR/" 2>/dev/null || echo "Unable to calculate size"
echo ""
echo "Next steps:"
echo "1. Copy $REPO_DIR/ to your air-gapped environment (optional)"
echo "2. Build ISO with optimized minimal cache:"
echo "   export REPO_DIR=\"\$PWD/$REPO_DIR\""
echo "   export TIMEOUT_MINUTES=180"
echo "   bash kickstart/build_iso.sh"
echo ""
echo "The build script will:"
echo "  - Use minimal cache (fedora + fedora-updates) for fast Anaconda install"
echo "  - Install third-party packages (NVIDIA, VS Code, etc.) in %post phase"
echo "  - Complete ISO will be in out-airgap/"
echo ""
