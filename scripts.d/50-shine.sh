#!/bin/bash

SCRIPT_REPO="https://github.com/toots/shine.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    if [[ -x ./bootstrap ]]; then
        ./bootstrap
    elif [[ -x ./bootstrap.sh ]]; then
        ./bootstrap.sh
    elif [[ -x ./autogen.sh ]]; then
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

    if [[ ! -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/shine.pc" ]]; then
        mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
        cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/shine.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: shine
Description: shine
Version: 3.1.1
Libs: -L\${libdir} -lshine
Cflags: -I\${includedir}
EOF
    fi
}

ffbuild_configure() {
    echo --enable-libshine
}

ffbuild_unconfigure() {
    echo --disable-libshine
}
