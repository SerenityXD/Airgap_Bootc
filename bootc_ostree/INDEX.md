# bootc_ostree: Complete Guide & Directory Index

## 🎯 Project Purpose

**SCVU Bootc Workstation** is a complete, air-gapped, offline-capable ISO installer for a fully configured Fedora 43 KDE workstation. It embeds a prebuilt container system image into the ISO, enabling installation without requiring any network repository access.

This project solves the problem of deploying identical, reproducible systems in disconnected environments—ideal for:
- Secure air-gapped facilities
- Consistent DevOps/ML workstations
- NVIDIA-accelerated compute nodes
- Rapid team onboarding with pre-configured tools

---

## 📦 What Gets Built

**Output ISO:** `bootc_ostree/output/bootiso/SCVU.iso` (~14 GB)

The ISO includes:
- **Base:** Fedora 43 bootc container image (systemd-based, immutable rootfs)
- **Desktop:** KDE Plasma with apps (Konsole, Dolphin, Kate, etc.)
- **Development:** Python 3.9–3.13, Jupyter, Git, VS Code, Docker/Podman
- **AI/ML:** NumPy, SciPy, pandas, Matplotlib, scikit-learn, OpenCV, Triton client
- **Graphics:** NVIDIA drivers/CUDA, Blender, GIMP, Inkscape
- **Multimedia:** FFmpeg, VLC, OBS Studio, GIMP, Inkscape
- **Networking:** Samba, Avahi (mDNS), wsdd (Windows discovery), XRDP (remote desktop)
- **Windows Emulation:** WineHQ, Lutris, Prism Launcher
- **GIS:** QGIS with Python support
- **Post-Install:** Smart user creation (AIBUser with Docker group auto-add)
- **Interactive Installer:** Optional Anaconda UI for disk/partition selection
- **OpenShift Tools:** oc, kubectl, CodeReady Containers (CRC)
- **Utilities:** LibreOffice, Firefox, Chrome, Draw.io, SQLite

---

## 📂 Directory Structure & Components

```
bootc_ostree/
├── INDEX.md                       # This file - complete project overview
├── README.md                      # Detailed technical guide (812 lines)
├── BUILD_STATUS.md                # Build history & current status
├── EXAMPLES.md                    # Usage examples & recipes
│
├── build-scripts/                 # Build orchestration
│   ├── build-iso-helper.sh        # Interactive build (simplest entry point)
│   ├── build_export_iso.sh        # Direct build script (advanced control)
│   ├── config-interactive.toml    # Config for Anaconda UI mode
│   ├── config-noninteractive.toml # Config for standard bootc mode
│   └── logs/                      # Build logs (timestamped)
│
├── fetch-scripts/                 # Offline package fetchers
│   ├── fetch_all_offline.sh       # Master: runs all individual fetchers
│   ├── fetch_offline_rpms.sh      # RPM packages (RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop)
│   ├── fetch_openshift_tools.sh   # OpenShift CLI tools (oc, kubectl)
│   ├── fetch_crc.sh               # CodeReady Containers
│   ├── fetch_drawio.sh            # draw.io desktop
│   ├── fetch_prismlauncher.sh     # Prism Launcher (Minecraft launcher)
│   ├── fetch_triton_server.sh     # Triton Inference Server
│   └── fetch_obs.sh               # OBS Studio
│
├── fetch_all_offline.sh           # Quick link to master fetch script
│
├── image/                         # System image definition & offline packages
│   ├── Containerfile              # Main definition (Fedora 43 KDE + all tools, 804 lines)
│   ├── Dockerfile                 # Alternative image definition
│   ├── README.md                  # Image-specific notes
│   │
│   ├── offline-repo/              # Cached third-party packages (auto-included during build)
│   │   ├── crc/                   # CodeReady Containers binary
│   │   ├── docker-desktop/        # Docker Desktop RPM
│   │   ├── drawio/                # draw.io RPM
│   │   ├── nvidia/                # NVIDIA driver RPMs (build dependencies)
│   │   ├── obs/                   # OBS Studio RPMs
│   │   ├── openshift/             # oc & kubectl binaries
│   │   ├── prismlauncher/         # Prism Launcher AppImage
│   │   ├── rpmfusion/             # RPM Fusion packages (ffmpeg, vlc, etc.)
│   │   ├── triton/                # Triton Inference Server
│   │   ├── vscode/                # VS Code RPM
│   │   └── winehq/                # WineHQ RPMs
│   │
│   ├── vscode-extensions/         # VS Code extensions (.vsix files)
│   │   # Automatically installed to /opt/vscode-extensions in built image
│   │
│   └── disk-selector/             # Interactive disk selection during install
│       ├── disk-selector.sh       # Main disk selection script
│       ├── disk-selector-initramfs.sh # Initramfs integration
│       ├── dracut-disk-selector.sh    # Dracut module wrapper
│       └── run-disk-selector.sh       # Execution wrapper
│
├── oci-image/                     # Built container images
│   └── scvu-bootc-kde.oci         # OCI archive (extracted & used by ISO builder)
│
├── output/                        # Build outputs
│   ├── bootiso/
│   │   └── SCVU.iso               # ✅ Final installable ISO (~14 GB)
│   ├── manifest-iso.json          # ISO metadata & layer info
│   └── iso-build.log              # Build log
│
└── output.prev-*/                 # Previous build archives (timestamped backups)
```

---

## 🚀 Quick Start (3 Commands)

### 1. Fetch Offline Packages (Optional but Recommended)
```bash
cd /home/benson/Documents/Bootc_Test
./bootc_ostree/fetch_all_offline.sh
```
**What it does:** Downloads NVIDIA, VS Code, Docker, WineHQ, draw.io, OpenShift tools, CRC, Prism Launcher, and other optional packages. Skips if files exist (safe to re-run).

### 2. Build Interactive ISO (Simplest)
```bash
cd bootc_ostree/build-scripts
./build-iso-helper.sh interactive --iso-name SCVU.iso
```
**What it does:** 
- Builds the Fedora 43 KDE container image (cached after first build)
- Exports to OCI archive
- Composes Anaconda installer ISO with the embedded image
- Time: ~25–30 min | Output: `../output/bootiso/SCVU.iso` (~14 GB)

**Alternative: Non-Interactive**
```bash
./build-iso-helper.sh non-interactive  # Standard bootc auto-partition mode
```

### 3. Write to USB & Boot
```bash
sudo dd if=bootc_ostree/output/bootiso/SCVU.iso of=/dev/sdX bs=4M status=progress oflag=sync
# Replace /dev/sdX with your USB device
```

---

## 🔧 System Architecture

### Container Image Build
```
Containerfile (image definition)
        ↓
    Podman Build
        ↓
OCI Container Image (cached locally)
        ↓
    Bootc Export
        ↓
OCI Archive (.oci file)
```

### ISO Composition
```
OCI Archive
    ↓
bootc-image-builder (or coreos-installer)
    ↓
Linux kernel + initramfs + Anaconda
    ↓
Final ISO
```

### Installation Flow
```
User boots ISO
    ↓
Disk Detection & Selection
    ↓
Anaconda UI (interactive mode) OR Automatic Partitioning (non-interactive)
    ↓
Deploy container to selected disk
    ↓
First boot → Post-install script (optional)
    ↓
User account ready with all tools pre-configured
```

---

## 📋 Key Features

### ✅ Air-Gapped Installation
- Entire system image embedded in ISO
- No network required during install
- Optional offline packages for third-party software
- All Python wheels (numpy, scipy, etc.) predownloaded for offline pip install

### ✅ Smart User Creation
- **AIBUser** account created automatically during post-install
- Default password: `AIBUser@A!BUser`
- Auto-added to Docker group for containerized development
- README deployed to Desktop

### Multi-Disk Safety
```bash
# System automatically prompts for disk selection
# Choose target disk from the installer menu
```
### ✅ Multiple Installation Modes
- **Interactive (Anaconda):** User-friendly GUI, disk/partition selection, user creation
- **Non-Interactive (bootc default):** Automatic, suitable for identical hardware

### ✅ Modular Post-Install
```bash
# Full post-install
sudo /usr/local/bin/scvu/scvu-post-install.sh

# Selective execution
sudo /usr/local/bin/scvu/scvu-post-install.sh --skip-nvidia --wheels-only

# Python wheel installation only
sudo /usr/local/bin/scvu/scvu-post-install.sh --wheels-only --py py310 --py py311
```

---

## 📊 Build Statistics

| Component | Size | Time |
|-----------|------|------|
| Container Image | ~28 GB (on disk) | ~12 sec (cached) |
| OCI Archive | ~15 GB | ~39 sec (copy) |
| Final ISO | ~14 GB | ~8 min (compose) |
| **Total Build** | **~60 GB disk** | **~25–30 min** |

---

## 🛠️ Build Modes

### Mode 1: Interactive Helper (Recommended)
```bash
cd bootc_ostree/build-scripts
./build-iso-helper.sh interactive
```
- Simplest: one command
- Auto-detects config, builds, composes
- Logs to `logs/build-YYYYMMDD-HHMMSS.log`

### Mode 2: Advanced Direct Script
```bash
./build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml \
  --fetch-offline \
  --packages all \
  --iso-name SCVU-Custom.iso
```
- Full control over build parameters
- Useful for CI/CD integration

### Mode 3: Environment Variables
```bash
ISO_TYPE=iso \
ISO_NAME=SCVU-Standard.iso \
FETCH_OFFLINE=1 \
./build_export_iso.sh
```

---

## 🔌 Offline Package Management

### Fetch All (Recommended)
```bash
./fetch_all_offline.sh
```

### Fetch Selective
```bash
./fetch-scripts/fetch_offline_rpms.sh --vscode --nvidia --docker-desktop --skip-existing
```

### Manual Placement
```bash
# Copy downloaded files to:
bootc_ostree/image/offline-repo/<vendor>/

# For example:
bootc_ostree/image/offline-repo/vscode/code-*.rpm
bootc_ostree/image/offline-repo/docker-desktop/docker-desktop-*.rpm
```

### What Happens During Build
- Containerfile checks for offline packages in `offline-repo/`
- If found: installs from local files
- If missing: attempts online download (requires internet during build)
- Offline packages are **automatically included** — no extra flags needed

---

## 📝 Key Build Scripts

### `build-iso-helper.sh` (Entry Point)
```bash
Usage: ./build-iso-helper.sh [MODE] [OPTIONS]

Modes:
  interactive              Build Anaconda UI installer (default)
  non-interactive          Build standard bootc auto-partition installer
  compare                  Build both for testing

Options:
  --iso-name NAME          Output ISO filename (default: SCVU.iso)
  --skip-existing          Skip if ISO already exists
```

### `build_export_iso.sh` (Direct Control)
```bash
Flags:
  --iso-type anaconda-iso|iso         Installer mode (default: anaconda-iso)
  --config PATH                       Config file (auto-selected if omitted)
  --fetch-offline                     Download/cache packages
  --packages all|list                 Package selection
  --iso-name NAME                     Output ISO name
  --tag IMAGE:TAG                     Container image tag (default: scvu-bootc:kde)
  --rootfs SIZE                       Root filesystem size (default: 25 GB)
  --output-dir PATH                   Output directory
  --oci-path PATH                     OCI archive location
  --skip-existing                     Skip if already built
```

---

## 🐛 Troubleshooting

### Build fails at image save
**Problem:** OCI save interrupted (network/disk issue)
**Solution:**
```bash
# Manually save image
podman save localhost/scvu-bootc:kde -o bootc_ostree/oci-image/scvu-bootc-kde.oci

# Then compose ISO
./build_export_iso.sh --skip-existing --iso-type anaconda-iso
```

### "Permission denied" during build
**Problem:** Podman rootful mode not available
**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# OR use rootful podman explicitly
sudo ./build-iso-helper.sh interactive
```

### ISO too large for USB
**Problem:** 14 GB ISO requires USB 3.0+ or high-capacity thumb drive
**Solution:**
- Use 32+ GB USB drive
- Or write to external SSD (faster, more reliable)
- Or use Ventoy USB multiboot (boots from ISO without dd)

### Missing offline packages during build
**Problem:** Containerfile tries to install online, build fails without internet
**Solution:**
```bash
# Pre-fetch all packages before build
./fetch_all_offline.sh

# Then build
./build-iso-helper.sh interactive
```

---

## 🎓 Understanding the Image

### Containerfile Sections
1. **Lines 1–25:** Metadata & timezone setup
2. **Lines 26–35:** Language packs & dnf optimization
3. **Lines 36–50:** KDE Desktop + base dev tools
4. **Lines 51–150:** Python, ML libraries, Node.js, Blender
5. **Lines 151–250:** NVIDIA drivers, VS Code, multimedia
6. **Lines 251–350:** Docker, WineHQ, Windows emulation tools, LibreOffice
7. **Lines 351–400:** OpenShift tools, offline repo setup
8. **Lines 401–550:** Post-install script
9. **Lines 551–800:** System configuration, hostname, cleanup

### Containerfile Key Functions
- `create_aibuser()` — User account creation with Docker group auto-add
- `install_js_frameworks()` — Node.js tooling (Vue, React, Angular)
- `install_python_wheels()` — Offline pip install for ML libraries
- Post-install script — Runs after first boot for additional config

---

## 🔗 Related Files

- **Root README:** `/home/benson/Documents/Bootc_Test/README.md` — Quick start & overview
- **Archived Kickstart:** `/home/benson/Documents/Bootc_Test/archived/kickstart/` — Legacy Anaconda + LUKS setup (not used with bootc)
- **Anaconda Scripts:** `/home/benson/Documents/Bootc_Test/anaconda/` — Old direct-install scripts (reference only)

---

## 📖 Examples & Recipes

### Recipe 1: Minimal Air-Gapped Build
```bash
# No internet after this point
./bootc_ostree/fetch_all_offline.sh

# Build without network access
cd bootc_ostree/build-scripts
./build-iso-helper.sh interactive

# Transfer ISO to air-gapped network
# Install & use with zero external connectivity
```

### Recipe 2: CI/CD Automated Build
```bash
export ISO_TYPE=anaconda-iso
export ISO_NAME=SCVU-CI-$(date +%Y%m%d).iso
export FETCH_OFFLINE=1
export SKIP_EXISTING=1

cd bootc_ostree/build-scripts
./build_export_iso.sh

# Upload ISO to artifact storage
aws s3 cp ../output/bootiso/$ISO_NAME s3://artifacts/
```

### Recipe 3: Custom Python Version Only
```bash
# Post-install with specific Python versions
sudo /usr/local/bin/scvu/scvu-post-install.sh \
  --wheels-only \
  --py py310 \
  --py py311 \
  --py py312
```

### Recipe 4: Skip User Creation (Ansible Deploy)
```bash
# For automated deployment, skip user creation
# Containerfile includes: --skip-create-user flag

# Or post-install:
sudo /usr/local/bin/scvu/scvu-post-install.sh --skip-create-user
```

---

## ⚙️ Advanced Configuration

### Custom Timezone
Edit `Containerfile` line 14:
```dockerfile
RUN ln -sf /usr/share/zoneinfo/YOUR/TIMEZONE /etc/localtime
```

### Custom NTP Servers
Edit `Containerfile` lines 17–21:
```dockerfile
echo "server your-ntp-server.com iburst" >> /etc/chrony.d/custom-servers.conf
```

### Custom Python Packages
Edit `Containerfile` line 120 (`pip download` loop):
```dockerfile
for pkg in YOUR_PACKAGE1 YOUR_PACKAGE2 YOUR_PACKAGE3; do
```

### Additional System Packages
Edit `Containerfile` RUN sections to add `dnf install` commands.

---

## 📌 Deployment Checklist

- [ ] Run `./fetch_all_offline.sh` (if air-gapped deployment needed)
- [ ] Run `./bootc_ostree/build-scripts/build-iso-helper.sh interactive`
- [ ] Verify ISO exists: `ls -lh bootc_ostree/output/bootiso/SCVU.iso`
- [ ] Test on hardware or VM (optional)
- [ ] Boot from ISO, select target disk, confirm installation
- [ ] After first boot, run `/usr/local/bin/scvu/scvu-post-install.sh` (optional, for post-config)
- [ ] Verify AIBUser login & Docker group membership
- [ ] Confirm README on Desktop
- [ ] Test Python environments: `python3.10 -c "import numpy; print(numpy.__version__)"`
- [ ] Test Docker: `docker run hello-world`

---

## 🆘 Support & Documentation

- **Detailed Guide:** See `README.md` (812 lines)
- **Build History:** See `BUILD_STATUS.md`
- **Usage Examples:** See `EXAMPLES.md`
- **Issues:** Check logs: `build-scripts/logs/build-*.log`
- **Containerfile:** Full image definition with inline comments

---

## 📜 Version Info

| Component | Version |
|-----------|---------|
| Base OS | Fedora 43 bootc |
| KDE Plasma | Latest in F43 |
| Python | 3.9, 3.10, 3.11, 3.12, 3.13 |
| Docker | Latest available |
| NVIDIA | Latest available (via RPM Fusion) |
| CUDA | Latest available (with NVIDIA driver) |
| Build Tool | bootc-image-builder:latest |

---

## 🎉 Summary

**bootc_ostree** is a production-ready, fully offline-capable ISO builder for deploying consistent, air-gapped Fedora 43 KDE workstations with complete ML/dev tool stacks. It combines bootc container technology with Anaconda installer flexibility to support both hands-off deployment and interactive user configuration.

Start with: `./fetch_all_offline.sh && cd bootc_ostree/build-scripts && ./build-iso-helper.sh interactive`

---

*Last Updated: December 7, 2025*
