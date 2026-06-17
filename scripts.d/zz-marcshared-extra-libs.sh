#!/bin/bash

# Aggregate script that preserves BtbN's existing final/root dependency and
# appends Marc-only extras for the custom marcshared variant.
ffbuild_depends() {
    local previous_root

    previous_root="$(ls -1d scripts.d/* | grep -v "/$(basename "$SELF")$" | tail -n 1)"
    previous_root="$(basename "$previous_root")"
    previous_root="${previous_root#??-}"
    previous_root="${previous_root%.sh}"

    echo "$previous_root"

    if [[ $VARIANT == *marcshared* ]]; then
        echo ccache
        echo speex
        echo gsm
        echo codec2
        echo lc3
        echo qrencode
        echo quirc
        echo ladspa
        echo lcms2
        echo bs2b
        echo ilbc
        echo modplug
        echo shine
        echo vo-amrwbenc
        echo mysofa
        echo caca
        echo flite
        echo cairo
        echo lensfun
        echo libcdio-paranoia
    fi
}

ffbuild_enabled() {
    return 0
}

# This is a dependency-graph aggregator only. There is no source repo to
# download/build, so keep download.sh from invoking the default git downloader
# with empty SCRIPT_REPO/SCRIPT_COMMIT values.
ffbuild_dockerdl() {
    return 0
}
