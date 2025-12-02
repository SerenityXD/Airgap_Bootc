# Fedora Bootc/Ostree Air-Gapped ISO

This repository builds a fully offline, air-gapped installer ISO by embedding a prebuilt bootc (container-based) system image. The ISO provisions the image without contacting network repos, making it ideal for air‑gapped installs.

We previously attempted an Anaconda/kickstart flow, but pivoted to bootc/ostree for reliability and offline friendliness. The kickstart approach is no longer used.

## Requirements

### Build Machine
- **OS:** Linux (Fedora, RHEL, Ubuntu, etc.) or WSL2 on Windows (experimental)
- **Container Runtime:** Podman (rootless and rootful access)
  ```bash
  sudo dnf install -y podman
  ```
- **Build Tools:**
  - `bash` (for build script)
  - `curl` (for online Docker repo fetch)
  - `sudo` access (for rootful operations)
- **Disk Space:** 60–100 GB free
  - ~28 GB for container image
  - ~12 GB for OCI archive
  - ~13 GB for ISO output
  - Additional space for build cache
- **Network:** Internet access for initial builds (unless fully offline payloads are supplied)

### Script Dependencies
The `build_export_iso.sh` script requires:
- `podman` (build and save image)
- `sudo podman` (load into rootful storage and run image builder)
- `bootc-image-builder` container image: `quay.io/centos-bootc/bootc-image-builder:latest`
  - Automatically pulled during first run
  - Requires internet connection unless pre-cached

### Target Machine (for installed system)
- **Disk:** 20+ GB
- **RAM:** 4+ GB
- **Boot:** UEFI or BIOS support
- **Optional:** NVIDIA GPU (for driver support)

## What's Included

- Desktop: KDE Plasma with SDDM
- Dev tools: gcc, cmake, git, make, fastfetch
- Multiple Python versions: 3.9–3.13 (with pip)
- Node.js + npm + yarn
- VS Code; offline VSIX extensions supported
- Docker Desktop (offline RPM), docker group handling
- WineHQ stable
- Multimedia: ffmpeg, mpv, OBS, codec packs (RPM Fusion)
- Filesystems: NTFS, exFAT, Btrfs, ext4, XFS, F2FS
- Remote access: xrdp
- Users: IAC (admin) and AIBUser (standard), both in `docker`

Exact contents are defined in `bootc_ostree/image/Containerfile` and may vary by build inputs and available offline payloads.

## Preparing Offline Packages (Optional)

If you want to include third-party packages (RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop), fetch them first on an internet-connected machine:

```bash
# Fetch all packages
/home/$USER/Documents/Bootc_Test/bootc_ostree/fetch_offline_rpms.sh --all

# Or fetch specific packages
/home/$USER/Documents/Bootc_Test/bootc_ostree/fetch_offline_rpms.sh --vscode --docker-desktop

# Skip if already downloaded
/home/$USER/Documents/Bootc_Test/bootc_ostree/fetch_offline_rpms.sh --all --skip-existing
```

Packages will be saved to `bootc_ostree/image/offline-repo/<vendor>/` and automatically included in the build.

**Important:** The fetch script downloads packages for Fedora 43 by default (matching the bootc base image). If you're using a different base image version, set `FEDORA_VERSION` environment variable:
```bash
FEDORA_VERSION=43 ./bootc_ostree/fetch_offline_rpms.sh --all
```

**Note:** If offline packages are not fetched, the build will automatically fall back to online installation during the container build process.

### Known Package Conflicts

Some packages may fail to download on systems with conflicting packages already installed:

**RPM Fusion (ffmpeg conflict)**:
- **Issue:** Conflicts with Fedora's `ffmpeg-free` package
- **Workaround:** Temporarily remove before fetching:
  ```bash
  sudo dnf remove -y ffmpeg-free
  ./bootc_ostree/fetch_offline_rpms.sh --rpmfusion
  sudo dnf install -y ffmpeg-free  # Reinstall if needed
  ```

**WineHQ (wine-desktop conflict)**:
- **Issue:** Conflicts with Fedora's `wine-desktop` package
- **Workaround:** Temporarily remove before fetching:
  ```bash
  sudo dnf remove -y wine-desktop
  ./bootc_ostree/fetch_offline_rpms.sh --winehq
  sudo dnf install -y wine-desktop  # Reinstall if needed
  ```

**Alternative:** Run the fetch script on a minimal Fedora installation without these packages installed, or skip fetching and rely on online fallback during build.

## Quick Start (Scripted)

Use the helper script to build the image, export an OCI archive, load it into rootful Podman, compose the ISO, and verify the result.

**Basic build (uses online fallback for packages):**
```bash
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh
```

**Build with automatic offline package fetching:**
```bash
# Fetch all packages before building
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh --fetch-offline

# Fetch specific packages only
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh --fetch-offline --packages vscode,nvidia,docker-desktop
```

**Advanced options:**
```bash
# Using environment variables
TAG=localhost/scvu-bootc:kde \
OUTPUT_DIR=/home/$USER/Documents/Bootc_Test/bootc_ostree/output \
OCI_PATH=/home/$USER/Documents/Bootc_Test/bootc_ostree/oci-image/scvu-bootc-kde.oci \
ROOTFS=btrfs \
FETCH_OFFLINE=true \
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh

# Using flags
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh \
  --tag localhost/scvu-bootc:kde \
  --output-dir /home/$USER/Documents/Bootc_Test/bootc_ostree/output \
  --rootfs btrfs \
  --fetch-offline \
  --packages all \
  --skip-existing
```

**Available options:**
- `--fetch-offline` or `-f`: Automatically fetch offline packages before building
- `--packages` or `-p`: Specify which packages to fetch (default: all)
  - Options: `all`, or comma-separated: `vscode,nvidia,docker-desktop,rpmfusion,winehq`
- `--skip-existing` or `-s`: Skip downloading packages that already exist (default: true)

Manual step‑by‑step commands and notes are in `bootc_ostree/README.md`.

## Build Pipeline Overview

0) (Optional) Fetch offline packages if `--fetch-offline` is specified
1) Build the bootc system image via Podman
2) Export to an OCI archive (rootless → rootful bridge)
3) Load into rootful Podman
4) Use `bootc-image-builder` to compose an installer ISO (Btrfs rootfs)
5) Verify ISO under `bootc_ostree/output/bootiso/install.iso`

## Artifacts and Disk Usage

- ISO: `bootc_ostree/output/bootiso/install.iso` (observed ~13 GB)
- OCI archive: `bootc_ostree/oci-image/scvu-bootc-kde.oci` (observed ~12 GB)
- Container image size in storage: ~28 GB

Recommendation: Have 60–100 GB free during builds to accommodate layers, caches, and artifacts.

## Post-Install

After installing from the ISO, run once:

```bash
sudo /usr/local/bin/scvu-post-install.sh
```

This will:
- Install VS Code extensions per user from `/opt/vscode-extensions` if present
- Enable SDDM and XRDP; set default to graphical target
- Rebuild initramfs if NVIDIA drivers are present
- Ensure the current user is in the `docker` group

## Burning ISO to USB

**Important:** Do NOT use Fedora Media Writer. Bootc ISOs use OSTree deployment and require different tools.

### Option 1: dd (Linux/Mac, Recommended)
```bash
# Find your USB device
lsblk

# Write the ISO (replace /dev/sdX with your USB device)
sudo dd if=/home/$USER/Documents/Bootc_Test/bootc_ostree/output/bootiso/install.iso \
    of=/dev/sdX \
    bs=4M \
    status=progress \
    oflag=sync
```

### Option 2: Ventoy (Multi-boot USB)
1. Install Ventoy on your USB drive: https://www.ventoy.net
2. Copy the ISO to the Ventoy partition
3. Boot from USB and select the ISO from Ventoy menu

### Option 3: Balena Etcher (Cross-platform GUI)
1. Download from: https://etcher.balena.io
2. Select the ISO file
3. Select target USB drive
4. Click "Flash!"

### Option 4: Rufus (Windows)
1. Download from: https://rufus.ie
2. Select the ISO
3. **Important:** Choose "DD Image" mode (not "ISO mode")
4. Write to USB

## Notes

- NVIDIA: Bare‑metal GPU support may require akmods packages and Secure Boot considerations. VM environments won't expose `nvidia-smi` without a passthrough GPU.
- Air‑gapped resilience: Third‑party RPMs (RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop) can be supplied offline under `bootc_ostree/image/offline-repo/` subfolders. The build guards online fetches when air‑gapped.
- Bootc ISOs are not compatible with Fedora Media Writer due to OSTree deployment structure.

## Documentation

- Full build and export guide: `bootc_ostree/README.md`
- Bootc image definition: `bootc_ostree/image/Containerfile`

## Windows Support (⚠️ Experimental)

Building bootc images on Windows requires **WSL2** since Podman and bootc-image-builder need a Linux environment.

### Setup WSL2 Build Environment

```powershell
# Install WSL2 (PowerShell as Administrator)
wsl --install

# After restart, enter WSL2 and install dependencies
wsl
sudo dnf install -y podman git

# Clone repository (or access Windows files via /mnt/c/)
git clone https://github.com/SerenityXD/SCVU_Bootc_Test.git
cd SCVU_Bootc_Test
```

### Build from WSL2

```bash
# Run the build script in WSL2
/home/$USER/SCVU_Bootc_Test/bootc_ostree/build_export_iso.sh
```

### Access ISO from Windows

The generated ISO is accessible from Windows at:
```
\\wsl$\Ubuntu\home\<username>\SCVU_Bootc_Test\bootc_ostree\output\bootiso\install.iso
```

Or copy to Windows:
```bash
# From WSL2
cp ~/SCVU_Bootc_Test/bootc_ostree/output/bootiso/install.iso /mnt/c/Users/<YourName>/Downloads/
```

### Burn ISO on Windows

Use native Windows tools (no WSL2 needed):

1. **Rufus** (Recommended): https://rufus.ie
   - Select ISO
   - **Use "DD Image" mode** (not "ISO mode")
   - Write to USB

2. **Balena Etcher**: https://etcher.balena.io
   - Cross-platform GUI
   - Auto-detects USB drives

3. **Win32 Disk Imager**: https://sourceforge.net/projects/win32diskimager/

### Known Limitations

- Build times may be slower in WSL2
- Requires ~80-120 GB free space (Windows + WSL2 combined)
- Podman in WSL2 may require additional configuration for rootless containers
- Not officially tested; Linux host recommended for production builds

## Support

Open issues or questions in this repo. For implementation details, see `bootc_ostree/README.md` and the embedded comments in the `Containerfile`.
