#!/usr/bin/env bash
set -euo pipefail

ISO=${1:-}
if [ -z "$ISO" ]; then
  echo "Usage: $0 /path/to/installer.iso" >&2
  exit 2
fi

if [ ! -f "$ISO" ]; then
  echo "ISO not found: $ISO" >&2
  exit 3
fi

# Check the ISO contents for common kernel/initrd paths livemedia-creator looks for
echo "Inspecting ISO: $ISO"
if ! command -v bsdtar >/dev/null 2>&1; then
  echo "bsdtar is required to probe ISO contents. Install with: sudo dnf install -y bsdtar" >&2
  exit 4
fi

paths=( "/isolinux/vmlinuz" "/isolinux/initrd.img" "/images/pxeboot/vmlinuz" "/images/pxeboot/initrd.img" "/images/kernel.img" "/images/initrd.img" )
found=0
for p in "${paths[@]}"; do
  if bsdtar -tf "$ISO" "$p" >/dev/null 2>&1; then
    echo "Found kernel/initrd path in ISO: $p"
    found=1
  fi
done

if [ $found -eq 0 ]; then
  echo "No installer kernel/initrd paths found in ISO. This ISO is probably a 'live' image not suitable for livemedia-creator virt-install."
  echo "Options: use an installer ISO (Anaconda installer) for your Fedora version, or run livemedia-creator with --image-repo pointing at the release's Everything/os/ tree."
  exit 1
fi

echo "OK — this ISO appears to contain installer kernel/initrd in one of the expected paths."
exit 0
