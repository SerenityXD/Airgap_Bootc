#!/bin/bash
# Dracut module to run disk selector before bootc installation
# This runs in the initramfs environment

check() {
    # Only run during installation (when bootc installer is present)
    return 0
}

depends() {
    echo "bash"
    return 0
}

install() {
    # Install the disk selector script into initramfs
    inst_simple "$moddir/disk-selector-initramfs.sh" "/usr/bin/disk-selector-initramfs.sh"
    inst_hook pre-mount 50 "$moddir/run-disk-selector.sh"
}
