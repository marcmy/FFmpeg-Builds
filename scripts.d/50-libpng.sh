#!/bin/bash

SCRIPT_REPO="https://github.com/pnggroup/libpng.git"
SCRIPT_COMMIT="v1.6.58"

ffbuild_depends() {
    echo base
    echo zlib
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    local myconf=(
        -S .
        -B ffbuild-build
        -G Ninja
        -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX"
        -DBUILD_SHARED_LIBS=OFF
        -DPNG_SHARED=OFF
        -DPNG_STATIC=ON
        -DPNG_TESTS=OFF
        -DPNG_TOOLS=OFF
    )

    cmake "${myconf[@]}"
    cmake --build ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" cmake --install ffbuild-build
}
