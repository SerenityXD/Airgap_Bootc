# Fedora Bootc/Ostree Air-Gapped ISO

This repository builds a fully offline, air-gapped installer ISO by embedding a prebuilt bootc (container-based) system image. The ISO provisions the image without contacting network repos, making it ideal for air‑gapped installs.

We previously attempted an Anaconda/kickstart flow, but pivoted to bootc/ostree for reliability and offline friendliness. The kickstart approach is no longer used.

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

## Quick Start (Scripted)

Use the helper script to build the image, export an OCI archive, load it into rootful Podman, compose the ISO, and verify the result.

```bash
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh
```

Optional overrides:

```bash
TAG=localhost/scvu-bootc:kde \
OUTPUT_DIR=/home/$USER/Documents/Bootc_Test/bootc_ostree/output \
OCI_PATH=/home/$USER/Documents/Bootc_Test/bootc_ostree/oci-image/scvu-bootc-kde.oci \
ROOTFS=btrfs \
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh
```

Manual step‑by‑step commands and notes are in `bootc_ostree/README.md`.

## Build Pipeline Overview

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

## Requirements

- Build machine: Podman, internet access for initial builds (unless fully offline payloads are supplied), and adequate disk space (60–100 GB recommended)
- Target machine: 20+ GB disk, 4+ GB RAM, UEFI or BIOS boot

## Support

Open issues or questions in this repo. For implementation details, see `bootc_ostree/README.md` and the embedded comments in the `Containerfile`.
