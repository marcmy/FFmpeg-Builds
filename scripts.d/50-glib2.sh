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
        local options_file

        for options_file in meson.options meson_options.txt; do
            if [[ -f "$options_file" ]] && grep -Eq "option\(['\"]${name}['\"]" "$options_file"; then
                myconf+=("-D${name}=${value}")
                return 0
            fi
        done
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

    # run_stage removes the installed bin directory because target executables
    # cannot run on the Linux builder. Preserve GLib's architecture-neutral
    # Python build tools elsewhere so Pango/librsvg can use them while crossing.
    local host_tools_dir="$FFBUILD_DESTDIR$FFBUILD_PREFIX/libexec/ffbuild-glib-tools"
    local tool
    mkdir -p "$host_tools_dir"
    for tool in glib-mkenums glib-genmarshal gdbus-codegen glib-gettextize gtester-report; do
        if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/bin/$tool" ]]; then
            install -m755 "$FFBUILD_DESTDIR$FFBUILD_PREFIX/bin/$tool" "$host_tools_dir/$tool"
        fi
    done

    if [[ -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc" ]]; then
        if grep -q '^Libs.private:' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc"; then
            sed -i 's/^Libs.private:.*/& -lws2_32 -lole32 -lwinmm -lshlwapi -lintl -liconv/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc"
        else
            echo 'Libs.private: -lws2_32 -lole32 -lwinmm -lshlwapi -lintl -liconv' >> "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/glib-2.0.pc"
        fi
    fi
}
