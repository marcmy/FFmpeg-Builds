#!/bin/bash

SCRIPT_REPO="https://github.com/dlbeer/quirc.git"
SCRIPT_COMMIT="dd7d1ab9dd732bdf66d8434821f97db467b8d620"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    mkdir -p build "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"

    local cc="$FFBUILD_TOOLCHAIN-gcc"
    local ar="$FFBUILD_TOOLCHAIN-ar"
    local ranlib="$FFBUILD_TOOLCHAIN-ranlib"
    local objs=()

    for src in lib/decode.c lib/identify.c lib/quirc.c lib/version_db.c; do
        obj="build/$(basename "$src" .c).o"
        "$cc" -O3 -Wall -fPIC -Ilib -c "$src" -o "$obj"
        objs+=("$obj")
    done

    "$ar" rcs libquirc.a "${objs[@]}"
    "$ranlib" libquirc.a

    cp libquirc.a "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/libquirc.a"
    cp lib/quirc.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/quirc.h"

    {
        echo "prefix=$FFBUILD_PREFIX"
        echo 'exec_prefix=${prefix}'
        echo 'libdir=${prefix}/lib'
        echo 'includedir=${prefix}/include'
        echo
        echo 'Name: quirc'
        echo 'Description: quirc'
        echo 'Version: 1.2'
        echo 'Libs: -L${libdir} -lquirc -lm'
        echo 'Cflags: -I${includedir}'
    } > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/quirc.pc"
}

ffbuild_configure() {
    echo --enable-libquirc
}

ffbuild_unconfigure() {
    echo --disable-libquirc
}
