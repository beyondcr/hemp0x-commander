#!/bin/bash
set -e

# CONSTANTS
ENGINE="podman"
APP_NAME="Hemp0x_Commander"
VERSION="1.3.0"
# Default path for Legacy Runtime (user can override or place in root)
LEGACY_APPIMAGE_PATH="${LEGACY_APPIMAGE_PATH:-$PROJECT_DIR/Hemp0x_Commander_1.2.0_Universal_Fixed.AppImage}"
DOCKER_IMAGE_NAME="hemp0x-builder-2204"
PROJECT_DIR=$(pwd)
OUTPUT_DIR="$PROJECT_DIR/release"
mkdir -p "$OUTPUT_DIR"
# ... (Header OK)

# ... (Docker Check OK)

# 1.5. FETCH DEPENDENCIES (Binaries)
echo "[0/5] Preparing Daemon Binaries..."

# Define paths
NEW_BINARIES_DIR="$PROJECT_DIR/binaries_new"
SRC_TAURI_BIN="$PROJECT_DIR/src-tauri/binaries"
# Clean and create
rm -rf "$SRC_TAURI_BIN"
mkdir -p "$SRC_TAURI_BIN"

# Check if binaries exist in the dedicated 'new' folder
if [ -f "$NEW_BINARIES_DIR/hemp0xd" ] && [ -f "$NEW_BINARIES_DIR/hemp0x-cli" ]; then
    echo "   Using Clean/New Binaries from: $NEW_BINARIES_DIR"
    
    cp "$NEW_BINARIES_DIR/hemp0xd" "$SRC_TAURI_BIN/hemp0xd-x86_64-unknown-linux-gnu"
    cp "$NEW_BINARIES_DIR/hemp0x-cli" "$SRC_TAURI_BIN/hemp0x-cli-x86_64-unknown-linux-gnu"
    
    chmod +x "$SRC_TAURI_BIN/hemp0xd-x86_64-unknown-linux-gnu"
    chmod +x "$SRC_TAURI_BIN/hemp0x-cli-x86_64-unknown-linux-gnu"
    
    echo "   Stripping binaries to reduce size..."
    strip --strip-unneeded "$SRC_TAURI_BIN/hemp0xd-x86_64-unknown-linux-gnu" || true
    strip --strip-unneeded "$SRC_TAURI_BIN/hemp0x-cli-x86_64-unknown-linux-gnu" || true

    echo "   Daemons copied to src-tauri/binaries/"
else
    echo "Error: Clean binaries not found in $NEW_BINARIES_DIR"
    echo "Please ensure 'hemp0xd' and 'hemp0x-cli' are in $NEW_BINARIES_DIR"
    exit 1
fi

# ...

# 3. RUN BUILD & PACKAGING INSIDE CONTAINER
echo "[2/5] Compiling & Packaging (Inside Container)..."
# We define the inner script here to avoid mounting extra files
cat <<EOF > scripts/internal_build.sh
#!/bin/bash
set -e
shopt -s nullglob # Prevent globbing errors

export APPIMAGE_EXTRACT_AND_RUN=1 # Bypass FUSE
cd /app

# B. Build Application
echo "--> Starting npm install..."
npm install || { echo "npm install failed"; exit 1; }

echo "--> Updating Rust dependencies (fix version mismatch)..."
cargo update --manifest-path src-tauri/Cargo.toml

echo "--> npm install complete. Checking tauri binary..."
ls -l node_modules/.bin/tauri
echo "--> Running tauri info..."
./node_modules/.bin/tauri info || echo "tauri info failed"
echo "--> Starting tauri build (verbose)..."
./node_modules/.bin/tauri build > tauri_build_out.log 2>&1 || { 
    echo "tauri build failed! Dumping log:"
    tail -n 100 tauri_build_out.log
    exit 1
}
echo "--> tauri build complete."

# C. Define APPDIR (Dynamic detection for Tauri v2 naming)
APPDIR=\$(find /app/src-tauri/target/release/bundle/appimage -maxdepth 1 -name "*.AppDir" | head -n 1)
if [ -z "\$APPDIR" ]; then
    echo "Error: Could not find AppDir in /app/src-tauri/target/release/bundle/appimage/"
    ls -F /app/src-tauri/target/release/bundle/appimage/
    exit 1
fi
echo "APPDIR is found at: '\$APPDIR'"

# A. Install Dependencies (Rust/Node) - Handled by Image mostly, but ensure setup
source \$HOME/.cargo/env || true

# ...

# D. OPTIMIZATION (The "Slim" Logic)
echo "--> Optimizing Size (Slimming)..."
# Move to lib_bak for Universal Fix (Clean first to avoid mov errors)
if [ -d "\$APPDIR/usr/lib_bak" ]; then
    rm -rf "\$APPDIR/usr/lib_bak"
fi
mv "\$APPDIR/usr/lib" "\$APPDIR/usr/lib_bak"
mkdir -p "\$APPDIR/usr/lib"

# PRUNE BLOAT (LLVM/Drivers/Docs)
rm -rf "\$APPDIR/usr/lib_bak/libLLVM"*
rm -rf "\$APPDIR/usr/lib_bak/dri"
rm -rf "\$APPDIR/usr/share/doc"
rm -rf "\$APPDIR/usr/share/man"
# rm -rf "\$APPDIR/usr/share/applications" # PRESERVE: Deleting this breaks the root desktop file symlink!
rm -rf "\$APPDIR/usr/lib/girepository-1.0"
rm -rf "\$APPDIR/usr/lib_bak/girepository-1.0"

# REMOVE REDUNDANT NESTED LIBS (Fixes 240MB duplication)
if [ -d "\$APPDIR/usr/lib_bak/lib" ]; then
    echo "   Removing redundant nested lib folder..."
    rm -rf "\$APPDIR/usr/lib_bak/lib"
fi

# AGGRESSIVE STRIPPING (The 65MB Goal)
echo "   Aggressive Stripping of Libraries..."
find "\$APPDIR" -type f -name "*.so*" -exec strip --strip-unneeded {} \; || true
find "\$APPDIR" -type f -executable -exec strip --strip-unneeded {} \; || true

# Strip binaries again just in case
strip --strip-unneeded "\$APPDIR/usr/bin/hemp0xd" || true
strip --strip-unneeded "\$APPDIR/usr/bin/hemp0x-commander" || true


# E. Generate Intermediate AppImage
echo "--> Generating Intermediate AppImage..."
# Check for 'file' util
if ! command -v file &> /dev/null; then apt-get update && apt-get install -y file; fi

ARCH=x86_64 /build_tools/appimagetool-x86_64.AppImage --no-appstream "\$APPDIR" "Internal_Docker_AppImage.AppImage"
mv "Internal_Docker_AppImage.AppImage" "/app/release/"
EOF

chmod +x scripts/internal_build.sh
# Run container
$ENGINE run --rm -v "$PROJECT_DIR:/app:Z" -w /app "$DOCKER_IMAGE_NAME" /bin/bash /app/scripts/internal_build.sh

echo "[3/5] Extracting & Patching with Legacy V1.2 Runtime..."
# 4. EXTRACT & REPACK (LEGACY RUNTIME)
DOCKER_APPIMAGE="$OUTPUT_DIR/Internal_Docker_AppImage.AppImage"
FINAL_APPIMAGE="$OUTPUT_DIR/${APP_NAME}_${VERSION}_Universal_Linux.AppImage"

if [ ! -f "$DOCKER_APPIMAGE" ]; then
    echo "Error: Docker build failed to produce AppImage."
    exit 1
fi

# Extract v1.2 Runtime Header
if [ -f "$LEGACY_APPIMAGE_PATH" ]; then
    echo "   Using Legacy Runtime from: $LEGACY_APPIMAGE_PATH"
    OFFSET=$("$LEGACY_APPIMAGE_PATH" --appimage-offset)
    dd if="$LEGACY_APPIMAGE_PATH" of="runtime_header_v1.2" bs=1 count="$OFFSET" status=none
else
    echo "Error: Legacy v1.2 AppImage not found at $LEGACY_APPIMAGE_PATH"
    echo "Cannot patch runtime. Exiting."
    exit 1
fi

# Extract Docker AppImage
echo "   Extracting payload..."
chmod +x "$DOCKER_APPIMAGE"
# Use extracting on host (requires FUSE or simple extract)
# We assume current host can extract or we use --appimage-extract which usually works.
"$DOCKER_APPIMAGE" --appimage-extract > /dev/null

# Repack with ZSTD (High Compression) - Supported by v1.2 Runtime & Smaller than GZIP
echo "   Repacking payload (ZSTD-22)..."
rm -f payload.sqfs
mksquashfs squashfs-root payload.sqfs -root-owned -noappend -comp zstd -Xcompression-level 22 -quiet

# Concatenate
echo "   Fusing Runtime + Payload..."
cat runtime_header_v1.2 payload.sqfs > "$FINAL_APPIMAGE"
chmod +x "$FINAL_APPIMAGE"

# 5. CLEANUP
echo "[4/5] Cleaning up..."
rm -rf squashfs-root payload.sqfs runtime_header_v1.2 scripts/internal_build.sh "$DOCKER_APPIMAGE"

echo "========================================================"
echo "BUILD COMPLETE!"
echo "Artifact: $FINAL_APPIMAGE"
ls -lh "$FINAL_APPIMAGE"
echo "========================================================"
