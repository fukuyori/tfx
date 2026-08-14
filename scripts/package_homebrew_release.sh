#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR_DEFAULT="$ROOT_DIR/artifacts"
RELEASE_INFO_PATH="${TFX_RELEASE_INFO:-$ARTIFACTS_DIR_DEFAULT/release-info.env}"

if [[ ! -f "$RELEASE_INFO_PATH" ]]; then
  echo "Release metadata not found: $RELEASE_INFO_PATH" >&2
  echo "Run ./scripts/build_release_app.sh first, or set TFX_RELEASE_INFO." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$RELEASE_INFO_PATH"

ARTIFACTS_DIR="${TFX_ARTIFACTS_DIR:-$ARTIFACTS_DIR_DEFAULT}"
SCHEME="${TFX_SCHEME:-tfx}"
VERSION="${TFX_VERSION:?Missing TFX_VERSION in release metadata.}"
APP_PATH="${TFX_APP_PATH:?Missing TFX_APP_PATH in release metadata.}"
APP_SIGN_IDENTITY="${TFX_APP_SIGN_IDENTITY:-Developer ID Application: Noriaki Fukuyori (Q6GG27UYG5)}"
NOTARY_PROFILE="${TFX_NOTARY_PROFILE:-notarytool}"
NOTARY_APPLE_ID="${TFX_NOTARY_APPLE_ID:-}"
NOTARY_TEAM_ID="${TFX_NOTARY_TEAM_ID:-Q6GG27UYG5}"
NOTARY_PASSWORD="${TFX_NOTARY_PASSWORD:-${TFX_NOTARY_APP_PASSWORD:-}}"
SKIP_NOTARIZATION="${TFX_SKIP_NOTARIZATION:-0}"
STAGING_DIR="${TFX_HOMEBREW_STAGING_DIR:-$ARTIFACTS_DIR/homebrew-staging}"
STAGED_APP_PATH="$STAGING_DIR/$SCHEME.app"
NOTARY_ZIP_PATH="$ARTIFACTS_DIR/$SCHEME-$VERSION-notarization.zip"
ZIP_PATH="${TFX_ZIP_PATH:-$ARTIFACTS_DIR/$SCHEME-$VERSION.zip}"
SHA256_PATH="${TFX_SHA256_PATH:-$ZIP_PATH.sha256}"
CASK_PATH="${TFX_CASK_PATH:-$ARTIFACTS_DIR/homebrew-tap/Casks/tfx.rb}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found: $APP_PATH" >&2
  echo "Run ./scripts/build_release_app.sh first." >&2
  exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ "$APP_VERSION" != "$VERSION" ]]; then
  echo "App version '$APP_VERSION' does not match release version '$VERSION'." >&2
  exit 1
fi

if ! lipo -archs "$APP_PATH/Contents/MacOS/$SCHEME" | tr ' ' '\n' | grep -qx arm64; then
  echo "The Homebrew release must contain an arm64 executable." >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
rm -f "$NOTARY_ZIP_PATH" "$ZIP_PATH" "$SHA256_PATH"
mkdir -p "$STAGING_DIR" "$(dirname "$CASK_PATH")"

echo "Staging app: $STAGED_APP_PATH"
ditto --norsrc --noextattr "$APP_PATH" "$STAGED_APP_PATH"
xattr -cr "$STAGED_APP_PATH"
find "$STAGED_APP_PATH" \( -name ".DS_Store" -o -name "._*" \) -delete

echo "Signing app with: $APP_SIGN_IDENTITY"
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$APP_SIGN_IDENTITY" \
  "$STAGED_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP_PATH"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Skipping notarization because TFX_SKIP_NOTARIZATION=1."
  echo "This artifact is for local validation only and must not be published." >&2
else
  NOTARY_AUTH_ARGS=()
  if [[ -n "$NOTARY_APPLE_ID" && -n "$NOTARY_PASSWORD" ]]; then
    NOTARY_AUTH_ARGS=(
      --apple-id "$NOTARY_APPLE_ID"
      --team-id "$NOTARY_TEAM_ID"
      --password "$NOTARY_PASSWORD"
    )
  elif [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  else
    echo "Notarization credentials are required." >&2
    echo "Set TFX_NOTARY_PROFILE, or TFX_NOTARY_APPLE_ID and TFX_NOTARY_PASSWORD." >&2
    exit 1
  fi

  echo "Creating notarization upload: $NOTARY_ZIP_PATH"
  ditto -c -k --keepParent --norsrc "$STAGED_APP_PATH" "$NOTARY_ZIP_PATH"

  echo "Submitting app to Apple's notary service"
  xcrun notarytool submit "$NOTARY_ZIP_PATH" \
    "${NOTARY_AUTH_ARGS[@]}" \
    --wait

  echo "Stapling notarization ticket"
  xcrun stapler staple "$STAGED_APP_PATH"
  xcrun stapler validate "$STAGED_APP_PATH"
  spctl --assess --type execute --verbose=2 "$STAGED_APP_PATH"

  rm -f "$NOTARY_ZIP_PATH"
fi

echo "Creating Homebrew release archive: $ZIP_PATH"
ditto -c -k --keepParent --norsrc "$STAGED_APP_PATH" "$ZIP_PATH"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "$(basename "$ZIP_PATH")" > "$SHA256_PATH"

cat > "$CASK_PATH" <<EOF
cask "tfx" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/fukuyori/tfx/releases/download/#{version}/tfx-#{version}.zip"
  name "tfx"
  desc "Keyboard-first file manager with a terminal-inspired interface"
  homepage "https://github.com/fukuyori/tfx"

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "tfx.app"
  command_wrapper "tfx", executable: "#{appdir}/tfx.app/Contents/MacOS/tfx"

  zap trash: "~/Library/Application Support/tfx"
end
EOF

echo "Built Homebrew release archive: $ZIP_PATH"
echo "Wrote checksum: $SHA256_PATH"
echo "Generated cask: $CASK_PATH"
echo "SHA-256: $SHA256"
