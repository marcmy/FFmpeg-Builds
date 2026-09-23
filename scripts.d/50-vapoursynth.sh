#!/bin/bash

SCRIPT_REPO="https://github.com/vapoursynth/vapoursynth.git"
SCRIPT_COMMIT="R77"

ffbuild_depends() {
    echo base
}

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # FFmpeg only needs the VapourSynth 4 headers at build time. Its demuxer
    # loads VSScript.dll dynamically at runtime, so do not drag Python and the
    # complete VapourSynth runtime into the FFmpeg dependency image.
    local include_dir="$FFBUILD_DESTPREFIX/include/vapoursynth"

    install -d "$include_dir"
    install -m 0644 include/*.h "$include_dir/"

    test -f "$include_dir/VapourSynth4.h"
    test -f "$include_dir/VSScript4.h"
}

ffbuild_configure() {
    echo --enable-vapoursynth
}

ffbuild_unconfigure() {
    echo --disable-vapoursynth
}
