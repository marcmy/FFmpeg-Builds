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
        local options_file

        for options_file in meson.options meson_options.txt; do
            if [[ -f "$options_file" ]] && grep -Eq "option\(['\"]${name}['\"]" "$options_file"; then
                myconf+=("-D${name}=${value}")
                return 0
            fi
        done
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

    # Pango 1.56.4 calls FcFreeTypeQueryAll() without including the header
    # that declares it. Newer Pango includes this upstream.
    if ! grep -q '^#include <fontconfig/fcfreetype.h>' pango/pangofc-fontmap.c; then
        sed -i '/^#include <hb-ft.h>/a #include <fontconfig/fcfreetype.h>' pango/pangofc-fontmap.c
    fi

    # GLib's pkg-config files point to $prefix/bin, but run_stage removes that
    # directory from cross-built dependencies. Recreate only the host-runnable
    # Python tools from the preserved GLib tool bundle.
    local host_tools_dir="$FFBUILD_PREFIX/libexec/ffbuild-glib-tools"
    local tool
    mkdir -p "$FFBUILD_PREFIX/bin"
    for tool in glib-mkenums glib-genmarshal; do
        if [[ ! -x "$host_tools_dir/$tool" ]]; then
            echo "Missing preserved GLib host tool: $host_tools_dir/$tool"
            return 1
        fi
        ln -sf "../libexec/ffbuild-glib-tools/$tool" "$FFBUILD_PREFIX/bin/$tool"
    done

    rm -rf ffbuild-build
    meson setup ffbuild-build "${myconf[@]}"
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install
}
