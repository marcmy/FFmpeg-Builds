#!/bin/bash

SCRIPT_REPO="https://github.com/Fraunhofer-IIS/mpeghdec.git"
SCRIPT_COMMIT="r3.0.3"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    python3 - <<'PY'
from pathlib import Path

path = Path("src/libFDK/include/common_fix.h")
lines = path.read_text().splitlines(keepends=True)
if not lines[453].startswith("FDK_INLINE SHORT fMax"):
    raise SystemExit("Unexpected MPEG-H fMax location")
if not lines[456].startswith("FDK_INLINE SHORT fMin"):
    raise SystemExit("Unexpected MPEG-H fMin location")
del lines[453:459]
path.write_text("".join(lines))

pc = Path("mpeghdec.pc.in")
text = pc.read_text()
old = 'Cflags: -I"${includedir}"\n'
new = 'Cflags: -I"${includedir}" -DMPEGHDEC_STATIC\n'
if text.count(old) != 1:
    raise SystemExit("Unexpected MPEG-H pkg-config template")
pc.write_text(text.replace(old, new))
PY

    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -Dmpeghdec_BUILD_BINARIES=OFF \
        -Dmpeghdec_BUILD_DOC=OFF \
        -DUSE_PKGCONFIG_DEPS=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install
}

ffbuild_configure() {
    echo --enable-libmpeghdec
}

ffbuild_libs() {
    echo -lstdc++ -lm
}

ffbuild_unconfigure() {
    echo --disable-libmpeghdec
}
