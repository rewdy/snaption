#!/usr/bin/env bash
set -euo pipefail

PROJECT="Snaption.xcodeproj"
SCHEME="Snaption"
DESTINATION="platform=macOS,arch=arm64"
NOTARY_PROFILE="${1:-}"
LOCAL_RELEASE="${LOCAL_RELEASE:-0}"
DEVELOPER_DIR_PATH="${DEVELOPER_DIR_PATH:-/Applications/Xcode.app/Contents/Developer}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

for cmd in xcodebuild xcrun security codesign spctl ditto shasum; do
  require_cmd "$cmd"
done

if [[ ! -d "$PROJECT" ]]; then
  echo "project not found: $PROJECT" >&2
  exit 1
fi

if ! settings="$(DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "$DESTINATION" -showBuildSettings 2>/dev/null)"; then
  echo "failed to read build settings via xcodebuild -showBuildSettings" >&2
  exit 1
fi

bundle_id="$(printf '%s\n' "$settings" | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER = / {print $2; exit}')"
marketing_version="$(printf '%s\n' "$settings" | awk -F' = ' '/ MARKETING_VERSION = / {print $2; exit}')"
build_version="$(printf '%s\n' "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION = / {print $2; exit}')"

if [[ -z "$bundle_id" || -z "$marketing_version" || -z "$build_version" ]]; then
  echo "failed to read release build settings" >&2
  exit 1
fi

if [[ "$LOCAL_RELEASE" == "1" ]]; then
  echo "LOCAL_RELEASE=1: skipping Developer ID identity requirement"
  if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "LOCAL_RELEASE=1: ignoring notary profile argument ($NOTARY_PROFILE)"
  fi
else
  if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "missing Developer ID Application signing identity in keychain" >&2
    exit 1
  fi

  if [[ -n "$NOTARY_PROFILE" ]]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
      echo "notary profile check failed: $NOTARY_PROFILE" >&2
      exit 1
    fi
  fi
fi

echo "Preflight OK"
echo "Bundle ID: $bundle_id"
echo "Version: $marketing_version ($build_version)"
if [[ "$LOCAL_RELEASE" == "1" ]]; then
  echo "Release mode: local (self-signed/not-notarized)"
elif [[ -n "$NOTARY_PROFILE" ]]; then
  echo "Notary profile: $NOTARY_PROFILE"
else
  echo "Notary profile: not checked (pass as first arg to validate)"
fi

echo "Running SnaptionTests..."
DEVELOPER_DIR="$DEVELOPER_DIR_PATH" \
  xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:SnaptionTests

echo "Preflight complete"
