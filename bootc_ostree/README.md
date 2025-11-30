# Bootc/Ostree Offline ISO Workflow

## Overview
This pivot avoids Anaconda+distro repos during install by embedding a prebuilt bootc (container-based) system image into the ISO. The installer only provisions the image; no dnf repos are needed in the air-gapped environment.

## Components
- System image: OCI container built via `bootc-image-builder` (or `podman build` + `bootc` labels)
- Installer ISO: composed with `bootc-image-builder` `installer` target or `coreos-installer` embedding the image
- Offline cache: local OCI registry (directory) or tarball containing the system image

## Flow
1. Build system image (online machine)
2. Export image to an offline artifact (directory or tarball)
3. Compose installer ISO embedding that image
4. Transfer ISO to air-gapped environment and install

## Build, Export, and Convert to ISO

### Scripted Build (recommended)
- Run everything in one command using the helper script. It cleans the output folder, builds the image, exports to OCI, loads it into rootful Podman, creates the ISO, and verifies the result.

```bash
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh
```

- Optional overrides via env vars or flags:

```bash
TAG=localhost/scvu-bootc:kde \
OUTPUT_DIR=/home/$USER/Documents/Bootc_Test/bootc_ostree/output \
OCI_PATH=/home/$USER/Documents/Bootc_Test/bootc_ostree/oci-image/scvu-bootc-kde.oci \
ROOTFS=btrfs \
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh

# or flags
/home/$USER/Documents/Bootc_Test/bootc_ostree/build_export_iso.sh \
	--tag localhost/scvu-bootc:kde \
	--image-dir /home/$USER/Documents/Bootc_Test/bootc_ostree/image \
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

## Air-gapped Install
- Boot the ISO
- The installer provisions the embedded image (no network, no repos)
- First boot runs systemd units to finalize setup

Post-install steps (run once after first boot):
```bash
sudo /usr/local/bin/scvu-post-install.sh
```
This will:
- Install VS Code extensions from `/opt/vscode-extensions` if VS Code is installed
- Enable `sddm` and `xrdp`, set default to graphical target
- Rebuild initramfs if NVIDIA drivers are present
- Ensure current user is in the `docker` group

## Notes
- You can keep separate variants (KDE, NVIDIA/CUDA, Docker Desktop, VS Code) via Dockerfiles and tags
- For updates, rebuild image online and recompose ISO

### Notes & Requirements
- Run the builder container with rootful Podman so it can access the loaded image.
- Ensure sufficient disk space (image ~50 GB, OCI ~40 GB, ISO size varies).
- If air-gapped, skip online repo steps; use offline RPMs under `image/` subfolders.

Third-party RPMs integration:
- Place offline RPMs under `bootc_ostree/image/` subfolders: `rpmfusion/`, `nvidia/`, `vscode/`, `winehq/`, `docker-desktop/`
- VS Code extensions: put `.vsix` files in `bootc_ostree/image/vscode-extensions/`
- The `Containerfile` copies and installs these if present during build
