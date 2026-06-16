#!/bin/bash

SCRIPT_REPO="https://github.com/google/liblc3.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    local cc="$FFBUILD_TOOLCHAIN-gcc"
    local ar="$FFBUILD_TOOLCHAIN-ar"
    local ranlib="$FFBUILD_TOOLCHAIN-ranlib"
    local cflags=(
        -O3
        -std=c11
        -Wall
        -Wextra
        -Wdouble-promotion
        -Wvla
        -pedantic
        -ffast-math
        -fPIC
        -DLC3_PLUS=1
        -DLC3_PLUS_HR=1
        -Iinclude
    )
    local srcs=(
        src/attdet.c
        src/bits.c
        src/bwdet.c
        src/energy.c
        src/lc3.c
        src/ltpf.c
        src/mdct.c
        src/plc.c
        src/sns.c
        src/spec.c
        src/tables.c
        src/tns.c
    )
    local objs=()

    mkdir -p build
    for src in "${srcs[@]}"; do
        obj="build/$(basename "$src" .c).o"
        "$cc" "${cflags[@]}" -c "$src" -o "$obj"
        objs+=("$obj")
    done

    "$ar" rcs liblc3.a "${objs[@]}"
    "$ranlib" liblc3.a

    install -Dm644 liblc3.a "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/liblc3.a"
    install -Dm644 include/lc3.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/lc3.h"
    install -Dm644 include/lc3_private.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/lc3_private.h"

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/lc3.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: lc3
Description: Low Complexity Communication Codec
Version: 1.1.0
Libs: -L\${libdir} -llc3 -lm
Cflags: -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-liblc3
}

ffbuild_unconfigure() {
    echo --disable-liblc3
}
