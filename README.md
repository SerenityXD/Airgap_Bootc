# Bootc Air-Gapped Fedora ISO

This repository builds an air-gapped Fedora installer ISO and a matching OCI image using a prebuilt Bootc container image.

## Quick start

From the repository root:

```bash
make fetch-full           # Fetch offline artifacts, VS Code extensions, and npm tarballs
make build-iso            # Build the full interactive ISO with optional packages enabled
make build-oci-full       # Build the full OCI archive from the same image
make verify-iso           # Validate the delivered ISO and OCI contents
make help                # Show common targets
```

Custom ISO name:

```bash
make build-iso ISO_NAME=BOOTC-Custom.iso
```

## Prerequisites

- Fedora/RHEL based Linux Distribution
- `podman`, `bash`, `make`, `curl`, `git`, `unzip`, `wget`, `tar`, `xz`, `rpm`, `npm`
- `dnf` for installing host tools
- sudo access
- ~70 GB free disk space

## Install prerequisites

On Fedora/RHEL and WSL2 Fedora:

```bash
sudo dnf install -y podman curl make bash git unzip wget tar xz rpm npm
```

If you need third-party RPM packages, enable the required RPM repositories before running the install command.

For example, to enable Fedora's RPM Fusion free and nonfree repositories:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

If Podman is not available in your distribution, install it from the distro package repositories or follow the Podman installation guide for your platform.

## Recommended workflow

1. `make fetch-full`
2. `make build-iso-bare`
3. `make build-oci-full`
4. `make verify-iso`

If you want a single command that fetches, builds, and verifies everything, use:

```bash
make fetch-bare-full-verify
```

## Common make targets

- `make fetch-full`
  - downloads all offline payloads, VS Code extensions, and npm tarballs
- `make build-iso`
  - builds the full interactive ISO image
- `make build-iso-bare`
  - builds the bare ISO baseline (GUI + Podman, without optional packages)
- `make build-oci-full`
  - exports the full OCI archive from the built image
- `make verify-iso`
  - checks the ISO and OCI contents against the expected delivery
- `make clean-iso`
  - removes generated output directories under `bootc_ostree/fedora/output/`
- `make prune-podman`
  - aggressively cleans Podman images, build cache, containers, volumes, and networks
- `make clean-all`
  - runs `prune-podman` and `clean-iso`
- `make fetch-bare-full-verify`
  - fetches artifacts, builds bare ISO, builds full OCI, and verifies the result
- `make bare-full-verify`
  - builds bare ISO, builds full OCI, and verifies the result

## Offline artifact layout

The build uses staged payloads in:

- `bootc_ostree/fedora/image/offline-repo/`

The following directories must exist before the build runs:

- `bootc_ostree/fedora/image/offline-repo/rations/`
- `bootc_ostree/fedora/image/offline-repo/wallpapers/`

Use this link to get the relevant base files: https://pixeldrain.com/u/SRewN6nn

`rations/` and `wallpapers/` can be empty, but they must be present for the Containerfile copy steps.

## Build notes

- The image is built offline when possible and prefers staged artifacts from `bootc_ostree/fedora/image/offline-repo/`.
- Optional packages such as Blender, GIMP/Krita, Docker Desktop, Rations, and CUDA are enabled by default.
- Use `EXTRA_BUILD_ARGS` to customize build behavior when needed.

## Verification

Run:

```bash
make verify-iso
```

This target finds the latest generated ISO and OCI archive, then validates that the delivered image contains the expected offline assets and tools.

## Cleanup

- `make clean-iso` — remove generated ISO/OCI output only
- `make prune-podman` — remove Podman cache, images, containers, and volumes
- `make clean-all` — remove both image outputs and Podman artifacts

## More documentation

- Canonical Fedora build guide: `bootc_ostree/fedora/README.md`
- Image packaging and runtime notes: `bootc_ostree/fedora/image/docs/BOOTC-README.md`
- Bare-image runtime notes: `bootc_ostree/fedora/image/docs/BOOTC-README-bare.md`
- Project architecture: `docs/README.md`

## Output locations

- ISO files: `bootc_ostree/fedora/output/bootiso/`
- OCI archives: `bootc_ostree/fedora/output/oci-image/`
- Build logs: `bootc_ostree/fedora/build-scripts/logs/`
