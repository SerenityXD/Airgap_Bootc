# NVIDIA Hybrid Mode Checklist (D3cold and nvidia-smi)

Use this checklist on installed systems where laptops run in hybrid graphics mode (iGPU primary) and the dGPU may remain in D3cold.

## Goal
- Confirm whether the issue is policy/service level (recoverable by helpers and config)
- Or platform/firmware level (requires BIOS/ACPI/driver constraints to be addressed)

## Automated one-command diagnostics
Run:

```bash
sudo /usr/local/bin/bootc/nvidia-hybrid-diagnostics.sh
```

Optional strict mode (non-zero exit when failures are detected):

```bash
sudo /usr/local/bin/bootc/nvidia-hybrid-diagnostics.sh --strict
```

Integrated post-install usage:

```bash
sudo /usr/local/bin/bootc/bootc-post-install.sh --run-nvidia-diagnostics
# or
sudo /usr/local/bin/bootc/bootc-post-install.sh --only-steps nvidia-diagnostics
```

## 1. Baseline package checks
Run:

```bash
rpm -q \
  akmod-nvidia \
  xorg-x11-drv-nvidia \
  xorg-x11-drv-nvidia-cuda \
  xorg-x11-drv-nvidia-power \
  nvidia-persistenced \
  switcheroo-control
```

Pass criteria:
- All packages are installed

## 2. Module and blacklist checks
Run:

```bash
cat /etc/modprobe.d/nvidia-pm.conf
cat /etc/modprobe.d/blacklist-nouveau.conf
cat /etc/modprobe.d/blacklist-nouveau-extra.conf
lsmod | grep -E 'nvidia|nvidia_drm|nouveau'
```

Pass criteria:
- `nvidia-pm.conf` contains:
  - `options nvidia_drm modeset=1`
  - `options nvidia_drm fbdev=1`
- `nouveau` is not loaded

## 3. Hybrid helper services
Run:

```bash
systemctl status \
  switcheroo-control.service \
  nvidia-powerd.service \
  nvidia-persistenced.service \
  nvidia-suspend.service \
  nvidia-resume.service \
  nvidia-hibernate.service
```

Pass criteria:
- `switcheroo-control.service` active
- `nvidia-persistenced.service` active
- `nvidia-powerd.service` active on supported hardware
- suspend/resume/hibernate NVIDIA units enabled when present

## 4. Kernel module build and initramfs
Run:

```bash
sudo akmods --force
sudo dracut -f --regenerate-all
sudo reboot
```

After reboot:

```bash
lsmod | grep -E 'nvidia|nvidia_drm'
nvidia-smi
```

Pass criteria:
- NVIDIA modules loaded
- `nvidia-smi` returns GPU details

## 5. D3cold vs D0 check
Identify the NVIDIA PCI device and inspect power state:

```bash
lspci -nn | grep -i nvidia
# Replace 0000:01:00.0 with your NVIDIA device
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null || true
```

Interpretation:
- `active` usually indicates D0 or usable state
- `suspended` with persistent D3cold behavior under load indicates power-gating not exiting

## 6. Trigger dGPU demand in hybrid mode
Run a workload with explicit NVIDIA offload:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo -B
nvidia-smi
```

Pass criteria:
- Offload command succeeds
- `nvidia-smi` reflects active device/processes

## 7. Secure Boot and firmware checks
Run:

```bash
mokutil --sb-state
sudo dmesg | grep -Ei 'nvidia|nouveau|secure boot|module|acpi' | tail -n 200
```

Pass criteria:
- Secure Boot does not block NVIDIA module load
- No recurring ACPI/firmware errors preventing dGPU power transition

## 8. External display path checks (hybrid laptops)
Run:

```bash
sudo dmesg | grep -Ei 'drm|edid|nvidia' | tail -n 120
xrandr --listproviders 2>/dev/null || true
```

Pass criteria:
- No repeated EDID/link-training failures
- Providers and outputs appear consistently after hotplug

## 9. Recovery decision
- If helpers are inactive or config is missing: fix services/config and retest
- If modules fail to load: resolve Secure Boot, initramfs, or package/kernel mismatch
- If dGPU remains stuck in D3cold despite correct stack: treat as platform-level firmware/ACPI limitation and test BIOS options

## 10. BIOS settings to test
- Disable Secure Boot
- If available, test:
  - Hybrid mode (target mode)
  - Discrete mode (comparison baseline)
- Update laptop BIOS/EC firmware to latest vendor release

## Quick PASS criteria
- NVIDIA modules loaded, `nouveau` absent
- `switcheroo-control` and `nvidia-persistenced` active
- `nvidia-powerd` active on supported systems
- `nvidia-smi` works in hybrid mode
- External monitor hotplug stable without black screen
