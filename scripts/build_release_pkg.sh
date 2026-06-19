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
NOTARY_PROFILE="${TFX_NOTARY_PROFILE:-notarytool}"
NOTARY_TIMEOUT="${TFX_NOTARY_TIMEOUT:-30m}"
SIGNING_KEYCHAIN="${TFX_SIGNING_KEYCHAIN:-}"
SKIP_SIGNING="${TFX_SKIP_SIGNING:-0}"
SKIP_NOTARIZATION="${TFX_SKIP_NOTARIZATION:-0}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool is missing: $1" >&2
    exit 1
  fi
}

require_xcode() {
  local xcodebuild_output

  if ! xcodebuild_output="$(xcodebuild -version 2>&1)"; then
    echo "xcodebuild is not usable." >&2
    echo "$xcodebuild_output" >&2
    echo "Select a full Xcode installation, for example:" >&2
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    exit 1
  fi
}

require_signing_identity() {
  local identity="$1"
  local policy="$2"
  local identities
  if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    identities="$(security find-identity -v -p "$policy" "$SIGNING_KEYCHAIN")"
  else
    identities="$(security find-identity -v -p "$policy")"
  fi

  if [[ "$identities" != *"$identity"* ]]; then
    echo "Signing identity not found: $identity" >&2
    echo "Searched with security policy: $policy" >&2
    echo "Available identities for this policy:" >&2
    echo "$identities" >&2
    echo "Check Keychain Access or override the identity with TFX_APP_SIGN_IDENTITY/TFX_PKG_SIGN_IDENTITY." >&2
    exit 1
  fi
}

require_tool xcodebuild
require_tool codesign
require_tool pkgbuild
require_tool pkgutil
require_tool security
require_tool xcrun
require_tool spctl
require_tool ditto
require_xcode

if [[ "$SKIP_SIGNING" != "1" ]]; then
  echo "Checking Developer ID signing identities"
  require_signing_identity "$APP_SIGN_IDENTITY" codesigning
  require_signing_identity "$PKG_SIGN_IDENTITY" basic
fi

echo "Reading Xcode build settings"
if ! BUILD_SETTINGS="$(xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -showBuildSettings 2>&1)"; then
  echo "Failed to read Xcode build settings." >&2
  echo "$BUILD_SETTINGS" >&2
  exit 1
fi
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
  CODE_SIGN_FLAGS="--timestamp"
  if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    CODE_SIGN_FLAGS="$CODE_SIGN_FLAGS --keychain $SIGNING_KEYCHAIN"
  fi

  XCODEBUILD_SIGNING_ARGS=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
    CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY"
    OTHER_CODE_SIGN_FLAGS="$CODE_SIGN_FLAGS"
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
  )

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "${XCODEBUILD_SIGNING_ARGS[@]}" \
    build

  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
fi

mkdir -p "$PACKAGE_ROOT/Applications"
ditto --norsrc --noextattr "$APP_PATH" "$PACKAGE_ROOT/Applications/$SCHEME.app"

PKGBUILD_ARGS=(
  --root "$PACKAGE_ROOT"
  --install-location /
  --identifier "$BUNDLE_IDENTIFIER"
  --version "$VERSION"
)

if [[ "$SKIP_SIGNING" != "1" ]]; then
  PKGBUILD_ARGS+=(--sign "$PKG_SIGN_IDENTITY" --timestamp)

  if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    PKGBUILD_ARGS+=(--keychain "$SIGNING_KEYCHAIN")
  fi
fi

COPYFILE_DISABLE=1 pkgbuild "${PKGBUILD_ARGS[@]}" "$PKG_PATH"

if [[ "$SKIP_SIGNING" != "1" ]]; then
  pkgutil --check-signature "$PKG_PATH"

  if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    if [[ -z "$NOTARY_PROFILE" ]]; then
      echo "TFX_NOTARY_PROFILE is empty. Set it to a notarytool keychain profile or use TFX_SKIP_NOTARIZATION=1." >&2
      exit 1
    fi

    echo "Submitting $PKG_PATH for notarization with keychain profile '$NOTARY_PROFILE'"
    xcrun notarytool submit "$PKG_PATH" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait \
      --timeout "$NOTARY_TIMEOUT"

    echo "Stapling notarization ticket"
    xcrun stapler staple "$PKG_PATH"

    echo "Verifying notarized package"
    pkgutil --check-signature "$PKG_PATH"
    xcrun stapler validate "$PKG_PATH"
    spctl -a -vv -t install "$PKG_PATH"
  else
    echo "Skipping notarization because TFX_SKIP_NOTARIZATION=1."
  fi
else
  pkgutil --payload-files "$PKG_PATH" >/dev/null
  echo "Skipping notarization because TFX_SKIP_SIGNING=1."
fi

echo "Built $PKG_PATH"
echo "Version $VERSION ($BUILD_NUMBER)"
