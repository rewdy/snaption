#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-Snaption.xcodeproj}"
SCHEME="${SCHEME:-Snaption}"
DESTINATION="${DESTINATION:-platform=macOS}"
DEVELOPER_DIR_PATH="${DEVELOPER_DIR_PATH:-/Applications/Xcode.app/Contents/Developer}"
TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  echo "usage: $0 <tag>" >&2
  echo "example: $0 v1.2.0" >&2
  exit 1
fi

version_from_tag="${TAG#v}"
if [[ "$version_from_tag" == "$TAG" ]]; then
  echo "tag must start with 'v', got: $TAG" >&2
  exit 1
fi

if ! settings="$(DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "$DESTINATION" -showBuildSettings 2>/dev/null)"; then
  echo "failed to read build settings via xcodebuild -showBuildSettings" >&2
  exit 1
fi

marketing_version="$(printf '%s\n' "$settings" | awk -F' = ' '/ MARKETING_VERSION = / {print $2; exit}')"
build_version="$(printf '%s\n' "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION = / {print $2; exit}')"

if [[ -z "$marketing_version" || -z "$build_version" ]]; then
  echo "could not parse MARKETING_VERSION/CURRENT_PROJECT_VERSION from build settings" >&2
  exit 1
fi

if [[ "$marketing_version" != "$version_from_tag" ]]; then
  echo "tag/version mismatch: tag=$version_from_tag MARKETING_VERSION=$marketing_version" >&2
  exit 1
fi

if [[ ! "$build_version" =~ ^[0-9]+$ ]]; then
  echo "CURRENT_PROJECT_VERSION must be numeric, got: $build_version" >&2
  exit 1
fi

echo "Release tag validated"
echo "MARKETING_VERSION=$marketing_version"
echo "CURRENT_PROJECT_VERSION=$build_version"
