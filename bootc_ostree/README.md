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
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh --fetch-offline

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
