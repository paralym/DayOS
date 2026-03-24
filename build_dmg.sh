#!/bin/bash
set -e

APP_NAME="DayOS"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"
RELEASE_DIR="${BUILD_DIR}/Build/Products/Release"
APP_PATH="${RELEASE_DIR}/${APP_NAME}.app"
STAGING_DIR="${BUILD_DIR}/dmg_staging"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     DAYOS — BUILD & PACKAGE DMG      ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Check Xcode ────────────────────────────────────────────────────────────
if ! xcodebuild -version &>/dev/null; then
    XCODE_PATH=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -1)
    if [ -n "$XCODE_PATH" ]; then
        echo "► Setting Xcode path: $XCODE_PATH"
        sudo xcode-select -s "${XCODE_PATH}/Contents/Developer"
    else
        echo "✗ Xcode not found. Install it from the App Store first."
        exit 1
    fi
fi
echo "► Xcode: $(xcodebuild -version | head -1)"

# ── 2. Generate icons (if not already done) ───────────────────────────────────
if [ ! -f "Assets.xcassets/AppIcon.appiconset/icon_512x512.png" ]; then
    echo "► Generating icons..."
    python3 generate_icon.py
fi

# ── 3. Build Release ──────────────────────────────────────────────────────────
echo "► Building ${APP_NAME} (Release)..."
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme  "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    clean build 2>&1 | tee /tmp/dayos_build.log | grep -E "(error:|Build succeeded|BUILD FAILED|\*\* BUILD)" || true

if [ ! -d "$APP_PATH" ]; then
    echo "✗ Build failed — ${APP_PATH} not found."
    exit 1
fi
echo "✓ Build succeeded: ${APP_PATH}"

# ── 4. Create DMG ─────────────────────────────────────────────────────────────
echo "► Creating DMG..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Temp DMG
TEMP_DMG="${BUILD_DIR}/temp.dmg"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDRW \
    "$TEMP_DMG" > /dev/null

# Optional: set background / icon layout (skipped for simplicity)

# Compress to final DMG
rm -f "$DMG_NAME"
hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_NAME" > /dev/null
rm -f "$TEMP_DMG"

echo "✓ DMG created: $(pwd)/${DMG_NAME}"
echo ""
echo "  → Drag DayOS to Applications to install."
echo "  → First launch: right-click → Open (bypasses Gatekeeper)"
echo ""

# Open Finder at the DMG location
open -R "$DMG_NAME"
