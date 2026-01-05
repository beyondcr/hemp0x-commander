#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Hemp0x Node Installer - Portable Version  
# Works on: Nobara Linux, Ubuntu 24.04, and all compatible systems
# Place this script in any folder and run it - builds to: ./hemp0x-core/
# Date: 2025-12-27
# ═══════════════════════════════════════════════════════════════════════════

# === CONFIGURATION ===
REPO_URL="https://github.com/hemp0x/hemp0x-core.git"

# PORTABLE: Install to directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/hemp0x-core"

echo "═══════════════════════════════════════════════════════"
echo "     Hemp0x Installer (Portable - Works Everywhere)    "
echo "═══════════════════════════════════════════════════════"
echo "Build location: $BUILD_DIR"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Cancelled."; exit 0; }

echo ""
echo ">>> 1. Preparing Workspace..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo ">>> 2. Cloning Hemp0x Network..."
git clone "$REPO_URL" "$BUILD_DIR"
cd "$BUILD_DIR"

echo ">>> 3. Applying Build System Fixes (Nobara/Linux)..."

# --- GENERATE ROBUST DEPENDENCY PATCH ---
cat > fix_depends.py <<'PY'
import pathlib
root = pathlib.Path("depends/packages")
if not root.exists(): exit(0)

boost_mk = root / "boost.mk"
bdb_mk   = root / "bdb.mk"

# PATCH: Boost 1.71 (GCC 15 Fixes)
# We use placeholders to ensure exact Makefile syntax (Tabs vs Spaces)
boost_content = r'''package=boost
$(package)_version=1_71_0
$(package)_download_path=https://archives.boost.io/release/1.71.0/source/
$(package)_file_name=boost_$($(package)_version).tar.bz2
$(package)_sha256_hash=d73a8da01e8bf8c7eda40b4c84915071a8c8a0df4a6734537ddde4a8580524ee
$(package)_dependencies=native_b2

define $(package)_set_vars
__SPACE__$(package)_config_opts=--layout=tagged --build-type=complete threading=multi link=static -sNO_COMPRESSION=1
__SPACE__$(package)_config_opts_linux=target-os=linux threadapi=pthread runtime-link=shared
__SPACE__$(package)_cxxflags=-std=c++17 -fvisibility=hidden -fpermissive -w -fPIC -D_GLIBCXX_USE_DEPRECATED=1
endef

define $(package)_preprocess_cmds
__TAB__find . -name "thread.cpp" -exec sed -i 's/token_compress_on/algorithm::token_compress_on/g' {} +
__TAB__find . -name "*.hpp" -exec sed -i 's/((Model\*)0)->[^;]*;/((void)0);/g' {} +
__TAB__find . -name "thread_data.hpp" -exec sed -i 's/#if PTHREAD_STACK_MIN > 0/#ifdef PTHREAD_STACK_MIN/g' {} +
endef

define $(package)_config_cmds
__TAB__./bootstrap.sh --without-icu --with-libraries=chrono,filesystem,program_options,system,thread
__TAB__echo "using gcc : : $(CXX) : <cxxflags>\"$($(package)_cxxflags)\" ;" > project-config.jam
endef

define $(package)_build_cmds
__TAB__b2 -d0 -j2 --prefix=$($(package)_staging_prefix_dir) $($(package)_config_opts) stage
endef

define $(package)_stage_cmds
__TAB__b2 -d0 -j2 --prefix=$($(package)_staging_prefix_dir) $($(package)_config_opts) install
endef
'''

# PATCH: BDB 4.8 (Permission & Rename Fix)
bdb_content = r'''package=bdb
$(package)_version=4.8.30
$(package)_download_path=https://download.oracle.com/berkeley-db
$(package)_file_name=db-$($(package)_version).NC.tar.gz
$(package)_sha256_hash=12edc0df75bf9abd7f82f821795bcee50f42cb2e5f76a6a281b85732798364ef

define $(package)_set_vars
__SPACE__$(package)_config_opts=--enable-cxx --disable-shared --with-pic --with-mutex=POSIX/pthreads --disable-atomicsupport
endef

define $(package)_preprocess_cmds
__TAB__sed -i.old 's/__atomic_compare_exchange/__atomic_compare_exchange_db/' dbinc/atomic.h
endef

define $(package)_config_cmds
__TAB__mkdir -p build_unix && cd build_unix && ../dist/configure $($(package)_config_opts)
endef

define $(package)_build_cmds
__TAB__cd build_unix && $(MAKE) libdb.a libdb_cxx.a
endef

define $(package)_stage_cmds
__TAB__cd build_unix && $(MAKE) DESTDIR=$($(package)_staging_dir) install_lib install_include
endef

define $(package)_postprocess_cmds
__TAB__mkdir -p $($(package)_staging_prefix_dir)/include/bdb4.8 $($(package)_staging_prefix_dir)/lib
__TAB__cp -a $($(package)_staging_dir)/usr/local/BerkeleyDB.4.8/include/db*.h $($(package)_staging_prefix_dir)/include/
__TAB__cp -a $($(package)_staging_dir)/usr/local/BerkeleyDB.4.8/lib/libdb*.a     $($(package)_staging_prefix_dir)/lib/
__TAB__cd $($(package)_staging_prefix_dir)/lib && rm -f libdb_cxx.a && ln -sf libdb_cxx-4.8.a libdb_cxx.a
__TAB__ln -sf ../db_cxx.h $($(package)_staging_prefix_dir)/include/bdb4.8/db_cxx.h
__TAB__ln -sf ../db.h     $($(package)_staging_prefix_dir)/include/bdb4.8/db.h
__TAB__cd $($(package)_staging_prefix_dir)/include && \
__TAB__chmod u+w db.h db_cxx.h 2>/dev/null || true && \
__TAB__if [ -f db.h ] && [ ! -f db_orig.h ]; then mv db.h db_orig.h; fi && \
__TAB__if [ -f db_cxx.h ] && [ ! -f db_cxx_orig.h ]; then mv db_cxx.h db_cxx_orig.h; fi && \
__TAB__printf "#ifndef HEMP0X_BDB48_DB_WRAPPER_H\n#define HEMP0X_BDB48_DB_WRAPPER_H\n#include <sys/types.h>\n#include <stdint.h>\n#include <stddef.h>\n#include \"db_orig.h\"\n#endif\n" > db.h && \
__TAB__printf "#ifndef HEMP0X_BDB48_DB_CXX_WRAPPER_H\n#define HEMP0X_BDB48_DB_CXX_WRAPPER_H\n#include <sys/types.h>\n#include <stdint.h>\n#include <stddef.h>\n#include <string.h>\n#include \"db_cxx_orig.h\"\n#endif\n" > db_cxx.h
endef
'''

# REPLACE PLACEHOLDERS WITH REAL TABS/SPACES
boost_mk.write_text(boost_content.replace("__TAB__", "\t").replace("__SPACE__", "  "))
bdb_mk.write_text(bdb_content.replace("__TAB__", "\t").replace("__SPACE__", "  "))
PY
python3 fix_depends.py

echo ">>> 4. Building Dependencies (Verbose)..."
# We remove old work to prevent corruption
rm -rf depends/work depends/built depends/*-linux-gnu
# NO_QT=1 because we only need the daemon/cli
make -C depends -j"$(nproc)" NO_QT=1

# --- 5. Configure & Build ---
echo ">>> 5. Configuring & Compiling..."
./autogen.sh
PREFIX=$(ls -d depends/*-linux-gnu | head -n 1)

# CRITICAL FLAGS for Nobara/Fedora/GCC 15
CONFIG_SITE="$PREFIX/share/config.site" \
CXXFLAGS="-std=c++17 -Wno-error=deprecated-declarations -Wno-error -D_GLIBCXX_USE_DEPRECATED=1" \
LDFLAGS="-no-pie" \
./configure --prefix="$PWD/installed" \
            --disable-tests \
            --disable-bench \
            --without-gui \
            --disable-shared

make -j"$(nproc)"

echo ">>> 6. Verifying Build..."
if [ -x src/hemp0xd ] && [ -x src/hemp0x-cli ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "          ✓✓✓ BUILD SUCCESSFUL ✓✓✓                     "
    echo "═══════════════════════════════════════════════════════"
    echo ""
    ls -lh src/hemp0xd src/hemp0x-cli
    echo ""
    echo "Location: $BUILD_DIR/src/"
    echo ""
    echo "Start: $BUILD_DIR/src/hemp0xd -daemon"
    echo "Check: $BUILD_DIR/src/hemp0x-cli getinfo"
    echo "Stop:  $BUILD_DIR/src/hemp0x-cli stop"
    echo ""
else
    echo "✗ BUILD FAILED - Check output above"
    exit 1
fi
