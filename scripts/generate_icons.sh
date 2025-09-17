#!/bin/bash

# Script to generate app icons for all platforms from the source icon
# Requires ImageMagick (convert command)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ICON_SOURCE="$PROJECT_ROOT/assets/app_icon.png"

echo "🎨 Generating app icons from $ICON_SOURCE"

# Check if source icon exists
if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "❌ Error: Source icon not found at $ICON_SOURCE"
    exit 1
fi

# Check if ImageMagick is available
if ! command -v convert &> /dev/null; then
    echo "❌ Error: ImageMagick 'convert' command not found. Please install ImageMagick."
    echo "   Ubuntu/Debian: sudo apt-get install imagemagick"
    echo "   macOS: brew install imagemagick"
    echo "   Windows: Download from https://imagemagick.org/script/download.php"
    exit 1
fi

cd "$PROJECT_ROOT"

# Android icons
echo "📱 Generating Android icons..."
mkdir -p android/app/src/main/res/{mipmap-mdpi,mipmap-hdpi,mipmap-xhdpi,mipmap-xxhdpi,mipmap-xxxhdpi}
convert "$ICON_SOURCE" -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
convert "$ICON_SOURCE" -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
convert "$ICON_SOURCE" -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
convert "$ICON_SOURCE" -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
convert "$ICON_SOURCE" -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# iOS icons
echo "🍎 Generating iOS icons..."
cd ios/Runner/Assets.xcassets/AppIcon.appiconset
convert "$ICON_SOURCE" -resize 1024x1024 Icon-App-1024x1024@1x.png
convert "$ICON_SOURCE" -resize 20x20 Icon-App-20x20@1x.png
convert "$ICON_SOURCE" -resize 40x40 Icon-App-20x20@2x.png
convert "$ICON_SOURCE" -resize 60x60 Icon-App-20x20@3x.png
convert "$ICON_SOURCE" -resize 29x29 Icon-App-29x29@1x.png
convert "$ICON_SOURCE" -resize 58x58 Icon-App-29x29@2x.png
convert "$ICON_SOURCE" -resize 87x87 Icon-App-29x29@3x.png
convert "$ICON_SOURCE" -resize 40x40 Icon-App-40x40@1x.png
convert "$ICON_SOURCE" -resize 80x80 Icon-App-40x40@2x.png
convert "$ICON_SOURCE" -resize 120x120 Icon-App-40x40@3x.png
convert "$ICON_SOURCE" -resize 50x50 Icon-App-50x50@1x.png
convert "$ICON_SOURCE" -resize 100x100 Icon-App-50x50@2x.png
convert "$ICON_SOURCE" -resize 57x57 Icon-App-57x57@1x.png
convert "$ICON_SOURCE" -resize 114x114 Icon-App-57x57@2x.png
convert "$ICON_SOURCE" -resize 120x120 Icon-App-60x60@2x.png
convert "$ICON_SOURCE" -resize 180x180 Icon-App-60x60@3x.png
convert "$ICON_SOURCE" -resize 72x72 Icon-App-72x72@1x.png
convert "$ICON_SOURCE" -resize 144x144 Icon-App-72x72@2x.png
convert "$ICON_SOURCE" -resize 76x76 Icon-App-76x76@1x.png
convert "$ICON_SOURCE" -resize 152x152 Icon-App-76x76@2x.png
convert "$ICON_SOURCE" -resize 167x167 Icon-App-83.5x83.5@2x.png
cd "$PROJECT_ROOT"

# macOS icons
echo "🖥️  Generating macOS icons..."
convert "$ICON_SOURCE" -resize 16x16 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
convert "$ICON_SOURCE" -resize 32x32 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
convert "$ICON_SOURCE" -resize 64x64 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
convert "$ICON_SOURCE" -resize 128x128 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
convert "$ICON_SOURCE" -resize 256x256 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
convert "$ICON_SOURCE" -resize 512x512 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
convert "$ICON_SOURCE" -resize 1024x1024 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png

# Windows icon
echo "🪟 Generating Windows icon..."
mkdir -p windows/runner/resources
convert "$ICON_SOURCE" -resize 256x256 windows/runner/resources/app_icon.ico

# Web favicon
echo "🌐 Generating Web favicon..."
convert "$ICON_SOURCE" -resize 32x32 web/favicon.png

echo "✅ App icons generated successfully!"
echo "📝 Note: These files are ignored by git and should not be committed."
echo "🔄 Run this script again after updating assets/app_icon.png"
