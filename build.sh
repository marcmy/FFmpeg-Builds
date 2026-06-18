#!/bin/bash
set -xe
shopt -s globstar
cd "$(dirname "$0")"
source util/vars.sh

source "variants/${TARGET}-${VARIANT}.sh"

for addin in ${ADDINS[*]}; do
    source "addins/${addin}.sh"
done

if docker info -f "{{println .SecurityOptions}}" | grep rootless >/dev/null 2>&1; then
    UIDARGS=()
else
    UIDARGS=( -u "$(id -u):$(id -g)" )
fi

rm -rf ffbuild
mkdir ffbuild

FFMPEG_REPO="${FFMPEG_REPO:-https://github.com/FFmpeg/FFmpeg.git}"
FFMPEG_REPO="${FFMPEG_REPO_OVERRIDE:-$FFMPEG_REPO}"
GIT_BRANCH="${GIT_BRANCH:-master}"
GIT_BRANCH="${GIT_BRANCH_OVERRIDE:-$GIT_BRANCH}"

CCACHE_ARGS=()
if [[ -n "${FFBUILD_CCACHE_DIR:-}" ]]; then
    mkdir -p "$FFBUILD_CCACHE_DIR"
    CCACHE_ARGS=( -v "$FFBUILD_CCACHE_DIR":/ccache )
fi

BUILD_SCRIPT="$(mktemp)"
trap "rm -f -- '$BUILD_SCRIPT'" EXIT

cat <<'EOF' >"$BUILD_SCRIPT"
set -xe
cd /ffbuild
rm -rf ffmpeg prefix

if command -v ccache >/dev/null 2>&1 && [[ -d /ccache ]]; then
    export CCACHE_DIR=/ccache
    export CCACHE_COMPILERCHECK=content
    export CCACHE_MAXSIZE="${FFBUILD_CCACHE_MAX_SIZE:-5G}"
    ccache --set-config=max_size="$CCACHE_MAXSIZE" || true
    ccache --zero-stats || true

    mkdir -p /tmp/ccache-wrappers
    ln -sf "$(command -v ccache)" "/tmp/ccache-wrappers/$CC"
    ln -sf "$(command -v ccache)" "/tmp/ccache-wrappers/$CXX"
    export PATH="/tmp/ccache-wrappers:$PATH"
fi

git clone --filter=blob:none --branch='__GIT_BRANCH__' '__FFMPEG_REPO__' ffmpeg
cd ffmpeg

./configure --prefix=/ffbuild/prefix --pkg-config-flags="--static" $FFBUILD_TARGET_FLAGS $FF_CONFIGURE \
    --extra-cflags="$FF_CFLAGS" --extra-cxxflags="$FF_CXXFLAGS" --extra-libs="$FF_LIBS" \
    --extra-ldflags="$FF_LDFLAGS" --extra-ldexeflags="$FF_LDEXEFLAGS" \
    --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --nm="$NM" \
    --extra-version="$(date +%Y%m%d)" || { cat ffbuild/config.log; exit 1; }
make -j$(nproc) V=1
make install install-doc

copy_runtime_dlls() {
    local exe_dir="/ffbuild/prefix/bin"
    local required_tmp
    local missing=0

    required_tmp="$(mktemp)"
    trap 'rm -f "$required_tmp"' RETURN

    for exe in "$exe_dir"/*.exe; do
        [[ -f "$exe" ]] || continue
        echo "Inspecting runtime DLL imports for $(basename "$exe")"
        x86_64-w64-mingw32-objdump -p "$exe" |
            awk '/DLL Name:/ { print tolower($3) }' >> "$required_tmp"
    done

    sort -u "$required_tmp" | while IFS= read -r dll; do
        [[ -n "$dll" ]] || continue

        case "$dll" in
            avcodec-*.dll|avdevice-*.dll|avfilter-*.dll|avformat-*.dll|avutil-*.dll|postproc-*.dll|swresample-*.dll|swscale-*.dll)
                continue
                ;;
            kernel32.dll|user32.dll|gdi32.dll|advapi32.dll|shell32.dll|ole32.dll|oleaut32.dll|uuid.dll|ws2_32.dll|winmm.dll|shlwapi.dll|bcrypt.dll|crypt32.dll|secur32.dll|mfplat.dll|mfreadwrite.dll|mfuuid.dll|strmiids.dll|vfw32.dll|version.dll|setupapi.dll|cfgmgr32.dll|comdlg32.dll|comctl32.dll|dwmapi.dll|dxgi.dll|d3d11.dll|d3d12.dll|dxva2.dll|opengl32.dll|imm32.dll|normaliz.dll|ntdll.dll|msvcrt.dll)
                continue
                ;;
        esac

        if [[ -f "$exe_dir/$dll" ]]; then
            continue
        fi

        runtime_src="$(find /opt/ffbuild /usr/x86_64-w64-mingw32 -iname "$dll" -type f -print -quit 2>/dev/null || true)"
        if [[ -n "$runtime_src" ]]; then
            echo "Copying dependency runtime DLL $runtime_src into FFmpeg package bin"
            cp -av "$runtime_src" "$exe_dir/$(basename "$runtime_src")"
            continue
        fi

        echo "Missing runtime DLL required by packaged FFmpeg binaries: $dll"
        missing=1
    done

    return "$missing"
}

copy_runtime_dlls

if command -v ccache >/dev/null 2>&1 && [[ -d /ccache ]]; then
    ccache --show-stats || true
fi
EOF

sed -i \
    -e "s|__GIT_BRANCH__|$GIT_BRANCH|g" \
    -e "s|__FFMPEG_REPO__|$FFMPEG_REPO|g" \
    "$BUILD_SCRIPT"

[[ -t 1 ]] && TTY_ARG="-t" || TTY_ARG=""

docker run --rm -i $TTY_ARG "${UIDARGS[@]}" "${CCACHE_ARGS[@]}" -v "$PWD/ffbuild":/ffbuild -v "$BUILD_SCRIPT":/build.sh "$IMAGE" bash /build.sh

if [[ -n "$FFBUILD_OUTPUT_DIR" ]]; then
    mkdir -p "$FFBUILD_OUTPUT_DIR"
    package_variant ffbuild/prefix "$FFBUILD_OUTPUT_DIR"
    [[ -n "$LICENSE_FILE" ]] && cp "ffbuild/ffmpeg/$LICENSE_FILE" "$FFBUILD_OUTPUT_DIR/LICENSE.txt"
    rm -rf ffbuild
    exit 0
fi

mkdir -p artifacts
ARTIFACTS_PATH="$PWD/artifacts"
BUILD_NAME="ffmpeg-$(./ffbuild/ffmpeg/ffbuild/version.sh ffbuild/ffmpeg)-${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"

mkdir -p "ffbuild/pkgroot/$BUILD_NAME"
package_variant ffbuild/prefix "ffbuild/pkgroot/$BUILD_NAME"

[[ -n "$LICENSE_FILE" ]] && cp "ffbuild/ffmpeg/$LICENSE_FILE" "ffbuild/pkgroot/$BUILD_NAME/LICENSE.txt"

cd ffbuild/pkgroot
if [[ "${TARGET}" == win* ]]; then
    OUTPUT_FNAME="${BUILD_NAME}.zip"
    docker run --rm -i $TTY_ARG "${UIDARGS[@]}" -v "${ARTIFACTS_PATH}":/out -v "${PWD}/${BUILD_NAME}":"/${BUILD_NAME}" -w / "$IMAGE" zip -9 -r "/out/${OUTPUT_FNAME}" "$BUILD_NAME"
else
    OUTPUT_FNAME="${BUILD_NAME}.tar.xz"
    docker run --rm -i $TTY_ARG "${UIDARGS[@]}" -v "${ARTIFACTS_PATH}":/out -v "${PWD}/${BUILD_NAME}":"/${BUILD_NAME}" -w / "$IMAGE" tar cJf "/out/${OUTPUT_FNAME}" "$BUILD_NAME"
fi
cd -

rm -rf ffbuild

if [[ -n "$GITHUB_ACTIONS" ]]; then
    echo "build_name=${BUILD_NAME}" >> "$GITHUB_OUTPUT"
    echo "${OUTPUT_FNAME}" > "${ARTIFACTS_PATH}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}.txt"
fi
