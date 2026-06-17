#!/bin/bash

SCRIPT_REPO="https://gitlab.gnome.org/GNOME/glib.git"
SCRIPT_COMMIT="main"

ffbuild_depends() {
    echo base
    echo zlib
    echo libiconv
    echo libffi
    echo pcre2
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
    )

    add_meson_option() {
        local name="$1"
        local value="$2"

        if [[ -f meson_options.txt ]] && grep -Eq "option\(['\"]${name}['\"]" meson_options.txt; then
            myconf+=("-D${name}=${value}")
        fi
    }

    add_meson_option tests false
    add_meson_option installed_tests false
    add_meson_option installed-tests false
    add_meson_option introspection disabled
    add_meson_option documentation false
    add_meson_option gtk_doc false
    add_meson_option gtk-doc false
    add_meson_option man false
    add_meson_option man-pages disabled
    add_meson_option selinux disabled
    add_meson_option libmount disabled
    add_meson_option xattr false
    add_meson_option dtrace false
    add_meson_option systemtap false

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

    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc" ]]; then
        if grep -q '^Libs.private:' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc"; then
            sed -i 's/^Libs.private:.*/& -lws2_32 -lole32 -lwinmm -lshlwapi -lintl -liconv/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc"
        else
            echo 'Libs.private: -lws2_32 -lole32 -lwinmm -lshlwapi -lintl -liconv' >> "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc"
        fi
    fi
}
