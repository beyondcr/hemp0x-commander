#!/bin/bash
set -ex

# Define Paths
PROJECT_DIR="$HOME/projects/hemp0x-commander1.3"
BUILD_TOOLS="$PROJECT_DIR/build_tools"
APPDIR="$PROJECT_DIR/src-tauri/target/release/bundle/appimage/Hemp0x_Commander.AppDir"
OUTPUT_IMAGE="$PROJECT_DIR/Hemp0x_Commander_1.3.0_Linux_Universal.AppImage"

# Ensure Environment
export LINUXDEPLOY_PLUGIN_PATH="$BUILD_TOOLS"
export ARCH=x86_64

echo "--- Starting Repair Build ---"

# 1. Run LinuxDeploy with GTK Plugin to populate resources
# Note: We point to the AppDir and ask it to use the GTK plugin. 
# It might complain about missing binaries if not found, but we know they are in usr/bin.
"$BUILD_TOOLS/linuxdeploy-x86_64.AppImage" --appdir "$APPDIR" --plugin gtk || true

echo "--- LinuxDeploy Finished (Ignoring errors) ---"

echo "--- LinuxDeploy Finished ---"

# 2. Universal Fix: Move bundled libraries to lib_bak (Hides them from loader but keeps them)
echo "Moving bundled libraries to lib_bak..."
if [ -d "$APPDIR/usr/lib" ]; then
    mv "$APPDIR/usr/lib" "$APPDIR/usr/lib_bak"
    mkdir -p "$APPDIR/usr/lib"
fi

# 3. Strip Binaries (Optimized for size/stability)
echo "Stripping binaries..."
strip --strip-unneeded "$APPDIR/usr/bin/hemp0xd" || true
strip --strip-unneeded "$APPDIR/usr/bin/hemp0x-cli" || true
strip --strip-unneeded "$APPDIR/usr/bin/hemp0x-commander" || true

# 4. Pack
echo "Packing AppImage..."
"$BUILD_TOOLS/appimagetool-x86_64.AppImage" --no-appstream "$APPDIR" "$OUTPUT_IMAGE"

echo "--- Build Success! ---"
ls -lh "$OUTPUT_IMAGE"
