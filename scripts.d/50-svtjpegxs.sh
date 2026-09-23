#!/bin/bash

SCRIPT_REPO="https://github.com/OpenVisualCloud/SVT-JPEG-XS.git"
SCRIPT_COMMIT="main"

ffbuild_enabled() {
    [[ $VARIANT == *marc-shared* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    rm -rf ffbuild-build
    cmake -G Ninja -S . -B ffbuild-build -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_APPS=OFF \
        -DBUILD_TESTING=OFF \
        -DENABLE_NASM=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    ninja -C ffbuild-build -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja -C ffbuild-build install

    if [[ ! -f "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/SvtJpegxs.pc" ]]; then
        mkdir -p "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig"
        cat > "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/SvtJpegxs.pc" <<EOF
prefix=$FFBUILD_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include/svt-jpegxs

Name: SvtJpegxs
Description: Intel SVT JPEG XS codec library
Version: 0.10.0
Libs: -L\${libdir} -lSvtJpegxs
Libs.private: -lstdc++ -lm
Cflags: -I\${includedir}
EOF
    else
        if grep -q '^Libs.private:' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/SvtJpegxs.pc"; then
            sed -i 's/^Libs.private:.*/& -lstdc++ -lm/' "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/SvtJpegxs.pc"
        else
            echo 'Libs.private: -lstdc++ -lm' >> "$FFBUILD_DESTDIR$FFBUILD_PREFIX/lib/pkgconfig/SvtJpegxs.pc"
        fi
    fi
}

ffbuild_configure() {
    echo --enable-libsvtjpegxs
}

ffbuild_libs() {
    echo -lstdc++ -lm
}

ffbuild_unconfigure() {
    echo --disable-libsvtjpegxs
}
