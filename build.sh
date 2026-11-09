#!/bin/bash
# Builds LidSound.app — a double-clickable macOS app bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP="LidSound.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O lidsound.swift -o "$APP/Contents/MacOS/LidSound"
cp Info.plist "$APP/Contents/Info.plist"

echo "Built $APP"
