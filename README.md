# Fedora Bootc/Ostree Air-Gapped ISO

Build a fully offline, air-gapped installer ISO by embedding a prebuilt bootc container image. Installs without network repos; includes both interactive (Anaconda) and non-interactive modes.

## Table of Contents
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Offline Payloads](#offline-payloads)
- [Build Options](#build-options)
- [Artifacts & Disk Use](#artifacts--disk-use)
- [Install & Boot Media](#install--boot-media)
- [Modes: Interactive vs Non-Interactive](#modes-interactive-vs-non-interactive)
- [Post-Install](#post-install)
- [Updates](#updates)
- [Windows/WSL2](#windowswsl2)
- [Reference Files](#reference-files)
- [Support & Links](#support--links)

## Quick Start
- Fetch everything (optional but recommended for air-gap):
  ```bash
  ./bootc_ostree/fetch_all_offline.sh
  ```
- Build interactive ISO (simplest):
  ```bash
  cd bootc_ostree/build-scripts && ./build-iso-helper.sh interactive
  ```
- Build non-interactive ISO:
  ```bash
  cd bootc_ostree/build-scripts && ./build-iso-helper.sh non-interactive
  ```
- Build both for testing:
  ```bash
  cd bootc_ostree/build-scripts && ./build-iso-helper.sh compare
  ```
- Or use the direct script (full control):
  ```bash
  ./bootc_ostree/build-scripts/build_export_iso.sh --iso-type anaconda-iso --iso-name SCVU-Interactive.iso
  ./bootc_ostree/build-scripts/build_export_iso.sh --iso-type iso --iso-name SCVU-Standard.iso
  ```
- Write ISO to USB (replace /dev/sdX):
  ```bash
  sudo dd if=bootc_ostree/output/bootiso/SCVU*.iso of=/dev/sdX bs=4M status=progress oflag=sync
  ```

## Requirements
- Host OS: Linux (Fedora/RHEL/Ubuntu) or WSL2 on Windows
- Tools: `podman`, `sudo` for rootful podman, `curl`, `bash`
- Image builder: pulls `quay.io/centos-bootc/bootc-image-builder:latest` (cache or pre-pull if offline)
- Disk: 70–130 GB free during build (image ~28 GB, OCI ~15 GB, ISO ~14 GB; add ~20 GB for offline packages)
- Target hardware: 20+ GB disk, 4+ GB RAM, UEFI/BIOS; NVIDIA optional

## Offline Payloads
- One-shot fetch (all vendors): `./bootc_ostree/fetch_all_offline.sh`
- Individual fetchers: see `bootc_ostree/fetch-scripts/` (RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop, draw.io, OpenShift tools, CRC, Prism Launcher, OBS)
- Place RPMs/VSIX under `bootc_ostree/image/offline-repo/<vendor>/` and `bootc_ostree/image/vscode-extensions/`
- Default Fedora base: 43. Override with `FEDORA_VERSION=43 ...` if you build a different base.
- Known conflicts: `ffmpeg-free` vs RPM Fusion; `wine-desktop` vs WineHQ. Remove temporarily if fetch fails.

## Build Options
- Helper (simplest):
  - Interactive (default): `./bootc_ostree/build-scripts/build-iso-helper.sh`
  - Non-interactive: `./bootc_ostree/build-scripts/build-iso-helper.sh non-interactive`
  - Both: `./bootc_ostree/build-scripts/build-iso-helper.sh compare`
- Direct script (full control):
  ```bash
  ./bootc_ostree/build-scripts/build_export_iso.sh \
    --iso-type anaconda-iso \
    --config bootc_ostree/build-scripts/config-interactive.toml \
    --fetch-offline \
    --packages all \
    --iso-name SCVU.iso
  ```
- Useful flags: `--fetch-offline`, `--packages <list>`, `--skip-existing`, `--tag`, `--rootfs`, `--image-dir`, `--output-dir`, `--oci-path`, `--iso-name`.
- Env var style:
  ```bash
  ISO_TYPE=iso ISO_NAME=SCVU-Standard.iso ./bootc_ostree/build-scripts/build_export_iso.sh
  ```

## Artifacts & Disk Use
- ISO: `bootc_ostree/output/bootiso/install.iso`
- OCI archive: `bootc_ostree/oci-image/scvu-bootc-kde.oci`
- Logs: `bootc_ostree/output/iso-build.log`

## Install & Boot Media
- Write with `dd`, Ventoy, Etcher, or Rufus (DD mode). Fedora Media Writer is unsupported for bootc ISOs.
- Multi-disk safe installation: system prompts to select target disk.

## Modes: Interactive vs Non-Interactive
- Non-interactive (default bootc flow): automatic disk select/partition; best for identical hardware and automation.
- Interactive (Anaconda UI): user picks disk/partitions/users/timezone; best for varied hardware or dual-boot prep. Requires `--iso-type anaconda-iso --config build-scripts/config-interactive.toml` when building.

## Post-Install
- Run once after first boot:
  ```bash
  sudo /usr/local/bin/scvu/scvu-post-install.sh
  ```
- Includes cached Python wheel install by default (offline, Python 3.9–3.13).
- Flags: `--no-wheels` to skip, `--wheels-only` to install wheels only, `--py py310 --py py311` to target versions.
- Per-step control (combine as needed): `--skip-extensions`, `--skip-readme`, `--skip-services`, `--skip-nvidia`, `--skip-docker`, `--skip-podman`, or `--only-steps extensions,services` to run just listed base steps.
- scvu-post-install does: install VS Code extensions from `/opt/vscode-extensions`, enable `sddm` and `xrdp`, rebuild initramfs if NVIDIA present, ensure user in `docker` group, and install cached Python wheels from `/opt/python-wheels/py<ver>` if present.
- Optional script: `scvu/install-js-frameworks.sh`.

## Updates
- Status: `bootc status`
- Update current image: `sudo bootc upgrade && sudo reboot`
- Switch to new tag: `sudo bootc switch localhost/scvu-bootc:kde && sudo reboot`
- Roll back: `sudo bootc rollback && sudo reboot`
- Offline update: move `scvu-bootc-kde.oci`, load with `sudo podman load -i ...`, then `bootc switch`.

## Windows/WSL2
- Use WSL2 with Podman installed. Build via:
  ```bash
  /home/$USER/SCVU_Bootc_Test/bootc_ostree/build-scripts/build_export_iso.sh
  ```
- ISO path from Windows: `\\wsl$\<distro>\home\<user>\SCVU_Bootc_Test\bootc_ostree\output\bootiso\install.iso`
- Burn on Windows with Rufus (DD Image mode) or Etcher.

## Reference Files
- Build script (direct): `bootc_ostree/build-scripts/build_export_iso.sh`
- Helper wrapper: `bootc_ostree/build-scripts/build-iso-helper.sh`
- Config for interactive ISO: `bootc_ostree/build-scripts/config-interactive.toml`
- Container build: `bootc_ostree/image/Containerfile`
- Offline content: `bootc_ostree/image/offline-repo/`, `bootc_ostree/image/vscode-extensions/`
- Detailed workflow (full text): `bootc_ostree/README.md`

## Support & Links
- Open issues in this repo for help.
- References: Supakeen guide on interactive bootc installer; Fedora Anaconda docs; bootc-image-builder repo; bootc docs.
