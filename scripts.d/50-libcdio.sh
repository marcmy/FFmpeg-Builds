#!/bin/bash

SCRIPT_REPO="https://github.com/libcdio/libcdio.git"
SCRIPT_COMMIT="master"

ffbuild_depends() {
    echo base
}

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    autoreconf -fiv

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --disable-cxx
        --disable-cpp-progs
        --disable-example-progs
        --without-versioned-libs
        --without-cd-drive
        --without-cd-info
        --without-cdda-player
        --without-cd-read
        --without-iso-info
        --without-iso-read
    )

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(--host="$FFBUILD_TOOLCHAIN")
    else
        echo "Unknown target"
        return -1
    fi

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}
