#!/bin/bash

SCRIPT_REPO="https://github.com/tesseract-ocr/tesseract.git"
SCRIPT_COMMIT="5.5.2"

ffbuild_depends() {
    echo base
    echo leptonica
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # Tesseract spells the Windows socket library as Ws2_32. MinGW's linker
    # searches case-sensitively on Linux, while the import library is lowercase.
    sed -i 's/set(LIB_Ws2_32 Ws2_32)/set(LIB_Ws2_32 ws2_32)/' CMakeLists.txt

    cmake -G Ninja -S . -B ffbuild-build \
        -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TRAINING_TOOLS=OFF \
        -DBUILD_TESTS=OFF \
        -DSW_BUILD=OFF \
        -DOPENMP_BUILD=OFF \
        -DGRAPHICS_DISABLED=ON \
        -DENABLE_NATIVE=OFF \
        -DENABLE_PRECOMPILED_HEADERS=OFF \
        -DENABLE_CCACHE=OFF \
        -DENABLE_NINJA_POOL=OFF \
        -DDISABLE_TIFF=ON \
        -DLEPT_TIFF_RESULT=1 \
        -DDISABLE_ARCHIVE=ON \
        -DDISABLE_CURL=ON \
        -DINSTALL_CONFIGS=OFF

    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    local pc="$FFBUILD_DESTPREFIX/lib/pkgconfig/tesseract.pc"
    if [[ ! -f "$pc" ]]; then
        echo "Tesseract pkg-config file was not installed: $pc"
        return 1
    fi

    # FFmpeg links the static OCR stack into avfilter. Leptonica's CMake install
    # does not provide lept.pc here, so keep it directly in Tesseract's static
    # link closure instead of leaving an unsatisfied Requires.private entry.
    sed -i '/^Requires.private:/d' "$pc"
    sed -i 's/^Libs.private:.*/Libs.private: -lleptonica -lstdc++ -lws2_32/' "$pc"
}

ffbuild_configure() {
    echo --enable-libtesseract
}

ffbuild_libs() {
    echo -lstdc++ -lws2_32
}

ffbuild_unconfigure() {
    echo --disable-libtesseract
}
