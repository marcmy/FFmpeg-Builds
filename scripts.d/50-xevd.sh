#!/bin/bash

SCRIPT_REPO="https://github.com/mpeg5/xevd.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # Shallow/minimal clones may not have tags. Upstream CMake requires either
    # a git tag or version.txt matching vMAJOR.MINOR.PATCH.
    [[ -f version.txt ]] || echo v0.5.0 > version.txt

    rm -rf ffbuild-build
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DSET_PROF=MAIN \
        -DXEVD_APP_STATIC_BUILD=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install || true

    local lib
    lib="$(find ffbuild-build -name 'libxevd.a' -type f -print -quit)"
    [[ -n "$lib" ]] || return -1
    install -Dm644 "$lib" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/libxevd.a"

    # Do not leave import libraries in the prefix. With only libxevd.a present,
    # -L${libdir} -lxevd resolves to the static archive while preserving the
    # normal linker ordering used by FFmpeg's configure tests.
    find "$FFBUILD_DESTDIR$FFBUILD_PREFIX" -type f \
        \( -name 'libxevd.dll.a' -o -name 'xevd.dll.a' -o -name 'libxevd.dll' -o -name 'xevd.dll' \) \
        -delete

    find inc -name '*.h' -type f -print0 | while IFS= read -r -d '' header; do
        install -Dm644 "$header" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/$(basename "$header")"
    done

    # Force static-consumer export semantics. Some generated export headers can
    # mark symbols as DLL imports, which makes FFmpeg depend on libxevd.dll.
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/xevd_exports.h" <<'EOF'
#ifndef XEVD_EXPORTS_H
#define XEVD_EXPORTS_H
#ifndef XEVD_EXPORT
#define XEVD_EXPORT
#endif
#endif
EOF

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/xevd.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: xevd
Description: eXtra-fast Essential Video Decoder, MPEG-5 EVC
Version: 0.5.0
Libs: -L\${libdir} -lxevd
Libs.private: -lm
Cflags: -DXEVD_STATIC_DEFINE -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-libxevd
}

ffbuild_cflags() {
    echo -DXEVD_STATIC_DEFINE
}

ffbuild_libs() {
    echo -lm
}

ffbuild_unconfigure() {
    echo --disable-libxevd
}
