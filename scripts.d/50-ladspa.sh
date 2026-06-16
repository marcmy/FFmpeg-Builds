#!/bin/bash

SCRIPT_REPO="https://github.com/dlfcn-win32/dlfcn-win32.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    apt-get -y update
    apt-get -y install --no-install-recommends ladspa-sdk

    mkdir build && cd build
    cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        ..
    ninja -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja install

    install -Dm644 /usr/include/ladspa.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/ladspa.h"

    apt-get -y clean autoclean
    rm -rf /var/lib/apt/lists/*
}

ffbuild_configure() {
    echo --enable-ladspa
}

ffbuild_libs() {
    echo -ldl
}

ffbuild_unconfigure() {
    echo --disable-ladspa
}
