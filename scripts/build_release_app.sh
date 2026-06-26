#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${TFX_PROJECT_PATH:-$ROOT_DIR/tfx.xcodeproj}"
SCHEME="${TFX_SCHEME:-tfx}"
CONFIGURATION="${TFX_CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${TFX_DERIVED_DATA_PATH:-$ROOT_DIR/artifacts/release-derived}"
ARTIFACTS_DIR="${TFX_ARTIFACTS_DIR:-$ROOT_DIR/artifacts}"
RELEASE_INFO_PATH="${TFX_RELEASE_INFO:-$ARTIFACTS_DIR/release-info.env}"

BUILD_SETTINGS="$(xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -showBuildSettings 2>&1)"
VERSION="$(awk -F '= ' '/MARKETING_VERSION/ { print $2; exit }' <<<"$BUILD_SETTINGS")"
BUILD_NUMBER="$(awk -F '= ' '/CURRENT_PROJECT_VERSION/ { print $2; exit }' <<<"$BUILD_SETTINGS")"
BUNDLE_IDENTIFIER="$(awk -F '= ' '/PRODUCT_BUNDLE_IDENTIFIER/ { print $2; exit }' <<<"$BUILD_SETTINGS")"

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" || -z "$BUNDLE_IDENTIFIER" ]]; then
  echo "Failed to read version, build number, or bundle identifier from Xcode build settings." >&2
  exit 1
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$SCHEME.app"

rm -rf "$APP_PATH" "$APP_PATH.dSYM"
mkdir -p "$ARTIFACTS_DIR"

echo "Building unsigned $SCHEME $VERSION ($BUILD_NUMBER)"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app was not produced: $APP_PATH" >&2
  exit 1
fi

{
  printf 'TFX_PROJECT_PATH=%q\n' "$PROJECT_PATH"
  printf 'TFX_SCHEME=%q\n' "$SCHEME"
  printf 'TFX_CONFIGURATION=%q\n' "$CONFIGURATION"
  printf 'TFX_DERIVED_DATA_PATH=%q\n' "$DERIVED_DATA_PATH"
  printf 'TFX_ARTIFACTS_DIR=%q\n' "$ARTIFACTS_DIR"
  printf 'TFX_VERSION=%q\n' "$VERSION"
  printf 'TFX_BUILD_NUMBER=%q\n' "$BUILD_NUMBER"
  printf 'TFX_BUNDLE_IDENTIFIER=%q\n' "$BUNDLE_IDENTIFIER"
  printf 'TFX_APP_PATH=%q\n' "$APP_PATH"
} > "$RELEASE_INFO_PATH"

echo "Built app: $APP_PATH"
echo "Wrote release metadata: $RELEASE_INFO_PATH"
echo "Version $VERSION ($BUILD_NUMBER)"
