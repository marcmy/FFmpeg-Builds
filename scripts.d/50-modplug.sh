#!/bin/bash

SCRIPT_REPO="https://github.com/Konstanty/libmodplug.git"
SCRIPT_COMMIT="master"

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

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/libmodplug.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libmodplug
Description: libmodplug
Version: 0.8.9.1
Libs: -L\${libdir} -lmodplug
Libs.private: -lstdc++
Cflags: -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-libmodplug
}

ffbuild_libs() {
    echo -lstdc++
}

ffbuild_unconfigure() {
    echo --disable-libmodplug
}
