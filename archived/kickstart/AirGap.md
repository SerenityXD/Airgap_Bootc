# Air-Gapped Deployment Guide

## Overview

This guide covers how to build and deploy the bootc ISO in an air-gapped (offline) environment where no network access is available.

The ISO includes:
- **KDE Plasma** desktop environment with SDDM display manager
- **Development tools**: Python 3, VS Code, git, Docker Desktop (GUI)
- **NVIDIA/CUDA**: GPU drivers and CUDA toolkit
- **Machine Learning**: PyTorch, TensorFlow, scikit-learn, Jupyter (via offline Python wheels)
- **Multimedia**: mpv, OBS Studio, ffmpeg, codec plugins
- **Windows compatibility**: WineHQ stable, Bottles
- **Filesystem support**: NTFS, exFAT, ext4, Btrfs, XFS, F2FS
- **3D Graphics**: Blender
- **JavaScript**: Node.js, npm, yarn with framework installer (React, Vue, Angular, Next.js, etc.)
- **Users**: IAC (admin) and AIBUser (standard), both in docker group

---

## Quick Start (Recommended Method)

### Preflight (Online Prep Machine)

Before running the prep script, ensure the following on the internet-connected machine:

- Tools: `dnf`, `curl`, `createrepo_c`, `python3`
- Optional: Multiple Python versions available (`python3.9`-`python3.13`) to download matching wheels
- Permissions: Ability to run `sudo dnf install createrepo_c`
- Disk space: At least 40-50 GB free (packages + ISO build artifacts)
- Network: Stable internet connection (30-60 min download)

Quick checks:

```bash
# Tools
command -v dnf && command -v curl && command -v createrepo_c || echo "Missing tools"

# Python versions (optional, script falls back gracefully)
for v in 3.9 3.10 3.11 3.12 3.13; do command -v python${v} || true; done

# Disk space
df -h .
```

If `createrepo_c` is missing, the prep script auto-installs it:

```bash
sudo dnf -y install createrepo_c
```

### Step 1: Download All Packages and Dependencies

On a machine **with internet access**, run:

```bash
./kickstart/prepare_airgap_repo.sh
```

This creates `airgap-packages-full/` directory with:
- Fedora base and updates repos (x86_64, newest-only)
- NVIDIA/CUDA packages
- VS Code and extensions (Python, Jupyter)
- Docker Desktop
- WineHQ stable and Bottles
- Node.js, npm, yarn, and Blender
- Multimedia packages (mpv, ffmpeg, OBS Studio, codecs)
- ML/AI Python wheels (TensorFlow, PyTorch, transformers, etc.)
- RPM Fusion release packages

**Download time**: 30-60 minutes (depending on bandwidth)
**Storage required**: ~15-30 GB
### Slim Mode (Smaller Cache) - **NOT RECOMMENDED**

**Note**: Slim Mode is fragile and requires manual dependency seeding. Use Full Mode unless you have specific size constraints and are willing to troubleshoot missing packages.

If you want a smaller offline cache, enable Slim Mode. It mirrors only the packages required by your kickstart and their dependencies, instead of syncing the entire Fedora/Updates repositories.

Run:

```bash
SLIM_MODE=1 ./kickstart/prepare_airgap_repo.sh
Separate slim cache folder (optional):
To keep the slim cache separate from the full one, set `REPO_DIR` when preparing and when building:

```bash
# Prepare into a dedicated folder
REPO_DIR=airgap-packages-slim SLIM_MODE=1 ./kickstart/prepare_airgap_repo.sh

# Build using that folder
REPO_DIR=./airgap-packages-slim TIMEOUT_MINUTES=180 bash kickstart/build_iso.sh
```

```

What Slim Mode does:
- Builds an allowlist from `%packages` in `kickstart/bootc-airgap.ks`.
- Uses Fedora/Updates mirrors to compute the dependency closure.
- Downloads only the resolved RPM set into local `airgap-packages-full/fedora` and `airgap-packages-full/fedora-updates`.
- Generates local metadata with `createrepo_c` so Anaconda can install from `file://` repos.

Trade-offs:
- Much smaller cache footprint (often trims several GB).
- **High failure rate**: Missing transitive dependencies for GUI apps (X11, Qt6, multimedia libs) cause build failures.
- Requires manual seeding of base system packages (see Troubleshooting).
- If a package is missing from `%packages` and not pulled in by deps, Anaconda may fail.

Recommendation:
- **Use Full Mode** for reliable builds with all dependencies included.
- Only use Slim Mode if you've stripped the kickstart to bare essentials (no Blender, OBS Studio, Bottles, etc.) and are prepared to manually seed missing libraries.


### Step 2: Build ISO with Cached Packages

```bash
sudo livemedia-creator --make-iso --no-virt \
  --ks kickstart/bootc-airgap.ks \
  --project SCVU \
  --resultdir out-airgap \
  --tmp /var/tmp \
  --cachedir $PWD/airgap-packages-full
```

**Options:**
- `--make-iso`: Create bootable ISO image
- `--no-virt`: Build without virtualization (faster, uses host system)
- `--ks`: Path to kickstart file
- `--project`: Name of the project (affects ISO naming)
- `--resultdir`: Output directory for built ISO
- `--tmp`: Temporary build directory
- `--cachedir`: Directory with downloaded packages

**Build time**: 20-40 minutes
**ISO size**: ~10-20 GB

### Monitor Build & Logs

Use these commands to follow progress and diagnose stalls during ISO build:

```bash
# Live build log (most useful)
sudo tail -f /var/tmp/bootc-build/build.log

# One-off last lines
sudo tail -n 100 /var/tmp/bootc-build/build.log

# Check log timestamp
sudo stat -c '%y  %n' /var/tmp/bootc-build/build.log

# Process sampling
ps aux | grep -E '[l]ivemedia|[a]naconda'

# CPU/memory snapshot for anaconda
pid=$(pgrep -f '/usr/sbin/anaconda' | tail -n1)
sudo ps -p "$pid" -o pid,comm,%cpu,%mem

# I/O monitoring (enable task delay accounting)
echo 1 | sudo tee /proc/sys/kernel/task_delayacct
sudo iotop -o -b -n 3 | cat
```

If you see repeated "anaconda ... started" lines with no progress, verify local repo metadata exists:

```bash
sudo ls -l /var/tmp/bootc-build/airgap-packages-full/fedora/repodata
sudo ls -l /var/tmp/bootc-build/airgap-packages-full/fedora-updates/repodata
```

### Step 3: Fix Ownership and Transfer ISO

```bash
# Fix ownership
sudo chown -R "$(id -un)":"$(id -gn)" out-airgap/

# Copy ISO to air-gapped environment
cp out-airgap/images/boot.iso /media/usb/bootc-airgap.iso
```

---

## After Installation (Air-Gapped Machine)

### 1. Boot from ISO

Burn to USB:
```bash
sudo dd if=bootc-airgap.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### 2. First Login

Default users (change passwords after first login):
- **IAC**: Admin user (wheel group, sudo access)
- **AIBUser**: Standard user
- **Root**: Set during installation

Both users are in the `docker` group.

### 3. Install ML/AI Packages (Optional)

After first boot, run the offline installer:

```bash
sudo /usr/local/bin/install-ml-packages.sh
```

This installs from embedded Python wheels in `/opt/ml-wheels/`:
- **Deep Learning**: TensorFlow, PyTorch, torchvision, torchaudio
- **Transformers/LLMs**: transformers, datasets, huggingface-hub, accelerate, diffusers
- **Computer Vision**: opencv-python, albumentations
- **Experiment Tracking**: wandb, mlflow
- **AutoML**: optuna, lightgbm, xgboost, catboost
- **Performance**: xformers (memory-efficient attention)

**Installation time**: 5-10 minutes (no internet required)

### 4. Install JavaScript Frameworks (Optional)

For web development, run the JavaScript installer:

```bash
/usr/local/bin/install-js-frameworks.sh
```

This installs popular JavaScript tools globally:
- **Frameworks**: React (create-react-app), Vue.js (@vue/cli), Angular (@angular/cli), Next.js
- **Build Tools**: Vite, Webpack
- **Language**: TypeScript, ts-node
- **Testing**: Jest, Mocha
- **Code Quality**: ESLint, Prettier
- **Package Managers**: pnpm

**Note**: Requires internet access or pre-cached npm packages. For air-gapped environments, consider using `npm cache` before deployment.

**Unreal Engine**: Included in air-gap setup. After running the preparation script, manually download Unreal Engine and place it in `airgap-packages-full/unreal-engine/` directory. Then run `/usr/local/bin/install-unreal-engine.sh` after boot. See detailed instructions below.

### 5. Install Unreal Engine (Optional)

For game development with Unreal Engine:

```bash
/usr/local/bin/install-unreal-engine.sh
```

**Post-ISO Installation (keeps ISO size manageable):**

1. **On a machine with internet access:**
   - Visit https://www.unrealengine.com/download
   - Sign in with Epic Games account
   - Download and install Epic Games Launcher for Linux
   - Download Unreal Engine 5.x through the launcher
   - Create tarball: `tar -czf UnrealEngine-5.x.tar.gz -C ~/.local/share/Epic UnrealEngine/`

2. **Transfer to air-gapped machine** via USB drive or network

3. **On the air-gapped machine** (after ISO installation):
   ```bash
   # Copy tarball to system (as root or with sudo)
   sudo mkdir -p /opt/unreal-engine
   sudo cp /path/to/UnrealEngine-5.x.tar.gz /opt/unreal-engine/
   
   # Install as user
   /usr/local/bin/install-unreal-engine.sh
   ```

**Size**: ~40-50 GB compressed

**Note**: This keeps the ISO size manageable (~10-20 GB). Unreal Engine can be added on-demand to systems that need it without rebuilding the entire ISO.

### 6. Start Docker Desktop

Launch from KDE Applications menu or terminal:
```bash
systemctl --user enable --now docker-desktop
```

---

## What's Included

### Desktop Environment
- **KDE Plasma** with Wayland/X11 support
- **SDDM** display manager
- **Konsole**, Dolphin, Kate, and KDE core apps

### Development Tools
- Python 3.9-3.13 with pip and development headers
- VS Code (Microsoft official) with Python/Jupyter extensions
- Node.js, npm, yarn
- git, make, kernel-devel, gcc toolchain
- Docker Desktop (GUI + CLI)

### 3D Graphics and Game Development
- Blender (3D modeling, animation, rendering)
- Unreal Engine: Manual download required (see installation notes)

### NVIDIA GPU Support
- NVIDIA proprietary drivers (akmod)
- CUDA Toolkit
- nvidia-smi, nvidia-settings
 - Auto-detects NVIDIA GPU during install and installs drivers if present

### Machine Learning (via post-install script)
- TensorFlow
- PyTorch (CPU/CUDA)
- scikit-learn, pandas, numpy, scipy
- Jupyter Notebook
- transformers, datasets, huggingface-hub

### Multimedia
- mpv (video player)
- OBS Studio (streaming/recording)
- ffmpeg, gstreamer plugins
- PipeWire, PulseAudio utilities

### Windows Compatibility
- WineHQ stable
- Bottles (GUI for Wine)

### Filesystem Support
- NTFS (read/write): ntfs-3g, ntfsprogs
- exFAT: exfatprogs, fuse-exfat
- ext2/ext3/ext4: e2fsprogs
- Btrfs: btrfs-progs
- XFS: xfsprogs
- F2FS: f2fs-tools
- FAT32: dosfstools

---

## Troubleshooting

### "Package not found" errors during build

- **Cause**: Package not in local cache
- **Solution**: Re-run the airgap repo script or add specific packages:
  ```bash
  cd airgap-packages-full/fedora
  sudo dnf download --resolve <missing-package>
  createrepo --update .
  ```

If you used Slim Mode and a package is missing, add it to `%packages` in `kickstart/bootc-airgap.ks`, then rerun:

```bash
SLIM_MODE=1 ./kickstart/prepare_airgap_repo.sh
```

**Slim Mode missing base dependencies**: If Anaconda reports "nothing provides" errors for basic libraries (`glibc`, `bash`, `libgcc`, `ca-certificates`, etc.), seed the slim repo with base packages:

```bash
# Unmount any stale bind
sudo umount /var/tmp/bootc-build/airgap-packages-full 2>/dev/null || true
sudo rm -rf /var/tmp/bootc-build ./out-airgap

# Seed fedora repo with base system packages
cd airgap-packages-slim/fedora
sudo dnf download --destdir . --resolve \
  bash coreutils glibc libgcc filesystem \
  ca-certificates systemd kernel rpm dnf yum \
  libstdc++ zlib expat sqlite ncurses-libs \
  readline libffi tzdata setup shadow-utils \
  pam util-linux sed grep gawk diffutils findutils

# Refresh metadata
sudo createrepo_c --update .

# Seed fedora-updates repo (minimal)
cd ../fedora-updates
sudo dnf download --destdir . --resolve glibc bash systemd || true
sudo createrepo_c --update .

cd ../..

# Rebuild ISO
REPO_DIR="$PWD/airgap-packages-slim" TIMEOUT_MINUTES=180 bash kickstart/build_iso.sh
```

### ML installer fails with "No module named 'torch'"

- **Cause**: ML wheels not embedded in ISO
- **Solution**: Verify `/opt/ml-wheels/` exists and contains `.whl` files. Re-run `prepare_airgap_repo.sh` if missing.

### Docker Desktop won't start

- **Cause**: Missing virtualization support or dependencies
- **Solution**: 
  1. Enable VT-x/AMD-V in BIOS
  2. Verify KVM loaded: `lsmod | grep kvm`
  3. Check Docker Desktop logs: `journalctl --user -u docker-desktop`

### NVIDIA drivers not loading

- **Cause**: Secure Boot or missing kernel modules
- **Solution**:
  1. Disable Secure Boot in BIOS, or
  2. Enroll MOK key after first boot (akmod will prompt)
  3. Verify: `nvidia-smi`
  4. Rebuild modules manually: `sudo akmods --force && sudo dracut --force`

### Display manager (SDDM) doesn't start

- **Cause**: Graphics driver issue
- **Solution**: Boot with `nomodeset` kernel parameter, then troubleshoot GPU drivers

### Unreal Engine installer shows "No archive found"

- **Cause**: Unreal Engine not copied to `/opt/unreal-engine/`
- **Solution**:
  1. Download Unreal Engine on a machine with internet
  2. Create tarball: `tar -czf UnrealEngine-5.x.tar.gz -C ~/.local/share/Epic UnrealEngine/`
  3. Transfer via USB to air-gapped machine
  4. Copy to system: `sudo cp /path/to/UnrealEngine-5.x.tar.gz /opt/unreal-engine/`
  5. Run: `/usr/local/bin/install-unreal-engine.sh`

---

## File Reference

- `kickstart/bootc-airgap.ks` - Main air-gapped kickstart (KDE, Docker Desktop, users IAC/AIBUser)
- `kickstart/prepare_airgap_repo.sh` - Full repo mirror script (Fedora + third-party + ML wheels + Unreal Engine setup)
- `airgap-packages-full/` - Full repository cache (~15-30 GB + Unreal Engine)
- `/usr/local/bin/install-ml-packages.sh` - Post-boot ML installer (created during ISO build)
- `/usr/local/bin/install-js-frameworks.sh` - Post-boot JavaScript frameworks installer
- `/usr/local/bin/install-unreal-engine.sh` - Post-boot Unreal Engine installer
- `/opt/ml-wheels/` - Embedded Python wheels for offline ML installation
- `/opt/unreal-engine/` - Unreal Engine archive (if manually added)

---

## Size Estimates

- **Fedora base + updates sync**: ~10-15 GB
- **Third-party packages** (NVIDIA, VS Code, Docker Desktop, WineHQ, multimedia, Node.js): ~3-5 GB
- **ML Python wheels**: ~2-4 GB
- **Total airgap cache**: ~15-30 GB
- **Final ISO size**: ~10-20 GB
- **Unreal Engine** (post-ISO, optional): ~40-50 GB compressed (transferred separately via USB)

**Total workspace storage needed**: ~40-50 GB (cache + ISO + build artifacts)

**Unreal Engine**: Added post-installation via USB transfer to individual systems as needed. This keeps the ISO manageable and avoids unnecessary 40-50 GB transfers.

---

## Performance Optimizations

The `prepare_airgap_repo.sh` script includes:
- `--arch=x86_64 --newest-only`: Skip old package versions
- `--setopt=max_parallel_downloads=20`: Faster downloads
- `--setopt=fastestmirror=True`: Auto-select fastest mirrors
- `--best=False`: Skip unnecessary upgrades during resolution

Additional flags:
- `SLIM_MODE=1`: Enable Slim Mode (dependency-closure download only for Fedora/Updates).
- `SKIP_STEP_1=1`: Skip Fedora base reposync in Full Mirror mode (useful if already cached).

Build script aids:
- `TIMEOUT_MINUTES` and `CHECK_INTERVAL_SECONDS` in `kickstart/build_iso.sh` for timeout guard and progress checkpoints.
- Automatic stale pid guard: removes stale `/var/run/anaconda.pid` if no Anaconda is running.

For even faster syncing, run on a machine with:
- Fast internet (100+ Mbps)
- SSD storage for cache directory
- Multiple CPU cores (parallel compression during ISO build)
