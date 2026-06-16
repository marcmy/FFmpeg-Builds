#!/bin/bash

SCRIPT_REPO="https://github.com/cacalabs/libcaca.git"
SCRIPT_COMMIT="main"

ffbuild_depends() {
    echo base
    echo zlib
}

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    ./bootstrap

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --host="$FFBUILD_TOOLCHAIN"
        --disable-slang
        --disable-ncurses
        --disable-conio
        --enable-win32
        --disable-x11
        --disable-gl
        --disable-cocoa
        --disable-network
        --disable-csharp
        --disable-java
        --disable-cxx
        --disable-python
        --disable-ruby
        --disable-imlib2
        --disable-doc
        --disable-cppunit
        --disable-zzuf
        --disable-plugins
    )

    ./configure "${myconf[@]}"

    # Current MinGW headers provide vsnprintf_s, but libcaca's configure probe
    # can still report it missing. If left undefined, libcaca declares/defines
    # a weak fallback that collides with MinGW's inline implementation.
    sed -i 's|/\* #undef HAVE_VSNPRINTF_S \*/|#define HAVE_VSNPRINTF_S 1|' config.h

    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"

    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/caca.pc" ]]; then
        sed -i 's/^Libs.private:.*/Libs.private: -lz/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/caca.pc"
    fi
}

ffbuild_configure() {
    echo --enable-libcaca
}

ffbuild_libs() {
    echo -lz
}

ffbuild_unconfigure() {
    echo --disable-libcaca
}
