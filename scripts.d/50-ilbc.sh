#!/bin/bash

SCRIPT_REPO="https://github.com/TimothyGu/libilbc.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    echo "git clone --depth=1 --branch=\"$SCRIPT_COMMIT\" --recurse-submodules --shallow-submodules \"$SCRIPT_REPO\" ."
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        ..
    ninja -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja install
}

ffbuild_configure() {
    echo --enable-libilbc
}

ffbuild_libs() {
    echo -lilbc
}

ffbuild_unconfigure() {
    echo --disable-libilbc
}
