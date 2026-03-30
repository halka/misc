# misc

Miscellaneous scripts and utilities for macOS, Linux, Windows, and Android.

## Description

### macOS Scripts
- [`uninstall_xcode.sh`](uninstall_xcode.sh): Refactored Xcode uninstaller and Simulator cleanup. Supports dry-run, skipping simulator cleanup, and optional removal of Command Line Tools.

  Usage examples:
  ```bash
  ./uninstall_xcode.sh --help
  ./uninstall_xcode.sh --dry-run             # preview actions, no changes
  ./uninstall_xcode.sh --force               # uninstall Xcode + simulator runtimes
  ./uninstall_xcode.sh --remove-clt --force  # also remove Command Line Tools
  ./uninstall_xcode.sh --skip-sims --force   # keep simulator runtimes
  ```

- [`cleanup_sim_runtimes.sh`](cleanup_sim_runtimes.sh): Cleans up old Simulator runtimes using current `simctl runtime list` output. Keeps only platform+major versions listed in `KEEP_VERSIONS` and deletes the rest.

  Quick start:
  ```bash
  # Edit KEEP_VERSIONS inside the script (e.g., "iOS 18", "watchOS 11", "tvOS 18", "xrOS 26")
  ./cleanup_sim_runtimes.sh
  ```

  Notes:
  - `simctl` requires full Xcode. If missing, install Xcode and set the active developer dir:
    ```bash
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    xcrun simctl list
    ```
  - On some Xcode versions, visionOS may appear as `visionOS` rather than `xrOS`. Adjust `KEEP_VERSIONS` accordingly.

### Linux Scripts
- **[`lvm_clean.sh`](lvm_clean.sh)**: 
A script to fix issues with `apt update` or `apt upgrade`. It will help you to fix the issues and extend the LVM volume to the maximum size of the disk.

- **[`raspberry_pi_update.sh`](raspberry_pi_update.sh)**: A comprehensive update script for Raspberry Pi OS. Handles packages, firmware, EEPROM, snaps, flatpaks, and performs optimizations.

- **[`ubuntu_update.sh`](ubuntu_update.sh)**: A robust system update script for Ubuntu. Includes internet availability checks, package upgrades, snap/flatpak updates, firmware updates, and release upgrade options.

### Windows Scripts
- **[`update-winget.bat`](update-winget.bat)**: Simple batch script to auto-elevate and upgrade all software packages using Windows Package Manager (`winget`).

### Android Scripts
- **[`shutter_off.ps1`](shutter_off.ps1)**: PowerShell script to disable the forced camera shutter sound on Samsung devices via ADB.

### License
- **[`MIT`](LICENSE)**

### Author
- halka from Hakodate 🇯🇵