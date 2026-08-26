#!/usr/bin/env bash
# Installs Vibe Check straight onto Jack's iPhone over USB or Wi-Fi, no TestFlight.
#
#   ./run-device.sh            # install the already-built ipa and launch it
#   ./run-device.sh --rebuild  # rebuild from source first
#
# The phone must be unlocked and either plugged in or on the same Wi-Fi as this Mac.
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE=com.jackmielke.vibecheck
KEY_ID=D64LNK6B96
ISSUER=30502701-dad4-4788-9777-3a7c61beeac5
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
IPA="build/dev-export/Vibe Check.ipa"

if [[ "${1:-}" == "--rebuild" ]]; then
  echo "==> Building"
  xcodegen generate >/dev/null
  rm -rf build/VibeCheck.xcarchive build/dev-export
  xcodebuild archive -project VibeCheck.xcodeproj -scheme VibeCheck -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/VibeCheck.xcarchive \
    -allowProvisioningUpdates -authenticationKeyPath "$KEY" \
    -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER" \
    DEVELOPMENT_TEAM=2A35RW57TC >/dev/null
  xcodebuild -exportArchive -archivePath build/VibeCheck.xcarchive \
    -exportOptionsPlist ExportOptions-dev.plist -exportPath build/dev-export \
    -allowProvisioningUpdates -authenticationKeyPath "$KEY" \
    -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER" >/dev/null
fi

[[ -f "$IPA" ]] || { echo "No build found. Run: ./run-device.sh --rebuild"; exit 1; }

echo "==> Looking for the phone (unlock it and plug it in if this hangs)"
DEVICE=$(xcrun devicectl list devices 2>/dev/null \
  | awk '/iPhone/ && !/unavailable/ {print $(NF-2); exit}')

if [[ -z "$DEVICE" ]]; then
  echo "No reachable iPhone. Unlock it, plug it in, trust this Mac, then re-run."
  echo "Currently visible:"
  xcrun devicectl list devices 2>/dev/null | tail -n +3
  exit 1
fi

echo "==> Installing to $DEVICE"
xcrun devicectl device install app --device "$DEVICE" "$IPA"
echo "==> Launching"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE" || true
echo "Done. If iOS blocks it, go to Settings > General > VPN & Device Management and trust the developer."
