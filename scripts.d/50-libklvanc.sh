#!/bin/bash

SCRIPT_REPO="https://github.com/stoth68000/libklvanc.git"
SCRIPT_COMMIT="master"

ffbuild_depends() {
    echo base
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # libklvanc assumes glibc-style <sys/errno.h>; MinGW provides the standard
    # <errno.h> instead. Patch both public/private headers before configuring.
    grep -RIl '#include <sys/errno.h>' src | while IFS= read -r header; do
        sed -i 's|#include <sys/errno.h>|#include <errno.h>|g' "$header"
    done

    ./autogen.sh --build

    ./configure \
        --prefix="$FFBUILD_PREFIX" \
        --host="$FFBUILD_TOOLCHAIN" \
        --disable-shared \
        --enable-static \
        --disable-debug

    # FFmpeg only needs the library and public headers. Skip the example/test
    # tools, which are irrelevant to the dependency image and more likely to
    # trip over host-specific assumptions during a MinGW cross-build.
    make -C src -j$(nproc)
    make -C src install DESTDIR="$FFBUILD_DESTDIR"

    test -f "$FFBUILD_DESTPREFIX/lib/libklvanc.a"
    test -f "$FFBUILD_DESTPREFIX/include/libklvanc/vanc.h"
}

ffbuild_configure() {
    echo --enable-libklvanc
}

ffbuild_libs() {
    echo -lpthread -lstdc++ -lm
}

ffbuild_unconfigure() {
    echo --disable-libklvanc
}
