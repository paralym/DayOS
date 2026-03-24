#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       DAYOS — PROJECT SETUP          ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Generate pixel art icons
echo "► Generating pixel art icons..."
python3 generate_icon.py
echo ""

# Check for xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo "► xcodegen not found — installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "ERROR: Homebrew not found. Please install it first: https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi

echo "► Generating Xcode project..."
xcodegen generate

echo ""
echo "✓ Done! Opening in Xcode..."
open DayOS.xcodeproj
