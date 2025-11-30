# Kickstart for Bootc - Air-Gapped Version
# This kickstart expects a local repository mounted at /run/install/repo/local-packages/

# System language
lang en_US.UTF-8

# Keyboard layouts
keyboard us

# Network information (minimal, no external access)
network --bootproto=dhcp --device=eth0 --onboot=on --hostname=bootc-system

# Use LOCAL repositories from prepared air-gap cache
# Base install method
url --url=file:///var/tmp/bootc-build/airgap-packages-full/fedora

# Additional local repositories
repo --name="fedora-updates" --baseurl=file:///var/tmp/bootc-build/airgap-packages-full/fedora-updates
# Third-party repos deferred to %post for speed (use full cache there)
#repo --name="nvidia" --baseurl=file:///var/tmp/bootc-build/airgap-packages-full/nvidia
#repo --name="vscode" --baseurl=file:///var/tmp/bootc-build/airgap-packages-full/vscode
#repo --name="rpmfusion-free" --baseurl=file:///var/tmp/bootc-build/airgap-packages-full/rpmfusion-free
#repo --name="rpmfusion-nonfree" --baseurl=file:///var/tmp/bootc-build/airgap-packages-full/rpmfusion-nonfree
#repo --name="winehq" --baseurl=file:///var/tmp/bootc-build/airgap-packages-full/winehq
#repo --name="nodejs" --baseurl=file:///var/tmp/bootc-build/airgap-packages-full/nodejs

# Root password (password: fedora - CHANGE THIS!)
rootpw --iscrypted $6$saltsaltsalt$4nIfqBfaig2sHpJMxWhvljiZthuK4Lpf9s5dgl76krHPrp9d8CGLzCCbNP7qYVqTHqGazoS5SIde/Kt3U5sJq.

# SELinux configuration
selinux --enforcing

# Firewall configuration
firewall --enabled --ssh

# System timezone
timezone UTC --utc

# Create users (password: fedora - CHANGE THIS!)
# Generate with:  openssl passwd -6 'YourPassword'
user --name=IAC --groups=wheel --password=$6$saltsaltsalt$4nIfqBfaig2sHpJMxWhvljiZthuK4Lpf9s5dgl76krHPrp9d8CGLzCCbNP7qYVqTHqGazoS5SIde/Kt3U5sJq. --iscrypted
user --name=AIBUser --password=$6$saltsaltsalt$4nIfqBfaig2sHpJMxWhvljiZthuK4Lpf9s5dgl76krHPrp9d8CGLzCCbNP7qYVqTHqGazoS5SIde/Kt3U5sJq. --iscrypted

# Disk partitioning (dirinstall mode uses pre-created image)
zerombr
clearpart --all --initlabel
part /boot --fstype=ext4 --size=1024
part swap --fstype=swap --size=2048
part / --fstype=ext4 --size=10240

# Services
services --enabled=sddm

# Shutdown after installation (for livemedia-creator)
shutdown

# Package selection (NO external repos needed)
%packages --ignoremissing
@core
sudo
which
tar
gzip
make
kernel-devel
fuse-overlayfs
qemu-kvm
slirp4netns
iptables
nftables
conntrack-tools
virtiofsd
iproute
bridge-utils
uidmap

# Remote desktop (RDP server)
xrdp
xorgxrdp

# Multimedia and creator tools (deferred to %post for speed)
#mpv
#obs-studio
#ffmpeg
#gstreamer1
#gstreamer1-libav
#gstreamer1-plugins-base
#gstreamer1-plugins-good
#gstreamer1-plugins-bad-free
#gstreamer1-plugins-ugly-free
#pulseaudio-utils
pipewire
pipewire-alsa
pipewire-pulseaudio
pipewire-jack
alsa-utils

# Windows compatibility and bottles (deferred to %post)
#winehq-stable
#bottles

# Filesystem support (NTFS, exFAT, ext4, Btrfs, XFS, F2FS)
ntfs-3g
ntfsprogs
exfatprogs
fuse-exfat
e2fsprogs
btrfs-progs
xfsprogs
f2fs-tools
dosfstools


# Live image support
dracut-live

# Boot/bootloader packages (BIOS + UEFI + Secure Boot)
grub2-pc
grub2-pc-modules
grub2-efi-x64
grub2-efi-x64-modules
grub2-efi-x64-cdboot
grub2-efi-ia32
grub2-efi-ia32-cdboot
grub2-tools
grub2-tools-efi
syslinux
efibootmgr
shim-x64
shim-ia32

# Desktop environment
@kde-desktop-environment
@kde-apps
sddm
filelight

# Office suite
libreoffice

# 3D Graphics and Game Development
blender

# Development tools
python3
python3-pip
python3-devel
git

# Node.js and JavaScript development (deferred to %post)
#nodejs
#npm
#yarn

# Multiple Python versions (3.9-3.13) with pip for each
python3.9
python3.9-pip
python3.10
python3.10-pip
python3.11
python3.11-pip
python3.12
python3.12-pip
python3.13
python3.13-pip

# Machine Learning and Data Science tools
python3-numpy
python3-scipy
python3-pandas
python3-matplotlib
python3-scikit-learn
python3-jupyter-core
python3-notebook
python3-ipython
python3-seaborn
python3-pillow
python3-opencv
python3-torch
python3-tensorboard
hdf5
hdf5-devel
openblas
openblas-devel
lapack
lapack-devel

# Container tools handled via Docker Desktop (installed in %post)

# NVIDIA / CUDA (deferred to %post for speed)
#akmod-nvidia
#xorg-x11-drv-nvidia
#cuda-toolkit

# VS Code (deferred to %post)
#code

%end

%post --log=/var/log/ks-post.log
# Set graphical target
systemctl set-default graphical.target || true

# Install third-party packages from full cache (deferred for speed)
echo "Installing third-party packages from full cache..."

# Configure full cache repos for post-install
FULL_CACHE="/var/tmp/bootc-build/airgap-packages-full-complete"
if [ -d "$FULL_CACHE" ]; then
  # Create temporary repo configs
  cat > /etc/yum.repos.d/airgap-nvidia.repo <<NVEOF
[airgap-nvidia]
name=Air-Gap NVIDIA
baseurl=file://$FULL_CACHE/nvidia
enabled=1
gpgcheck=0
NVEOF

  cat > /etc/yum.repos.d/airgap-vscode.repo <<VSEOF
[airgap-vscode]
name=Air-Gap VS Code
baseurl=file://$FULL_CACHE/vscode
enabled=1
gpgcheck=0
VSEOF

  cat > /etc/yum.repos.d/airgap-rpmfusion.repo <<RPEOF
[airgap-rpmfusion-free]
name=Air-Gap RPM Fusion Free
baseurl=file://$FULL_CACHE/rpmfusion-free
enabled=1
gpgcheck=0

[airgap-rpmfusion-nonfree]
name=Air-Gap RPM Fusion Nonfree
baseurl=file://$FULL_CACHE/rpmfusion-nonfree
enabled=1
gpgcheck=0
RPEOF

  cat > /etc/yum.repos.d/airgap-winehq.repo <<WEOF
[airgap-winehq]
name=Air-Gap WineHQ
baseurl=file://$FULL_CACHE/winehq
enabled=1
gpgcheck=0
WEOF

  cat > /etc/yum.repos.d/airgap-nodejs.repo <<NJSEOF
[airgap-nodejs]
name=Air-Gap Node.js
baseurl=file://$FULL_CACHE/nodejs
enabled=1
gpgcheck=0
NJSEOF

  # Install packages
  dnf install -y --nogpgcheck \
    code \
    nodejs npm yarn \
    mpv obs-studio ffmpeg gstreamer1 gstreamer1-libav \
    gstreamer1-plugins-base gstreamer1-plugins-good \
    gstreamer1-plugins-bad-free gstreamer1-plugins-ugly-free \
    winehq-stable bottles \
    akmod-nvidia xorg-x11-drv-nvidia cuda-toolkit || true
  
  # Clean up temporary repo configs
  rm -f /etc/yum.repos.d/airgap-*.repo
else
  echo "Full cache not found at $FULL_CACHE; skipping third-party package install"
  echo "You can install these packages manually after boot."
fi

# Enable SDDM
systemctl enable sddm || true

# Enable xrdp for remote desktop access
systemctl enable xrdp || true
firewall-cmd --permanent --add-port=3389/tcp || true
firewall-cmd --reload || true

# Add developer user to docker group (if present)
groupadd -f docker 2>/dev/null || true
usermod -aG docker IAC 2>/dev/null || true
usermod -aG docker AIBUser 2>/dev/null || true

# If Docker Desktop RPM was bundled, install it now
if ls /opt/offline-rpms/docker-desktop/*.rpm >/dev/null 2>&1; then
  dnf install -y /opt/offline-rpms/docker-desktop/*.rpm || true
fi

# Auto-detect NVIDIA GPU and install drivers (offline-first)
if lspci | grep -i nvidia >/dev/null 2>&1; then
  echo "NVIDIA GPU detected. Installing drivers..."
  # Prefer local cached packages; fall back to configured repos
  dnf install -y akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda cuda-toolkit || true
  # Build kernel modules (akmods) on first boot
  akmods --force || true
  dracut --force || true
  echo "NVIDIA driver setup attempted. If Secure Boot is enabled, you may need to enroll MOK keys."
else
  echo "No NVIDIA GPU detected. Skipping NVIDIA driver installation."
fi

# Install VS Code extensions for Python and Jupyter from local .vsix files
for USERNAME in IAC AIBUser; do
  USER_HOME="/home/$USERNAME"
  if [ -d /opt/vscode-extensions ]; then
    # Install extensions from offline .vsix files
    sudo -u $USERNAME code --install-extension /opt/vscode-extensions/ms-python.python.vsix 2>/dev/null || true
    sudo -u $USERNAME code --install-extension /opt/vscode-extensions/ms-toolsai.jupyter.vsix 2>/dev/null || true
    sudo -u $USERNAME code --install-extension /opt/vscode-extensions/ms-toolsai.jupyter-keymap.vsix 2>/dev/null || true
    sudo -u $USERNAME code --install-extension /opt/vscode-extensions/ms-toolsai.jupyter-renderers.vsix 2>/dev/null || true
    sudo -u $USERNAME code --install-extension /opt/vscode-extensions/ms-python.vscode-pylance.vsix 2>/dev/null || true
  else
    # Fallback to online installation if offline extensions not available
    sudo -u $USERNAME code --install-extension ms-python.python 2>/dev/null || true
    sudo -u $USERNAME code --install-extension ms-toolsai.jupyter 2>/dev/null || true
    sudo -u $USERNAME code --install-extension ms-toolsai.jupyter-keymap 2>/dev/null || true
    sudo -u $USERNAME code --install-extension ms-toolsai.jupyter-renderers 2>/dev/null || true
    sudo -u $USERNAME code --install-extension ms-python.vscode-pylance 2>/dev/null || true
  fi
done

# Create Node.js/JavaScript framework installer script
cat > /usr/local/bin/install-js-frameworks.sh <<'JSSCRIPT'
#!/bin/bash
# JavaScript frameworks and tools installer

set -e

echo "Installing popular JavaScript frameworks and tools..."
echo ""

# Check if npm is available
if ! command -v npm &>/dev/null; then
  echo "npm not found! Please install Node.js first."
  exit 1
fi

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo ""

echo "Installing global npm packages..."
# React and related tools
npm install -g create-react-app || true

# Vue.js
npm install -g @vue/cli || true

# Angular
npm install -g @angular/cli || true

# Next.js
npm install -g create-next-app || true

# Build tools
npm install -g vite webpack webpack-cli || true

# TypeScript
npm install -g typescript ts-node || true

# Testing frameworks
npm install -g jest mocha || true

# Linters and formatters
npm install -g eslint prettier || true

# Package managers
npm install -g pnpm || true

echo ""
echo "JavaScript frameworks installation complete!"
echo "Installed packages list:"
npm list -g --depth=0 > ~/js-frameworks-installed.txt
cat ~/js-frameworks-installed.txt

echo ""
echo "Note: Unreal Engine must be downloaded separately from Epic Games."
echo "Visit: https://www.unrealengine.com/download"
echo "Unreal Engine requires ~40GB+ and Epic Games account."
JSSCRIPT

chmod +x /usr/local/bin/install-js-frameworks.sh

# Create Unreal Engine installer script
cat > /usr/local/bin/install-unreal-engine.sh <<'UESCRIPT'
#!/bin/bash
# Unreal Engine installer for air-gapped environment

UE_SOURCE="/opt/unreal-engine"
UE_INSTALL_DIR="$HOME/.local/share/Epic"

echo "Unreal Engine Installation Script"
echo "=================================="
echo ""

if [ ! -d "$UE_SOURCE" ] || [ -z "$(ls -A $UE_SOURCE 2>/dev/null)" ]; then
  echo "ERROR: No Unreal Engine installation found in $UE_SOURCE"
  echo ""
  echo "To install Unreal Engine in an air-gapped environment:"
  echo "  1. Download Unreal Engine on a machine with internet:"
  echo "     - Visit https://www.unrealengine.com/download"
  echo "     - Sign in with Epic Games account and download Unreal Engine 5.x"
  echo "     - Create tarball: tar -czf UnrealEngine-5.x.tar.gz -C ~/.local/share/Epic UnrealEngine/"
  echo "  2. Copy tarball to air-gapped machine via USB/network"
  echo "  3. As root, copy to: sudo cp UnrealEngine-5.x.tar.gz /opt/unreal-engine/"
  echo "  4. Run this script again as your user"
  echo ""
  exit 1
fi

echo "Found Unreal Engine package(s) in $UE_SOURCE:"
ls -lh "$UE_SOURCE"
echo ""

# Find tarball or zip
UE_ARCHIVE=$(find "$UE_SOURCE" -type f \( -name "*.tar.gz" -o -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.zip" \) | head -n 1)

if [ -z "$UE_ARCHIVE" ]; then
  echo "ERROR: No Unreal Engine archive found (expected .tar.gz, .tar.bz2, .tar.xz, or .zip)"
  exit 1
fi

echo "Installing from: $UE_ARCHIVE"
echo "Target directory: $UE_INSTALL_DIR"
echo ""

read -p "Proceed with installation? This may take several minutes [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Installation cancelled."
  exit 0
fi

mkdir -p "$UE_INSTALL_DIR"

echo "Extracting Unreal Engine..."
if [[ "$UE_ARCHIVE" == *.zip ]]; then
  unzip -q "$UE_ARCHIVE" -d "$UE_INSTALL_DIR" || {
    echo "ERROR: Failed to extract archive"
    exit 1
  }
else
  tar -xf "$UE_ARCHIVE" -C "$UE_INSTALL_DIR" || {
    echo "ERROR: Failed to extract archive"
    exit 1
  }
fi

echo ""
echo "Unreal Engine extracted to: $UE_INSTALL_DIR"
echo ""

# Try to find the Unreal Engine executable
UE_EDITOR=$(find "$UE_INSTALL_DIR" -type f -name "UnrealEditor" -o -name "UE5Editor" 2>/dev/null | head -n 1)

if [ -n "$UE_EDITOR" ]; then
  echo "Unreal Engine Editor found at: $UE_EDITOR"
  echo ""
  echo "To launch Unreal Engine, run:"
  echo "  $UE_EDITOR"
  echo ""
  echo "Or create a desktop shortcut from KDE Applications menu."
else
  echo "Installation complete, but editor executable not found."
  echo "You may need to run setup scripts in: $UE_INSTALL_DIR"
fi

echo ""
echo "Installation complete!"
UESCRIPT

chmod +x /usr/local/bin/install-unreal-engine.sh

# Create directory for post-ISO Unreal Engine installation
mkdir -p /opt/unreal-engine
cat > /opt/unreal-engine/README.txt <<'UEINFO'
Unreal Engine Post-Installation Directory
==========================================

To install Unreal Engine:

1. On a machine with internet, download Unreal Engine:
   - Visit: https://www.unrealengine.com/download
   - Sign in with Epic Games account
   - Download Unreal Engine 5.x through Epic Games Launcher
   - Create tarball: tar -czf UnrealEngine-5.x.tar.gz -C ~/.local/share/Epic UnrealEngine/

2. Transfer tarball to this machine via USB/network

3. Copy tarball here:
   sudo cp UnrealEngine-5.x.tar.gz /opt/unreal-engine/

4. Run installer:
   /usr/local/bin/install-unreal-engine.sh

Size: ~40-50 GB compressed
UEINFO

# Create ML/AI package installer script for post-boot
cat > /usr/local/bin/install-ml-packages.sh <<'MLSCRIPT'
#!/bin/bash
# ML/AI Python packages installer (air-gapped compatible, multi-version)
# Run this after first boot to install ML frameworks

echo "=== Installing ML/AI Python packages ==="

ML_WHEELS_DIR="/opt/ml-wheels"

# Detect available Python versions
PY_VERSIONS=()
for ver in 3.9 3.10 3.11 3.12 3.13; do
  if command -v python${ver} &>/dev/null; then
    PY_VERSIONS+=("${ver}")
  fi
done

if [ ${#PY_VERSIONS[@]} -eq 0 ]; then
  echo "No Python versions found!"
  exit 1
fi

echo "Found Python versions: ${PY_VERSIONS[*]}"
echo ""

for PY_VER in "${PY_VERSIONS[@]}"; do
  echo "=== Installing packages for Python ${PY_VER} ==="
  
  PY_WHEELS_SUBDIR="${ML_WHEELS_DIR}/py${PY_VER//./}"
  
  if [ -d "$PY_WHEELS_SUBDIR" ] && [ "$(ls -A $PY_WHEELS_SUBDIR)" ]; then
    echo "Using offline wheels from $PY_WHEELS_SUBDIR"
    INSTALL_OPTS="--no-index --find-links=$PY_WHEELS_SUBDIR"
  else
    echo "No offline wheels found for Python ${PY_VER}. Using PyPI (requires internet)..."
    INSTALL_OPTS=""
  fi
  
  echo "Upgrading pip for Python ${PY_VER}..."
  python${PY_VER} -m pip install $INSTALL_OPTS --upgrade pip setuptools wheel || true
  
  echo "Installing deep learning frameworks..."
  python${PY_VER} -m pip install $INSTALL_OPTS tensorflow torch torchvision torchaudio || true
  
  echo "Installing transformers and NLP tools..."
  python${PY_VER} -m pip install $INSTALL_OPTS transformers datasets huggingface-hub accelerate diffusers tokenizers sentencepiece || true
  
  echo "Installing performance optimizations..."
  python${PY_VER} -m pip install $INSTALL_OPTS xformers || true
  
  echo "Installing computer vision tools..."
  python${PY_VER} -m pip install $INSTALL_OPTS opencv-python albumentations || true
  
  echo "Installing experiment tracking..."
  python${PY_VER} -m pip install $INSTALL_OPTS wandb mlflow || true
  
  echo "Installing AutoML and boosting..."
  python${PY_VER} -m pip install $INSTALL_OPTS optuna lightgbm xgboost catboost || true
  
  echo ""
  echo "=== Python ${PY_VER} packages installation complete ==="
  python${PY_VER} -m pip list > ~/ml-packages-py${PY_VER//./}-installed.txt
  echo ""
done

echo "All ML/AI packages installed across ${#PY_VERSIONS[@]} Python versions"
echo "Package lists saved to ~/ml-packages-py*-installed.txt"
MLSCRIPT

chmod +x /usr/local/bin/install-ml-packages.sh

# Create reference file with package list
cat > /etc/skel/ml-packages.txt <<'MLEOF'
# ML/AI Python packages
# To install all packages, run: /usr/local/bin/install-ml-packages.sh

tensorflow
torch
torchvision
torchaudio
transformers
datasets
huggingface-hub
accelerate
diffusers
tokenizers
sentencepiece
xformers
opencv-python
albumentations
wandb
mlflow
optuna
lightgbm
xgboost
catboost
MLEOF# Clean up to save space
dnf clean all || true

echo "Air-gapped post-installation complete"
%end

%post --nochroot --log=/mnt/sysimage/var/log/ks-post-nochroot.log
echo "Kickstart post (nochroot) finished"
mkdir -p /mnt/sysimage/opt/offline-rpms/docker-desktop || true
# Copy Docker Desktop RPM into target if present on install media
if ls /run/install/repo/docker-desktop/*.rpm >/dev/null 2>&1; then
  cp -v /run/install/repo/docker-desktop/*.rpm /mnt/sysimage/opt/offline-rpms/docker-desktop/
elif ls /run/install/repo/*docker-desktop*.rpm >/dev/null 2>&1; then
  cp -v /run/install/repo/*docker-desktop*.rpm /mnt/sysimage/opt/offline-rpms/docker-desktop/
fi

# Copy ML Python wheels into target if present
mkdir -p /mnt/sysimage/opt/ml-wheels || true
if [ -d /run/install/repo/ml-wheels ]; then
  cp -rv /run/install/repo/ml-wheels/* /mnt/sysimage/opt/ml-wheels/ || true
fi

# Copy VS Code extensions into target if present
mkdir -p /mnt/sysimage/opt/vscode-extensions || true
if [ -d /run/install/repo/vscode-extensions ]; then
  cp -v /run/install/repo/vscode-extensions/*.vsix /mnt/sysimage/opt/vscode-extensions/ || true
fi

# Copy README documentation to system
mkdir -p /mnt/sysimage/usr/share/doc/bootc-airgap || true
if [ -f /run/install/repo/README_AirGap.md ]; then
  cp -v /run/install/repo/README_AirGap.md /mnt/sysimage/usr/share/doc/bootc-airgap/ || true
fi
%end