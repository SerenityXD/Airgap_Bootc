#!/bin/bash
# Wrapper script that runs in initramfs to trigger disk selection

# Check if we're in installation mode
if [ -f /usr/lib/bootc-install ]; then
    /usr/bin/disk-selector-initramfs.sh
fi
