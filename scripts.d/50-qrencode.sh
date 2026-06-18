#!/bin/bash

SCRIPT_REPO="https://github.com/fukuchi/libqrencode.git"
SCRIPT_COMMIT="v4.1.1"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=OFF -DWITH_TOOLS=OFF -DWITH_TESTS=OFF -DWITHOUT_PNG=ON ..
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_configure() {
    echo --enable-libqrencode
}

ffbuild_unconfigure() {
    echo --disable-libqrencode
}
