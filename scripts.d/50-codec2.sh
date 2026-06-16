#!/bin/bash

SCRIPT_REPO="https://github.com/drowe67/codec2.git"
SCRIPT_COMMIT="310777b1c6f1af0bc7c72f5b32f80f6fd9136962"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # Codec2 builds a native generate_codebook helper during MinGW cross builds.
    # Its CMake ExternalProject install step can fail copying the helper on this
    # image, so use a shell copy with a suffix-tolerant glob and normalize the
    # final filename expected by the imported executable target.
    python3 - <<'PY'
from pathlib import Path
p = Path('src/CMakeLists.txt')
s = p.read_text()
old = 'INSTALL_COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/codec2_native/src/generate_codebook ${CMAKE_CURRENT_BINARY_DIR}'
new = 'INSTALL_COMMAND /bin/sh -c "cp -f ${CMAKE_CURRENT_BINARY_DIR}/codec2_native/src/generate_codebook* ${CMAKE_CURRENT_BINARY_DIR}/generate_codebook"'
if old not in s:
    raise SystemExit('codec2 native helper copy command not found')
p.write_text(s.replace(old, new))
PY

    mkdir build && cd build

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DUNITTEST=OFF -DLPCNET=OFF ..
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_configure() {
    echo --enable-libcodec2
}

ffbuild_unconfigure() {
    echo --disable-libcodec2
}
