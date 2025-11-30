# Fedora Bootable ISO - Air-Gapped ML/AI Development Environment

This repository contains kickstart files and scripts to build a fully offline, air-gapped bootable Fedora 43 ISO for ML/AI development and general computing.

## What's Included

- **Desktop Environment**: KDE Plasma with SDDM display manager
- **Development Tools**: 
  - Python 3.9-3.13 with pip for each version
  - VS Code with Python and Jupyter extensions (offline)
  - Node.js, npm, yarn
  - git, gcc, make, kernel-devel
- **Containerization**: Docker Desktop (GUI + CLI)
- **GPU Support**: NVIDIA drivers and CUDA toolkit
- **Machine Learning**: TensorFlow, PyTorch, transformers, scikit-learn, Jupyter (offline Python wheels)
- **3D Graphics**: Blender (Unreal Engine via post-ISO installation)
- **Multimedia**: mpv, OBS Studio, ffmpeg, codec plugins
- **Windows Compatibility**: WineHQ stable, Bottles
- **Office Suite**: LibreOffice
- **Remote Access**: xrdp (RDP server)
- **Filesystem Support**: NTFS, exFAT, ext4, Btrfs, XFS, F2FS
- **Users**: IAC (admin with sudo), AIBUser (standard) - both in docker group

## Quick Start

### Preflight (Online Prep Machine)

Ensure the following on the internet-connected machine:
- Tools: `dnf`, `curl`, `createrepo_c`, `python3`
- Optional: `python3.9`-`python3.13` available to fetch matching wheels
- Disk: 40-50 GB free
- Network: Stable internet

Quick checks:

```bash
command -v dnf && command -v curl && command -v createrepo_c || echo "Missing tools"
for v in 3.9 3.10 3.11 3.12 3.13; do command -v python${v} || true; done
df -h .
```

Install missing metadata tool:
```bash
sudo dnf -y install createrepo_c
```
### 1. Prepare Air-Gap Repository (Requires Internet)

On a machine with internet access:

```bash
./kickstart/prepare_airgap_repo.sh
```

This downloads all packages, Python wheels, and VS Code extensions (~15-30 GB).

### 2. Build Bootable ISO

```bash
sudo livemedia-creator --make-iso --no-virt \
  --ks kickstart/bootc-airgap.ks \
  --project bootc-airgap \
  --resultdir out-airgap \
  --tmp /var/tmp \
  --cachedir $PWD/airgap-packages-full
```

Build time: 20-40 minutes | ISO size: ~10-20 GB

### 3. Fix Ownership and Transfer

```bash
sudo chown -R "$(id -un)":"$(id -gn)" out-airgap/
# Burn to USB or transfer to air-gapped environment
```

## Files

- `kickstart/bootc-airgap.ks` - Main kickstart file for air-gapped ISO
- `kickstart/prepare_airgap_repo.sh` - Script to download all offline packages
- `kickstart/README_AirGap.md` - Detailed documentation (copied to ISO)
- `airgap-packages-full/` - Downloaded packages cache (~15-30 GB, created by prep script)

## Post-Installation

After booting from the ISO:

1. **Install ML/AI packages**: `/usr/local/bin/install-ml-packages.sh`
2. **Install JavaScript frameworks**: `/usr/local/bin/install-js-frameworks.sh`
3. **Install Unreal Engine** (optional): `/usr/local/bin/install-unreal-engine.sh`
4. **Start Docker Desktop**: Launch from KDE menu or `systemctl --user enable --now docker-desktop`

## Documentation

Full documentation is available in:
- `kickstart/README_AirGap.md` - Complete guide with troubleshooting
- `/usr/share/doc/bootc-airgap/README_AirGap.md` - On installed system

## System Requirements

- **Build Machine**: 40-50 GB free space, internet access
- **Target Machine**: 20+ GB disk, 4+ GB RAM, UEFI or BIOS boot
- **GPU Support** (optional): NVIDIA GPU with compatible drivers

## Customization

- **Change hostname**: Edit `network --hostname=` in `kickstart/bootc-airgap.ks`
- **Change project name**: Use `--project your-name` in livemedia-creator command
- **Modify packages**: Edit package list in `kickstart/bootc-airgap.ks`
- **Add repos**: Extend `kickstart/prepare_airgap_repo.sh`

## Security Notes

- Default root password is encrypted placeholder - **change during installation**
- Users IAC and AIBUser are created during installation
- Both users have docker group access
- xrdp enabled on port 3389 for remote desktop access
- Firewall configured automatically

## Support

For detailed installation instructions, troubleshooting, and advanced configuration, see `kickstart/README_AirGap.md`.
