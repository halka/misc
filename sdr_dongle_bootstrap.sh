#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Color Definitions ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color (Reset)

# --- Compact & Stylish Header ---
clear
echo -e "${GREEN}SDR DONGLE BOOTSTRAP${NC}"
echo -e "${GREEN}For Ubuntu Raspberry Pi OS${NC}"
echo -e "${CYAN}BY JM8UTW, 15JUL26${NC}"
echo ""

echo -e "${CYAN}=== 1. Updating Package Lists & Upgrading System ===${NC}"
sudo apt-get update -y
sudo apt-get full-upgrade -y
sudo apt-get autoremove -y
sudo apt-get autoclean -y

echo -e "${BLUE}=== 2. Installing Basic Tools & Build Dependencies ===${NC}"
sudo apt-get install -y jq curl git neovim screen \
                        libusb-1.0-0-dev cmake pkg-config build-essential

echo -e "${PURPLE}=== 3. Installing Docker ===${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh # Clean up the installation script

echo -e "${YELLOW}=== 4. Purging Old RTL-SDR Drivers ===${NC}"
sudo apt-get purge -y ^librtlsdr || true
sudo rm -rvf /usr/lib/librtlsdr*
sudo rm -rvf /usr/include/rtl-sdr*
sudo rm -rvf /usr/local/lib/librtlsdr*
sudo rm -rvf /usr/local/include/rtl-sdr*
sudo rm -rvf /usr/local/include/rtl_*
sudo rm -rvf /usr/local/bin/rtl_*

echo -e "${GREEN}=== 5. Building & Installing Osmocom RTL-SDR Drivers ===${NC}"
# Create a temporary directory for building
BUILD_DIR=$(mktemp -d)
cd "$BUILD_DIR"

git clone https://github.com/osmocom/rtl-sdr
cd rtl-sdr
mkdir build
cd build
cmake ../ -DINSTALL_UDEV_RULES=ON
make
sudo make install
sudo cp ../rtl-sdr.rules /etc/udev/rules.d/
sudo ldconfig

# Clean up build files
cd ~
rm -rf "$BUILD_DIR"

echo -e "${CYAN}=== 6. Blacklisting Default DVB-T Drivers ===${NC}"
# Temporarily unload the driver
sudo rmmod dvb_usb_rtl28xxu || true

# Permanently blacklist the driver
echo 'blacklist dvb_usb_rtl28xxu' | sudo tee --append /etc/modprobe.d/blacklist-dvb_usb_rtl28xxu.conf

echo -e "${GREEN}==========================================================${NC}"
echo -e "  All setups completed successfully!"
echo -e "  Rebooting the system to apply changes."
echo -e "  ${YELLOW}(Press ${RED}Ctrl+C${YELLOW} to cancel the reboot)${GREEN}"
echo -e "==========================================================${NC}"

# 10-second countdown with shifting colors
for i in {10..1}; do
    if [ $i -le 3 ]; then
        COLOR=$RED     # Red for last 3 seconds
    elif [ $i -le 6 ]; then
        COLOR=$YELLOW  # Yellow for last 6 seconds
    else
        COLOR=$CYAN    # Cyan for the beginning
    fi
    echo -ne "${COLOR}Rebooting in ${i} seconds...\r${NC}"
    sleep 1
done
echo -e "${RED}Rebooting now!                             ${NC}"

# Reboot the system
sudo reboot
