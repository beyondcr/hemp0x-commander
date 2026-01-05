#!/bin/bash
set -euo pipefail

# ==============================================================================
# HEMP0X WINDOWS BUILDER (ROBUST STAGE FIX)
# Target: Windows 64-bit (.exe) on Nobara/Fedora
# Fixes: "cp: cannot stat" (Searches for headers/libs instead of assuming path)
# Fixes: All previous issues (Boost, Hash, DLLs, etc.)
# ==============================================================================

# 1. SAFETY CHECK
if [ "$EUID" -eq 0 ]; then
  echo "ERROR: DO NOT RUN AS ROOT!"
  echo "Please run as your normal user."
  exit 1
fi

WORK_DIR="$HOME/hemp0x-win-build"
CACHE_DIR="$HOME/hemp0x-sources"
MINGW_HOST="x86_64-w64-mingw32"

# Verified Hash for MiniUPnPc
UPNP_FILE="miniupnpc-2.0.20170509.tar.gz"
UPNP_HASH="d3c368627f5cdfb66d3ebd64ca39ba54d6ff14a61966dbecb8dd296b7039f16a"
UPNP_URL="https://bitcoincore.org/depends-sources/$UPNP_FILE"

# # echo ">>> [1/9] System Prep (Nobara/Fedora)..."
# # if command -v dnf >/dev/null 2>&1; then
# #     # sudo dnf install -y mingw64-gcc-c++ mingw64-filesystem mingw64-headers \
# #     #                     make automake gcc-c++ libtool patch python3 zip git \
# #     #                     python3-setuptools wget
# #     echo "Skipping System Prep (Assumed Installed)"
# # else
# #     echo "ERROR: 'dnf' not found. This script is for Nobara/Fedora."
# #     exit 1
# # fi

echo ">>> [2/9] Managing Download Cache..."
mkdir -p "$CACHE_DIR"

FILE_PATH="$CACHE_DIR/$UPNP_FILE"
NEED_DOWNLOAD=true

if [ -f "$FILE_PATH" ]; then
    echo "Checking existing miniupnpc..."
    CURRENT_HASH=$(sha256sum "$FILE_PATH" | awk '{print $1}')
    if [ "$CURRENT_HASH" == "$UPNP_HASH" ]; then
        echo " - MiniUPnPc verified. Skipping download."
        NEED_DOWNLOAD=false
    else
        echo " - Hash mismatch. Deleting..."
        rm -f "$FILE_PATH"
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "Downloading $UPNP_FILE from reliable mirror..."
    wget -O "$FILE_PATH" "$UPNP_URL"

    # Verify again
    CURRENT_HASH=$(sha256sum "$FILE_PATH" | awk '{print $1}')
    if [ "$CURRENT_HASH" != "$UPNP_HASH" ]; then
        echo "ERROR: Download failed. Hash mismatch."
        exit 1
    fi
fi

echo ">>> [3/9] Workspace Setup..."
if [ -d "$WORK_DIR" ]; then rm -rf "$WORK_DIR"; fi
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo ">>> [4/9] Cloning Hemp0x..."
git clone https://github.com/hemp0x/hemp0x-core.git
cd hemp0x-core

# Link Cache
rm -rf depends/sources
ln -sf "$CACHE_DIR" depends/sources

echo ">>> [5/9] Rebranding..."
sed -i '/CMempoolAddressDeltaKey/s/\bRVN\b/HEMP/g' src/txmempool.cpp
sed -i '/#include <algorithm>/a #include <stdexcept>' src/support/lockedpool.cpp
sed -i 's/ravend/hemp0xd/g' src/Makefile.am
sed -i 's/raven-cli/hemp0x-cli/g' src/Makefile.am
sed -i 's/raven-tx/hemp0x-tx/g' src/Makefile.am
sed -i 's/raven_cli/hemp0x_cli/g' src/Makefile.am
sed -i 's/raven_tx/hemp0x_tx/g' src/Makefile.am
[ -f src/ravend.cpp ] && mv src/ravend.cpp src/hemp0xd.cpp
[ -f src/raven-cli.cpp ] && mv src/raven-cli.cpp src/hemp0x-cli.cpp
[ -f src/raven-tx.cpp ] && mv src/raven-tx.cpp src/hemp0x-tx.cpp
sed -i 's/Ravencoin Core/Hemp0x Core/g' configure.ac src/init.cpp
sed -i 's/Raven Core/Hemp0x Core/g' configure.ac src/init.cpp
sed -i 's/Ravencoin/Hemp0x/g' src/init.cpp
find src -name "*.cpp" -print0 | xargs -0 sed -i 's/"\.raven"/"\.hemp0x"/g'

echo ">>> [6/9] Applying Source Code Fixes..."
if [ -f src/util.cpp ]; then
  grep -q 'boost/thread/locks.hpp' src/util.cpp || \
    sed -i '/#include <boost\/thread\/mutex.hpp>/a #include <boost/thread/locks.hpp>' src/util.cpp
  perl -pi -e 's/\bboost::mutex::scoped_lock\b/boost::unique_lock<boost::mutex>/g' src/util.cpp
fi
if [ -f src/sync.h ]; then
  sed -i 's/typedef[[:space:]]\+boost::condition_variable[[:space:]]\+CConditionVariable;/typedef boost::condition_variable_any CConditionVariable;/' src/sync.h
fi
if [ -f src/rpc/mining.cpp ]; then
  grep -q 'boost/chrono.hpp' src/rpc/mining.cpp || \
    sed -i '/#include <boost\/thread\/condition_variable.hpp>/a #include <boost/chrono.hpp>' src/rpc/mining.cpp
  perl -0777 -pi -e 's/\bif\s*\(\s*!\s*cvBlockChange\.timed_wait\(\s*lock\s*,\s*checktxtime\s*\)\s*\)/const auto _wait_ms = (checktxtime - boost::get_system_time()).total_milliseconds();\n                if (cvBlockChange.wait_for(lock, boost::chrono::milliseconds(_wait_ms > 0 ? _wait_ms : 0)) == boost::cv_status::timeout)/g' src/rpc/mining.cpp
fi
if [ -f src/bench/bench.h ]; then
  grep -q '^#include <cstdint>' src/bench/bench.h || \
    sed -i 's|#include <boost/preprocessor/stringize.hpp>|#include <boost/preprocessor/stringize.hpp>\n#include <cstdint>|' src/bench/bench.h
fi

echo ">>> [7/9] Generating Dependency Patches..."
mkdir -p depends/patches/zeromq
cat > depends/patches/zeromq/remove_libstd_link.patch <<'PATCH'
--- a/AUTHORS
+++ b/AUTHORS
@@ -1,1 +1,2 @@
+
PATCH

cat > patch_depends.py <<'END_OF_PYTHON'
import pathlib
root = pathlib.Path("depends/packages")
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

# === MINIUPNPC PATCH (ROBUST STAGING) ===
# 1. Manually generates header.
# 2. Builds static library.
# 3. Robust staging: searches for headers/libs wherever they are.
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

boost_mk.write_text(boost_content.replace("__TAB__", "\t"))
bdb_mk.write_text(bdb_content.replace("__TAB__", "\t"))
upnp_mk.write_text(upnp_content.replace("__TAB__", "\t"))
END_OF_PYTHON

python3 patch_depends.py
echo "    Patches Applied."

echo ">>> [8/9] Building Dependencies (Target: Windows 64-bit)..."
make -C depends HOST="$MINGW_HOST" NO_QT=1 -j"$(nproc)"

echo ">>> [9/9] Compiling Hemp0x Core..."
./autogen.sh

CONFIG_SITE="$PWD/depends/$MINGW_HOST/share/config.site" \
./configure --prefix=/ \
            --host="$MINGW_HOST" \
            --disable-tests \
            --disable-bench \
            --without-gui \
            --disable-shared

make -j"$(nproc)"

# --- PACKAGING ---
if [ -f "src/hemp0xd.exe" ]; then
    echo "=========================================================="
    echo "SUCCESS: Windows Binaries Created!"
    echo "=========================================================="

    cd ..
    mkdir -p Hemp0x-Win64
    cp hemp0x-core/src/hemp0xd.exe Hemp0x-Win64/
    cp hemp0x-core/src/hemp0x-cli.exe Hemp0x-Win64/

    cat > Hemp0x-Win64/hemp.conf <<EOF
rpcuser=hemp0xuser
rpcpassword=hemp0xpassword
addnode=154.38.164.123:42069
addnode=147.93.185.184:42069
EOF

    cat > Hemp0x-Win64/start_node.bat <<EOF
@echo off
echo Starting Hemp0x Node...
hemp0xd.exe -conf=hemp.conf
pause
EOF

    zip -r hemp0x-win64.zip Hemp0x-Win64
    echo "Binaries Zipped: $WORK_DIR/hemp0x-win64.zip"
else
    echo "ERROR: Compilation finished but .exe not found."
    exit 1
fi
