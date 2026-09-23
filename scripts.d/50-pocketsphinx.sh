#!/bin/bash

SCRIPT_REPO="https://github.com/cmusphinx/pocketsphinx.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_PROGRAMS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/pocketsphinx"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/pocketsphinx/pocketsphinx.h" <<'EOF'
#ifndef FFMPEG_POCKETSPHINX_COMPAT_H
#define FFMPEG_POCKETSPHINX_COMPAT_H

#include <pocketsphinx.h>

typedef ps_config_t cmd_ln_t;

static inline cmd_ln_t *cmd_ln_parse_r(cmd_ln_t *config, const ps_arg_t *defn,
                                        int argc, char *argv[], int strict)
{
    int own_config = 0;
    (void)strict;

    if (config == NULL) {
        config = ps_config_init(defn);
        own_config = 1;
    }
    if (config == NULL)
        return NULL;

    for (int i = 0; i + 1 < argc; i += 2) {
        const char *name = argv[i][0] == '-' ? argv[i] + 1 : argv[i];
        const char *value = argv[i + 1];

        if (value != NULL && ps_config_set_str(config, name, value) == NULL) {
            if (own_config)
                ps_config_free(config);
            return NULL;
        }
    }

    return config;
}

static inline int cmd_ln_free_r(cmd_ln_t *config)
{
    return ps_config_free(config);
}

#endif
EOF
}

ffbuild_configure() {
    echo --enable-pocketsphinx
}

ffbuild_libs() {
    echo -lm
}

ffbuild_unconfigure() {
    echo --disable-pocketsphinx
}
