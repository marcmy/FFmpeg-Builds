#!/bin/bash

SCRIPT_REPO="https://github.com/drowe67/codec2.git"
SCRIPT_COMMIT="310777b1c6f1af0bc7c72f5b32f80f6fd9136962"

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    # Codec2 needs a build-machine generator during MinGW cross builds.
    # Build that helper with the native Linux compiler and point CMake's
    # imported generate_codebook target at it, instead of letting the
    # ExternalProject inherit the MinGW compiler and produce a Windows exe.
    cc -O2 -o native_generate_codebook src/generate_codebook.c -lm

    python3 - <<'PY'
from pathlib import Path
p = Path('src/CMakeLists.txt')
s = p.read_text()
start = s.index('if(CMAKE_CROSSCOMPILING)')
end = s.index('else(CMAKE_CROSSCOMPILING)', start)
replacement = '''if(CMAKE_CROSSCOMPILING)
    add_executable(generate_codebook IMPORTED GLOBAL)
    set_target_properties(generate_codebook PROPERTIES
        IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/native_generate_codebook")
'''
p.write_text(s[:start] + replacement + s[end:])
PY

    mkdir build && cd build

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DUNITTEST=OFF -DLPCNET=OFF ..
    cmake --build . --target codec2 --parallel $(nproc)
    DESTDIR="$FFBUILD_DESTDIR" cmake --install .
}

ffbuild_configure() {
    echo --enable-libcodec2
}

ffbuild_unconfigure() {
    echo --disable-libcodec2
}
