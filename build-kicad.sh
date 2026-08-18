#!/bin/bash
# Configure (first run) and incrementally build + install the patched KiCad.
#
# Dependencies (KiCad's wxWidgets fork, Python framework, wxPython, ngspice)
# come from kicad-mac-builder's build/ tree, built once with
#   cd kicad-mac-builder && ./build.py --arch arm64 --target setup-kicad-dependencies
# The CMake arguments below are the ones that target prints (KICAD_CMAKE_ARGS),
# with the install prefix moved to ../install so the bundle we run lives here.
#
# CMAKE_OSX_SYSROOT is set explicitly on purpose: without a sysroot, Apple
# clang searches /usr/local/include ahead of every -isystem directory, and this
# machine has a stray protobuf 28.3 + abseil there that shadows Homebrew's and
# breaks the API code generation ("gencode built with an incompatible version").
set -euo pipefail

DEV="$(cd "$(dirname "$0")" && pwd)"
SRC="$DEV/kicad"
BUILD="$SRC/build/release"
INSTALL="$DEV/install"
KMB="$DEV/kicad-mac-builder/build"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

mkdir -p "$BUILD" "$INSTALL" "$DEV/logs"
LOG="$DEV/logs/build-$(date +%Y%m%d-%H%M%S).log"

if [ ! -f "$BUILD/build.ninja" ]; then
    echo "Configuring KiCad (first time) -> $BUILD"
    cmake -S "$SRC" -B "$BUILD" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        "-DDEFAULT_INSTALL_PATH=/Library/Application Support/kicad" \
        -DOCC_INCLUDE_DIR="$(brew --prefix opencascade)/include/opencascade" \
        -DOCC_LIBRARY_DIR="$(brew --prefix opencascade)/lib" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL" \
        -DCMAKE_C_COMPILER=/usr/bin/clang \
        -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$(sw_vers -productVersion | cut -d. -f1,2)" \
        -DwxWidgets_CONFIG_EXECUTABLE="$KMB/wxwidgets-dest/bin/wx-config" \
        -DKICAD_BUILD_I18N=OFF \
        -DKICAD_SCRIPTING_WXPYTHON=ON \
        -DPYTHON_EXECUTABLE="$KMB/python-dest/Library/Frameworks/Python.framework/Versions/Current/bin/python3" \
        -DPYTHON_INCLUDE_DIR="$KMB/python-dest/Library/Frameworks/Python.framework/Versions/Current/include/python3.9/" \
        -DPYTHON_LIBRARY="$KMB/python-dest/Library/Frameworks/Python.framework/Versions/Current/lib/libpython3.9.dylib" \
        -DPYTHON_SITE_PACKAGE_PATH="$KMB/python-dest/Library/Frameworks/Python.framework/Versions/Current/lib/python3.9/site-packages" \
        -DPYTHON_FRAMEWORK="$KMB/python-dest/Library/Frameworks/Python.framework" \
        -DNGSPICE_INCLUDE_DIR="$KMB/ngspice-dest/include" \
        -DNGSPICE_LIBRARY="$KMB/ngspice-dest/lib/libngspice.dylib" \
        -DKICAD_BUILD_QA_TESTS=OFF \
        -DKICAD_USE_SENTRY=OFF \
        -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)" \
        2>&1 | tee "$LOG"
fi

echo "Building (ninja -j$JOBS) -> $LOG"
ninja -C "$BUILD" -j"$JOBS" 2>&1 | tee -a "$LOG" | grep -E "^\[|error|warning: unused|FAILED" | tail -n 5
echo "Installing -> $INSTALL"
ninja -C "$BUILD" install 2>&1 | tail -n 3 >> "$LOG"
echo "Done. Run:  open $INSTALL/KiCad.app"
