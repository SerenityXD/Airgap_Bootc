#!/bin/bash
# Interactive disk selection for bootc installation - runs in initramfs
set -e

echo "======================================"
echo "SCVU Bootc Workstation Installer"
echo "======================================"
echo ""
echo "Detecting available disks..."
echo ""

# Get excluded disks from kernel command line
EXCLUDED_DISKS=()
for param in $(cat /proc/cmdline); do
    if [[ "$param" =~ ^rd\.disk\.exclude=(.+)$ ]]; then
        excluded="${BASH_REMATCH[1]}"
        # Remove /dev/ prefix if present
        excluded="${excluded#/dev/}"
        EXCLUDED_DISKS+=("$excluded")
    fi
done

# List available disks
DISKS=()
declare -A DISK_SIZES

i=1
while read -r line; do
    disk=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    
    # Skip loop devices, ram disks, partitions, and CD/DVD drives
    if [[ "$disk" =~ ^(loop|ram|sr|dm-) ]] || [[ "$disk" =~ [0-9]$ ]]; then
        continue
    fi
    
    # Skip excluded disks
    is_excluded=0
    for excluded in "${EXCLUDED_DISKS[@]}"; do
        if [ "$disk" = "$excluded" ]; then
            is_excluded=1
            echo "  (Skipping /dev/$disk - excluded by rd.disk.exclude)"
            break
        fi
    done
    
    if [ $is_excluded -eq 1 ]; then
        continue
    fi
    
    DISKS+=("$disk")
    DISK_SIZES["$disk"]="$size"
    echo "$i) /dev/$disk ($size)"
    ((i++))
done < <(lsblk -d -n -o NAME,SIZE 2>/dev/null)

echo ""

if [ ${#DISKS[@]} -eq 0 ]; then
    echo "Error: No suitable disks found!"
    if [ ${#EXCLUDED_DISKS[@]} -gt 0 ]; then
        echo "Excluded disks: ${EXCLUDED_DISKS[*]}"
    fi
    echo "Press Enter to drop to emergency shell..."
    read
    exit 1
fi

# If only one disk, ask for confirmation
if [ ${#DISKS[@]} -eq 1 ]; then
    echo "Only one disk found: /dev/${DISKS[0]} (${DISK_SIZES[${DISKS[0]}]})"
    echo ""
    echo "WARNING: All data on this disk will be erased!"
    echo -n "Type 'yes' to proceed with installation: "
    read confirm
    
    if [ "$confirm" = "yes" ]; then
        TARGET_DISK="/dev/${DISKS[0]}"
    else
        echo "Installation cancelled."
        exit 1
    fi
else
    # Multiple disks - let user choose
    while true; do
        echo -n "Select disk number (1-${#DISKS[@]}): "
        read choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#DISKS[@]}" ]; then
            idx=$((choice - 1))
            selected_disk="${DISKS[$idx]}"
            TARGET_DISK="/dev/$selected_disk"
            
            echo ""
            echo "You selected: $TARGET_DISK (${DISK_SIZES[$selected_disk]})"
            echo ""
            echo "WARNING: All data on $TARGET_DISK will be ERASED!"
            echo -n "Type 'yes' to confirm: "
            read confirm
            
            if [ "$confirm" = "yes" ]; then
                break
            else
                echo ""
                echo "Selection cancelled. Choose again or press Ctrl+C to exit."
                echo ""
            fi
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

echo ""
echo "Selected disk: $TARGET_DISK"
echo "Proceeding with bootc installation..."
echo ""

# Export for bootc installer
export BOOTC_INSTALL_DEVICE="$TARGET_DISK"
echo "$TARGET_DISK" > /run/bootc-install-device

# Create a flag file so we know selection was completed
touch /run/disk-selected

exit 0
