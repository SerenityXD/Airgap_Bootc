# BOOTC Bare ISO Quick Guide

This image is the bare deployment stage for a two-step workflow:
1. Install bare image (GUI + Podman baseline)
2. Switch to full OCI image using `bootc switch`

## Switch to Full OCI Image

Use one of these transports.

### Option A: OCI archive (offline media)

```bash
sudo bootc switch --transport oci-archive /path/to/bootc-gnome-full.oci
sudo reboot
```

### Option B: Registry image

```bash
sudo bootc switch registry.example.com/bootc-gnome:full
sudo reboot
```

## Validation After Reboot

```bash
bootc status
```

Confirm expected tools are present, then run targeted post-install steps if needed.

## Rollback

If needed, roll back to the previous deployment:

```bash
sudo bootc rollback
sudo reboot
```

## Notes

- If using virt-manager to mount filesystem, ensure that "Shared Memory" is ticked and add a new Filesystem hardware. In the OS, use command `sudo mount -t virtiofs <mount_name> <selected_path>`, where mount_name is the mount name used when creating Filesystem and selected_path is the path where the mount should be located.
- Users created on the bare deployment persist across `bootc switch`.
- Local user data remains; only the booted image deployment changes.
- Keep the full OCI artifact in a stable location before switching.

# When entering the updated OS

## Relavant scipts

All helper scripts support `--help`:

```bash
/usr/local/bin/bootc/bootc-post-install.sh --help
/usr/local/bin/bootc/install-python-wheels.sh --help
/usr/local/bin/bootc/automount-drive.sh --help
/usr/local/bin/bootc/install-js-frameworks.sh
/usr/local/bin/bootc/nvidia-hybrid-diagnostics.sh
```