#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Hemp0x Windows Installer (Cross-Compile on Linux)
# Target: Windows 64-bit (.exe)
# Host System: Nobara Linux / Ubuntu
# ═══════════════════════════════════════════════════════════════════════════

# === CONFIGURATION ===
# Using the FIXED fork/branch to ensure the Asset Activation fix is included
REPO_URL="https://github.com/beyondcr/hemp0x-core.git"
BRANCH="feature/activation-block-265000"

# Install to directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/hemp0x-core-win"
MINGW_HOST="x86_64-w64-mingw32"

echo "═══════════════════════════════════════════════════════"
echo "     Hemp0x Windows Builder (Cross-Compile)            "
echo "═══════════════════════════════════════════════════════"
echo "Source: $REPO_URL ($BRANCH)"
echo "Build location: $BUILD_DIR"
echo "Target: Windows 64-bit"
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
git checkout "$BRANCH"

echo ">>> 3. Applying Build System Fixes (Windows/MinGW)..."

# --- GENERATE ROBUST DEPENDENCY PATCH (From build_windows_binaries_on_linux.sh) ---
cat > fix_depends_win.py <<'PY'
import pathlib
root = pathlib.Path("depends/packages")
if not root.exists(): exit(0)

boost_mk = root / "boost.mk"
bdb_mk   = root / "bdb.mk"
upnp_mk  = root / "miniupnpc.mk"

# === BOOST PATCH ===
boost_content = r'''package=boost
$(package)_version=1_71_0
$(package)_download_path=https://archives.boost.io/release/1.71.0/source/
$(package)_file_name=boost_$($(package)_version).tar.bz2
$(package)_sha256_hash=d73a8da01e8bf8c7eda40b4c84915071a8c8a0df4a6734537ddde4a8580524ee
$(package)_dependencies=native_b2

define $(package)_set_vars
__TAB__$(package)_config_opts=--layout=tagged --build-type=complete threading=multi link=static -sNO_COMPRESSION=1
__TAB__$(package)_config_opts_linux=target-os=linux threadapi=pthread runtime-link=shared
__TAB__$(package)_config_opts_mingw32=target-os=windows binary-format=pe address-model=64 threadapi=win32 runtime-link=static toolset=gcc-mingw
__TAB__$(package)_cxxflags=-std=c++17 -fvisibility=hidden -fpermissive -w -fPIC -D_GLIBCXX_USE_DEPRECATED=1
endef

define $(package)_preprocess_cmds
__TAB__if [ -d boost_1_71_0 ]; then mv boost_1_71_0/* . && rm -rf boost_1_71_0; fi
__TAB__find . -name "thread.cpp" -exec sed -i 's/token_compress_on/algorithm::token_compress_on/g' {} +
__TAB__find . -name "*.hpp" -exec sed -i 's/((Model\*)0)->[^;]*;/((void)0);/g' {} +
__TAB__find . -name "thread_data.hpp" -exec sed -i 's/#if PTHREAD_STACK_MIN > 0/#ifdef PTHREAD_STACK_MIN/g' {} +
endef

define $(package)_config_cmds
__TAB__echo "using gcc : mingw : x86_64-w64-mingw32-g++ : <cxxflags>\"$($(package)_cxxflags)\" ;" > user-config.jam
endef

define $(package)_build_cmds
__TAB__b2 -d0 -j2 \
__TAB__  --user-config=user-config.jam \
__TAB__  --prefix=$($(package)_staging_prefix_dir) \
__TAB__  $($(package)_config_opts) \
__TAB__  --with-chrono --with-filesystem --with-program_options --with-system --with-thread \
__TAB__  stage
endef

define $(package)_stage_cmds
__TAB__b2 -d0 -j2 \
__TAB__  --user-config=user-config.jam \
__TAB__  --prefix=$($(package)_staging_prefix_dir) \
__TAB__  $($(package)_config_opts) \
__TAB__  --with-chrono --with-filesystem --with-program_options --with-system --with-thread \
__TAB__  install
endef
'''

# === BDB PATCH ===
bdb_content = r'''package=bdb
$(package)_version=4.8.30
$(package)_download_path=https://download.oracle.com/berkeley-db
$(package)_file_name=db-$($(package)_version).NC.tar.gz
$(package)_sha256_hash=12edc0df75bf9abd7f82f821795bcee50f42cb2e5f76a6a281b85732798364ef

define $(package)_set_vars
__TAB__$(package)_config_opts=--enable-cxx --disable-shared --with-pic --disable-replication
__TAB__$(package)_config_opts_mingw32=--enable-mingw
__TAB__$(package)_config_opts_linux=--with-mutex=POSIX/pthreads
endef

define $(package)_preprocess_cmds
__TAB__sed -i.old 's/__atomic_compare_exchange/__atomic_compare_exchange_db/' dbinc/atomic.h
endef

define $(package)_config_cmds
__TAB__mkdir -p build_unix && cd build_unix && ../dist/configure --host=$(host) $($(package)_config_opts)
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

# === MINIUPNPC PATCH ===
upnp_content = r'''package=miniupnpc
$(package)_version=2.0.20170509
$(package)_download_path=https://bitcoincore.org/depends-sources/
$(package)_file_name=miniupnpc-$($(package)_version).tar.gz
$(package)_sha256_hash=d3c368627f5cdfb66d3ebd64ca39ba54d6ff14a61966dbecb8dd296b7039f16a

define $(package)_set_vars
__TAB__$(package)_config_opts=
__TAB__$(package)_config_opts_linux=
__TAB__$(package)_config_opts_mingw32=
endef

define $(package)_preprocess_cmds
__TAB__sed -i 's/setsockopt(sudp, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, &mcastHops/setsockopt(sudp, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, (const char *)\&mcastHops/' minissdpc.c && \
__TAB__sed -i '/miniupnpcstrings.h: miniupnpcstrings.h.in wingenminiupnpcstrings/d' Makefile.mingw && \
__TAB__sed -i '/\twingenminiupnpcstrings $< $@/d' Makefile.mingw
endef

define $(package)_build_cmds
__TAB__mkdir -p dll && \
__TAB__sed -e 's|OS_STRING ".*"|OS_STRING "Windows"|' -e 's|MINIUPNPC_VERSION_STRING ".*"|MINIUPNPC_VERSION_STRING "$($(package)_version)"|' miniupnpcstrings.h.in > miniupnpcstrings.h && \
__TAB__$(MAKE) -f Makefile.mingw CC="$(host)-gcc" AR="$(host)-ar" libminiupnpc.a
endef

define $(package)_stage_cmds
__TAB__dest_inc="$($(package)_staging_prefix_dir)/include/miniupnpc"; \
__TAB__dest_lib="$($(package)_staging_prefix_dir)/lib"; \
__TAB__mkdir -p "$$dest_inc" "$$dest_lib"; \
__TAB__if ls -1 *.h >/dev/null 2>&1; then \
__TAB__  cp -f *.h "$$dest_inc/"; \
__TAB__elif ls -1 */*.h >/dev/null 2>&1; then \
__TAB__  find . -maxdepth 2 -type f -name '*.h' -exec cp -f {} "$$dest_inc/" \; ; \
__TAB__else \
__TAB__  echo "ERROR: Headers not found in $$(pwd)"; ls -la; exit 1; \
__TAB__fi; \
__TAB__if [ -f libminiupnpc.a ]; then cp -f libminiupnpc.a "$$dest_lib/"; \
__TAB__elif [ -f */libminiupnpc.a ]; then find . -name libminiupnpc.a -exec cp -f {} "$$dest_lib/" \; ; \
__TAB__else \
__TAB__  echo "ERROR: Lib not found"; exit 1; \
__TAB__fi
endef
'''

# REPLACE PLACEHOLDERS
boost_mk.write_text(boost_content.replace("__TAB__", "\t"))
bdb_mk.write_text(bdb_content.replace("__TAB__", "\t"))
upnp_mk.write_text(upnp_content.replace("__TAB__", "\t"))
PY

python3 fix_depends_win.py
echo "    Patches Applied."

echo ">>> 4. Building Dependencies (MinGW-w64)..."
# We remove old work to prevent corruption
rm -rf depends/work depends/built depends/*-mingw32
# NO_QT=1 because we only need the daemon/cli
make -C depends HOST="$MINGW_HOST" NO_QT=1 -j"$(nproc)"

# --- 5. Configure & Build ---
echo ">>> 5. Configuring & Compiling..."
./autogen.sh

# Use the depends configuration
CONFIG_SITE="$PWD/depends/$MINGW_HOST/share/config.site" \
./configure --prefix=/ \
            --host="$MINGW_HOST" \
            --disable-tests \
            --disable-bench \
            --without-gui \
            --disable-shared

make -j"$(nproc)"

echo ">>> 6. Verifying Build..."
if [ -f "src/hemp0xd.exe" ] && [ -f "src/hemp0x-cli.exe" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "          ✓✓✓ WINDOWS BUILD SUCCESSFUL ✓✓✓             "
    echo "═══════════════════════════════════════════════════════"
    echo ""
    ls -lh src/hemp0xd.exe src/hemp0x-cli.exe
    echo ""
    echo "Location: $BUILD_DIR/src/"
else
    echo "✗ BUILD FAILED - Check output above"
    exit 1
fi
