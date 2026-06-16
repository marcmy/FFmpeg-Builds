#!/bin/bash

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    return 0
}

ffbuild_dockerbuild() {
    apt-get -y update
    apt-get -y install --no-install-recommends ladspa-sdk

    install -Dm644 /usr/include/ladspa.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/ladspa.h"

    apt-get -y clean autoclean
    rm -rf /var/lib/apt/lists/*
}

ffbuild_configure() {
    echo --enable-ladspa
}

ffbuild_unconfigure() {
    echo --disable-ladspa
}
