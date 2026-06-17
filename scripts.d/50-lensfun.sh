#!/bin/bash

SCRIPT_REPO="https://github.com/lensfun/lensfun.git"
SCRIPT_COMMIT="master"

ffbuild_depends() {
    echo base
    echo glib2
}

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    rm -rf ffbuild-build
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DCMAKE_INSTALL_DATAROOTDIR=share \
        -DBUILD_STATIC=ON \
        -DBUILD_TESTS=OFF \
        -DBUILD_LENSTOOL=OFF \
        -DBUILD_DOC=OFF \
        -DINSTALL_PYTHON_MODULE=OFF \
        -DINSTALL_HELPER_SCRIPTS=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/lensfun.pc" ]]; then
        sed -i 's/^Cflags:.*/Cflags: -DCONF_LENSFUN_STATIC -I${includedir}/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/lensfun.pc"
        if grep -q '^Libs.private:' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/lensfun.pc"; then
            sed -i 's/^Libs.private:.*/& -lstdc++ -lglib-2.0 -lintl -liconv -lpcre2-8 -lffi -lz -lws2_32 -lole32 -lwinmm -lshlwapi/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/lensfun.pc"
        else
            echo 'Libs.private: -lstdc++ -lglib-2.0 -lintl -liconv -lpcre2-8 -lffi -lz -lws2_32 -lole32 -lwinmm -lshlwapi' >> "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/lensfun.pc"
        fi
    fi
}

ffbuild_configure() {
    echo --enable-liblensfun
}

ffbuild_cflags() {
    echo -DCONF_LENSFUN_STATIC
}

ffbuild_libs() {
    echo -lstdc++ -lglib-2.0 -lintl -liconv -lpcre2-8 -lffi -lz -lws2_32 -lole32 -lwinmm -lshlwapi
}

ffbuild_unconfigure() {
    echo --disable-liblensfun
}
