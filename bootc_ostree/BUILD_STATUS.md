# Bootc ISO Build Status

## Current Status: Updated Build System ✓

**Started:** November 30, 2025  
**Updated:** December 3, 2025

### Recent Changes (December 3, 2025)
- ✅ Added offline support for OpenShift/Kubernetes tools (oc, kubectl)
- ✅ Added offline support for CodeReady Containers (CRC)
- ✅ Added offline support for draw.io (diagrams.net)
- ✅ Added Podman with rootless support
- ✅ Created unified `fetch_all_offline.sh` script
- ✅ Organized fetch scripts in `fetch-scripts/` subdirectory
- ✅ Added sudo keep-alive to build script (no timeout during long builds)
- ✅ Custom ISO naming support (`--iso-name` flag)

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
```

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
- **OCI Archive:** `bootc_ostree/oci-image/scvu-bootc-kde.oci`
- **Installer ISO:** `bootc_ostree/output/bootiso/install.iso` (size: 13G; built Nov 30 23:35)
- **Build Log:** `bootc_ostree/output/iso-build.log`

### System Image Contents
✅ **Desktop Environment:** KDE Plasma (`@kde-desktop-environment @kde-apps`, `sddm`)  
✅ **Development Tools:** gcc, cmake, git, make, fastfetch  
✅ **Python Versions:** 3.9, 3.10, 3.11, 3.12, 3.13 (complete)  
✅ **Container Runtimes:** Podman (rootless support), Docker Desktop  
✅ **OpenShift/Kubernetes:** oc, kubectl, CRC (offline binaries supported)  
✅ **Applications:** LibreOffice, draw.io, Blender, SQLite Browser  
✅ **VS Code:** Offline VSIX extensions at `/opt/vscode-extensions/`  
✅ **WineHQ:** Stable (offline RPM)  
✅ **Filesystem Support:** NTFS, exFAT, Btrfs, ext4, XFS, F2FS  
✅ **Multimedia:** ffmpeg, vlc, OBS, codec packs (RPM Fusion)  
✅ **NVIDIA:** Driver support (offline preferred, online fallback)  
✅ **Remote Access:** xrdp

### Offline Package Support
All third-party packages support offline inclusion:
- **RPMs:** RPM Fusion, NVIDIA, VS Code, WineHQ, Docker Desktop
- **Binaries:** draw.io, oc, kubectl, CRC
- **Location:** `image/offline-repo/<vendor>/`
- **Fallback:** Online installation during build if offline packages not present

### User Accounts (Pre-configured)
- **Username:** IAC / AIBUser  
- **Password:** fedora  
- **Groups:** wheel, docker

### Post-Install Steps (After ISO Boot)
1. Run post-install script: `sudo /usr/local/bin/scvu-post-install.sh`
   - Installs VS Code extensions per-user
   - Rebuilds NVIDIA initramfs (if hardware present)
   - Enables SDDM, xrdp services
   - Adds current user to docker group

2. (Optional) Install OpenShift/Kubernetes tools:
   - If pre-fetched with `fetch_openshift_tools.sh`: Already installed
   - Otherwise: `sudo /usr/local/bin/install-openshift-tools.sh`

3. (Optional) Set up CodeReady Containers:
   - If pre-fetched with `fetch_crc.sh`: Already at `/usr/local/bin/crc`
   - Requires internet for OpenShift bundle (~9 GB) on first start
   - See README for fully offline CRC setup

### Disk Space Usage
- Output directory (ISO + manifests): ~13 GB
- OCI archive: ~12 GB
- Container image (rootless & rootful): ~28 GB
- Offline packages (if all fetched): ~2-3 GB
  - OpenShift tools (oc/kubectl): 370 MB
  - CRC binary: 95 MB
  - draw.io: 101 MB
  - RPMs vary by selection
- **Total recommended free space:** 60-100 GB

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
- **Out of space:** Need at least 60 GB free for full build with offline packages
- **Sudo timeout:** Build script now keeps sudo active; password requested once at start

---
**Build Log Location:** `/home/benson/Documents/Bootc_Test/bootc_ostree/output/iso-build.log`  
**Terminal Monitor:** `tail -f` the log file to watch progress
