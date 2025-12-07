# Bootc ISO Build Status

## Current Status: Interactive Installation & Enhanced Disk Selection ✓

**Started:** November 30, 2025  
**Updated:** December 6, 2025

### Recent Changes (December 6, 2025)
- ✅ Rebuilt ISO with latest bootc-image-builder (Fedora 43 base)
- ✅ Verified installer: `output/bootiso/SCVU.iso` (17G, built Dec 6 19:58)
- ✅ End-to-end build duration: 00:38:19 (image build, OCI save, rootful load, ISO compose)
- ✅ Documentation refresh: added README appendix with build matrix, env flags, offline validation, troubleshooting, and FAQ

### Recent Changes (December 4, 2025)
- ✅ Removed unused Anaconda kickstart file (not compatible with bootc-image-builder)

### Recent Changes (December 3, 2025)
- ✅ Added offline support for OpenShift/Kubernetes tools (oc, kubectl)
- ✅ Added offline support for CodeReady Containers (CRC)
- ✅ Added offline support for draw.io (diagrams.net)
- ✅ Added Podman with rootless support
- ✅ Created unified `fetch_all_offline.sh` script
- ✅ Organized fetch scripts in `fetch-scripts/` subdirectory
- ✅ Added sudo keep-alive to build script (no timeout during long builds)
- ✅ Custom ISO naming support (`--iso-name` flag)

### Multi-Drive Installation Safety
The system provides ways to ensure safe installation to the correct disk:

**Option 1: Standard Installation**
```bash
# Boot normally from GRUB menu
# Installer will automatically detect available disks
# Choose target disk when prompted
```



### Build Process Stages
1. ✅ Sudo validation and keep-alive setup
2. ✅ Optional: Fetch offline packages
3. ✅ Container image build (with offline/online fallback)
4. ✅ Export to OCI archive
5. ✅ Load into rootful podman storage
6. ✅ ISO generation with bootc-image-builder
7. ✅ Optional: ISO rename

### Fetch Offline Packages (Recommended)
```bash
# Fetch all offline packages with one command
./fetch_all_offline.sh

# Individual scripts are in fetch-scripts/ subdirectory
./fetch-scripts/fetch_offline_rpms.sh --all
./fetch-scripts/fetch_drawio.sh
./fetch-scripts/fetch_openshift_tools.sh
./fetch-scripts/fetch_crc.sh
./fetch-scripts/fetch_prismlauncher.sh
```

**Optional:**
- Triton Server container image: `./fetch-scripts/fetch_triton_server.sh` (~8-10 GB)

### Build ISO
```bash
# Build with custom name (sudo requested once, kept alive throughout)
./build_export_iso.sh --iso-name SCVU.iso

# Or with automatic fetch
./build_export_iso.sh --fetch-offline --iso-name SCVU.iso
```

### Monitor Progress
```bash
# Check build progress
tail -f /home/benson/Documents/Bootc_Test/bootc_ostree/output/iso-build.log

# Check output directory
ls -lh /home/benson/Documents/Bootc_Test/bootc_ostree/output/bootiso/
```

### Outputs
- **OCI Archive:** `bootc_ostree/oci-image/scvu-bootc-kde.oci` (size: 15G; built Dec 6 19:46)
- **Installer ISO:** `bootc_ostree/output/bootiso/SCVU.iso` (size: 17G; built Dec 6 19:58)
- **Build Log:** `bootc_ostree/output/iso-build.log`

### System Image Contents
✅ **Desktop Environment:** KDE Plasma (`@kde-desktop-environment @kde-apps`, `sddm`)  
✅ **Development Tools:** gcc, cmake, git, make, fastfetch  
✅ **Python Versions:** 3.9, 3.10, 3.11, 3.12, 3.13 (complete with unified pip packages)  
✅ **Container Runtimes:** Podman (rootless support), Docker Desktop  
✅ **OpenShift/Kubernetes:** oc, kubectl, CRC (offline binaries supported)  
✅ **Applications:** LibreOffice, draw.io, Blender, SQLite Browser  
✅ **VS Code:** Offline VSIX extensions at `/opt/vscode-extensions/`  
✅ **WineHQ:** Stable (offline RPM)  
✅ **Windows Emulation:** Lutris, Prism Launcher v9.4 AppImage (88 MB)  
✅ **Filesystem Support:** NTFS, exFAT, Btrfs, ext4, XFS, F2FS  
✅ **Multimedia:** ffmpeg, vlc, OBS, codec packs (RPM Fusion)  
✅ **Web Browsers:** Firefox, Google Chrome (direct RPM download)  
✅ **NVIDIA:** Driver support (offline preferred, online fallback)  
✅ **Remote Access:** xrdp  
✅ **System Config:** Asia/Singapore timezone, NTP (time.windows.com, time.nist.gov, pool.ntp.org)  
✅ **Network Discovery:** Samba, Avahi (mDNS), wsdd (Windows 10/11 WS-Discovery)

### Offline Package Support
All third-party packages support offline inclusion (current stash: ~20 GB at `image/offline-repo/`):
- **RPMs:** RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop (majority of size)
- **Applications:** draw.io, Prism Launcher AppImage (88 MB)
- **Binaries:** oc, kubectl, CRC, Triton Server container image (optional)
- **Location:** `image/offline-repo/<vendor>/` and `image/disk-selector/`
- **Fallback:** Online installation during build if offline packages not present

### User Accounts (Pre-configured)
- No default user is baked into the image; create your own account during/after install.

### Post-Install Steps (After ISO Boot)
1. Run post-install script: `sudo /usr/local/bin/scvu/scvu-post-install.sh`
   - Installs VS Code extensions per-user
   - Rebuilds NVIDIA initramfs (if hardware present)
   - Enables SDDM, xrdp services
   - Adds current user to docker group
   - Installs cached Python wheels (Python 3.9–3.13) from `/opt/python-wheels/py<ver>` if present
   - Flags: `--no-wheels` to skip, `--wheels-only` to run only wheels, `--py py310 --py py311` to target interpreters

2. (Optional) Install OpenShift/Kubernetes tools:
   - If pre-fetched with `fetch_openshift_tools.sh`: Already installed
   - Otherwise: `sudo /usr/local/bin/scvu/install-openshift-tools.sh`

3. (Optional) Set up CodeReady Containers:
   - If pre-fetched with `fetch_crc.sh`: Already at `/usr/local/bin/crc`
   - Requires internet for OpenShift bundle (~9 GB) on first start
   - See README for fully offline CRC setup

### Disk Space Usage
- **Output directory** (ISO + manifests): ~14 GB (current `SCVU.iso`)
- **OCI archive:** ~15 GB (current `scvu-bootc-kde.oci`)
- **Container image** (rootless & rootful caches): ~28-35 GB (varies by system)
- **Offline packages** (actual current): ~20 GB (NVIDIA + RPM Fusion dominate)
- **Triton Server** (optional): 8-10 GB

**Total Free Space Recommended:**
- **Minimal build** (online fallback, no offline packages): ~70 GB
- **Full build** (all current offline packages, no Triton): ~100-120 GB
- **Complete build** (all packages + Triton): ~110-130 GB

### Next Steps
1. **Verify ISO:** `ls -lh bootc_ostree/output/bootiso/SCVU.iso` (or `install.iso`)
2. **Test in VM:**
   ```bash
   sudo virt-install \
     --name fedora-bootc-test \
     --ram 4096 \
     --disk size=50 \
   --cdrom /home/benson/Documents/Bootc_Test/bootc_ostree/output/bootiso/SCVU.iso \
     --os-variant fedora43
   ```
   - If it errors, ensure `virt-install` and `qemu-kvm` are installed: `sudo dnf -y install virt-install qemu-kvm`.
3. **Burn to USB:**
   ```bash
   sudo dd if=/home/benson/Documents/Bootc_Test/bootc_ostree/output/bootiso/SCVU.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```

### Troubleshooting
- **Build fails:** Check `iso-build.log` for errors
- **ISO not found:** Verify path (`bootc_ostree/output/bootiso/`); use `--iso-name` for custom naming
- **Out of space:** Need at least ~100 GB free for full build with current offline packages
- **Sudo timeout:** Build script now keeps sudo active; password requested once at start
- **Disk selection not working:** Verify the installation is running in interactive mode during boot

---

**Status Summary:**
- ✅ Build pipeline fully functional with multiple offline package support
- ✅ Interactive disk selection implemented and integrated into ISO
- ✅ System configuration complete (timezone, NTP, network discovery)
- ✅ All fetch scripts tested and working (Prism Launcher, OpenShift tools, CRC, draw.io)
- ✅ Multi-drive installation safety measures in place
- ✅ Documentation updated with usage examples

**Ready for:** Production builds, multi-drive installations, air-gapped deployments

**Build Log Location:** `/home/benson/Documents/Bootc_Test/bootc_ostree/output/iso-build.log`  
**Terminal Monitor:** `tail -f` the log file to watch progress
