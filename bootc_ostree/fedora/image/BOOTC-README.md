# Bootc Workstation — Welcome

This system is a **Fedora-bootc** immutable OS image pre-loaded with a curated set of developer,
data-science, multimedia, and emulation tools — ready to use in air-gapped (offline) environments.

---

## What's Included

### Desktop & Browsers
- **GNOME** desktop environment with GDM display manager
- **GNOME Connections** remote desktop client
- **Firefox** and **Google Chrome** web browsers
- **LibreOffice** full office suite
- **draw.io** diagram editor

### Development Tools
- **Visual Studio Code** — launch from the application menu or run `code`
- **Git**, **GCC / G++**, **CMake**, **Make**, **Autoconf / Automake**
- **Node.js**, **npm**, **yarn** — plus pre-installed global JS frameworks:
  `create-react-app`, Vue CLI, Angular CLI, `create-next-app`, Vite, Webpack,
  TypeScript, Jest, ESLint, Prettier, pnpm
- **Python 3.11 – 3.13** — each with pip, plus common packages:
  NumPy, SciPy, Pandas, Matplotlib, scikit-learn, Jupyter/notebook, OpenCV, Seaborn

### Containers & Kubernetes
- **Docker Desktop** — full Docker engine + Compose + Buildx
- **Podman** — rootless container runtime
- **kubectl** and **oc** (OpenShift CLI) — if provided in the offline repo
- **k3s** binary and systemd services are preconfigured for offline-first startup

### Data Science & ML
- Pre-downloaded Python wheels in `/opt/python-wheels/<pyXY>/` for offline pip installs
  (NumPy, SciPy, Pandas, Matplotlib, scikit-learn, Tritonclient, …)
- **NVIDIA GPU drivers** (akmod-nvidia + CUDA libs) — auto-loaded if an NVIDIA GPU is present
- Hybrid graphics helpers are enabled when available (`switcheroo-control`, `nvidia-powerd`)
- **NVIDIA Triton Inference Server** client libraries are included; server image tarballs are optional build artifacts

### Geospatial & Scientific
- **QGIS** with Python bindings (`python3-qgis`)
- HDF5, NetCDF, GDAL, PROJ, GEOS libraries

### Multimedia
- **OBS Studio** screen/webcam recording and streaming
- **VLC** media player
- **FFmpeg**, x264, x265 codecs
- **Blender** 3D creation suite

### Emulation & Compatibility
- **Wine** (WineHQ stable) — run Windows applications
- **Lutris** — game launcher and compatibility manager
- **portablemc** plus staged **rations** data — offline Minecraft-compatible launcher workflow
- `minecraft` wrapper command runs portablemc with `/opt/rations` as the main directory

### Networking & File Sharing
- **Samba** (SMB/CIFS) — visible to Windows machines on the local network
- **Avahi** mDNS / Zeroconf
- **wsdd** Web Services Discovery daemon (makes the machine appear in Windows Network)
- XRDP — Remote Desktop Protocol server (connect with any RDP client)

### Lightweight Kubernetes (k3s)
- `k3s` binary is staged in `/usr/local/bin/k3s` when offline artifact is provided
- Air-gap image archives are staged in `/usr/share/k3s/` when provided
- `k3s.service`, kubeconfig distribution, and route setup services are enabled by default

---

## First Steps After Boot

### 1 — Run the Post-Install Script

A setup script is included that creates your user, installs VS Code extensions, configures
services, and installs Python wheels.  Run it once as root after first login:

```bash
sudo /usr/local/bin/bootc/bootc-post-install.sh \
     --bootc-user <yourname> \
     --bootc-password <password>
```

Full options:

```
sudo /usr/local/bin/bootc/bootc-post-install.sh --help
```

NVIDIA-related options:

```bash
# Run NVIDIA hybrid diagnostics after normal setup
sudo /usr/local/bin/bootc/bootc-post-install.sh --run-nvidia-diagnostics

# Run only the diagnostics step
sudo /usr/local/bin/bootc/bootc-post-install.sh --only-steps nvidia-diagnostics
```

### 2 — Install Python Wheels for a Specific Version

Pre-downloaded wheels live in `/opt/python-wheels/pyXY/`.  To install them into a venv or
system-wide for Python 3.11 for example:

```bash
sudo /usr/local/bin/bootc/install-python-wheels.sh --py py311
```

### 3 — Install VS Code Extensions (manual / extra users)

Extensions stored in `/opt/vscode-extensions/` are installed per-user by the post-install
script.  To install them manually for the current user:

```bash
for vsix in /opt/vscode-extensions/*.vsix; do
    code --install-extension "$vsix" --force
done
```

### 4 — Load the Triton Inference Server Image

If your image build included Triton archives, load them with:

```bash
podman load -i /usr/share/triton/tritonserver-*.tar
```

If no files match that path, Triton server archives were not bundled in this build.

### 5 — Set Up k3s in Air-Gap Mode

`k3s` is preconfigured and enabled in this image. Check status first:

```bash
systemctl status k3s --no-pager
```

Staged air-gap archives in `/usr/share/k3s/` are copied into
`/var/lib/rancher/k3s/agent/images/` automatically by the pre-start helper.

If you need a manual copy:

```bash
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo cp /usr/share/k3s/k3s-airgap-images-amd64.tar.zst \
        /var/lib/rancher/k3s/agent/images/
```

Useful checks:

```bash
sudo journalctl -u k3s -b --no-pager | tail -n 80
kubectl get nodes
```

### 6 — Mount an Additional Hard Drive

```bash
/usr/local/bin/bootc/automount-drive.sh /dev/sdb1 /mnt/data
```

### 7 — Run NVIDIA Hybrid Diagnostics (optional)

Use this on laptops in hybrid graphics mode (especially if external displays are not detected
or remain black):

```bash
sudo /usr/local/bin/bootc/nvidia-hybrid-diagnostics.sh
```

Strict mode returns non-zero if failures are detected:

```bash
sudo /usr/local/bin/bootc/nvidia-hybrid-diagnostics.sh --strict
```

---

## Useful Locations

| Path | Contents |
|---|---|
| `/usr/local/bin/bootc/` | Helper scripts and this README |
| `/opt/python-wheels/` | Pre-downloaded Python wheels (per version) |
| `/opt/vscode-extensions/` | Offline VS Code VSIX extensions |
| `/opt/npm-packages/` | Offline npm tarballs |
| `/opt/rations/` | Staged portablemc/rations data (when included) |
| `/usr/local/bin/k3s` | k3s binary (when bundled in build artifacts) |
| `/usr/share/k3s/` | k3s air-gap image archives |
| `/usr/share/triton/` | Optional Triton Server archives (if bundled) |
| `/etc/rancher/k3s/config.yaml` | k3s server configuration |
| `/var/lib/rancher/k3s/agent/images/` | Runtime air-gap image location for k3s |

---

## System Update

This is a **bootc / OSTree** immutable system.  Do **not** use `dnf` to permanently install
packages — changes will be lost on reboot.  To apply image updates:

```bash
# Pull the latest image and stage for next boot
sudo bootc upgrade

# Reboot to activate the new image
sudo reboot
```

To roll back to the previous image:

```bash
sudo bootc rollback
sudo reboot
```

---

## Remote Desktop

XRDP is enabled by default.  Connect from any RDP client (e.g. Windows Remote Desktop,
Remmina) using:

- **Host:** `<machine-ip>:3389`
- **Username / Password:** your local user credentials

---

## Windows Network Discovery

The machine is configured to be visible in the Windows "Network" browser via Samba, Avahi,
and wsdd.  No manual setup is required.  To share a folder, right-click it in Dolphin and
choose "Properties → Share".

---

## Getting Help

All helper scripts support `--help`:

```bash
/usr/local/bin/bootc/bootc-post-install.sh --help
/usr/local/bin/bootc/install-python-wheels.sh --help
/usr/local/bin/bootc/automount-drive.sh --help
/usr/local/bin/bootc/install-js-frameworks.sh
/usr/local/bin/bootc/nvidia-hybrid-diagnostics.sh
```
