#!/bin/bash

SCRIPT_REPO="https://github.com/mstorsjo/vo-amrwbenc.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    if [[ -x ./autogen.sh ]]; then
        ./autogen.sh
    else
        autoreconf -fiv
    fi

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --host="$FFBUILD_TOOLCHAIN"
    )

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"

    if [[ ! -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/vo-amrwbenc.pc" ]]; then
        mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
        cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/vo-amrwbenc.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: vo-amrwbenc
Description: vo-amrwbenc
Version: 0.1.3
Libs: -L\${libdir} -lvo-amrwbenc
Cflags: -I\${includedir}
EOF
    fi
}

ffbuild_configure() {
    echo --enable-libvo-amrwbenc
}

ffbuild_unconfigure() {
    echo --disable-libvo-amrwbenc
}
