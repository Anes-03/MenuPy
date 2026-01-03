#!/usr/bin/env bash
set -euo pipefail

# Build a Release .app and package DMG + ZIP into dist/ using the app's version.
# Usage:
#   tools/make_dist.sh [--scheme MenuPy] [--configuration Release] [--sign]
#
# By default, code signing is disabled (for local testing). Pass --sign to
# allow Xcode to sign with your configured settings.

SCHEME="MenuPy"
CONFIG="Release"
ALLOW_SIGNING="NO"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme) SCHEME="$2"; shift 2 ;;
    --configuration|--config) CONFIG="$2"; shift 2 ;;
    --sign) ALLOW_SIGNING="YES"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo "Building scheme=$SCHEME configuration=$CONFIG signing_allowed=$ALLOW_SIGNING" >&2

xcodebuild -project MenuPy.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" clean >/dev/null
xcodebuild -project MenuPy.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" CODE_SIGNING_ALLOWED=$ALLOW_SIGNING -destination 'platform=macOS' build >/dev/null

# Locate the built app
BUILD_DIR=$(xcodebuild -project MenuPy.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" -showBuildSettings 2>/dev/null | sed -n 's/^ *TARGET_BUILD_DIR = //p' | tail -1)
FULL_PRODUCT_NAME=$(xcodebuild -project MenuPy.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" -showBuildSettings 2>/dev/null | sed -n 's/^ *FULL_PRODUCT_NAME = //p' | tail -1)
APP_PATH="$BUILD_DIR/$FULL_PRODUCT_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build artifact not found: $APP_PATH" >&2
  exit 1
fi

# Version for filenames
PLIST="$APP_PATH/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")
if [[ -z "$VERSION" ]]; then VERSION="0.0.0"; fi

DIST_DIR="dist"
mkdir -p "$DIST_DIR"

# Create a pretty DMG with Applications link
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications" 2>/dev/null || true

DMG_PATH="$DIST_DIR/MenuPy-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/MenuPy-$VERSION.zip"

hdiutil create -volname "MenuPy" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH" >/dev/null

(cd "$(dirname "$APP_PATH")" && ditto -c -k --sequesterRsrc --keepParent "$FULL_PRODUCT_NAME" "$(cd - >/dev/null; pwd)/$ZIP_PATH")

echo "Artifacts:"
ls -lh "$DMG_PATH" "$ZIP_PATH"

