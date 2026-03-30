#!/bin/bash
set -euo pipefail

# ==========================================================
#  Xcode Uninstaller & Simulator Cleanup (refactored)
# ==========================================================
# Safely removes:
# - All Simulator runtimes (via simctl)
# - Xcode app bundle
# - Common Xcode caches, preferences, and developer folders
# Optional:
# - Remove Command Line Tools receipts and files (--remove-clt)
# - Dry run to preview actions (--dry-run)
# - Skip simulator cleanup (--skip-sims)
# - Non-interactive confirmation (--force or -y)
# ==========================================================

usage() {
  cat <<'USAGE'
Usage: ./uninstall_xcode.sh [options]

Options:
  --dry-run        Print what would be deleted, but do not delete.
  --skip-sims      Do not delete Simulator runtimes (skips simctl runtime delete).
  --remove-clt     Also remove Xcode Command Line Tools and pkgutil receipts.
  --force, -y      Skip confirmation prompt.
  -h, --help       Show this help.

Notes:
- Simulator runtimes are deleted first (before removing Xcode) so simctl can unmount images cleanly.
- After uninstall, you can reinstall from the App Store (Xcode) or via: xcode-select --install (CLT only).
USAGE
}

DRY_RUN=false
SKIP_SIMS=false
REMOVE_CLT=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --skip-sims) SKIP_SIMS=true ;;
    --remove-clt) REMOVE_CLT=true ;;
    --force|-y) FORCE=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

log() { printf "%s\n" "$*"; }
run() {
  if $DRY_RUN; then
    printf "DRY-RUN: %s\n" "$*"
  else
    eval "$@"
  fi
}

delete_path() {
  local path="$1"; local use_sudo="${2:-false}"
  if [[ -e "$path" || -L "$path" ]]; then
    if $DRY_RUN; then
      printf "DRY-RUN rm -rf %s%s\n" "$([[ "$use_sudo" == true ]] && echo "(sudo) ")" "$path"
    else
      if [[ "$use_sudo" == true ]]; then sudo rm -rf "$path"; else rm -rf "$path"; fi
    fi
  fi
}

confirm() {
  if $FORCE; then return 0; fi
  printf "\nThis operation will make irreversible changes. Proceed? (y/N): "
  read -r ans || true
  [[ "$ans" =~ ^([yY]|[yY][eE][sS])$ ]]
}

print_plan() {
  log "========================================================="
  log "Xcode Uninstaller & Simulator Cleanup"
  log "========================================================="
  $DRY_RUN && log "Mode: DRY RUN (no changes will be made)"
  $SKIP_SIMS && log "Note: Simulator runtime cleanup will be skipped"
  $REMOVE_CLT && log "Note: Command Line Tools will also be removed"
  log ""
}

cleanup_sim_runtimes() {
  if $SKIP_SIMS; then
    log "[skip] Simulator runtimes (per --skip-sims)"; return
  fi
  if ! command -v xcrun >/dev/null 2>&1; then
    log "xcrun not found; skipping simctl runtime cleanup (Xcode may already be removed)."; return
  fi

  log "Step 1: Cleaning up Simulator Runtimes via simctl..."
  run "xcrun simctl shutdown all || true"

  # Iterate over Ready runtimes and delete by UUID (safer unmount & asset cleanup)
  xcrun simctl runtime list | grep -E "Ready" | while IFS= read -r line; do
    # Example: iOS 26.2 (23C54) - DFF381EF-0742-49FF-8784-53D8FA04AB4E (Ready)
    local uuid
    uuid=$(echo "$line" | awk -F ' - ' '{print $2}' | awk '{print $1}')
    local name
    name=$(echo "$line" | cut -d'-' -f1 | sed 's/ *$//')
    if [[ -n "$uuid" ]]; then
      if $DRY_RUN; then
        log "DRY-RUN: xcrun simctl runtime delete $uuid  # $name"
      else
        xcrun simctl runtime delete "$uuid" || true
      fi
    fi
  done
  log "✅ Simulator runtimes cleanup step complete."
}

remove_xcode_and_files() {
  log "Step 2: Removing Xcode app and system files..."
  delete_path "/Applications/Xcode.app" true
  delete_path "/Library/Preferences/com.apple.dt.Xcode.plist" true

  log "Step 3: Removing user-specific files..."
  delete_path "$HOME/Library/Preferences/com.apple.dt.Xcode.plist"
  delete_path "$HOME/Library/Preferences/com.apple.iphonesimulator.plist"
  delete_path "$HOME/Library/Caches/com.apple.dt.Xcode"
  delete_path "$HOME/Library/Application Support/Xcode"
  delete_path "$HOME/Library/Developer/Xcode"
  delete_path "$HOME/Library/Developer/CoreSimulator"
}

remove_clt() {
  if ! $REMOVE_CLT; then return; fi
  log "Step 4: Removing Command Line Tools and receipts (--remove-clt)..."
  delete_path "/Library/Developer/CommandLineTools" true
  # Forget CLT receipts if present
  if command -v pkgutil >/dev/null 2>&1; then
    local pkgs
    pkgs=$(pkgutil --pkgs | grep -E '^com\.apple\.pkg\.CLTools' || true)
    if [[ -n "$pkgs" ]]; then
      while IFS= read -r p; do
        if [[ -n "$p" ]]; then
          if $DRY_RUN; then
            log "DRY-RUN: sudo pkgutil --forget $p"
          else
            sudo pkgutil --forget "$p" || true
          fi
        fi
      done <<< "$pkgs"
    fi
  fi
}

main() {
  print_plan
  if ! confirm; then
    log "Uninstall aborted."; exit 1
  fi

  # Show current dev dir for context
  if command -v xcode-select >/dev/null 2>&1; then
    local devdir
    devdir=$(xcode-select -p 2>/dev/null || true)
    [[ -n "$devdir" ]] && log "Active developer dir: $devdir"
  fi

  cleanup_sim_runtimes
  remove_xcode_and_files
  remove_clt

  log ""
  log "🎉 Done. Xcode and related files have been removed${REMOVE_CLT:+ (including CLT)}."
  $DRY_RUN && log "(No changes were made due to --dry-run)"
}

main "$@"
