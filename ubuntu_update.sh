#!/bin/bash

# Ubuntu System Update Script
# This script performs a comprehensive system update including packages, snaps, and cleanup

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
FORCE_RELEASE_UPGRADE=false

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
            --release-upgrade)
                FORCE_RELEASE_UPGRADE=true
                ;;
            --help|-h)
                echo "Usage: $0 [-y|--yes] [--auto|--auto-reboot] [--countdown N] [--release-upgrade]"
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

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

# Function to check internet connectivity
check_internet() {
    print_status "Checking internet connectivity..."
    if ping -c 1 google.com &> /dev/null; then
        print_success "Internet connection is active"
    else
        print_error "No internet connection. Please check your network settings."
        exit 1
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
    print_success "Package cleanup completed"
}

# Function to update firmware (if available)
update_firmware() {
    if command -v fwupdmgr \u0026> /dev/null; then
        print_status "Checking for firmware updates..."
        sudo fwupdmgr refresh --force
        sudo fwupdmgr update -y || print_warning "No firmware updates available or update failed"
        print_success "Firmware update check completed"
    else
        print_warning "fwupdmgr not available, skipping firmware updates"
    fi
}

# Function to optionally perform Ubuntu distribution release upgrade
release_upgrade() {
    if command -v do-release-upgrade \u0026> /dev/null; then
        print_status "Checking for Ubuntu release upgrades..."
        # Ensure the release upgrader is installed
        sudo apt install -y ubuntu-release-upgrader-core >/dev/null 2>&1 || true

        # Show if an upgrade is available
        sudo do-release-upgrade -c || true

        echo
        local ru_choice
        if $FORCE_RELEASE_UPGRADE; then
            print_status "--release-upgrade specified: proceeding with Ubuntu release upgrade."
            ru_choice="y"
        elif $ASSUME_YES; then
            ru_choice="y"
        else
            read -p "If a new Ubuntu release is available, do you want to start the upgrade now? (y/N): " ru_choice
        fi
        if [[ $ru_choice =~ ^[Yy]$ ]]; then
            print_warning "Starting Ubuntu distribution release upgrade. This may take a long time and could reboot the system."
            if $ASSUME_YES; then
                print_status "Running non-interactive release upgrade..."
                sudo DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive || print_warning "Release upgrade did not complete. Review the output above."
            else
                # Run interactively so the user can confirm prompts
                sudo do-release-upgrade || print_warning "Release upgrade did not complete. Review the output above."
            fi
        else
            print_status "Skipping Ubuntu release upgrade."
        fi
    else
        print_warning "do-release-upgrade not found. Skipping Ubuntu release upgrade."
    fi
}

# Function to check for reboot requirement
check_reboot() {
    if [ -f /var/run/reboot-required ]; then
        print_warning "System restart is required to complete updates!"
        print_warning "Reboot required packages:"
        if [ -f /var/run/reboot-required.pkgs ]; then
            cat /var/run/reboot-required.pkgs
        fi
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

# Function to show system information
show_system_info() {
    print_status "System Information:"
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Disk Usage:"
    df -h / | tail -1 | awk '{print "  Root: " $3 " used, " $4 " available (" $5 " used)"}'
    echo "Memory Usage:"
    free -h | awk 'NR==2{printf "  RAM: %.1fG used, %.1fG available (%.1f%% used)\n", $3/1024, $7/1024, $3*100/($3+$7)}'
}

# Main execution
main() {
    echo "================================================"
    echo "         Ubuntu System Update Script"
    echo "================================================"
    echo
    
    # Parse arguments and validate
    parse_args "$@"

    # Show system info
    show_system_info
    echo
    
    # Perform checks
    check_root
    check_internet
    
    # Perform updates
    echo "Starting system update process..."
    echo
    
    update_package_lists
    upgrade_packages
    dist_upgrade
    update_snaps
    update_flatpaks
    cleanup_packages
    update_firmware

    # Offer Ubuntu release upgrade (optional)
    release_upgrade
    
    echo
    print_success "All updates completed successfully!"
    echo
    
    # Check if reboot is needed
    check_reboot
    
    echo
    print_success "Update script finished!"
}

# Run main function
main "$@"
