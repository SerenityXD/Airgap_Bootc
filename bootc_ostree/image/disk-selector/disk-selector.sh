#!/bin/bash
# Interactive disk selection menu for bootc installer
# This script runs before the bootc deployment to let users choose target disk

set -e

echo "======================================"
echo "SCVU Bootc Workstation Installer"
echo "======================================"
echo ""
echo "Select target installation disk:"
echo ""

# List available disks
DISKS=()
declare -A DISK_NAMES
declare -A DISK_SIZES

# Find all block devices (skip partitions and loop devices)
i=1
for disk in $(lsblk -d -n -o NAME,SIZE | awk '{print $1}'); do
    size=$(lsblk -d -n -o SIZE "$disk" | head -1)
    DISKS+=("$disk")
    DISK_NAMES["$disk"]="/dev/$disk"
    DISK_SIZES["$disk"]="$size"
    echo "$i) /dev/$disk ($size)"
    ((i++))
done

echo ""

if [ ${#DISKS[@]} -eq 0 ]; then
    echo "Error: No disks found!"
    exit 1
fi

if [ ${#DISKS[@]} -eq 1 ]; then
    echo "Only one disk found. Using /dev/${DISKS[0]}"
    TARGET_DISK="/dev/${DISKS[0]}"
else
    echo ""
    read -p "Enter disk number (1-${#DISKS[@]}): " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#DISKS[@]} ]; then
        echo "Invalid selection"
        exit 1
    fi
    
    idx=$((choice - 1))
    TARGET_DISK="/dev/${DISKS[$idx]}"
fi

echo ""
echo "WARNING: This will wipe the disk!"
echo "Selected disk: $TARGET_DISK (${DISK_SIZES[${TARGET_DISK##*/}]})"
echo ""
read -p "Continue with installation to $TARGET_DISK? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Installation cancelled"
    exit 1
fi

echo ""
echo "Writing bootc image to $TARGET_DISK..."
echo "This may take several minutes..."
echo ""

# Export the selected disk for bootc deployment
export BOOTC_TARGET_DISK="$TARGET_DISK"

# Proceed with bootc deployment
echo "Proceeding with deployment..."

exit 0
