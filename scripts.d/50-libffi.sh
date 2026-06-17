#!/bin/bash

SCRIPT_REPO="https://github.com/libffi/libffi.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # libffi master still references LT_SYS_SYMBOL_USCORE, which newer libtool
    # no longer provides. For the x86_64-w64-mingw32 target used here, symbols
    # are not prefixed with underscores, so provide the result directly before
    # regenerating configure.
    sed -i 's/^LT_SYS_SYMBOL_USCORE$/sys_symbol_underscore=no/' configure.ac
    ./autogen.sh

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --with-pic
        --disable-docs
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
