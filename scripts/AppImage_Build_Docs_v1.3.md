# Hemp0x Commander - Universal Linux Build Guide (v1.3)

**One Script to Build Them All.**

This guide describes how to generate the official **Universal Linux AppImage** for Hemp0x Commander. This artifact is optimized (<85MB) and patched to work on:
*   **Modern Distros** (Fedora, Nobara, Arch)
*   **Older LTS Distros** (Ubuntu 20.04/22.04, Debian 11/12)
*   **Systems without `libfuse2`** (via Legacy Runtime Magic)

## 1. Setup & Pre-Requisites

### A. Folder Structure
Ensure your project directory looks like this before building:

```
hemp0x-commander1.3/
├── binaries_new/           <-- PLACE CLEAN BINARIES HERE
│   ├── hemp0xd
│   └── hemp0x-cli
├── Hemp0x_Commander_1.2.0_Universal_Fixed.AppImage  <-- PLACE LEGACY v1.2 APPIMAGE HERE
├── scripts/
│   └── build_linux_universal.sh
├── src-tauri/
└── ...
```

### B. Requirements
1.  **Docker** or **Podman** installed on the host machine.
2.  **Clean Binaries**: Place your latest Linux-compiled `hemp0xd` and `hemp0x-cli` in `binaries_new/`.
3.  **Legacy Runtime**: Place the v1.2 AppImage in the project root (used for the "No-FUSE" patch).
    *   *If stored elsewhere, update `LEGACY_APPIMAGE_PATH` in the script.*

## 2. Build Instructions
Run the single consolidated build script from the project root:

```bash
chmod +x scripts/build_linux_universal.sh
./scripts/build_linux_universal.sh
```

### What does this script do?
1.  **Prepares Binaries**: Copies/Strips fresh binaries from `binaries_new/` to `src-tauri/binaries/`.
2.  **Builds Docker Environment**: Creates a clean Ubuntu 22.04 container.
3.  **Compiles & Packages**:
    *   Builds the Rust/Tauri application (GLIBC 2.35).
    *   Bundles dependencies (WebKit, GTK, Soup3).
    *   **Prunes Bloat**: Removes duplicates, docs, `libLLVM`, and `dri` drivers (saves ~100MB).
    *   **ZSTD Compression**: Use Level 22 ZSTD for maximum size reduction (~84MB final).
4.  **Patches Runtime**:
    *   Extracts the "Legacy Runtime" from the v1.2 AppImage.
    *   Repacks the new payload with the legacy runtime (allowing it to run without `libfuse2` installed).

## 3. Output
The final artifact is placed in the `release/` folder:

```
release/Hemp0x_Commander_1.3.0_Universal_Linux.AppImage  (~84-85MB)
```

## 4. Troubleshooting
*   **Missing Binaries**: If the script fails with "Clean binaries not found", ensure `binaries_new/` exists and contains the files.
*   **Legacy Image Missing**: Ensure the v1.2 AppImage is in the root or the path in the script matches.
*   **Logs**: Check the console output (or redirect to a log file like `build.log`) for details.

