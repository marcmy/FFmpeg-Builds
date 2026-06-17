#!/bin/bash

SCRIPT_REPO="https://github.com/alexmarsev/libbs2b.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    local cc="$FFBUILD_TOOLCHAIN-gcc"
    local ar="$FFBUILD_TOOLCHAIN-ar"
    local ranlib="$FFBUILD_TOOLCHAIN-ranlib"

    "$cc" $CFLAGS -Isrc -c src/bs2b.c -o bs2b.o
    "$ar" rcs libbs2b.a bs2b.o
    "$ranlib" libbs2b.a

    install -Dm644 libbs2b.a "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/libbs2b.a"
    for header in src/*.h; do
        install -Dm644 "$header" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/$(basename "$header")"
    done

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libbs2b.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libbs2b
Description: libbs2b
Version: 3.1.0
Libs: -L\${libdir} -lbs2b
Libs.private: -lm
Cflags: -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-libbs2b
}

ffbuild_unconfigure() {
    echo --disable-libbs2b
}
