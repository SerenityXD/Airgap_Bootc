# Kickstart Build Guide (merged with Air-Gap workflow)

This guide consolidates kickstart-specific notes with the air-gapped build and deployment workflow used by `bootc-airgap.ks`.

## Overview

We build a bootable Fedora 43 ISO using `livemedia-creator` and a kickstart, with all packages cached locally via `kickstart/prepare_airgap_repo.sh`. The resulting ISO installs KDE Plasma, Docker Desktop, multiple Python versions, NVIDIA/CUDA support, VS Code with Python/Jupyter extensions, multimedia tooling, and more.

## Preflight (Online Prep Machine)

- Fedora machine with internet
- Tools: `dnf`, `curl`, `createrepo_c`, `python3`
- Disk space: 40-50 GB free (cache + ISO artifacts)
- Optional: `python3.9`-`python3.13` installed to match wheel downloads

Quick checks:

```bash
command -v dnf && command -v curl && command -v createrepo_c || echo "Missing tools"
for v in 3.9 3.10 3.11 3.12 3.13; do command -v python${v} || true; done
df -h .
```

## Step 1: Prepare air-gap cache

Run on the internet-connected machine:

```bash
./kickstart/prepare_airgap_repo.sh
```

This mirrors Fedora repos and downloads third-party packages, ML wheels, and VS Code extensions into `airgap-packages-full/`.

## Step 2: Build the ISO (offline-friendly)

Install build tools (if missing):

```bash
sudo dnf install -y lorax livemedia-creator
```

Build using the cached packages:

```bash
sudo livemedia-creator --make-iso --no-virt \
	--ks kickstart/bootc-airgap.ks \
	--project SCVU \
	--resultdir out-airgap \
	--tmp /var/tmp \
	--cachedir $PWD/airgap-packages-full
```

Notes:
- `--cachedir` points to the local cache to avoid network access
- If you prefer, you can use `--image-repo` with Fedora Everything URLs instead of `--cachedir`

## Step 3: Write ISO to USB and install

```bash
sudo dd if=out-airgap/images/boot.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Kickstart specifics and fixes

- Use `timezone UTC --utc`
- Include `dracut-live` in `%packages` for live ISO creation
- Remove deprecated `auth` directives
- `akmod-nvidia` builds kernel modules on install/first boot; Secure Boot may need MOK enrollment

## Post-install scripts (created by Kickstart)

- `/usr/local/bin/install-ml-packages.sh` — installs ML/AI Python packages from `/opt/ml-wheels/`
- `/usr/local/bin/install-js-frameworks.sh` — installs Node.js frameworks (React, Vue, Angular, Next.js, etc.)
- `/usr/local/bin/install-unreal-engine.sh` — extract Unreal Engine tarball if copied to `/opt/unreal-engine/`

## Troubleshooting

- Missing metadata tool: `sudo dnf -y install createrepo_c`
- NVIDIA drivers: `sudo akmods --force && sudo dracut --force`
- Docker Desktop: `systemctl --user enable --now docker-desktop`

For the full air-gap guide, see `kickstart/README_AirGap.md` (also copied to `/usr/share/doc/bootc-airgap/README_AirGap.md` on the installed system).
