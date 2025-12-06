# Bootc/Ostree Offline ISO Workflow

## Overview
This pivot avoids Anaconda+distro repos during install by embedding a prebuilt bootc (container-based) system image into the ISO. The installer only provisions the image; no dnf repos are needed in the air-gapped environment.

## Components
- System image: OCI container built via `bootc-image-builder` (or `podman build` + `bootc` labels)
- Installer ISO: composed with `bootc-image-builder` `installer` target or `coreos-installer` embedding the image
- Offline cache: local OCI registry (directory) or tarball containing the system image

## Flow
1. (Optional) Fetch offline RPMs for third-party packages
2. Build system image (online machine)
3. Export image to an offline artifact (directory or tarball)
4. Compose installer ISO embedding that image
5. Transfer ISO to air-gapped environment and install

## Fetching Offline Packages

Before building, download third-party packages on an internet-connected machine.

### All-in-One Fetch (Recommended)

```bash
# Fetch everything: RPMs, draw.io, OpenShift tools, CRC, Prism Launcher
./fetch_all_offline.sh
```

This master script runs all individual fetch scripts and provides a summary.

### Individual Fetch Scripts

All individual fetch scripts are in the `fetch-scripts/` subdirectory:

```bash
# Fetch RPM packages (RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop)
./fetch-scripts/fetch_offline_rpms.sh --all

# Fetch draw.io (diagrams.net)
./fetch-scripts/fetch_drawio.sh

# Fetch OpenShift/Kubernetes CLI tools (oc, kubectl)
./fetch-scripts/fetch_openshift_tools.sh

# Fetch CodeReady Containers (CRC)
./fetch-scripts/fetch_crc.sh

# Fetch Prism Launcher (Minecraft launcher)
./fetch-scripts/fetch_prismlauncher.sh

# Fetch specific RPM packages only
./fetch-scripts/fetch_offline_rpms.sh --vscode --docker-desktop --nvidia

# Skip downloads if files already exist
./fetch-scripts/fetch_offline_rpms.sh --all --skip-existing
```

Packages are saved to `image/offline-repo/<vendor>/` and automatically included during build.

**Note:** If offline packages are not fetched, the Containerfile will automatically fall back to online installation during build (where available).

**NVIDIA Drivers:** Currently configured to install from RPM Fusion online repository. The offline NVIDIA repo is incomplete (missing `nvidia-kmod-common` and dependencies). To fix the offline repo, run `./fetch-scripts/fix_nvidia_offline.sh` which will download all required NVIDIA packages with dependencies.

### Included Software

**Pre-configured System Settings:**
- Timezone: Asia/Singapore
- NTP servers: time.windows.com (primary), time.nist.gov, pool.ntp.org
- Network discovery: Samba, Avahi (mDNS), wsdd (WS-Discovery for Windows)

**Development Tools:**
- VS Code, Visual Studio Code (flatpak)
- Python 3.9, 3.10, 3.11, 3.12, 3.13 with unified pip packages:
  - tritonclient[all], numpy, scipy, pandas, matplotlib
  - scikit-learn, jupyter, notebook, ipython, seaborn, opencv-python
- Git, Docker/Podman, OpenShift tools (oc, kubectl)
- CodeReady Containers (CRC) for local OpenShift

**Gaming:**
- Lutris (gaming platform with Wine/Proton support)
- Prism Launcher (Minecraft launcher, AppImage)

**Applications:**
- Firefox, Google Chrome
- QGIS (Geographic Information System)
- Draw.io Desktop (diagrams.net)
- OBS Studio (online installation only due to Qt6 conflicts)

**Multimedia & Graphics:**
- NVIDIA drivers and CUDA toolkit (if hardware detected)
- FFmpeg, VLC, GIMP, Inkscape, Blender

**System Tools:**
- Interactive disk selector for multi-drive installations
- XRDP (remote desktop)
- Wine/WineHQ (Windows app compatibility)
- Docker Desktop support

### Known Package Conflicts

Some packages may fail to download on systems with conflicting packages already installed:

**RPM Fusion**: Conflicts with `ffmpeg-free`
```bash
# Workaround: temporarily remove conflict
sudo dnf remove -y ffmpeg-free
./fetch_offline_rpms.sh --rpmfusion
sudo dnf install -y ffmpeg-free  # Reinstall if needed
```

**WineHQ**: Conflicts with `wine-desktop`
```bash
# Workaround: temporarily remove conflict
sudo dnf remove -y wine-desktop
./fetch_offline_rpms.sh --winehq
sudo dnf install -y wine-desktop  # Reinstall if needed
```

**Alternative:** Run the fetch script on a minimal Fedora system without these packages, or skip offline fetching and use online fallback.

## Build, Export, and Convert to ISO

### Scripted Build (recommended)

The build script validates sudo access once at start and maintains it throughout (no timeouts). It can automatically fetch offline packages before building, or use online fallback during the build.

**Basic build (online fallback):**
```bash
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh
```

**Build with offline packages (recommended workflow):**
```bash
# Step 1: Fetch all offline packages
./fetch_all_offline.sh

# Step 2: Build ISO
./build_export_iso.sh --iso-name SCVU.iso
```

**Build with automatic offline package fetching:**
```bash
# Fetch all packages automatically during build
/home/$USER/Documents/Bootc_Test/bootc_ostree/build-scripts/build_export_iso.sh --fetch-offline

# Fetch specific packages only
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh \
  --fetch-offline \
  --packages vscode,nvidia,docker-desktop
```

**Advanced usage with environment variables:**

```bash
TAG=localhost/scvu-bootc:kde \
OUTPUT_DIR=/home/$USER/Documents/Bootc_Test/bootc_ostree/output \
OCI_PATH=/home/$USER/Documents/Bootc_Test/bootc_ostree/oci-image/scvu-bootc-kde.oci \
ROOTFS=btrfs \
FETCH_OFFLINE=true \
FETCH_PACKAGES=all \
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh

# or using flags
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh \
	--tag localhost/scvu-bootc:kde \
	--image-dir /home/$USER/Documents/Bootc_Test/bootc_ostree/image \
	--oci-path /home/$USER/Documents/Bootc_Test/bootc_ostree/oci-image/scvu-bootc-kde.oci \
	--output-dir /home/$USER/Documents/Bootc_Test/bootc_ostree/output \
	--rootfs btrfs \
	--fetch-offline \
	--packages all \
	--skip-existing
```
	--oci-path /home/$USER/Documents/Bootc_Test/bootc_ostree/oci-image/scvu-bootc-kde.oci \
	--output-dir /home/$USER/Documents/Bootc_Test/bootc_ostree/output \
	--rootfs btrfs
```

The ISO and build log will be under `bootc_ostree/output/` (ISO at `output/bootiso/install.iso`, log at `output/iso-build.log`).

### 0) Prepare workspace and temp directory
```bash
mkdir -p /home/$USER/tmpbuild
```

### 1) Build the bootc system image
```bash
cd /home/$USER/Documents/Bootc_Test/bootc_ostree/image
TMPDIR=/home/$USER/tmpbuild podman build -t localhost/scvu-bootc:kde -f Containerfile .
```

### 2) Export the image to an OCI archive (rootless → rootful bridge)
```bash
cd /home/$USER/Documents/Bootc_Test/bootc_ostree
mkdir -p oci-image
podman save --format oci-archive -o oci-image/scvu-bootc-kde.oci localhost/scvu-bootc:kde
```

### 3) Load into rootful Podman and convert to ISO
```bash
sudo podman load -i /home/$USER/Documents/Bootc_Test/bootc_ostree/oci-image/scvu-bootc-kde.oci
mkdir -p /home/$USER/Documents/Bootc_Test/bootc_ostree/output
sudo podman run --rm -it --privileged \
	--security-opt label=type:unconfined_t \
	-v /home/$USER/Documents/Bootc_Test/bootc_ostree/output:/output \
	-v /var/lib/containers/storage:/var/lib/containers/storage:rw \
	quay.io/centos-bootc/bootc-image-builder:latest \
	--type iso --rootfs btrfs localhost/scvu-bootc:kde
```

### 4) Verify resulting ISO
```bash
ls -lh /home/$USER/Documents/Bootc_Test/bootc_ostree/output/bootiso/install.iso
file /home/$USER/Documents/Bootc_Test/bootc_ostree/output/bootiso/install.iso
```

## Creating Bootable USB

**Important:** Do NOT use Fedora Media Writer. Use one of these methods:

### Method 1: dd (Linux/Mac)
```bash
# Find your USB device
lsblk

# Write ISO to USB (replace /dev/sdX)
sudo dd if=/home/$USER/Documents/Bootc_Test/bootc_ostree/output/bootiso/install.iso \
    of=/dev/sdX bs=4M status=progress oflag=sync
```

### Method 2: Ventoy
- Install Ventoy on USB: https://www.ventoy.net
- Copy ISO to Ventoy partition
- Boot and select from menu

### Method 3: Balena Etcher (GUI)
- Download: https://etcher.balena.io
- Select ISO, select USB, flash

### Method 4: Rufus (Windows)
- Use "DD Image" mode (not "ISO mode")
- https://rufus.ie

## Air-gapped Install

### Interactive Installation (Recommended for Multi-Drive Systems)

The ISO includes an interactive disk selector that runs during boot. To enable it:

1. Boot from the USB/ISO
2. At the boot menu (GRUB), press 'e' to edit boot parameters
3. Add `rd.bootc.interactive` to the kernel command line (on the line starting with `linux`)
4. Press Ctrl+X or F10 to boot

The disk selector will:
- Display all available disks with sizes
- Let you choose the target installation disk
- Ask for confirmation before proceeding
- **Only the selected disk will be used** - other disks remain untouched

**Example:**
```
======================================
SCVU Bootc Workstation Installer
======================================

Detecting available disks...

1) /dev/sda (238.5G)
2) /dev/nvme0n1 (953.9G)

Select disk number (1-2): 2

You selected: /dev/nvme0n1 (953.9G)

WARNING: All data on /dev/nvme0n1 will be ERASED!
Type 'yes' to confirm: yes

Proceeding with bootc installation...
```

### Protecting Specific Disks

If you want to ensure certain disks are completely invisible to the installer, add this to the kernel command line:

```
rd.bootc.interactive rd.disk.exclude=/dev/sda
```

This will:
- Hide `/dev/sda` from the disk selector menu
- Prevent the installer from seeing or using that disk
- Useful for protecting drives with important data

**Example for multiple disks:**
```
rd.bootc.interactive rd.disk.exclude=/dev/sda rd.disk.exclude=/dev/sdb
```

### Non-Interactive Installation (Single Drive or Automated)

If you don't add the `rd.bootc.interactive` parameter:
- The installer will automatically select a disk (usually the largest available)
- No user interaction required
- Suitable for single-drive systems or automated deployments

### Post-Install Steps

After installation completes and you boot into the system (run once after first boot):
```bash
sudo /usr/local/bin/scvu-post-install.sh
```
This will:
- Install VS Code extensions from `/opt/vscode-extensions` if VS Code is installed
- Enable `sddm` and `xrdp`, set default to graphical target
- Rebuild initramfs if NVIDIA drivers are present
- Ensure current user is in the `docker` group

### Creating a Standard User (AIBUser)

The system ships with a default admin user `IAC` who has wheel/sudo privileges.

During Interactive Startup, create an `AIBUser` with no Admin Permissions

## Dual Boot & Manual Partitioning Workaround

### Interactive Disk Selection

For multi-drive systems or when you want to choose the installation disk, use the interactive mode:

1. Boot from the ISO
2. At the GRUB menu, press 'e' to edit boot parameters
3. Add `rd.bootc.interactive` to the kernel command line
4. Press Ctrl+X to boot
5. Select your target disk from the interactive menu

### Dual Boot with Windows

Bootc/ostree ISOs do not provide a graphical/manual partitioning option during installation. To dual boot with Windows or customize partitions:

**Workaround:**
1. Shrink your Windows partition and create a new empty partition for Linux _before_ running the installer.
   - In Windows: Use Disk Management to shrink the main partition and leave unallocated space.
   - Or use a live USB with GParted to resize and create a new partition.
2. Boot from the bootc/ostree ISO and run the installer. It will typically use the largest available unallocated space for installation.
3. After install, GRUB should detect both Windows and Linux for dual boot.

**Note:** Always back up your data before resizing partitions. If BitLocker is enabled, suspend it before making changes.

## Notes
- You can keep separate variants (KDE, NVIDIA/CUDA, Docker Desktop, VS Code) via Dockerfiles and tags
- For updates, rebuild image online and recompose ISO

### Notes & Requirements
- Run the builder container with rootful Podman so it can access the loaded image.
- Ensure sufficient disk space (image ~50 GB, OCI ~40 GB, ISO size varies).
- If air-gapped, skip online repo steps; use offline RPMs under `image/` subfolders.

Third-party RPMs integration:
- **Automated:** Run `./fetch_offline_rpms.sh --all` to download packages
- **Manual:** Place offline RPMs under `bootc_ostree/image/offline-repo/` subfolders: `rpmfusion/`, `nvidia/`, `vscode/`, `winehq/`, `docker-desktop/`
- VS Code extensions: put `.vsix` files in `bootc_ostree/image/vscode-extensions/`
- The `Containerfile` copies and installs these if present during build

---

# Interactive vs Non-Interactive Installation

## Quick Overview

This project supports **two build modes**:

1. **Non-Interactive (Default):** Standard Fedora bootc ISO with pre-configured system
2. **Interactive (Anaconda Installer):** User-configurable installer for custom hardware

Both modes use the same container image and produce similar-sized ISOs (~14GB).

## Which Should You Use?

### Use Non-Interactive When:
- ✅ Deploying to identical hardware (data center)
- ✅ Need consistent, repeatable installations
- ✅ CI/CD pipeline or automated rollout
- ✅ Pre-configured system works for all users
- ✅ Minimal user interaction desired
- ✅ Single-drive systems or standardized configs

### Use Interactive When:
- ✅ Deploying to varied hardware
- ✅ End users making their own servers
- ✅ Custom partitioning needed per machine
- ✅ Different configurations per site/user
- ✅ Flexibility more important than automation
- ✅ Multi-drive systems needing disk selection

## Build Commands by Use Case

### Quick Start: Interactive Installer

```bash
# Build interactive installer ISO
./build-scripts/build_export_iso.sh \
  --iso-type anaconda-iso \
  --config build-scripts/config-interactive.toml \
  --iso-name SCVU-Interactive.iso
```

Or use the helper script:

```bash
./build-scripts/build-iso-helper.sh interactive
```

### Quick Start: Standard Non-Interactive

```bash
# Build standard ISO (default behavior)
./build-scripts/build_export_iso.sh --iso-name SCVU-Standard.iso

# Or without specifying name
./build-scripts/build_export_iso.sh
```

### Build Both for Testing

```bash
# Build both ISOs at once
./build-scripts/build-iso-helper.sh compare
```

## How Interactive Mode Works

Based on the pattern from https://supakeen.com/weblog/building-interactive-installer-bootc/:

1. **Empty Kickstart:** The configuration file contains an empty kickstart directive:
   ```toml
   [customizations.installer]
   contents = ""
   ```

2. **bootc-image-builder Behavior:** When bootc-image-builder sees only an `ostreecontainer` directive (with no other installation details), it signals Anaconda to enter **interactive mode**.

3. **User Choices:** Anaconda displays the standard installer UI where users:
   - Select installation destination disk
   - Create/configure partitions (**must label `/boot` as "boot"**)
   - Configure users and passwords
   - Set timezone and keyboard
   - Customize software selection (optional)

4. **Installation:** Anaconda performs the standard installation and deploys the bootc container image with all configured tools and applications.

## Installation Flow Comparison

### Non-Interactive Boot Sequence
```
GRUB Menu → Anaconda Loads → Auto Detect Disk → Auto Partition → 
Auto Format & Install → System Ready
(No user prompts, ~20-30 minutes)
```

### Interactive Boot Sequence
```
GRUB Menu → Anaconda Loads → Welcome Screen → Language Selection → 
Disk Selection & Partitioning → User Setup → Network Config → 
Timezone & Keyboard → Format & Install → System Ready
(User makes decisions, ~25-40 minutes including user input time)
```

## Build with Offline Packages

Both modes support offline package fetching:

```bash
# Interactive with offline packages
./build-scripts/build_export_iso.sh \
  --iso-type anaconda-iso \
  --config build-scripts/config-interactive.toml \
  --fetch-offline \
  --packages docker-desktop,vscode,nvidia \
  --iso-name SCVU-Interactive-Offline.iso

# Non-interactive with offline packages
./build_export_iso.sh \
  --fetch-offline \
  --packages all \
  --iso-name SCVU-Standard-Offline.iso
```

## File Reference

| File | Purpose | Required? |
|------|---------|-----------|
| `build_export_iso.sh` | Main build orchestrator | ✅ Yes (core) |
| `build-iso-helper.sh` | Convenience wrapper for quick builds | ❌ No (but recommended) |
| `config-interactive.toml` | Anaconda config for interactive mode | ✅ Only for `--iso-type anaconda-iso` |
| `Containerfile` | Container image with tools | ✅ Yes (unchanged) |
| `fetch_all_offline.sh` | Fetch all offline packages | ❌ Optional (for air-gapped) |
| `fetch-scripts/` | Individual package fetch scripts | ❌ Optional (for air-gapped) |

## Advanced: Using Environment Variables

```bash
# Override defaults with environment variables
ISO_TYPE=anaconda-iso \
CONFIG_FILE=build-scripts/config-interactive.toml \
ISO_NAME=SCVU-Interactive.iso \
./build-scripts/build_export_iso.sh

# Or for non-interactive
ISO_TYPE=iso \
ISO_NAME=SCVU-Standard.iso \
./build-scripts/build_export_iso.sh
```

## Real-World Scenarios

### Scenario 1: Data Center Deployment (3 Identical Servers)

**Approach:** Non-Interactive
```bash
# Build once
./build_export_iso.sh --iso-name SCVU-DataCenter.iso

# Deploy to 3 servers
# Boot Server1, Server2, Server3 from SCVU-DataCenter.iso
# Each auto-installs identically (exact same config)
# ~30 minutes per server, no user interaction
```

**Pros:** Repeatable, consistent, minimal per-server time  
**Cons:** All servers get same partitioning (no customization)

### Scenario 2: Varied Hardware Deployment (3 Servers with Different Disks)

**Approach:** Interactive
```bash
# Build once
./build-scripts/build_export_iso.sh \
  --iso-type anaconda-iso \
  --config build-scripts/config-interactive.toml \
  --iso-name SCVU-Flexible.iso

# Deploy to 3 servers with different hardware
# Boot Server1: User configures disk (500GB available) → creates large /var
# Boot Server2: User configures disk (2TB available) → creates smaller /var
# Boot Server3: User configures disk (4TB available) → creates custom partitions
# ~45 minutes per server (includes user decisions)
```

**Pros:** Customizable per-hardware, flexible, optimal for each machine  
**Cons:** Requires manual input, slightly longer per machine

### Scenario 3: Dual Boot (Windows + Linux)

**Setup:**
1. Boot from Windows, use Disk Management to shrink Windows partition
2. Leave unallocated space for Linux
3. Boot from SCVU ISO (interactive recommended)
4. In Anaconda, select the unallocated space
5. After install, GRUB will detect both Windows and Linux

**Note:** Always back up data before resizing partitions. If BitLocker is enabled, suspend it first.

### Scenario 4: Multi-Drive System with Disk Protection

Use the interactive disk selector to choose which disk to install to and protect others:

```bash
# During boot, edit GRUB parameters to add:
rd.bootc.interactive rd.disk.exclude=/dev/sda rd.disk.exclude=/dev/sdb
# This hides sda and sdb from the installer, only showing nvme0n1
```

## File Size Comparison

Both ISO types are approximately the same size (~14GB for SCVU Bootc):

```
Non-Interactive:   14G  SCVU-Standard.iso
Interactive:       14G  SCVU-Interactive.iso
```

**Why same size?** Both contain the same container image (SCVU Bootc with KDE, tools, etc.) and the same Anaconda installer. The difference is only in how the kickstart provisions the system.

## Summary Table

| Aspect | Non-Interactive | Interactive |
|--------|-----------------|-------------|
| **Build Command** | `./build_export_iso.sh` | `./build_export_iso.sh --iso-type anaconda-iso --config config-interactive.toml` |
| **Boot Experience** | Automatic, no prompts | Anaconda GUI with menus |
| **Partitioning** | Pre-configured | User-chosen |
| **Root Password** | Pre-set in container | User-set during install |
| **User Accounts** | Pre-configured | User-created during install |
| **Use Case** | Standardized deployments | Custom/flexible deployments |
| **Time to Deploy** | 20-30 minutes | 25-40 minutes (includes user input) |
| **Learning Curve** | None (automatic) | Low (standard installer) |
| **ISO Size** | ~14GB | ~14GB |

## Troubleshooting Interactive Builds

### Error: "Config file not found"
```
[prep] Error: Config file not found: config-interactive.toml
```
**Solution:** Ensure `config-interactive.toml` exists:
```bash
ls -l config-interactive.toml
```

### Error: "--config FILE is required for anaconda-iso mode"
**Solution:** Always provide `--config` when using `--iso-type anaconda-iso`:
```bash
./build-scripts/build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml
```

### Installation fails: "/boot not labeled as boot"
**Solution:** During Anaconda interactive installation, manually label `/boot`:
1. In Anaconda's partition editor
2. Select `/boot` partition
3. Set label to `boot` (not `Boot` or other variants)

## Helper Script Quick Reference

```bash
# Interactive build with timestamp
./build-iso-helper.sh interactive
# Output: SCVU-Interactive-20251206-160530.iso

# Non-interactive build
./build-iso-helper.sh non-interactive
# Output: SCVU-Standard-20251206-160530.iso

# Build both for comparison testing
./build-iso-helper.sh compare
# Outputs both ISOs side-by-side

# With custom name
./build-iso-helper.sh interactive --iso-name SCVU-v1.0.iso

# With offline packages
./build-iso-helper.sh interactive --fetch-offline
```

## Migration Path

If you're already using non-interactive ISOs:

```bash
# Your existing ISOs still work! No changes needed.
# You can now ALSO build interactive ISOs for new deployments:

./build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml \
  --iso-name SCVU-Interactive-v2.iso

# Anaconda interactive installer is now the DEFAULT
# Non-interactive (pre-configured) still available via --iso-type iso
# Users can choose between modes
```

---

## 📦 Post-Install Guide: SCVU Bootc Image

After installing from the ISO and first boot, run the consolidated post-install to finalize setup.

### One-Time Post-Install
```bash
sudo /usr/local/bin/scvu-post-install.sh
```

**What it does:**
- Installs ML packages from embedded wheels for Python 3.9–3.13
- Installs VS Code extensions from `/opt/vscode-extensions` (if VS Code is installed)
- Enables `sddm` and `xrdp`, sets default to graphical target
- Rebuilds initramfs if NVIDIA drivers are present
- Ensures the current user is in the `docker` group

### Individual Scripts (Optional)
- **ML wheels:** `sudo /usr/local/bin/install-ml-packages.sh`
- **JS frameworks:** `/usr/local/bin/install-js-frameworks.sh`

### Image Users
- **IAC** (admin, sudo access)
- **AIBUser** (standard user)
- **Default password:** `fedora` (change immediately after first login)

### Third-Party Content in Image Build

Place these in the image build context before building:

**RPMs:** 
- `image/rpmfusion/` - RPMFusion packages
- `image/nvidia/` - NVIDIA drivers and tools
- `image/vscode/` - VS Code packages
- `image/winehq/` - Wine packages
- `image/docker-desktop/` - Docker Desktop packages

**VS Code Extensions:**
- `image/vscode-extensions/` - VSIX extension files

The `Containerfile` copies and installs them during the build process if present.

### Post-Install Troubleshooting

**ML Install Disk Limits:**
If ML install hits disk limits, install selected packages manually:
```bash
cd /opt/ml-wheels/py313  # or py39, py310, py311, py312
pip install *.whl
```

**Space Issues During Build/Export:**
Use a larger temp directory:
```bash
TMPDIR=/home/$USER/tmpbuild ./build_export_iso.sh
```

### Quick Verification After Install

```bash
# Confirm services are running
systemctl status sddm xrdp || true

# Confirm VS Code extensions (if VS Code installed)
code --list-extensions || true

# Confirm NVIDIA drivers (if applicable)
nvidia-smi || true
```

---

## References

- [Supakeen: Building Interactive Installer Bootc](https://supakeen.com/weblog/building-interactive-installer-bootc/)
- [Fedora Anaconda Installer Documentation](https://anaconda-installer.readthedocs.io/)
- [bootc-image-builder GitHub](https://github.com/osbuild/bootc-image-builder)
- [bootc Documentation](https://containers.github.io/bootc/)

---

# Appendix: Detailed Playbook

## Prerequisites (Host)
- Linux host (Fedora/RHEL/Ubuntu) or WSL2; `sudo` available for rootful Podman.
- Packages: `podman`, `curl`, `tar`, `bash`; pull access to `quay.io/centos-bootc/bootc-image-builder:latest` (pre-pull if offline).
- Disk headroom: 60–100 GB free (image ~28 GB, OCI ~12 GB, ISO ~13 GB, plus cache/temp).
- Temp directory: set `TMPDIR=/fast/disk` if default storage is small.

## Repository Layout (bootc_ostree/)
- `build_export_iso.sh` — main orchestrator (builds image, exports OCI, composes ISO).
- `build-iso-helper.sh` — convenience wrapper (interactive/non-interactive/compare).
- `config-interactive.toml` — enables Anaconda interactive ISO.
- `image/Containerfile` — bootc image definition.
- `image/offline-repo/` — vendor subfolders for RPM payloads.
- `image/vscode-extensions/` — VSIX files copied into image.
- `image/disk-selector/` — interactive disk selector scripts and dracut hook.
- `fetch-scripts/` — per-vendor fetch helpers and fixes (e.g., NVIDIA fix script).
- `output/` — ISO and logs after build (created on demand).
- `oci-image/` — exported OCI archives (created on demand).

## Build Matrix (common commands)
- Interactive ISO (default): `./build_export_iso.sh --iso-name SCVU-Interactive.iso`
- Non-interactive ISO: `./build_export_iso.sh --iso-type iso --iso-name SCVU-Standard.iso`
- Interactive with offline payloads: `./build_export_iso.sh --iso-type anaconda-iso --config config-interactive.toml --fetch-offline --packages all --iso-name SCVU-Interactive-Offline.iso`
- Helper both variants (compare): `./build-iso-helper.sh compare`
- Override paths/tags:
  ```bash
  TAG=localhost/scvu-bootc:kde \
  OUTPUT_DIR=$PWD/output \
  OCI_PATH=$PWD/oci-image/scvu-bootc-kde.oci \
  ./build_export_iso.sh --rootfs btrfs --iso-name SCVU.iso
  ```

## Environment Flag Cheat Sheet
- `ISO_TYPE` (`anaconda-iso`|`iso`), `CONFIG_FILE`, `ISO_NAME`, `TAG`, `OUTPUT_DIR`, `OCI_PATH`, `ROOTFS`, `FETCH_OFFLINE=true`, `FETCH_PACKAGES=all|vscode,nvidia,...`, `TMPDIR=/path/on/fast/disk`.

## Offline Payload Validation
- List staged RPMs: `find image/offline-repo -type f | wc -l`
- Check missing NVIDIA deps: run `./fetch-scripts/fix_nvidia_offline.sh` (downloads the full set).
- Validate VSIX presence: `ls image/vscode-extensions/*.vsix`

## ISO Verification
- Size: `ls -lh output/bootiso/install.iso`
- Type: `file output/bootiso/install.iso`
- Checksum: `sha256sum output/bootiso/install.iso > output/bootiso/install.iso.sha256`
- Optional QEMU smoke test (non-interactive):
  ```bash
  qemu-system-x86_64 -m 4096 -cpu host -enable-kvm \
    -drive if=virtio,file=output/bootiso/install.iso,media=cdrom \
    -drive if=virtio,file=/tmp/bootc-test.img,format=qcow2 \
    -boot d -nographic
  ```

## Troubleshooting Quick Wins
- `Config file not found` → ensure `config-interactive.toml` exists; pass `--config`.
- `/boot not labeled as boot` → in Anaconda interactive partitioning, label `/boot` exactly `boot`.
- Space errors during build/export → set `TMPDIR` to a large/fast volume; clear old `output/` and `oci-image/` if safe.
- Sudo timeout mid-build → script keeps sudo alive; if interrupted, rerun and enter password once.
- SELinux denials with builder container → add `--security-opt label=type:unconfined_t` (already present) and ensure volume paths are not on `noexec`.

## FAQ (build & install)
- **Can I customize rootfs type?** Yes, `--rootfs ext4|btrfs|xfs` when composing ISO.
- **Can I skip building the image and reuse an existing OCI?** Yes, set `OCI_PATH` to a prebuilt archive; script will load and compose.
- **How to protect disks during install?** Add `rd.bootc.interactive rd.disk.exclude=/dev/sdX` at GRUB.
- **How to auto-pick the largest disk?** Use non-interactive ISO (default boot flow) without `rd.bootc.interactive`.
- **Where are build logs?** `output/iso-build.log` and the terminal transcript from the orchestrator script.
