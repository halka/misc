#!/bin/bash

# --- CONFIGURATION ---
LV_PATH="/dev/ubuntu-vg/ubuntu-lv"
DRY_RUN=false

# Check for dry-run flag
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# --- COLORS ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- AUTOMATIC SUDO CHECK ---
if [[ $EUID -ne 0 && "$DRY_RUN" = false ]]; then
   echo -e "${YELLOW}This script requires root privileges. Requesting sudo...${NC}"
   exec sudo "$0" "$@"
fi

echo -e "${BLUE}${BOLD}------------------"
echo -e "  LVM EXTENDER "
echo -e "REVIVE LVM SPACE"
echo -e "------------------${NC}"

if "${DRY_RUN}"; then 
  echo -e "DRY RUN MODE\n"
fi




# 1. Check if the LV exists
if [ ! -b "$LV_PATH" ]; then
    echo -e "${RED}${BOLD}ERROR:${NC} Logical Volume ${YELLOW}$LV_PATH${NC} not found."
    exit 1
fi

# 2. Detect Filesystem Type
echo -e "${BLUE}[1/3]${NC} Detecting filesystem type..."
FS_TYPE=$(lsblk -no FSTYPE "$LV_PATH" | tr -d ' ')
echo -e "      Found: ${GREEN}${BOLD}$FS_TYPE${NC}"

# 4. Extend the Logical Volume
echo -e "${BLUE}[2/3]${NC} Extending LVM..."
if [ "$DRY_RUN" = true ]; then
    echo -e "      ${YELLOW}[DRY RUN] Would run: lvextend -l +100%FREE $LV_PATH${NC}"
else
    if lvextend -l +100%FREE "$LV_PATH" > /dev/null 2>&1; then
        echo -e "      ${GREEN}Success: LVM extended.${NC}"
    else
        echo -e "      ${YELLOW}Notice: No free space found.${NC}"
    fi
fi

# 4. Resize the Filesystem
echo -e "${BLUE}[3/3]${NC} Resizing ${GREEN}$FS_TYPE${NC} filesystem..."
case "$FS_TYPE" in
    ext2|ext3|ext4)
        if [ "$DRY_RUN" = true ]; then
            echo -e "      ${YELLOW}[DRY RUN] Would run: resize2fs $LV_PATH${NC}"
        else
            resize2fs "$LV_PATH"
        fi
        ;;
    xfs)
        if [ "$DRY_RUN" = true ]; then
            echo -e "      ${YELLOW}[DRY RUN] Would run: xfs_growfs $LV_PATH${NC}"
        else
            xfs_growfs "$LV_PATH"
        fi
        ;;
    *)
        echo -e "${RED}Unsupported filesystem type: $FS_TYPE${NC}"
        exit 1
        ;;
esac

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}${BOLD}DRY RUN COMPLETE.${NC} No changes were made."
else
    echo -e "${GREEN}${BOLD}FINISHED!${NC} Check your updated space above."
fi
