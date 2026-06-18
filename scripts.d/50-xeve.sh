#!/bin/bash

SCRIPT_REPO="https://github.com/mpeg5/xeve.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # Shallow/minimal clones may not have tags. Upstream CMake requires either
    # a git tag or version.txt matching vMAJOR.MINOR.PATCH.
    [[ -f version.txt ]] || echo v0.5.1 > version.txt

    rm -rf ffbuild-build
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DSET_PROF=MAIN \
        -DXEVE_APP_STATIC_BUILD=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install || true

    local lib
    lib="$(find ffbuild-build -name 'libxeve.a' -type f -print -quit)"
    [[ -n "$lib" ]] || return -1
    install -Dm644 "$lib" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/libxeve.a"

    # Do not leave import libraries in the prefix. If libxeve.dll.a exists,
    # MinGW may prefer it over libxeve.a and produce an avcodec DLL that imports
    # libxeve.dll even though no runtime DLL is shipped.
    rm -f \
        "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/libxeve.dll.a" \
        "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/xeve.dll.a" \
        "$FFBUILD_DESTDIR$FFBUILD_PREFIX/bin/libxeve.dll" \
        "$FFBUILD_DESTDIR$FFBUILD_PREFIX/bin/xeve.dll"

    find inc -name '*.h' -type f -print0 | while IFS= read -r -d '' header; do
        install -Dm644 "$header" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/$(basename "$header")"
    done

    # Force static-consumer export semantics. Some generated export headers can
    # mark symbols as DLL imports, which makes FFmpeg depend on libxeve.dll.
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/xeve_exports.h" <<'EOF'
#ifndef XEVE_EXPORTS_H
#define XEVE_EXPORTS_H
#ifndef XEVE_EXPORT
#define XEVE_EXPORT
#endif
#endif
EOF

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/xeve.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: xeve
Description: eXtra-fast Essential Video Encoder, MPEG-5 EVC
Version: 0.5.1
Libs: \${libdir}/libxeve.a
Libs.private: -lm
Cflags: -DXEVE_STATIC_DEFINE -I\${includedir}
EOF
}

ffbuild_configure() {
    echo --enable-libxeve
}

ffbuild_cflags() {
    echo -DXEVE_STATIC_DEFINE
}

ffbuild_libs() {
    echo -lm
}

ffbuild_unconfigure() {
    echo --disable-libxeve
}
