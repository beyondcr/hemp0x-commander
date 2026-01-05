#!/bin/bash
set -euo pipefail

# === CONFIG ===
PROJECT_ROOT="$HOME/projects/hemp0x-commander"
BASE_APPIMAGE="$HOME/Hemp_Commander_V1.1_Build/Hemp0x Commander_1.1.0_x64-portable.appimage"
OUTPUT_DIR="$HOME/Hemp_Commander_V1.2_Build"
OUTPUT_APPIMAGE="$OUTPUT_DIR/Hemp0x_Commander_1.2.0_Universal.AppImage"
APPIMAGETOOL="$PROJECT_ROOT/appimagetool-x86_64.AppImage"

echo "--- Starting Cross-Distro Build (v1.2.0) ---"

# 0. Setup Output Dir
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# 1. Check Base AppImage
if [ ! -f "$BASE_APPIMAGE" ]; then
    echo "ERROR: Base AppImage not found at: $BASE_APPIMAGE"
    # Fallback to Desktop check if user moved it
    if [ -f "$HOME/Desktop/Hemp0x_Commander_Fixed.AppImage" ]; then
        BASE_APPIMAGE="$HOME/Desktop/Hemp0x_Commander_Fixed.AppImage"
        echo "Found at Desktop: $BASE_APPIMAGE"
    else
        echo "Checking for any .appimage in V1.1 folder..."
        BASE_APPIMAGE=$(ls "$HOME/Hemp_Commander_V1.1_Build/"*.appimage | head -n 1)
        if [ -z "$BASE_APPIMAGE" ]; then
             echo "CRITICAL: No base AppImage found to extract runtime from."
             exit 1
        fi
        echo "Found: $BASE_APPIMAGE"
    fi
fi

# 2. Extract Base
echo "Extracting base AppImage..."
rm -rf squashfs-root
"$BASE_APPIMAGE" --appimage-extract >/dev/null

# 3. Update Binaries
echo "Updating binaries..."
# App Binary
cp "$PROJECT_ROOT/src-tauri/target/release/hemp0x-commander" squashfs-root/usr/bin/hemp0x-commander
# Daemon
cp "$PROJECT_ROOT/src-tauri/hemp0xd-x86_64-unknown-linux-gnu" squashfs-root/usr/bin/hemp0xd
# CLI
cp "$PROJECT_ROOT/src-tauri/hemp0x-cli-x86_64-unknown-linux-gnu" squashfs-root/usr/bin/hemp0x-cli

# 4. Strip (Size Reduction)
echo "Stripping binaries..."
strip --strip-unneeded squashfs-root/usr/bin/hemp0x-commander
strip --strip-unneeded squashfs-root/usr/bin/hemp0xd
strip --strip-unneeded squashfs-root/usr/bin/hemp0x-cli

# 5. Repack
echo "Repacking..."
export ARCH=x86_64
"$APPIMAGETOOL" squashfs-root "$OUTPUT_APPIMAGE" --no-appstream

echo "--- Build Complete ---"
ls -lh "$OUTPUT_APPIMAGE"
