#!/bin/bash

SCRIPT_REPO="https://github.com/alanxz/rabbitmq-c.git"
SCRIPT_COMMIT="v0.15.0"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_TOOLS=OFF \
        -DBUILD_TOOLS_DOCS=OFF \
        -DBUILD_API_DOCS=OFF \
        -DENABLE_SSL_SUPPORT=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install
}

ffbuild_configure() {
    echo --enable-librabbitmq
}

ffbuild_unconfigure() {
    echo --disable-librabbitmq
}
