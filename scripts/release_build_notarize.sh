#!/usr/bin/env bash
set -euo pipefail

PROJECT="Snaption.xcodeproj"
SCHEME="Snaption"
CONFIGURATION="Release"
ARCHIVE_PATH="${ARCHIVE_PATH:-$PWD/build/Snaption.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-$PWD/build/export}"
APP_NAME="Snaption.app"
ZIP_PATH="${ZIP_PATH:-$PWD/build/Snaption.zip}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
LOCAL_RELEASE="${LOCAL_RELEASE:-0}"
SELF_SIGN_IDENTITY="${SELF_SIGN_IDENTITY:--}"
DEVELOPER_DIR_PATH="${DEVELOPER_DIR_PATH:-/Applications/Xcode.app/Contents/Developer}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR" "$(dirname "$ZIP_PATH")"

echo "Archiving $SCHEME ($CONFIGURATION)..."
DEVELOPER_DIR="$DEVELOPER_DIR_PATH" \
  xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH"

APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "archived app not found at $APP_PATH" >&2
  exit 1
fi

rm -rf "$EXPORT_DIR/$APP_NAME"
cp -R "$APP_PATH" "$EXPORT_DIR/$APP_NAME"

if [[ "$LOCAL_RELEASE" == "1" ]]; then
  echo "LOCAL_RELEASE=1: re-signing app with identity: $SELF_SIGN_IDENTITY"
  codesign --force --deep --sign "$SELF_SIGN_IDENTITY" "$EXPORT_DIR/$APP_NAME"
fi

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$EXPORT_DIR/$APP_NAME"
if [[ "$LOCAL_RELEASE" == "1" ]]; then
  echo "LOCAL_RELEASE=1: skipping Gatekeeper assessment before notarization"
else
  spctl --assess --type execute --verbose "$EXPORT_DIR/$APP_NAME"
fi

echo "Creating release zip..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$EXPORT_DIR/$APP_NAME" "$ZIP_PATH"

checksum="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo "SHA-256: $checksum"

if [[ "$LOCAL_RELEASE" == "1" ]]; then
  echo "LOCAL_RELEASE=1: skipping notarization and stapling"
elif [[ -n "$NOTARY_PROFILE" ]]; then
  echo "Submitting for notarization using keychain profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$EXPORT_DIR/$APP_NAME"

  echo "Re-checking Gatekeeper..."
  spctl --assess --type execute --verbose "$EXPORT_DIR/$APP_NAME"
else
  echo "Skipping notarization (set NOTARY_PROFILE to enable)"
fi

echo "Release artifact ready: $ZIP_PATH"
