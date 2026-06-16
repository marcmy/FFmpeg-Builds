#!/bin/bash

SCRIPT_REPO="https://github.com/TimothyGu/libilbc.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    if [[ -x ./bootstrap.sh ]]; then
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
}

ffbuild_configure() {
    echo --enable-libilbc
}

ffbuild_libs() {
    echo -lilbc
}

ffbuild_unconfigure() {
    echo --disable-libilbc
}
