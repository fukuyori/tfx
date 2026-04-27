#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/tfx.xcodeproj"
SCHEME="tfx"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$ROOT_DIR/artifacts/release-derived"
ARTIFACTS_DIR="$ROOT_DIR/artifacts"
STAGING_DIR="$ARTIFACTS_DIR/staging"
APP_SIGN_IDENTITY="${TFX_APP_SIGN_IDENTITY:-Developer ID Application: Noriaki Fukuyori (Q6GG27UYG5)}"
PKG_SIGN_IDENTITY="${TFX_PKG_SIGN_IDENTITY:-Developer ID Installer: Noriaki Fukuyori (Q6GG27UYG5)}"

VERSION="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null | awk -F '= ' '/MARKETING_VERSION/ { print $2; exit }')"
BUILD_NUMBER="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null | awk -F '= ' '/CURRENT_PROJECT_VERSION/ { print $2; exit }')"
BUNDLE_IDENTIFIER="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null | awk -F '= ' '/PRODUCT_BUNDLE_IDENTIFIER/ { print $2; exit }')"

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" || -z "$BUNDLE_IDENTIFIER" ]]; then
  echo "Failed to read version, build number, or bundle identifier from Xcode build settings." >&2
  exit 1
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$SCHEME.app"
PKG_PATH="$ARTIFACTS_DIR/$SCHEME-$VERSION.pkg"

rm -rf "$STAGING_DIR" "$PKG_PATH"
mkdir -p "$ARTIFACTS_DIR"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  DEVELOPMENT_TEAM=Q6GG27UYG5 \
  build

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

pkgbuild \
  --component "$APP_PATH" \
  --install-location /Applications \
  --identifier "$BUNDLE_IDENTIFIER" \
  --version "$VERSION" \
  --sign "$PKG_SIGN_IDENTITY" \
  "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"

echo "Built $PKG_PATH"
echo "Version $VERSION ($BUILD_NUMBER)"
