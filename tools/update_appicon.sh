#!/usr/bin/env bash
set -euo pipefail

# Regenerates the macOS AppIcon asset set from a 1024×1024 PNG.
# Usage:
#   tools/update_appicon.sh /path/to/icon-1024.png
# or run without args to use AboutIcon from the asset catalog:
#   tools/update_appicon.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ASSETS_DIR="$ROOT_DIR/Resources/Assets.xcassets"
APPICON_DIR="$ASSETS_DIR/AppIcon.appiconset"

SRC="${1:-$ASSETS_DIR/AboutIcon.imageset/AboutIcon.png}"

if [[ ! -f "$SRC" ]]; then
  echo "Source icon not found: $SRC" >&2
  exit 1
fi

mkdir -p "$APPICON_DIR"

sizes=(16 32 128 256 512)
for sz in "${sizes[@]}"; do
  sips -s format png --resampleHeightWidth $sz $sz "$SRC" --out "$APPICON_DIR/appicon-${sz}.png" >/dev/null
  d=$((sz*2))
  sips -s format png --resampleHeightWidth $d $d "$SRC" --out "$APPICON_DIR/appicon-${sz}@2x.png" >/dev/null
done

cat > "$APPICON_DIR/Contents.json" << 'JSON'
{
  "images": [
    {"size": "16x16",  "idiom": "mac", "filename": "appicon-16.png",  "scale": "1x"},
    {"size": "16x16",  "idiom": "mac", "filename": "appicon-16@2x.png","scale": "2x"},
    {"size": "32x32",  "idiom": "mac", "filename": "appicon-32.png",  "scale": "1x"},
    {"size": "32x32",  "idiom": "mac", "filename": "appicon-32@2x.png","scale": "2x"},
    {"size": "128x128","idiom": "mac", "filename": "appicon-128.png", "scale": "1x"},
    {"size": "128x128","idiom": "mac", "filename": "appicon-128@2x.png","scale": "2x"},
    {"size": "256x256","idiom": "mac", "filename": "appicon-256.png", "scale": "1x"},
    {"size": "256x256","idiom": "mac", "filename": "appicon-256@2x.png","scale": "2x"},
    {"size": "512x512","idiom": "mac", "filename": "appicon-512.png", "scale": "1x"},
    {"size": "512x512","idiom": "mac", "filename": "appicon-512@2x.png","scale": "2x"}
  ],
  "info": {"version": 1, "author": "codex"}
}
JSON

echo "Updated AppIcon from: $SRC"

