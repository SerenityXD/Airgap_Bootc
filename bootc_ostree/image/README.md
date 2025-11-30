# SCVU Bootc Image – Post-Install Guide

## Overview
This image includes KDE, dev tools, ML wheels, third‑party RPMs (if provided), and helper scripts. After installing from the ISO and first boot, run the consolidated post‑install to finalize setup.

## One‑Time Post‑Install
```bash
sudo /usr/local/bin/scvu-post-install.sh
```
What it does:
- Installs ML packages from embedded wheels for Python 3.9–3.13
- Installs VS Code extensions from `/opt/vscode-extensions` (if VS Code is installed)
- Enables `sddm` and `xrdp`, sets default to graphical target
- Rebuilds initramfs if NVIDIA drivers are present
- Ensures the current user is in the `docker` group

## Individual Scripts (optional)
- ML wheels: `sudo /usr/local/bin/install-ml-packages.sh`
- JS frameworks: `/usr/local/bin/install-js-frameworks.sh`

## Users
- `IAC` (admin, sudo), `AIBUser` (standard)
- Default password: `fedora` (change immediately)

## Third‑Party Content
Place these in the image build context before building:
- RPMs: `image/rpmfusion/`, `image/nvidia/`, `image/vscode/`, `image/winehq/`, `image/docker-desktop/`
- VSIX: `image/vscode-extensions/`
The `Containerfile` copies and installs them during build if present.

## Troubleshooting
- If ML install hits disk limits, install selected packages manually from `/opt/ml-wheels/py{39..313}`.
- If space issues occur during build/export, use a larger temp directory: `TMPDIR=/home/$USER/tmpbuild`.

## Quick Verification
```bash
# Confirm services
systemctl status sddm xrdp || true

# Confirm VS Code extensions (if VS Code installed)
code --list-extensions || true

# Confirm NVIDIA
nvidia-smi || true
```