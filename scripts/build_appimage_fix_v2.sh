#!/bin/bash
set -euo pipefail

# === CONFIG ===
# Using binaries we built/deployed to ~/hemp0x-deploy/hemp0x-core
FIXED_BIN_DIR="$HOME/hemp0x-deploy/hemp0x-core/src"

# Base AppImage provided by user (EXACT PATH V1.2)
BASE_APPIMAGE="$HOME/Hemp_Commander_V1.2_Build/Hemp0x_Commander_1.2.0_Universal.AppImage"

OUTPUT_DIR="$HOME/hemp0x-appimage-fix-v2"
OUTPUT_APPIMAGE="$OUTPUT_DIR/Hemp0x_Commander_1.2.0_Universal_Fixed.AppImage"
# Using whatever appimagetool is available or assuming known path
APPIMAGETOOL="$HOME/projects/hemp0x-commander/appimagetool-x86_64.AppImage"

echo "--- Starting Emergency AppImage Repack (v1.2.0 Fix V2) ---"
echo "Binary Source: $FIXED_BIN_DIR"
echo "Base AppImage: $BASE_APPIMAGE"

if [ ! -f "$FIXED_BIN_DIR/hemp0xd" ]; then
    echo "ERROR: Fixed binaries not found at $FIXED_BIN_DIR"
    exit 1
fi

if [ ! -f "$BASE_APPIMAGE" ]; then
    echo "ERROR: Base AppImage not found at $BASE_APPIMAGE"
    exit 1
fi

# 0. Setup Output Dir
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Try to find valid appimagetool if not at hardcoded path
if [ ! -f "$APPIMAGETOOL" ]; then
    # Try current dir or similar
    APPIMAGETOOL=$(find $HOME -name "appimagetool-x86_64.AppImage" | head -n 1)
fi

if [ -z "$APPIMAGETOOL" ] || [ ! -f "$APPIMAGETOOL" ]; then
    echo "ERROR: appimagetool not found"
    exit 1
fi

# 1. Extract Base
echo "Extracting base AppImage..."
rm -rf squashfs-root
"$BASE_APPIMAGE" --appimage-extract >/dev/null

# 2. Update Binaries with FIXED versions
echo "Updating binaries..."
# Overwrite daemon/cli
cp "$FIXED_BIN_DIR/hemp0xd" squashfs-root/usr/bin/hemp0xd
cp "$FIXED_BIN_DIR/hemp0x-cli" squashfs-root/usr/bin/hemp0x-cli

# Verify Copy
echo "Verifying placement..."
ls -lh squashfs-root/usr/bin/hemp0xd squashfs-root/usr/bin/hemp0x-cli

# 3. Strip (Size Reduction)
echo "Stripping binaries..."
strip --strip-unneeded squashfs-root/usr/bin/hemp0xd
strip --strip-unneeded squashfs-root/usr/bin/hemp0x-cli

# 4. Repack
echo "Repacking..."
export ARCH=x86_64
chmod +x "$APPIMAGETOOL"
"$APPIMAGETOOL" squashfs-root "$OUTPUT_APPIMAGE" --no-appstream

echo "--- Build Complete ---"
ls -lh "$OUTPUT_APPIMAGE"
