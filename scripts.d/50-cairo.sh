#!/bin/bash

SCRIPT_REPO="https://gitlab.freedesktop.org/cairo/cairo.git"
SCRIPT_COMMIT="master"

ffbuild_depends() {
    echo base
    echo pixman
    echo zlib
}

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --buildtype=release
        --default-library=static
        -Dtests=disabled
        -Dperf_tests=disabled
        -Dspectre=disabled
        -Dsymbol-lookup=disabled
        -Dpng=disabled
        -Dxlib=disabled
        -Dxcb=disabled
        -Dquartz=disabled
        -Dgtk_doc=false
    )

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(--cross-file=/cross.meson)
    else
        echo "Unknown target"
        return -1
    fi

    rm -rf ffbuild-build
    meson setup ffbuild-build "${myconf[@]}"
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/cairo.pc" ]]; then
        sed -i 's/^Cflags:.*/Cflags: -DCAIRO_WIN32_STATIC_BUILD -I${includedir}\/cairo/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/cairo.pc"
    fi
}

ffbuild_configure() {
    echo --enable-cairo
}

ffbuild_cflags() {
    echo -DCAIRO_WIN32_STATIC_BUILD
}

ffbuild_unconfigure() {
    echo --disable-cairo
}
