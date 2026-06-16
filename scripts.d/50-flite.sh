#!/bin/bash

SCRIPT_REPO="https://github.com/festvox/flite.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    local make_args=(
        CC="$FFBUILD_TOOLCHAIN-gcc"
        AR="$FFBUILD_TOOLCHAIN-ar"
        RANLIB="$FFBUILD_TOOLCHAIN-ranlib"
    )

    ./configure --prefix="$FFBUILD_PREFIX" --host="$FFBUILD_TOOLCHAIN" --disable-shared --with-pic

    make -C src -j$(nproc) "${make_args[@]}"
    make -C lang -j$(nproc) "${make_args[@]}"

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib"
    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/flite"

    find build -name 'libflite*.a' -type f -print0 | while IFS= read -r -d '' lib; do
        install -Dm644 "$lib" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/$(basename "$lib")"
    done

    cp -a include/*.h "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/flite/"
}

ffbuild_configure() {
    echo --enable-libflite
}

ffbuild_libs() {
    echo -lflite_cmu_time_awb -lflite_cmu_us_awb -lflite_cmu_us_kal -lflite_cmu_us_kal16 -lflite_cmu_us_rms -lflite_cmu_us_slt -lflite_usenglish -lflite_cmulex -lflite
}

ffbuild_unconfigure() {
    echo --disable-libflite
}
