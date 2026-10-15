#!/usr/bin/env bash
# Build ws-hunter and install it beside, not over, an existing WS install.
#
#   ./build-hunter.sh [prefix]        default prefix: ~/ws-hunter-app
#
# Linux, or macOS with Homebrew (untested so far): first
#   xcode-select --install
#   brew install cmake qt@5 boost fftw libusb gcc pkg-config
# On macOS the result is the app bundle <prefix>/ws.app.
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
OS=$(uname -s)
if [ "$OS" = Darwin ]; then
  mem_mb=$(( $(sysctl -n hw.memsize) / 1048576 ))
  ncpu=$(sysctl -n hw.ncpu)
  md5ok() { [ -f "$1" ] && [ "$(md5 -q "$1")" = "$SUPER_MD5" ]; }
  GC_LDFLAGS=-Wl,-dead_strip           # Apple's linker has no --gc-sections
  command -v brew >/dev/null || { echo "macOS build needs Homebrew (https://brew.sh)"; exit 1; }
  BREW=$(brew --prefix)
  QT5=$(brew --prefix qt@5 2>/dev/null) || { echo "brew install qt@5 (WS needs Qt 5)"; exit 1; }
  export FC=${FC:-$(command -v gfortran || ls "$BREW"/bin/gfortran-* 2>/dev/null | sort -V | tail -1)}
  [ -n "$FC" ] || { echo "no gfortran: brew install gcc"; exit 1; }
  EXTRA_PREFIX="$QT5;$BREW"
  RUN="open $PREFIX/ws.app"
else
  mem_mb=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
  ncpu=$(nproc)
  md5ok() { echo "$SUPER_MD5  $1" | md5sum -c --status 2>/dev/null; }
  GC_LDFLAGS=-Wl,--gc-sections
  EXTRA_PREFIX=""
  RUN="$PREFIX/bin/ws"
fi
# mainwindow.cpp alone can take ~2 GB to compile, so below 6 GB of RAM
# build one file at a time. Override with JOBS=n.
JOBS=${JOBS:-$([ "$mem_mb" -lt 6000 ] && echo 1 || echo "$ncpu")}

SUPER_URL="https://sourceforge.net/projects/wsjt-x-improved/files/WS_v3.2.0/Source%20code/ws-3.2.0_260924.tgz/download"
SUPER_MD5=93069373277c7976eebbc4ec644bf79b
HAMLIB=hamlib-4.7.3

mkdir -p "$BUILD"
cd "$BUILD"

# 1. Official superbuild tarball, for Hamlib and its WS patch
if ! md5ok superbuild.tgz; then
  echo ">> downloading WS superbuild tarball (~80 MB)"
  curl -fL --retry 3 -o superbuild.tgz "$SUPER_URL"
  md5ok superbuild.tgz || { echo "superbuild.tgz: MD5 mismatch"; exit 1; }
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
          "LDFLAGS=$GC_LDFLAGS" \
     && make -j"$JOBS" && make install-strip)
  rm -rf superbuild "$HAMLIB"   # only the installed library is needed
fi

# 3. WS from this tree
echo ">> building ws-hunter into $PREFIX"
cmake -S "$SRC" -B ws -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="$BUILD/hamlib${EXTRA_PREFIX:+;$EXTRA_PREFIX}" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DWSJT_GENERATE_DOCS=OFF -DWSJT_SKIP_MANPAGES=ON -DWSJT_BUILD_UTILS=OFF
cmake --build ws -j"$JOBS"
cmake --install ws

echo ">> done: run $RUN"
