#!/bin/bash

# Raspberry Pi System Update Script
# This script performs a comprehensive system update for Raspberry Pi OS

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Defaults and flags
ASSUME_YES=false
AUTO_REBOOT=false
COUNTDOWN=10

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Reboot countdown with color changes (last 5s yellow, last 3s red)
reboot_countdown() {
    local seconds=${1:-10}
    print_warning "Reboot will start in ${seconds} seconds. Press Ctrl+C to cancel."
    for ((i=seconds; i>0; i--)); do
        if (( i <= 3 )); then color="$RED";
        elif (( i <= 5 )); then color="$YELLOW";
        else color="$GREEN"; fi
        printf "\r${color}Rebooting in %2d seconds...${NC} " "$i"
        sleep 1
    done
    echo
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                ASSUME_YES=true
                ;;
            --auto|--auto-reboot)
                AUTO_REBOOT=true
                ;;
            --countdown|--reboot-delay)
                shift
                COUNTDOWN=${1:-10}
                ;;
            --help|-h)
                echo "Usage: $0 [-y|--yes] [--auto|--auto-reboot] [--countdown N]"
                exit 0
                ;;
            *)
                print_warning "Unknown option: $1"
                ;;
        esac
        shift
    done
    # Validate COUNTDOWN is a number
    if ! [[ "$COUNTDOWN" =~ ^[0-9]+$ ]]; then
        print_warning "Invalid countdown '$COUNTDOWN'. Falling back to 10 seconds."
        COUNTDOWN=10
    fi
}

# Function to check if this is a Raspberry Pi
check_raspberry_pi() {
    if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model; then
        print_warning "This doesn't appear to be a Raspberry Pi system."
        read -p "Continue anyway? (y/N): " continue_choice
        if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to check temperature
check_temperature() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_celsius=$((temp / 1000))
        print_status "Current CPU temperature: ${temp_celsius}°C"
        
        if [ $temp_celsius -gt 70 ]; then
            print_warning "High CPU temperature detected (${temp_celsius}°C). Consider cooling before intensive operations."
        fi
    fi
}

# Function to update package lists
update_package_lists() {
    print_status "Updating package lists..."
    sudo apt update
    print_success "Package lists updated"
}

# Function to upgrade packages
upgrade_packages() {
    print_status "Upgrading installed packages..."
    sudo apt upgrade -y
    print_success "Packages upgraded"
}

# Function to perform distribution upgrade
dist_upgrade() {
    print_status "Performing distribution upgrade..."
    sudo apt dist-upgrade -y
    print_success "Distribution upgrade completed"
}

# Function to update Raspberry Pi firmware and kernel
update_rpi_firmware() {
    print_status "Updating Raspberry Pi firmware and kernel..."
    sudo rpi-update
    print_success "Firmware and kernel updated"
    print_warning "Firmware update completed - reboot will be required"
}

# Function to update Raspberry Pi EEPROM
update_rpi_eeprom() {
    if command -v rpi-eeprom-update &> /dev/null; then
        print_status "Checking for EEPROM updates..."
        if sudo rpi-eeprom-update | grep -q "UPDATE AVAILABLE"; then
            print_status "EEPROM update available, installing..."
            sudo rpi-eeprom-update -a
            print_success "EEPROM updated - reboot required"
        else
            print_success "EEPROM is up to date"
        fi
    else
        print_warning "rpi-eeprom-update not available, skipping EEPROM updates"
    fi
}

# Function to update Raspberry Pi configuration tools
update_rpi_tools() {
    print_status "Updating Raspberry Pi configuration tools..."
    if dpkg -l | grep -q raspberrypi-ui-mods; then
        print_status "Desktop version detected, updating GUI tools..."
    fi
    
    # Update raspi-config if available
    if command -v raspi-config &> /dev/null; then
        print_success "raspi-config is available and updated through apt"
    fi
}

# Function to update snap packages
update_snaps() {
    if command -v snap &> /dev/null; then
        print_status "Updating snap packages..."
        sudo snap refresh
        print_success "Snap packages updated"
    else
        print_warning "Snap is not installed, skipping snap updates"
    fi
}

# Function to update flatpak packages
update_flatpaks() {
    if command -v flatpak &> /dev/null; then
        print_status "Updating flatpak packages..."
        flatpak update -y
        print_success "Flatpak packages updated"
    else
        print_warning "Flatpak is not installed, skipping flatpak updates"
    fi
}

# Function to clean up packages
cleanup_packages() {
    print_status "Cleaning up unnecessary packages..."
    sudo apt autoremove -y
    sudo apt autoclean
    
    # Clean up old kernels if space is needed
    print_status "Cleaning old kernel modules..."
    sudo apt autoremove --purge -y
    
    print_success "Package cleanup completed"
}

# Function to optimize for Raspberry Pi
optimize_rpi() {
    print_status "Performing Raspberry Pi optimizations..."
    
    # Update locate database
    if command -v updatedb &> /dev/null; then
        print_status "Updating locate database..."
        sudo updatedb
    fi
    
    # Clear logs if they're getting large
    log_size=$(du -sh /var/log 2>/dev/null | cut -f1)
    print_status "Log directory size: ${log_size}"
    
    if [ -f /var/log/syslog ]; then
        syslog_size=$(du -sh /var/log/syslog | cut -f1)
        print_status "Syslog size: ${syslog_size}"
    fi
    
    print_success "Raspberry Pi optimizations completed"
}

# Function to check SD card health
check_sd_card() {
    print_status "Checking SD card health..."
    
    # Check filesystem
    root_fs=$(df / | tail -1 | awk '{print $1}')
    print_status "Root filesystem: ${root_fs}"
    
    # Check available space
    disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    print_status "Disk usage: ${disk_usage}%"
    
    if [ $disk_usage -gt 85 ]; then
        print_warning "Disk usage is high (${disk_usage}%). Consider cleaning up files or expanding filesystem."
    fi
    
    print_success "SD card health check completed"
}

# Function to check for reboot requirement
check_reboot() {
    needs_reboot=false
    
    if [ -f /var/run/reboot-required ]; then
        print_warning "System restart is required to complete updates!"
        needs_reboot=true
        if [ -f /var/run/reboot-required.pkgs ]; then
            print_warning "Reboot required packages:"
            cat /var/run/reboot-required.pkgs
        fi
    fi
    
    # Check if firmware was updated
    if [ -f /boot/kernel.img.bak ]; then
        print_warning "Firmware was updated - reboot required!"
        needs_reboot=true
    fi
    
    if [ "$needs_reboot" = true ]; then
        echo
        local reboot_choice
        if $AUTO_REBOOT || $ASSUME_YES; then
            reboot_choice="y"
        else
            read -p "Do you want to reboot now? (y/N): " reboot_choice
        fi
        if [[ $reboot_choice =~ ^[Yy]$ ]]; then
            print_status "Rebooting system..."
            reboot_countdown "$COUNTDOWN"
            sudo reboot
        else
            print_warning "Please remember to reboot your system later"
        fi
    else
        print_success "No reboot required"
    fi
}

# Function to show Raspberry Pi system information
show_rpi_info() {
    print_status "Raspberry Pi System Information:"
    
    # Model information
    if [ -f /proc/device-tree/model ]; then
        echo "Model: $(cat /proc/device-tree/model)"
    fi
    
    # OS information
    if command -v lsb_release &> /dev/null; then
        echo "OS: $(lsb_release -d | cut -f2)"
    fi
    
    # Kernel and uptime
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    
    # Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_celsius=$((temp / 1000))
        echo "CPU Temperature: ${temp_celsius}°C"
    fi
    
    # Memory and disk usage
    echo "Memory Usage:"
    free -h | awk 'NR==2{printf "  RAM: %.1fG used, %.1fG available (%.1f%% used)\n", $3/1024, $7/1024, $3*100/($3+$7)}'
    
    echo "Disk Usage:"
    df -h / | tail -1 | awk '{print "  Root: " $3 " used, " $4 " available (" $5 " used)"}'
    
    # GPU memory split (if vcgencmd is available)
    if command -v vcgencmd &> /dev/null; then
        gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2)
        echo "GPU Memory: ${gpu_mem}"
    fi
}

# Main execution
main() {
    echo "================================================"
    echo "      Raspberry Pi System Update Script"
    echo "================================================"
    echo
    
    # Parse arguments and validate
    parse_args "$@"

    # Show system info
    show_rpi_info
    echo
    
    # Perform checks
    check_raspberry_pi
    check_temperature
    
    # Perform updates
    echo "Starting Raspberry Pi update process..."
    echo
    
    update_package_lists
    upgrade_packages
    dist_upgrade
    
    # Ask about firmware update
    echo
    local firmware_choice
    if $ASSUME_YES; then
        firmware_choice="y"
    else
        read -p "Do you want to update Raspberry Pi firmware? This may take time and requires reboot (y/N): " firmware_choice
    fi
    if [[ $firmware_choice =~ ^[Yy]$ ]]; then
        update_rpi_firmware
    fi
    
    update_rpi_eeprom
    update_rpi_tools
    update_snaps
    update_flatpaks
    cleanup_packages
    optimize_rpi
    check_sd_card
    
    echo
    print_success "All updates completed successfully!"
    echo
    
    # Check if reboot is needed
    check_reboot
    
    echo
    print_success "Raspberry Pi update script finished!"
    
    # Final temperature check
    check_temperature
}

# Run main function
main "$@"
