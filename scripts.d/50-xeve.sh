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

    # Upstream may still produce a MinGW runtime DLL/import pair even when the
    # FFmpeg probe links successfully. Install the DLL into bin so shared Windows
    # packages do not ship an ffmpeg.exe that depends on a missing libxeve.dll.
    find ffbuild-build -type f \( -name 'libxeve.dll' -o -name 'xeve.dll' \) -print0 | while IFS= read -r -d '' dll; do
        install -Dm755 "$dll" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/bin/$(basename "$dll")"
    done
    find ffbuild-build -type f \( -name 'libxeve.dll.a' -o -name 'xeve.dll.a' \) -print0 | while IFS= read -r -d '' importlib; do
        install -Dm644 "$importlib" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/$(basename "$importlib")"
    done

    find inc -name '*.h' -type f -print0 | while IFS= read -r -d '' header; do
        install -Dm644 "$header" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/$(basename "$header")"
    done

    local export_header
    export_header="$(find ffbuild-build -name 'xeve_exports.h' -type f -print -quit)"
    if [[ -n "$export_header" ]]; then
        install -Dm644 "$export_header" "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/xeve_exports.h"
    else
        cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/include/xeve_exports.h" <<'EOF'
#ifndef XEVE_EXPORTS_H
#define XEVE_EXPORTS_H
#ifndef XEVE_EXPORT
#define XEVE_EXPORT
#endif
#endif
EOF
    fi

    mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
    cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/xeve.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: xeve
Description: eXtra-fast Essential Video Encoder, MPEG-5 EVC
Version: 0.5.1
Libs: -L\${libdir} -lxeve
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
