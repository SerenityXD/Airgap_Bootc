# Fedora Bootc Offline Build Guide

This is the canonical build and operations guide for the Fedora bootc air-gapped image and ISO workflow.

## Scope
This guide covers:
- Offline payload preparation
- Image and ISO build modes
- Post-install and verification steps
- Troubleshooting and operational checks

## 0. Common Entry Points (new)

### Make targets (recommended)
From repo root:

```bash
make fetch
make build-iso
make build-iso-ni
make build-iso-minimal
make build-iso-docker
make build-iso-full
make build-iso-compare
make verify-iso
```

### Direct script mode
The canonical script accepts positional modes:

```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive
./bootc_ostree/fedora/build-scripts/build_export_iso.sh non-interactive
./bootc_ostree/fedora/build-scripts/build_export_iso.sh compare
```

## 1. Build Modes

### Interactive (default)
Creates an Anaconda-based installer where users select disk/partition settings.

```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive
```

### Non-Interactive
Creates a standard bootc installer flow for automated or repeatable environments.

```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh non-interactive
```

### Compare
Builds both interactive and non-interactive variants.

```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh compare
```

## 2. Offline Payloads

### Fetch all supported payloads
```bash
./bootc_ostree/fedora/fetch_all_offline.sh
```

### Individual fetch scripts
Located in:
- `bootc_ostree/fedora/image/scripts/`

Common examples:
```bash
./bootc_ostree/fedora/image/scripts/fetch_offline_rpms.sh --all --skip-existing
./bootc_ostree/fedora/image/scripts/fetch_gimp.sh
./bootc_ostree/fedora/image/scripts/fetch_krita.sh
DAVINCI_RESOLVE_FILE=/path/to/DaVinci_Resolve_Linux.zip ./bootc_ostree/fedora/image/scripts/fetch_davinci_resolve.sh
UNREAL_ENGINE_FILE=/path/to/UnrealEngine-Linux.tar.xz ./bootc_ostree/fedora/image/scripts/fetch_unreal_engine.sh
./bootc_ostree/fedora/image/scripts/fetch_k3s_images.sh
./bootc_ostree/fedora/image/scripts/fetch_openshift_tools.sh
./bootc_ostree/fedora/image/scripts/fetch_helm.sh
./bootc_ostree/fedora/image/scripts/fetch_k3s_binary.sh
WALLPAPER_REPO_URL=https://github.com/GNOME/gnome-backgrounds.git WALLPAPER_REPO_SUBDIR=backgrounds ./bootc_ostree/fedora/image/scripts/fetch_wallpapers.sh
./bootc_ostree/fedora/image/scripts/create-npm-tarballs.sh
```

### Payload locations
- RPMs/binaries: `bootc_ostree/fedora/image/offline-repo/<vendor>/`
- VS Code extensions: `bootc_ostree/fedora/image/offline-repo/vscode-extensions/`
- npm tarballs: `bootc_ostree/fedora/image/offline-repo/npm-packages/`
- wallpapers: `bootc_ostree/fedora/image/offline-repo/wallpapers/`

### Required directories
The build expects these directories to exist before image creation:
- `bootc_ostree/fedora/image/offline-repo/rations/`
- `bootc_ostree/fedora/image/offline-repo/wallpapers/`

Notes:
- `rations/` is required by the Containerfile copy step. Keep the directory present even when you are not including rations in the final image. Folder should include portablemc and the archive required to run it.
- `wallpapers/` is required by the Containerfile bind-mount step. It may be empty, but the directory must exist.

Vendor-gated payload notes:
- `davinci-resolve/`: stage the official Linux installer ZIP, RPM, or `.run` bundle.
- `unreal-engine/`: stage an Epic-provided Linux installed-build archive.

### Optional: include wallpapers from a Git repository
```bash
WALLPAPER_REPO_URL=https://github.com/GNOME/gnome-backgrounds.git \
WALLPAPER_REPO_SUBDIR=backgrounds \
./bootc_ostree/fedora/fetch_all_offline.sh
```

Optional refinements:
- `WALLPAPER_REPO_REF=main`
- `WALLPAPER_REPO_URL=https://gitlab.gnome.org/GNOME/gnome-backgrounds.git` (canonical upstream)

## 3. Build Options

### Basic command
```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh
```

### Useful flags
```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh \
  --iso-type anaconda-iso \
  --config bootc_ostree/fedora/build-scripts/config-interactive.toml \
  --fetch-offline \
  --packages all \
  --iso-name BOOTC-Interactive.iso
```

### Environment-style usage
```bash
ISO_TYPE=iso ISO_NAME=BOOTC-Standard.iso \
./bootc_ostree/fedora/build-scripts/build_export_iso.sh
```

### Optional Packages and Build Arguments

Control image size by including or excluding optional packages via `--build-arg` flags. All optional packages are **enabled by default**; use `EXCLUDE_*=yes` to remove them:

| Package | Flag | Size | Notes |
|---------|------|------|-------|
| Docker Desktop | `EXCLUDE_DOCKER_DESKTOP=yes` | 404 MB | Enabled by default |
| GIMP + Krita | `EXCLUDE_GIMP_KRITA=yes` | 511 MB | Enabled by default |
| Blender 4.2 LTS | `EXCLUDE_BLENDER=yes` | ~300 MB | Enabled by default |
| Rations/Minecraft | `EXCLUDE_RATIONS=yes` | ~50 MB | Enabled by default |
| **CUDA Toolkit + cuDNN** | `EXCLUDE_CUDA_TOOLKIT=yes` | ~1 GB | **Enabled by default**; enables ML development (nvcc, CUDA runtime, cuDNN) |

**Example: Build minimal ISO (exclude all optional packages including CUDA):**
```bash
make build-iso-minimal

# Or manually:
./bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive \
  --iso-name bootc-minimal.iso \
  --build-arg EXCLUDE_BLENDER=yes \
  --build-arg EXCLUDE_DOCKER_DESKTOP=yes \
  --build-arg EXCLUDE_GIMP_KRITA=yes \
  --build-arg EXCLUDE_RATIONS=yes \
  --build-arg EXCLUDE_CUDA_TOOLKIT=yes
```

**Example: Build without CUDA (exclude CUDA, keep other packages):**
```bash
make build-iso-minimal-nocuda

# Or manually:
./bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive \
  --iso-name bootc-nocuda.iso \
  --build-arg EXCLUDE_CUDA_TOOLKIT=yes
```

**Example: Build full ISO with everything including CUDA (default):**
```bash
make build-iso-full

# Manually (showing explicit inclusion is not needed as default):
./bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive \
  --iso-name bootc-full.iso
```

### CUDA Toolkit and ML Framework Setup

**When to use:**
- Need to compile CUDA code or custom ML operators
- Want `nvcc` compiler for custom kernels
- Developing with PyTorch/TensorFlow that require compilation

**What is included:**
- `cuda-toolkit`: nvcc compiler, CUDA headers, development libraries
- `cuda-runtime`: CUDA runtime libraries (also available without toolkit)
- `libcudnn` + `libcudnn-devel`: NVIDIA Deep Neural Network library

**ML frameworks (PyTorch, TensorFlow, etc.):**
- **NOT pre-cached** in the image (storage optimization)
- Install post-boot via `pip` when internet is available:
  ```bash
  # On a CUDA-enabled system:
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

  # Or TensorFlow:
  pip install tensorflow[and-cuda]
  ```
- For **air-gapped environments**, pre-download wheels and stage them manually before image build

## 4. Outputs
- ISO files: `bootc_ostree/fedora/output/bootiso/`
- OCI archive: `bootc_ostree/fedora/output/oci-image/bootc-gnome.oci`
- Logs: `bootc_ostree/fedora/build-scripts/logs/`

### Verify ISO delivery
Run the host-side verifier after a build to confirm the ISO artifacts exist and
that the delivered bootc image contains the staged offline assets and key tools.
The default `make verify-iso` target now enforces Lutris presence:

```bash
make verify-iso
```

You can also run the verifier directly and pass explicit expectation flags:

```bash
./bootc_ostree/fedora/build-scripts/verify_iso_contents.sh \
  --expect-lutris \
  --expect-wine \
  --expect-docker-desktop \
  --expect-gimp-krita
```

## 5. Post-Install
Run once after first boot:
```bash
sudo /usr/local/bin/bootc/bootc-post-install.sh
```

Useful options:
- `--wheels-only`
- `--no-wheels`
- `--skip-extensions`
- `--skip-services`
- `--skip-nvidia`
- `--only-steps extensions,services`

Optional JavaScript framework verifier:
```bash
sudo /usr/local/bin/bootc/install-js-frameworks.sh
```

## 6. Boot Media

Use Fedora Media Writer

Alternative tools: Ventoy, Balena Etcher, Rufus (DD mode).

## 7. Troubleshooting

### Build fails due to missing offline artifacts
- Re-run `fetch_all_offline.sh`.
- Verify files under `bootc_ostree/fedora/image/offline-repo/`.

### NVIDIA modules fail after install
- Disable Secure Boot in firmware.
- Hybrid mode can break external outputs on some laptops; test Discrete GPU mode when available.

### Repo package conflicts while fetching
- `ffmpeg-free` can conflict with RPM Fusion packages.
- `wine-desktop` can conflict with WineHQ packages.

## 8. Script Responsibility Map
- `build-scripts/build_export_iso.sh`: canonical build entrypoint.
- `build-scripts/build-iso-helper.sh`: compatibility wrapper only.
- `fetch_all_offline.sh`: orchestrates all fetch scripts.
- `image/scripts/fetch_*.sh`: vendor/tool-specific fetchers.
- `image/Containerfile`: core system image definition.

## 9. Documentation Map
- Project quick start: `README.md`
- Documentation index: `docs/README.md`
- Conventions: `docs/CONVENTIONS.md`
- Offline artifacts: `docs/operations/offline-artifacts.md`
- Architecture overview: `docs/architecture/system-overview.md`

