#!/bin/bash

SCRIPT_REPO="https://github.com/mstorsjo/rtmpdump.git"
SCRIPT_COMMIT="master"

ffbuild_depends() {
    echo base
    echo zlib
    echo openssl
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    make -C librtmp -j$(nproc) \
        CC="$FFBUILD_TOOLCHAIN-gcc" \
        AR="$FFBUILD_TOOLCHAIN-ar" \
        RANLIB="$FFBUILD_TOOLCHAIN-ranlib" \
        SYS=mingw \
        CRYPTO=OPENSSL \
        XCFLAGS="$CFLAGS" \
        XLDFLAGS="$LDFLAGS" \
        prefix="$FFBUILD_PREFIX" \
        librtmp.a

    install -Dm644 librtmp/librtmp.a "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/librtmp.a"
    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/librtmp"
    cp -a librtmp/*.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/librtmp/"

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/librtmp.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: librtmp
Description: RTMP client library
Version: 2.4
Requires.private: libssl libcrypto zlib
Libs: -L\${libdir} -lrtmp
Libs.private: -lws2_32 -lwinmm -lgdi32
Cflags: -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-librtmp
}

ffbuild_libs() {
    echo -lws2_32 -lwinmm -lgdi32
}

ffbuild_unconfigure() {
    echo --disable-librtmp
}
