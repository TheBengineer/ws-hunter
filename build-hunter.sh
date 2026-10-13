#!/usr/bin/env bash
# Build ws-hunter and install it beside, not over, an existing WS install.
#
#   ./build-hunter.sh [prefix]        default prefix: ~/ws-hunter-app
#
# WS links a patched static Hamlib that ships only inside the official
# "superbuild" source tarball, so that tarball is downloaded once (MD5
# pinned) and its Hamlib built first. Everything else comes from this tree.
# Run the result with <prefix>/bin/ws; it shares settings, logs and
# ALL.TXT with the stock WS, so don't run both at once.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
PREFIX=${1:-$HOME/ws-hunter-app}
BUILD=$SRC/build-hunter
JOBS=$(nproc)

SUPER_URL="https://sourceforge.net/projects/wsjt-x-improved/files/WS_v3.2.0/Source%20code/ws-3.2.0_260924.tgz/download"
SUPER_MD5=93069373277c7976eebbc4ec644bf79b
HAMLIB=hamlib-4.7.3

mkdir -p "$BUILD"
cd "$BUILD"

# 1. Official superbuild tarball, for Hamlib and its WS patch
if ! echo "$SUPER_MD5  superbuild.tgz" | md5sum -c --status 2>/dev/null; then
  echo ">> downloading WS superbuild tarball (~80 MB)"
  curl -fL --retry 3 -o superbuild.tgz "$SUPER_URL"
  echo "$SUPER_MD5  superbuild.tgz" | md5sum -c
fi

# 2. Hamlib, static, into $BUILD/hamlib
if [ ! -f hamlib/lib/libhamlib.a ]; then
  echo ">> building $HAMLIB"
  rm -rf superbuild "$HAMLIB"
  mkdir superbuild
  tar xzf superbuild.tgz -C superbuild --strip-components=1 \
      "ws-3.2.0/src/$HAMLIB.tar.gz" ws-3.2.0/hamlib.patch
  tar xzf "superbuild/src/$HAMLIB.tar.gz"
  (cd "$HAMLIB" && patch -p1 -N < ../superbuild/hamlib.patch \
     && ./configure --prefix="$BUILD/hamlib" --disable-shared --enable-static \
          --without-cxx-binding \
          "CFLAGS=-O2 -fPIC -fdata-sections -ffunction-sections" \
          "LDFLAGS=-Wl,--gc-sections" \
     && make -j"$JOBS" && make install-strip)
  rm -rf superbuild "$HAMLIB"   # only the installed library is needed
fi

# 3. WS from this tree
echo ">> building ws-hunter into $PREFIX"
cmake -S "$SRC" -B ws -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="$BUILD/hamlib" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DWSJT_GENERATE_DOCS=OFF -DWSJT_SKIP_MANPAGES=ON -DWSJT_BUILD_UTILS=OFF
cmake --build ws -j"$JOBS"
cmake --install ws

echo ">> done: run $PREFIX/bin/ws"
