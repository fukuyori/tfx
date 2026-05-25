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
DEVELOPMENT_TEAM="${TFX_DEVELOPMENT_TEAM:-Q6GG27UYG5}"
NOTARY_PROFILE="${TFX_NOTARY_PROFILE:-}"
SKIP_SIGNING="${TFX_SKIP_SIGNING:-0}"
SKIP_NOTARIZATION="${TFX_SKIP_NOTARIZATION:-0}"

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
PKG_PATH="$ARTIFACTS_DIR/$SCHEME-$VERSION.pkg"
PACKAGE_ROOT="$STAGING_DIR/root"

rm -rf "$APP_PATH" "$APP_PATH.dSYM" "$PKG_PATH" "$STAGING_DIR"
mkdir -p "$ARTIFACTS_DIR"

echo "Building $SCHEME $VERSION ($BUILD_NUMBER)"

if [[ "$SKIP_SIGNING" == "1" ]]; then
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build
else
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
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    build

  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
fi

xattr -cr "$APP_PATH"
find "$APP_PATH" \( -name ".DS_Store" -o -name "._*" \) -delete
mkdir -p "$PACKAGE_ROOT/Applications"
ditto --norsrc --noextattr "$APP_PATH" "$PACKAGE_ROOT/Applications/$SCHEME.app"

PKGBUILD_ARGS=(
  --root "$PACKAGE_ROOT"
  --install-location /
  --identifier "$BUNDLE_IDENTIFIER"
  --version "$VERSION"
)

if [[ "$SKIP_SIGNING" != "1" ]]; then
  PKGBUILD_ARGS+=(--sign "$PKG_SIGN_IDENTITY")
fi

COPYFILE_DISABLE=1 pkgbuild "${PKGBUILD_ARGS[@]}" "$PKG_PATH"

if [[ "$SKIP_SIGNING" != "1" ]]; then
  pkgutil --check-signature "$PKG_PATH"

  if [[ "$SKIP_NOTARIZATION" != "1" && -n "$NOTARY_PROFILE" ]]; then
    echo "Submitting $PKG_PATH for notarization"
    xcrun notarytool submit "$PKG_PATH" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait

    echo "Stapling notarization ticket"
    xcrun stapler staple "$PKG_PATH"
    xcrun stapler validate "$PKG_PATH"

    echo "Checking Gatekeeper install assessment"
    spctl -a -vv -t install "$PKG_PATH"
  elif [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    echo "Skipping notarization because TFX_NOTARY_PROFILE is not set."
  else
    echo "Skipping notarization because TFX_SKIP_NOTARIZATION=1."
  fi
else
  pkgutil --payload-files "$PKG_PATH" >/dev/null
  echo "Skipping notarization because TFX_SKIP_SIGNING=1."
fi

echo "Built $PKG_PATH"
echo "Version $VERSION ($BUILD_NUMBER)"
