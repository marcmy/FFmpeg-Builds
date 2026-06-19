#!/bin/bash

SCRIPT_REPO="https://gitlab.gnome.org/GNOME/pango.git"
SCRIPT_COMMIT="1.56.4"

ffbuild_depends() {
    echo base
    echo fonts
    echo fribidi
    echo glib2
    echo cairo
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --buildtype=release
        --default-library=static
        --cross-file=/cross.meson
    )

    add_meson_option() {
        local name="$1"
        local value="$2"

        if [[ -f meson_options.txt ]] && grep -Eq "option\(['\"]${name}['\"]" meson_options.txt; then
            myconf+=("-D${name}=${value}")
        fi
    }

    add_meson_option introspection disabled
    add_meson_option gtk_doc false
    add_meson_option gtk-doc false
    add_meson_option install-tests false
    add_meson_option build-testsuite false
    add_meson_option build-examples false
    add_meson_option build-tools false
    add_meson_option xft disabled
    add_meson_option libthai disabled
    add_meson_option cairo enabled
    add_meson_option fontconfig enabled
    add_meson_option freetype enabled

    rm -rf ffbuild-build
    meson setup ffbuild-build "${myconf[@]}"
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install
}
