# Troubleshooting

## Build Process Issues

### Missing packages during build
**Symptom:** Build fails with "package not found" errors

**Solution:**
- Ensure offline payloads exist under `bootc_ostree/fedora/image/offline-repo/`.
- Re-run `./bootc_ostree/fedora/fetch_all_offline.sh` on an internet-connected machine.
- Verify the Containerfile's offline fallback logic by checking build logs for "Trying offline-repo" messages.

**Note:** Some packages may require internet access if offline artifacts are missing. Use `--fetch-offline` flag when re-running the build after fetching new artifacts.

### Build fails with "podman command not found"
**Symptom:** Script exits immediately saying podman is not installed

**Solution:**
- Install podman: `sudo dnf install podman` (Fedora) or `brew install podman` (macOS).
- On WSL2, ensure podman daemon is running: `podman system service --socket-activate` or use rootless mode.
- Verify: `podman version`

### Insufficient disk space during build
**Symptom:** Build fails with ENOSPC errors (no space left on device)

**Solution:**
- Ensure at least 70 GB free disk space before building.
- Check available space: `df -h` or `lsblk`.
- Clean up old builds: `make clean-iso` or `make clean-all`.
- If using custom `TMPDIR`: ensure the specified directory has sufficient space.

### Sudo password prompt during build
**Symptom:** Build asks for password repeatedly or times out

**Solution:**
- The build script keeps sudo alive automatically via background refresh.
- If interrupted, run: `sudo -k` to reset sudo session, then restart the build.
- Ensure your user has passwordless sudo for podman operations (or accept password prompt once).

### Container build layer caching issues
**Symptom:** Builds take longer than expected or cache doesn't appear to work

**Solution:**
- Clear podman cache: `podman system prune --all` (warning: removes all unused images/containers).
- Rebuild without cache: `podman build --no-cache ...`.
- Check available image storage: `podman system info | grep graphRoot`.

## Hardware and Installation Issues

### No audio / audio device not detected (Tiger Lake systems)
**Symptom:** No sound output, `aplay -l` shows no cards, or kernel logs contain `sof firmware file is missing`

**Solution:**
1. Confirm the SOF firmware is installed: `rpm -q alsa-sof-firmware`
2. Check PipeWire ALSA bridge: `rpm -q pipewire-alsa wireplumber`
3. Verify the audio service is running: `systemctl --user status pipewire wireplumber`
4. Check detected cards: `aplay -l` and `cat /proc/asound/cards`
5. Unmute master channel if needed: `amixer sset Master unmute && amixer sset Speaker unmute`
6. Test playback: `speaker-test -t wav -c 2 -l 1`

**Note:** The image ships `alsa-sof-firmware`, `alsa-ucm`, `pipewire-alsa`, `wireplumber`, and `alsa-utils` for Tiger Lake SOF DSP support. If audio still fails, check BIOS audio settings (ensure onboard audio is enabled).

### NVIDIA lock/sleep screen — missing icons after wake
**Symptom:** OS icons are missing or the lock screen appears blank after resuming from suspend/sleep

**Root cause:** NVIDIA VRAM contents are not preserved across suspend unless configured explicitly.

**Solution:**
The image ships `/etc/modprobe.d/nvidia-pm.conf` with `NVreg_PreserveVideoMemoryAllocations=1`, installs `xorg-x11-drv-nvidia-power`, and enables the NVIDIA suspend/resume helper units when available. Verify these are in place:
```bash
cat /etc/modprobe.d/nvidia-pm.conf
cat /etc/modprobe.d/blacklist-nouveau.conf
rpm -q xorg-x11-drv-nvidia-power
systemctl status nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service
lsinitrd /boot/initramfs-$(uname -r).img | grep nouveau  # should be empty
lsmod | grep nouveau                                      # should be empty
```
If the issue persists after verifying the above:
- Ensure `nvidia_drm.modeset=1` is on the kernel command line: `cat /proc/cmdline | grep nvidia`
- Check for pending GNOME compositor updates: `sudo bootc upgrade && reboot`
- As a fallback, switch GNOME to run on Xorg: at the GDM login screen, click the gear icon and select "GNOME on Xorg"

### External monitor not detected or stays black (laptops with NVIDIA)
**Symptom:** HDMI/DP monitor is connected but not detected, or an external screen stays black while the internal panel works

**Root cause:** On some hybrid-laptop paths (integrated GPU primary), external ports are still routed through NVIDIA and DRM handoff is unstable unless both KMS and fbdev handoff are explicitly enabled.

For a full validation flow (including D3cold checks and `nvidia-smi` in hybrid mode), use the dedicated checklist:
- `docs/operations/nvidia-hybrid-checklist.md`

**Solution:**
Verify NVIDIA DRM options and reconnect the monitor after reboot:
```bash
cat /etc/modprobe.d/nvidia-pm.conf
cat /proc/cmdline | grep -E 'nvidia|nouveau'
lsmod | grep nvidia_drm
sudo dmesg | grep -E 'nvidia|drm|edid' | tail -n 80
```
Expected in `/etc/modprobe.d/nvidia-pm.conf`:
- `options nvidia_drm modeset=1`
- `options nvidia_drm fbdev=1`

If detection still fails:
1. Disable Secure Boot and use Discrete GPU mode in firmware when available.
2. Ensure hybrid helpers are enabled: `systemctl status switcheroo-control.service nvidia-powerd.service`
3. Test GNOME on Xorg from the GDM gear menu.
4. Check cable/dock path directly on the laptop (bypass dock) to rule out USB-C dock firmware issues.

### `bootc-fetch-apply-updates` timer or service fails
**Symptom:** `bootc-fetch-apply-updates.service` shows failed, or automatic updates never run

**Root cause:** The timer may not be enabled on the deployed system, or the installed system may not have a valid update source/auth configuration for the image registry.

**Solution:**
Verify the timer is enabled and inspect the last service run:
```bash
systemctl status bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service
systemctl list-timers bootc-fetch-apply-updates.timer
journalctl -u bootc-fetch-apply-updates.service -b --no-pager
bootc status
sudo bootc upgrade --check
```
If the service reports registry/auth failures:
- Confirm the installed system has the expected image reference: `sudo bootc status --json | jq '.spec.image'`
- If the registry requires credentials, ensure `/etc/ostree/auth.json` contains valid auth for the target registry
- Re-enable the timer if needed: `sudo systemctl enable --now bootc-fetch-apply-updates.timer`

### NVIDIA driver fails to load after installation
**Symptom:** `nvidia-smi` returns "command not found" or "NVIDIA driver not loaded"

**Solution:**
1. Disable Secure Boot in BIOS.
2. Set BIOS graphics mode to "Discrete GPU" when available.
3. Reboot and verify: `nvidia-smi`.
4. If still failing, check kernel modules: `sudo dmesg | grep nvidia`.
5. Manually rebuild modules: `sudo dkms autoinstall` (if akmods failed during image build).

**Note:** NVIDIA kernel modules are pre-built at image creation time. If your target system has a different kernel version, modules may fail to load.

### GPU memory not available despite driver installed
**Symptom:** `nvidia-smi` shows driver but GPU has 0MB available

**Solution:**
- Check BIOS secure boot status and GPU assignment.
- Ensure no virtual machine pass-through conflicts.
- Verify GPU is recognized: `lspci | grep -i nvidia`.
- Reinstall drivers: `sudo dnf reinstall nvidia-driver-${VERSION}`.

### System boots into black screen after installation
**Symptom:** GRUB boots but GNOME doesn't start

**Solution:**
1. Check logs: `journalctl -xn` in a TTY (Ctrl+Alt+F2).
2. Verify XOrg is running: `systemctl status gdm`.
3. If GDM fails to start, try: `sudo systemctl restart gdm` or `sudo systemctl start gdm`.
4. Check graphics driver status: `glxinfo | grep "direct rendering"`.
5. If using NVIDIA, verify `nvidia-drm` module is loaded: `lsmod | grep nvidia`.

## Network and Package Issues

### Network drive (Samba share) authentication fails
**Symptom:** Connecting to the BOOTC machine's Samba share from Windows/macOS fails with "wrong username or password" even when using the correct BOOTC user credentials

**Root cause:** Samba maintains its own password database separate from Linux login passwords. A user account created with `bootc-post-install.sh` automatically registers in the Samba database, but users created by other means may not be registered.

The special Samba `[homes]` share should be accessed through the username-specific path, not as a literal `homes` folder. Use `\\hostname\\username` on Windows or `smb://hostname/username` in GNOME Files.

**Solution:**
```bash
# Register an existing Linux user in the Samba database
sudo smbpasswd -a <username>
# Enter the same password as the Linux login when prompted

# Verify the user is registered
sudo pdbedit -L | grep <username>

# Test authentication from the BOOTC machine itself
smbclient -L //localhost -U <username>

# Test the per-user home share directly
smbclient //localhost/<username> -U <username>
```

**Note:** The `bootc-post-install.sh` script registers newly created users automatically and now offers to register the invoking sudo/admin user as well. For future password changes, run `sudo smbpasswd <username>` in addition to `passwd` so both databases stay in sync.

### RPM Fusion and WineHQ conflicts
**Symptom:** Install fails with "conflicting packages" between RPM Fusion and system repos

**Solution:**
- RPM Fusion's `ffmpeg-full` conflicts with `ffmpeg-free` from Fedora.
- WineHQ packages may conflict with `wine-desktop` from Fedora repos.
- The build process tries to handle these, but if issues occur:
  - Remove conflicting package: `sudo dnf remove ffmpeg-free wine-desktop`.
  - Reinstall WineHQ: `sudo dnf install --repo=winehq wine-stable`.

### Offline build fails with "repo not found"
**Symptom:** Build fails during container build when trying to access online repos

**Solution:**
- Ensure offline artifacts are present before building (run `./bootc_ostree/fedora/fetch_all_offline.sh`).
- Verify artifact directories exist and are readable: `ls -la bootc_ostree/fedora/image/offline-repo/`.
- Check Containerfile logs for "COPY offline-repo" commands.
- For reproducible offline builds, always run fetch scripts on internet-connected machine first.

### Docker Desktop fails to start after installation
**Symptom:** Docker Desktop .AppImage or systemd service doesn't start

**Solution:**
1. Check if installed: `which docker-desktop` or `systemctl --user status docker-desktop`.
2. Try manual start: `systemctl --user start docker-desktop`.
3. Check logs: `journalctl --user -xe`.
4. Ensure Docker Desktop is available in offline-repo before build.
5. If `.AppImage`: make executable: `chmod +x ~/.local/bin/docker-desktop` and run directly.

## Post-Install Script Issues

### `bootc-post-install.sh` fails to create user
**Symptom:** User creation step exits with permission denied or user already exists

**Solution:**
- If user already exists: use a different username with `--bootc-user <newname>`.
- Check user creation manually: `getent passwd bootc`.
- Rerun with explicit password: `sudo /usr/local/bin/bootc/bootc-post-install.sh --bootc-user alice --bootc-password secret`.
- Verify `/home` directory exists and is writable: `ls -ld /home`.

### Python wheels installation fails
**Symptom:** `install-python-wheels.sh` reports missing packages

**Solution:**
- Verify wheel cache exists: `ls /opt/python-wheels/py*/` (should have .whl files).
- Try installing specific version: `sudo /usr/local/bin/bootc/install-python-wheels.sh --py py310`.
- Check available wheels: `python3.10 -m pip show <package>`.
- If wheels are missing entirely, they may not have been cached at image build time.

### VS Code extensions fail to install
**Symptom:** `bootc-post-install.sh` reports VSIX installation errors

**Solution:**
- Verify .vsix files exist: `ls bootc_ostree/fedora/image/offline-repo/vscode-extensions/*.vsix`.
- Check VS Code is installed: `code --version`.
- Try installing extensions manually: `code --install-extension /path/to/extension.vsix`.
- Check for conflicting extensions: `code --list-extensions`.
- Validate .vsix file integrity: `unzip -t extension.vsix 2>&1 | head -5`.

## Fetch Script Issues

### Fetch script downloads incomplete or corrupted file
**Symptom:** Offline artifact is present but size seems wrong or download was interrupted

**Solution:**
- Remove and refetch: `rm bootc_ostree/fedora/image/offline-repo/<vendor>/*` then re-run fetch script.
- Use `--skip-existing` flag cautiously; consider removing suspect files first.
- Check file integrity: `md5sum <file>` and compare if vendor provides checksums.
- Verify network connection during fetch and retry if interrupted.
- For large files, use `curl --continue-at -` to resume: `curl --continue-at - <url> -o <file>`.

### `fetch_vscode.sh` fails with "no package matches"
**Symptom:** VS Code RPM download skipped, saying "no package matches the repository"

**Solution:**
- Microsoft's VS Code repo may be down or unreachable.
- Verify network: `ping -c 2 packages.microsoft.com`.
- Check Fedora version: should match Containerfile base image (usually 43).
- Manually download from https://code.visualstudio.com/Download and place in `offline-repo/vscode/`.
- Verify: `rpm -qip code-*.rpm`.

### `fetch_k3s_images.sh` takes extremely long
**Symptom:** k3s image archive download stalls or appears to hang

**Solution:**
- k3s offline images archive can be 1+ GB. Check progress: `ps aux | grep curl`.
- For metered connections, consider running fetch in `tmux` or `screen`.
- If download stalls, Ctrl+C and manually resume (see "Fetch script downloads incomplete" above).
- Verify disk space: `df -h` (need ~10GB for k3s + other artifacts).

## Logs and Diagnostics

### Where to find build logs
- Main build logs: `bootc_ostree/fedora/build-scripts/logs/build-YYYYMMDD-HHMMSS.log`.
- Access during build: logs are tee'd to stdout; use `tee` to save output.
- Podman build logs are captured in the main build log file.

### How to enable verbose logging
- Set debug mode: `bash -x ./bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive` (verbose shell tracing).
- Check environment: echo `$ISO_TYPE`, `$CONFIG_FILE`, etc. to verify parameters.
- Inspect Containerfile build via Podman: `podman build --progress=plain ...` for step-by-step output.

### Interpreting common error messages
- **"mount: operation not permitted"**: Usually a permission issue; ensure running inside a privileged container or with `--privileged` flag.
- **"dnf: command not found"**: Podman build context doesn't have dnf; verify base image is Fedora-based.
- **"COPY failed"**: File/directory doesn't exist during Containerfile build; check offline-repo paths.
- **"grub-install: not found"**: ISO creation context missing bootloader tools; check bootc-image-builder image.
