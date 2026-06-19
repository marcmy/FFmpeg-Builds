#!/bin/bash

SCRIPT_REPO="https://github.com/cmusphinx/pocketsphinx.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_PROGRAMS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    # FFmpeg includes <pocketsphinx/pocketsphinx.h>, while current
    # PocketSphinx installs its umbrella header as <pocketsphinx.h>.
    install -Dm644 include/pocketsphinx.h \
        "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/pocketsphinx/pocketsphinx.h"
}

ffbuild_configure() {
    echo --enable-pocketsphinx
}

ffbuild_libs() {
    echo -lm
}

ffbuild_unconfigure() {
    echo --disable-pocketsphinx
}
