#!/usr/bin/env bash
set -euo pipefail

# Publishes a packaged release (steps after package_homebrew_release.sh):
#   1. Creates the GitHub Release for the version tag with the matching
#      CHANGELOG section as its body and the release zip attached.
#   2. Commits the regenerated cask in the tap clone and pushes it.
#
# Prerequisites:
#   - ./scripts/build_release_app.sh and ./scripts/package_homebrew_release.sh
#     have been run for this version.
#   - The version bump commit is already pushed to the main repository
#     (the release tag is created from the current remote HEAD).
#   - `gh` is authenticated for github.com.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR_DEFAULT="$ROOT_DIR/artifacts"
RELEASE_INFO_PATH="${TFX_RELEASE_INFO:-$ARTIFACTS_DIR_DEFAULT/release-info.env}"

if [[ ! -f "$RELEASE_INFO_PATH" ]]; then
  echo "Release metadata not found: $RELEASE_INFO_PATH" >&2
  echo "Run ./scripts/build_release_app.sh and ./scripts/package_homebrew_release.sh first." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$RELEASE_INFO_PATH"

ARTIFACTS_DIR="${TFX_ARTIFACTS_DIR:-$ARTIFACTS_DIR_DEFAULT}"
SCHEME="${TFX_SCHEME:-tfx}"
VERSION="${TFX_VERSION:?Missing TFX_VERSION in release metadata.}"
ZIP_PATH="${TFX_ZIP_PATH:-$ARTIFACTS_DIR/$SCHEME-$VERSION.zip}"
CASK_PATH="${TFX_CASK_PATH:-$ARTIFACTS_DIR/homebrew-tap/Casks/tfx.rb}"
TAP_DIR="${TFX_TAP_DIR:-$ARTIFACTS_DIR/homebrew-tap}"
CHANGELOG_PATH="${TFX_CHANGELOG_PATH:-$ROOT_DIR/CHANGELOG.md}"
MAIN_REPO="${TFX_MAIN_REPO:-fukuyori/tfx}"

for tool in gh git shasum; do
  command -v "$tool" >/dev/null || { echo "Required tool not found: $tool" >&2; exit 1; }
done

# --- Preflight: packaged artifacts exist and agree with each other ---

[[ -f "$ZIP_PATH" ]] || { echo "Release archive not found: $ZIP_PATH" >&2; exit 1; }
[[ -f "$CASK_PATH" ]] || { echo "Generated cask not found: $CASK_PATH" >&2; exit 1; }

CASK_VERSION="$(awk -F '"' '/^  version / { print $2; exit }' "$CASK_PATH")"
if [[ "$CASK_VERSION" != "$VERSION" ]]; then
  echo "Cask version '$CASK_VERSION' does not match release version '$VERSION'." >&2
  echo "Re-run ./scripts/package_homebrew_release.sh." >&2
  exit 1
fi

CASK_SHA256="$(awk -F '"' '/^  sha256 / { print $2; exit }' "$CASK_PATH")"
ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
if [[ "$CASK_SHA256" != "$ZIP_SHA256" ]]; then
  echo "Cask sha256 does not match $ZIP_PATH." >&2
  echo "  cask: $CASK_SHA256" >&2
  echo "  zip:  $ZIP_SHA256" >&2
  echo "Re-run ./scripts/package_homebrew_release.sh." >&2
  exit 1
fi

[[ -d "$TAP_DIR/.git" ]] || { echo "Tap clone not found: $TAP_DIR" >&2; exit 1; }

# --- Release notes: the CHANGELOG section for this version ---

NOTES_PATH="$(mktemp -t tfx-release-notes)"
trap 'rm -f "$NOTES_PATH"' EXIT
awk -v version="$VERSION" '
  $0 ~ "^## \\[" version "\\]" { printing = 1 }
  printing && $0 ~ "^## \\[" && $0 !~ "^## \\[" version "\\]" { exit }
  printing { print }
' "$CHANGELOG_PATH" > "$NOTES_PATH"

if [[ ! -s "$NOTES_PATH" ]]; then
  echo "No CHANGELOG section found for [$VERSION] in $CHANGELOG_PATH." >&2
  exit 1
fi

# --- Step 1: GitHub Release ---

if gh release view "$VERSION" --repo "$MAIN_REPO" >/dev/null 2>&1; then
  echo "Release $VERSION already exists; re-uploading the archive."
  gh release upload "$VERSION" "$ZIP_PATH" --repo "$MAIN_REPO" --clobber
else
  echo "Creating GitHub release $VERSION on $MAIN_REPO"
  gh release create "$VERSION" "$ZIP_PATH" \
    --repo "$MAIN_REPO" \
    --title "$VERSION" \
    --notes-file "$NOTES_PATH"
fi

# --- Step 2: Tap update ---

if [[ -n "$(git -C "$TAP_DIR" status --porcelain --untracked-files=no -- . ':!Casks/tfx.rb')" ]]; then
  echo "Tap clone has unrelated uncommitted changes; refusing to commit." >&2
  git -C "$TAP_DIR" status --short >&2
  exit 1
fi

echo "Syncing tap clone with origin"
git -C "$TAP_DIR" pull --ff-only

if git -C "$TAP_DIR" diff --quiet -- Casks/tfx.rb; then
  echo "Cask already up to date in the tap; nothing to commit."
else
  git -C "$TAP_DIR" add Casks/tfx.rb
  git -C "$TAP_DIR" commit -m "Update tfx to $VERSION"
fi

echo "Pushing tap"
git -C "$TAP_DIR" push

echo
echo "Published tfx $VERSION:"
echo "  release: https://github.com/$MAIN_REPO/releases/tag/$VERSION"
echo "  cask:    $CASK_PATH"
echo "Verify with: brew update && brew upgrade --cask tfx"
