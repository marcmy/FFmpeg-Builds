#!/bin/bash

SCRIPT_REPO="https://github.com/HorstBaerbel/libgsm.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    make CC="$FFBUILD_TOOLCHAIN-gcc -ansi -pedantic" AR="$FFBUILD_TOOLCHAIN-ar" RANLIB="$FFBUILD_TOOLCHAIN-ranlib" lib/libgsm.a

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/gsm" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cp lib/libgsm.a "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/libgsm.a"
    cp inc/gsm.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/gsm/gsm.h"
    cp inc/gsm.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/gsm.h"

    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/gsm.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: gsm
Description: GSM 06.10 lossy speech compression
Version: 1.0.22
Libs: -L\${libdir} -lgsm
Cflags: -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-libgsm
}

ffbuild_cflags() {
    echo -I/ffbuild/prefix/include
}

ffbuild_libs() {
    echo -lgsm
}

ffbuild_unconfigure() {
    echo --disable-libgsm
}
