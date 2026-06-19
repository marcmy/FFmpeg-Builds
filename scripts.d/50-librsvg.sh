#!/bin/bash

SCRIPT_REPO="https://gitlab.gnome.org/GNOME/librsvg.git"
SCRIPT_COMMIT="2.61.4"

ffbuild_depends() {
    echo base
    echo fonts
    echo glib2
    echo libxml2
    echo cairo
    echo pango
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    local rust_target_key="${FFBUILD_RUST_TARGET//-/_}"
    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --buildtype=release
        --default-library=static
        --cross-file=/cross.meson
        -Dintrospection=disabled
        -Dpixbuf=disabled
        -Dpixbuf-loader=disabled
        -Drsvg-convert=disabled
        -Ddocs=disabled
        -Dvala=disabled
        -Dtests=false
        -Dtriplet="$FFBUILD_RUST_TARGET"
        -Davif=disabled
    )

    export "AR_${rust_target_key}"="$AR"
    export "RANLIB_${rust_target_key}"="$RANLIB"
    export "NM_${rust_target_key}"="$NM"
    export "LD_${rust_target_key}"="$LD"
    export "CC_${rust_target_key}"="$CC"
    export "CXX_${rust_target_key}"="$CXX"
    export "CFLAGS_${rust_target_key}"="$CFLAGS"
    export "CXXFLAGS_${rust_target_key}"="$CXXFLAGS"
    export "LDFLAGS_${rust_target_key}"="$LDFLAGS"
    export "PKG_CONFIG_${rust_target_key}"="$PKG_CONFIG"
    export "PKG_CONFIG_LIBDIR_${rust_target_key}"="$PKG_CONFIG_LIBDIR"
    export PKG_CONFIG_ALLOW_CROSS=1

    rm -rf ffbuild-build
    meson setup ffbuild-build "${myconf[@]}"
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install
}

ffbuild_configure() {
    echo --enable-librsvg
}

ffbuild_unconfigure() {
    echo --disable-librsvg
}
