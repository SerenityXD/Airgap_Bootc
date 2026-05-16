# Offline Package Fetch Scripts

This directory contains scripts for fetching software packages and binaries for offline installation in the bootc image build. All scripts follow the same patterns and output their downloads to `../offline-repo/`.

## General Usage

Most scripts can be run directly:

```bash
./fetch_script_name.sh
```

Scripts that support options (e.g., `--all`, `--skip-existing`) should be documented in their headers.

## Special Requirements

### CUDA Toolkit

The `fetch_cuda_toolkit.sh` script downloads CUDA Toolkit and associated packages from NVIDIA. **The CUDA repository must be configured in DNF before this script can download packages.**

#### Option 1: Run with sudo (automatic setup)

```bash
sudo ./fetch_cuda_toolkit.sh
```

This will automatically configure the CUDA repository (requires sudo password).

#### Option 2: Manual repository setup (sudoless)

If you prefer not to use `sudo`, you can manually set up the CUDA repository once, then run the script without elevated privileges:

```bash
# One-time setup: install CUDA repo configuration
sudo dnf install -y https://developer.download.nvidia.com/compute/cuda/repos/fedora43/x86_64/cuda-repo-fedora-43-1.0-1.x86_64.rpm

# Then run the fetch script normally (no sudo needed)
./fetch_cuda_toolkit.sh
```

**Note:** For Fedora versions other than 43, adjust the URL accordingly:
- Fedora 42: Replace `fedora43` with `fedora42` and `fedora-43` with `fedora-42`
- Fedora 44: Replace `fedora43` with `fedora44` and `fedora-43` with `fedora-44`

#### Option 3: Use in air-gapped builds without local CUDA packages

If you cannot download CUDA packages locally (e.g., air-gapped network), you can exclude CUDA from the image build:

```bash
podman build --build-arg EXCLUDE_CUDA_TOOLKIT=yes -t bootc-bootc -f ../Containerfile .
```

CUDA can then be installed post-deployment on the target system if needed.

## Docker Desktop

`fetch_offline_rpms.sh` requires specific Docker Desktop URLs. See the script header for details.

## All Available Fetch Scripts

| Script | Purpose |
|--------|---------|
| `fetch_vscode.sh` | Visual Studio Code |
| `fetch_offline_rpms.sh` | RPM packages (WineHQ, Docker Desktop) |
| `fetch_gimp.sh` | GIMP image editor |
| `fetch_krita.sh` | Krita digital painter |
| `fetch_blender.sh` | Blender 3D modeling |
| `fetch_drawio.sh` | Draw.io diagrams editor |
| `fetch_obs.sh` | OBS Studio streaming software |
| `fetch_cuda_toolkit.sh` | NVIDIA CUDA Toolkit ⚠️ *Requires repo setup* |
| `fetch_openshift_tools.sh` | OpenShift/Kubernetes CLI (oc, kubectl) |
| `fetch_helm.sh` | Helm package manager |
| `fetch_k3s_binary.sh` | k3s Kubernetes binary |
| `fetch_k3s_images.sh` | k3s offline container images |
| `fetch_davinci_resolve.sh` | DaVinci Resolve (requires URL/license) |
| `fetch_unreal_engine.sh` | Unreal Engine (requires URL) |
| `fetch_triton_server.sh` | NVIDIA Triton inference server |
| `pull-vscode-extensions.sh` | VS Code Extensions |
| `create-npm-tarballs.sh` | npm framework tarballs |

## Integration with fetch_all_offline.sh

The main orchestrator script `../fetch_all_offline.sh` runs most of these scripts automatically. For full offline builds:

```bash
cd ../
DRY_RUN=false INCLUDE_OPTIONAL_FETCH=true ./fetch_all_offline.sh
```

## Common Issues

### "No matching repositories for cuda"

The CUDA repository is not configured. See **CUDA Toolkit** section above for setup options.

### "Could not download: [package]"

- Verify internet connectivity
- Check if the package is available for your Fedora version
- Some packages may require special access or authentication

### Permission denied

If you get permission errors when writing to `../offline-repo/`, ensure the directory is writable:

```bash
ls -ld ../offline-repo/
chmod u+w ../offline-repo/
```
