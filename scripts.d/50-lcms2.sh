#!/bin/bash

SCRIPT_REPO="https://github.com/mm2/Little-CMS.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DLCMS2_BUILD_SHARED=OFF \
        -DLCMS2_BUILD_STATIC=ON \
        -DLCMS2_BUILD_TOOLS=OFF \
        -DLCMS2_BUILD_TESTS=OFF \
        -DLCMS2_WITH_JPEG=OFF \
        -DLCMS2_WITH_TIFF=OFF \
        -DLCMS2_WITH_ZLIB=OFF \
        ..
    ninja -j$(nproc)

    install -Dm644 liblcms2.a "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/liblcms2.a"
    install -Dm644 ../include/lcms2.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/lcms2.h"
    install -Dm644 ../include/lcms2_plugin.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/lcms2_plugin.h"

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/lcms2.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: lcms2
Description: Little CMS color management library
Version: 2.19
Libs: -L\${libdir} -llcms2
Libs.private: -lm
Cflags: -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-lcms2
}

ffbuild_unconfigure() {
    echo --disable-lcms2
}
