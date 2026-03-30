#!/bin/bash
set -euo pipefail
# ============================================================
# 🧹 iOS/tvOS/watchOS/xrOS Simulator Runtime Cleanup Tool
# ============================================================

# List installed runtimes
echo "📋 Listing installed runtimes..."
xcrun simctl runtime list

echo ""
echo "⚠️ This script will delete ALL runtimes except the latest ones."
echo "Press Ctrl+C to cancel or Enter to continue."
read -r

# Configure which major OS versions to keep (format: "<Platform> <Major>", e.g., "iOS 26").
# Note: Matching is by platform and MAJOR version only; minor/builds will be cleaned up unless kept here.
KEEP_VERSIONS=("iOS 18" "tvOS 18" "watchOS 11" "xrOS 26")

# Iterate through Ready runtimes and delete those not matching KEEP_VERSIONS
xcrun simctl runtime list | grep -E "Ready" | while IFS= read -r line; do
    # Example line: iOS 26.2 (23C54) - DFF381EF-0742-49FF-8784-53D8FA04AB4E (Ready)
    PLATFORM=$(echo "$line" | awk '{print $1}')
    MAJOR=$(echo "$line" | awk '{print $2}' | cut -d'.' -f1)
    KEY="$PLATFORM $MAJOR"
    UUID=$(echo "$line" | awk -F ' - ' '{print $2}' | awk '{print $1}')
    if [[ " ${KEEP_VERSIONS[*]} " == *" $KEY "* ]]; then
        echo "✅ Keeping: $KEY"
    else
        echo "🗑️ Deleting: $KEY ($UUID)"
        xcrun simctl runtime delete "$UUID"
    fi
done

echo "🎉 Cleanup complete."
