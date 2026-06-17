#!/bin/bash

SCRIPT_REPO="https://github.com/libcdio/libcdio-paranoia.git"
SCRIPT_COMMIT="master"

ffbuild_depends() {
    echo base
    echo libcdio
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
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
        --disable-ld-version-script
    )

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(--host="$FFBUILD_TOOLCHAIN")
    else
        echo "Unknown target"
        return -1
    fi

    ./configure "${myconf[@]}"

    # Build only the libraries FFmpeg probes. The recursive default build enters
    # src/ and builds the cd-paranoia program, whose bundled getopt conflicts
    # with MinGW's getopt prototype.
    make -C include -j$(nproc)
    make -C lib -j$(nproc)

    make -C include install DESTDIR="$FFBUILD_DESTDIR"
    make -C lib install DESTDIR="$FFBUILD_DESTDIR"
    make install-pkgconfigDATA DESTDIR="$FFBUILD_DESTDIR"

    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_paranoia.pc" ]]; then
        if grep -q '^Libs.private:' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_paranoia.pc"; then
            sed -i 's/^Libs.private:.*/& -lcdio_cdda -lcdio -lm -lwinmm/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_paranoia.pc"
        else
            echo 'Libs.private: -lcdio_cdda -lcdio -lm -lwinmm' >> "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_paranoia.pc"
        fi
    fi

    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_cdda.pc" ]]; then
        if grep -q '^Libs.private:' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_cdda.pc"; then
            sed -i 's/^Libs.private:.*/& -lcdio -lm -lwinmm/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_cdda.pc"
        else
            echo 'Libs.private: -lcdio -lm -lwinmm' >> "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libcdio_cdda.pc"
        fi
    fi
}

ffbuild_configure() {
    echo --enable-libcdio
}

ffbuild_libs() {
    echo -lcdio_paranoia -lcdio_cdda -lcdio -lm -lwinmm
}

ffbuild_unconfigure() {
    echo --disable-libcdio
}
