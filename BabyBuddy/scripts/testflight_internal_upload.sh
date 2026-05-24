#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-BBB.xcodeproj}"
SCHEME="${SCHEME:-BBB}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/testflight-internal}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/$SCHEME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$BUILD_DIR/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$BUILD_DIR/ExportOptions.plist}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_DIR/DerivedData}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 2
  fi
}

require_env ASC_KEY_ID
require_env ASC_ISSUER_ID
require_env ASC_KEY_PATH
require_env APPLE_TEAM_ID

ALTOOL_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
if [[ "$ASC_KEY_PATH" != "$ALTOOL_KEY_PATH" ]]; then
  echo "ASC_KEY_PATH is used by xcodebuild, but altool expects the same key at:" >&2
  echo "  $ALTOOL_KEY_PATH" >&2
  echo "Move or symlink the key there before uploading." >&2
  exit 2
fi

mkdir -p "$BUILD_DIR" "$EXPORT_PATH"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>export</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${APPLE_TEAM_ID}</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>testFlightInternalTestingOnly</key>
  <true/>
  <key>iCloudContainerEnvironment</key>
  <string>Production</string>
</dict>
</plist>
PLIST

echo "Archiving $SCHEME..."
xcodebuild archive \
  -project "$ROOT_DIR/$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "Exporting IPA..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

IPA_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -name "*.ipa" -print -quit)"
if [[ -z "$IPA_PATH" ]]; then
  echo "Export completed, but no .ipa was found in $EXPORT_PATH" >&2
  exit 1
fi

echo "Uploading IPA to App Store Connect..."
xcrun altool --upload-app \
  --type ios \
  --file "$IPA_PATH" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo "Uploaded: $IPA_PATH"
echo "Next: run scripts/testflight_assign_internal_group.mjs after Apple finishes processing."
