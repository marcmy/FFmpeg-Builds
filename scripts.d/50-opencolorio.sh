#!/bin/bash

SCRIPT_REPO="https://github.com/AcademySoftwareFoundation/OpenColorIO.git"
SCRIPT_COMMIT="v2.5.2"

ffbuild_depends() {
    echo base
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # OpenColorIO 2.5.2 bundles a yaml-cpp revision whose emitterutils.cpp
    # uses uint16_t/uint32_t without including <cstdint>. GCC 15 no longer
    # accepts that accidental transitive include. CXXFLAGS is inherited by
    # OCIO's CMake ExternalProject builds, so force the standard header there.
    export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-include cstdint"

    cmake -G Ninja -S . -B ffbuild-build \
        -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=OFF \
        -DOCIO_BUILD_SHARED=OFF \
        -DOCIO_BUILD_STATIC=ON \
        -DOCIO_BUILD_APPS=OFF \
        -DOCIO_BUILD_DOCS=OFF \
        -DOCIO_BUILD_FROZEN_DOCS=OFF \
        -DOCIO_BUILD_GPU_TESTS=OFF \
        -DOCIO_BUILD_JAVA=OFF \
        -DOCIO_BUILD_NUKE=OFF \
        -DOCIO_BUILD_OPENFX=OFF \
        -DOCIO_BUILD_PYTHON=OFF \
        -DOCIO_BUILD_TESTS=OFF \
        -DOCIO_INSTALL_EXT_PACKAGES=ALL \
        -DOCIO_USE_SSE=OFF \
        -DOCIO_WARNING_AS_ERROR=OFF

    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    local pc="$FFBUILD_DESTPREFIX/lib/pkgconfig/OpenColorIO.pc"
    if [[ ! -f "$pc" ]]; then
        echo "OpenColorIO pkg-config file was not installed: $pc"
        return 1
    fi
}

ffbuild_configure() {
    echo --enable-libopencolorio
}

ffbuild_libs() {
    echo -lstdc++
}

ffbuild_unconfigure() {
    echo --disable-libopencolorio
}
