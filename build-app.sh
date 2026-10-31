#!/bin/sh
# Builds Nagbell.app next to this script. Run: ./build-app.sh && open Nagbell.app
set -e
cd "$(dirname "$0")"
swift build -c release

APP=Nagbell.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/" # drawn by make-icon.swift
cp .build/release/Nagbell "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Nagbell</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.tuhin.Nagbell</string>
    <key>CFBundleName</key><string>Nagbell</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$APP" # ad-hoc signature, enough to run on this Mac
rm -rf "/Applications/$APP" && cp -R "$APP" /Applications/ # so Spotlight/Launchpad find it
echo "Built $APP, installed to /Applications"
