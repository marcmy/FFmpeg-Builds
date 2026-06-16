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
        echo speex
        echo gsm
        echo codec2
        echo lc3
        echo qrencode
        echo quirc
    fi
}

ffbuild_enabled() {
    return 0
}
