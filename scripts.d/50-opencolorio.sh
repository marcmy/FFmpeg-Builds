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
    # MinGW's std::ifstream wchar_t overload accepts a pointer, but GCC 15 no
    # longer accepts the std::wstring returned by filenameToUTF directly.
    sed -i 's/Platform::filenameToUTF(filepath), mode))/Platform::filenameToUTF(filepath).c_str(), mode))/' \
        src/OpenColorIO/transforms/FileTransform.cpp

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

    # OCIO 2.5.2 downloads yaml-cpp 0.8.0 as an ExternalProject. Its
    # emitterutils.cpp uses uint16_t/uint32_t without including <cstdint>,
    # which GCC 15 rejects. Materialize the downloaded source, then patch it
    # before the ExternalProject configure/build stamps are created.
    local yaml_patch_stamp="ext/build/yaml-cpp/src/yaml-cpp_install-stamp/yaml-cpp_install-patch"
    local yaml_source="ffbuild-build/ext/build/yaml-cpp/src/yaml-cpp_install/src/emitterutils.cpp"

    ninja -C ffbuild-build "$yaml_patch_stamp"

    if [[ ! -f "$yaml_source" ]]; then
        echo "OpenColorIO yaml-cpp source was not downloaded: $yaml_source"
        return 1
    fi

    if ! grep -q '^#include <cstdint>$' "$yaml_source"; then
        sed -i '/#include "yaml-cpp\/null.h"/i #include <cstdint>' "$yaml_source"
    fi

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
