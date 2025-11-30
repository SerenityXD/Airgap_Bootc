# Bootc ISO Build Status

## Current Status: ISO Export Complete ✓

**Started:** November 30, 2025  
**Updated:** November 30, 2025 at 22:17

### Build Process Stages
1. ✅ Container image built successfully (52.4 GB)
2. ✅ Image loaded into rootful podman storage
3. ✅ ISO generation completed
4. ✅ OSTree commit creation completed
5. ✅ Installer ISO composition completed

### Monitor Progress
```bash
# Check build progress
tail -f /home/benson/Documents/Bootc_Test/bootc_ostree/output/iso-build.log

# Check output directory
ls -lh /home/benson/Documents/Bootc_Test/bootc_ostree/output/bootiso/
```

### Outputs
- **OCI Archive:** `bootc_ostree/oci-image/scvu-bootc-kde.oci`
- **Installer ISO:** `bootc_ostree/output/bootiso/install.iso` (size: 13G; built Nov 30 22:17)
- **Build Log:** `bootc_ostree/output/iso-build.log`

### System Image Contents
✅ **Desktop Environment:** KDE Plasma (`@kde-desktop-environment @kde-apps`, `sddm`)  
✅ **Development Tools:** gcc, cmake, git, make (complete)  
✅ **Python Versions:** 3.9, 3.10, 3.11, 3.12, 3.13 (complete)  
✅ **Machine Learning:** Folder kept at `/opt/ml-wheels` (no wheels embedded)  
✅ **Applications:** LibreOffice, Blender, SQLite Browser (complete)  
✅ **VS Code Extensions:** Python (8.5M), Jupyter (6.8M) at `/opt/vscode-extensions/`  
✅ **Docker:** Docker Desktop RPM at `/opt/docker-desktop/`  
✅ **Filesystem Support:** NTFS, exFAT, Btrfs, XFS (complete)  
✅ **Multimedia:** ffmpeg, vlc, codecs (complete)

### User Accounts (Pre-configured)
- **Username:** IAC / AIBUser  
- **Password:** fedora  
- **Groups:** wheel, docker

### Post-Install Steps (After ISO Boot)
1. Run post-install script: `sudo /usr/local/bin/scvu-post-install.sh`
2. This will:
   - Install VS Code extensions per-user
   - Rebuild NVIDIA initramfs (if hardware present)
   - Enable Docker and xrdp services
   - Add current user to docker group

### Disk Space Usage
- Output directory (ISO + manifests): 13 GB
- OCI archive: 12 GB
- Container image (rootless & rootful): 27.6 GB each

### Next Steps
1. **Verify ISO:** `ls -lh bootc_ostree/output/bootiso/install.iso`
2. **Test in VM:**
   ```bash
   sudo virt-install \
     --name fedora-bootc-test \
     --ram 4096 \
     --disk size=50 \
   --cdrom /home/benson/Documents/Bootc_Test/bootc_ostree/output/bootiso/install.iso \
     --os-variant fedora43
   ```
   - If it errors, ensure `virt-install` and `qemu-kvm` are installed: `sudo dnf -y install virt-install qemu-kvm`.
3. **Burn to USB:**
   ```bash
   sudo dd if=/home/benson/Documents/Bootc_Test/bootc_ostree/output/bootiso/install.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```

### Troubleshooting
- **Build fails:** Check `iso-build.log` for errors
- **ISO not found:** Verify path. Recent builds write to `bootc_ostree/output/bootiso/install.iso` (single directory); some earlier runs used `bootc_ostree/output/bootiso/bootiso/install.iso`.
- **Out of space:** Need at least 10 GB free for ISO build

---
**Build Log Location:** `/home/benson/Documents/Bootc_Test/bootc_ostree/output/iso-build.log`  
**Terminal Monitor:** `tail -f` the log file to watch progress
