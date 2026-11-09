#!/bin/bash
# Builds Clap.app — a double-clickable macOS app bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP="Clap.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O clap.swift -o "$APP/Contents/MacOS/Clap"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "Built $APP"
