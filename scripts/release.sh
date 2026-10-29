#!/usr/bin/env bash
# Build, sign, notarize and package a release DMG locally, and (with --publish)
# upload it to a GitHub release and bump the Homebrew cask.
#
# Usage:
#   scripts/release.sh <version>            # build + sign + notarize + DMG (no publish)
#   scripts/release.sh <version> --publish  # also: GitHub release + cask bump/push
#
# Publishing creates the v<version> tag, which later builds take their version
# from. The signing identity is the first "Developer ID Application" in the
# keychain, or LEAP_SIGN_IDENTITY. With none it builds an ad-hoc, un-notarized
# DMG – a dry run that refuses to publish. Notary credentials come from a
# keychain profile created with `xcrun notarytool store-credentials` (default
# leap-widget-notary, override with LEAP_NOTARY_PROFILE).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD_DIR="$ROOT/build"

VERSION="${1:-}"
PUBLISH=0
[ "${2:-}" = "--publish" ] && PUBLISH=1

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: scripts/release.sh <x.y.z> [--publish]" >&2
  exit 1
fi

TAG="v$VERSION"
APP="$BUILD_DIR/Build/Products/Release/Leap Widget.app"
WIDGET="$APP/Contents/PlugIns/LeapWidget.appex"
DMG="$BUILD_DIR/Leap-Widget-$VERSION.dmg"
NOTARY_PROFILE="${LEAP_NOTARY_PROFILE:-leap-widget-notary}"
TAP_REPO="antavik/homebrew-apps"

SIGN_ID="${LEAP_SIGN_IDENTITY:-}"
if [ -z "$SIGN_ID" ]; then
  # awk reads to the end: quitting early could SIGPIPE security under pipefail.
  SIGN_ID="$(security find-identity -v -p codesigning |
    awk -F'"' '/Developer ID Application/ && !id { id = $2 } END { print id }')"
fi
if [ -n "$SIGN_ID" ]; then
  SIGNED=1
  echo "==> signing identity: $SIGN_ID"
else
  SIGNED=0
  echo "==> WARNING: no Developer ID Application identity – building AD-HOC (dry run, not notarized)"
fi

if [ "$PUBLISH" = "1" ]; then
  [ "$SIGNED" = "1" ] || { echo "refusing to --publish an ad-hoc build" >&2; exit 1; }
  # XcodeGen compiles untracked sources too, so they count as uncommitted.
  [ -z "$(git status --porcelain)" ] || { echo "commit or stash changes first" >&2; exit 1; }
  # The release tags HEAD on GitHub: check here, not after a long notarization.
  git fetch -q --tags origin
  [ -n "$(git branch -r --contains HEAD)" ] || { echo "push HEAD first: the release tags it" >&2; exit 1; }
  # A re-run may finish a release of HEAD; it must never replace another commit's DMG.
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null &&
     [ "$(git rev-list -n 1 "$TAG")" != "$(git rev-parse HEAD)" ]; then
    echo "$TAG already tags another commit" >&2
    exit 1
  fi
fi

# Submit and wait; on anything but Accepted, print the notary log and stop.
notarize() {
  local path="$1" json status id
  echo "==> notarizing $(basename "$path")"
  json="$(xcrun notarytool submit "$path" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
  status="$(printf '%s' "$json" | jq -r '.status')"
  id="$(printf '%s' "$json" | jq -r '.id')"
  if [ "$status" != "Accepted" ]; then
    echo "notarization failed: status=$status" >&2
    xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" || true
    exit 1
  fi
}

# ── build ────────────────────────────────────────────────────────────────────
# Ad-hoc Release build; Developer ID is applied afterwards, with the secure
# timestamp notarization requires.
make release APP_VERSION="$VERSION"
[ -d "$APP" ] || { echo "expected app not found: $APP" >&2; exit 1; }

# ── sign, inside-out ─────────────────────────────────────────────────────────
# The widget keeps its sandbox entitlement; the app has none. No --deep: it
# would sign the widget without its entitlements.
if [ "$SIGNED" = "1" ]; then
  echo "==> signing Developer ID (timestamped)"
  codesign --force --options runtime --timestamp \
    --entitlements "$ROOT/LeapWidget/LeapWidget.entitlements" --sign "$SIGN_ID" "$WIDGET"
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
  codesign --verify --deep --strict "$APP"
fi

# ── notarize + staple the app ─────────────────────────────────────────────────
# Stapled so a copy dragged out of the DMG passes Gatekeeper offline too.
if [ "$SIGNED" = "1" ]; then
  ZIP="$BUILD_DIR/Leap-Widget-$VERSION.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  notarize "$ZIP"
  rm -f "$ZIP"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl -a -vv --type execute "$APP"
fi

# ── package the DMG ───────────────────────────────────────────────────────────
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Leap Widget" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

# ── sign + notarize + staple the DMG ──────────────────────────────────────────
# hdiutil makes an unsigned image; spctl rejects it without its own signature.
if [ "$SIGNED" = "1" ]; then
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
  notarize "$DMG"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl -a -vv -t open --context context:primary-signature "$DMG"
fi

echo "==> built: $DMG"

if [ "$PUBLISH" != "1" ]; then
  echo "==> dry run complete (pass --publish to upload + bump the cask)"
  exit 0
fi

# ── publish: GitHub release + cask bump ───────────────────────────────────────
# --target tags the commit that was built, not the tip of the default branch;
# GitHub rejects it until that commit is pushed.
echo "==> publishing $TAG"
NOTES="Signed with a Developer ID certificate and notarized by Apple. macOS 14 or later.

- **Homebrew:** \`brew install --cask antavik/apps/leap-widget\`
- **Direct download:** open the \`.dmg\` and drag \`Leap Widget.app\` into \`/Applications\`."
if ! gh release view "$TAG" >/dev/null 2>&1; then
  gh release create "$TAG" --target "$(git rev-parse HEAD)" \
    --title "Leap Widget $VERSION" --notes "$NOTES"
fi
gh release upload "$TAG" "$DMG" --clobber
# The tag was made on GitHub; fetch it so local builds pick up the new version.
git fetch -q --tags origin

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
TAP_DIR="$(mktemp -d)"
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --depth=1 >/dev/null
CASK="$TAP_DIR/Casks/leap-widget.rb"
if [ ! -f "$CASK" ]; then
  mkdir -p "$TAP_DIR/Casks"
  cp "$ROOT/packaging/leap-widget.rb" "$CASK" # first publish: seed from the in-repo source of truth
fi
sed -i '' -E "s/^( *version )\".*\"/\1\"$VERSION\"/" "$CASK"
sed -i '' -E "s/^( *sha256 )\".*\"/\1\"$SHA\"/" "$CASK"
git -C "$TAP_DIR" add Casks/leap-widget.rb
if git -C "$TAP_DIR" diff --cached --quiet; then
  echo "==> cask already at $VERSION, nothing to push"
else
  git -C "$TAP_DIR" commit -m "leap-widget $VERSION"
  git -C "$TAP_DIR" push
  echo "==> cask bumped to $VERSION"
fi
rm -rf "$TAP_DIR"
echo "==> done"
