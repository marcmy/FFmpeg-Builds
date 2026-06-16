#!/bin/bash

SCRIPT_REPO="https://github.com/hoene/libmysofa.git"
SCRIPT_COMMIT="main"

ffbuild_depends() {
    echo base
    echo zlib
}

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    rm -rf ffbuild-build
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_TESTS=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    # Be explicit for downstream static consumers. Newer CMake export headers
    # may use this define to avoid dllimport annotations with static linking.
    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libmysofa.pc" ]]; then
        sed -i 's/^Cflags:.*/Cflags: -DMYSOFA_STATIC -DMYSOFA_STATIC_DEFINE -I${includedir}/' \
            "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libmysofa.pc"
    fi
}

ffbuild_configure() {
    echo --enable-libmysofa
}

ffbuild_cflags() {
    echo -DMYSOFA_STATIC -DMYSOFA_STATIC_DEFINE
}

ffbuild_libs() {
    echo -lz
}

ffbuild_unconfigure() {
    echo --disable-libmysofa
}
