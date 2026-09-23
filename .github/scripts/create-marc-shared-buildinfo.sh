#!/bin/bash
set -euo pipefail

: "${ZIP_PATH:?ZIP_PATH is required}"
: "${BUILDINFO_PATH:?BUILDINFO_PATH is required}"
: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${FFMPEG_SHA:?FFMPEG_SHA is required}"
: "${IMAGE_INPUT_SHA:?IMAGE_INPUT_SHA is required}"
: "${IMAGE_REF:?IMAGE_REF is required}"

NV_CODEC_HEADERS_SCRIPT="${MARC_NV_CODEC_HEADERS_SCRIPT:-scripts.d/50-ffnvcodec.sh}"
if [[ ! -f "$NV_CODEC_HEADERS_SCRIPT" ]]; then
    echo "NV Codec headers build script not found: $NV_CODEC_HEADERS_SCRIPT" >&2
    exit 1
fi
# Source the normal dependency declaration so metadata records the exact
# nv-codec-headers source snapshot selected by the build.
# shellcheck disable=SC1090
source "$NV_CODEC_HEADERS_SCRIPT"

NV_CODEC_HEADERS_REPO="${SCRIPT_REPO:-}"
NV_CODEC_HEADERS_COMMIT="${SCRIPT_COMMIT:-}"
for required_var in NV_CODEC_HEADERS_REPO NV_CODEC_HEADERS_COMMIT; do
    if [[ -z "${!required_var:-}" ]]; then
        echo "Unable to resolve $required_var from $NV_CODEC_HEADERS_SCRIPT" >&2
        exit 1
    fi
done

zip_sha256="$(sha256sum "$ZIP_PATH" | awk '{print $1}')"
zip_size="$(stat -c '%s' "$ZIP_PATH")"
image_id="$(docker image inspect "$IMAGE_REF" --format '{{.Id}}')"
image_repo_digest="$(docker image inspect "$IMAGE_REF" --format '{{range .RepoDigests}}{{println .}}{{end}}' | head -n 1)"

container_value() {
    local expression="$1"
    docker run --rm "$IMAGE_REF" bash -lc "$expression"
}

cc_version="$(container_value '$CC --version | head -n 1')"
ld_version="$(container_value '$LD --version | head -n 1')"
ff_configure="$(container_value 'printf %s "$FF_CONFIGURE"')"
ff_cflags="$(container_value 'printf %s "$FF_CFLAGS"')"
ff_cxxflags="$(container_value 'printf %s "$FF_CXXFLAGS"')"
ff_ldflags="$(container_value 'printf %s "$FF_LDFLAGS"')"
ff_ldexeflags="$(container_value 'printf %s "$FF_LDEXEFLAGS"')"
ff_libs="$(container_value 'printf %s "$FF_LIBS"')"

nvenc_major="$(container_value 'grep -m1 "^#define NVENCAPI_MAJOR_VERSION " "$FFBUILD_PREFIX/include/ffnvcodec/nvEncodeAPI.h" | tr -s " " | cut -d" " -f3')"
nvenc_minor="$(container_value 'grep -m1 "^#define NVENCAPI_MINOR_VERSION " "$FFBUILD_PREFIX/include/ffnvcodec/nvEncodeAPI.h" | tr -s " " | cut -d" " -f3')"
nv_codec_headers_sha256="$(container_value 'sha256sum "$FFBUILD_PREFIX/include/ffnvcodec/nvEncodeAPI.h" | cut -d" " -f1')"

if ! [[ "$nvenc_major" =~ ^[0-9]+$ && "$nvenc_minor" =~ ^[0-9]+$ ]]; then
    echo "Unable to detect NVENC API version from the dependency image." >&2
    exit 1
fi
if ! [[ "$nv_codec_headers_sha256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Unable to hash nvEncodeAPI.h from the dependency image." >&2
    exit 1
fi
nvenc_api="${nvenc_major}.${nvenc_minor}"

mkdir -p "$(dirname "$BUILDINFO_PATH")"

jq -n \
    --arg schema_version "2" \
    --arg release_tag "$RELEASE_TAG" \
    --arg package_name "$(basename "$ZIP_PATH")" \
    --arg package_sha256 "$zip_sha256" \
    --argjson package_size "$zip_size" \
    --arg target "${TARGET:-win64}" \
    --arg variant "${VARIANT:-marc-shared}" \
    --arg ffmpeg_repo "${UPSTREAM_REPO:-https://github.com/FFmpeg/FFmpeg.git}" \
    --arg ffmpeg_sha "$FFMPEG_SHA" \
    --arg builder_repo "${GITHUB_REPOSITORY:-marcmy/FFmpeg-Builds}" \
    --arg builder_sha "${BUILDER_SHA:-${GITHUB_SHA:-unknown}}" \
    --arg metadata_run_id "${GITHUB_RUN_ID:-unknown}" \
    --arg metadata_run_attempt "${GITHUB_RUN_ATTEMPT:-unknown}" \
    --arg created_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg image_input_sha "$IMAGE_INPUT_SHA" \
    --arg image_ref "$IMAGE_REF" \
    --arg image_id "$image_id" \
    --arg image_repo_digest "$image_repo_digest" \
    --arg nvenc_api "$nvenc_api" \
    --arg nv_codec_headers_repo "$NV_CODEC_HEADERS_REPO" \
    --arg nv_codec_headers_commit "$NV_CODEC_HEADERS_COMMIT" \
    --arg nv_codec_headers_sha256 "$nv_codec_headers_sha256" \
    --arg cc_version "$cc_version" \
    --arg ld_version "$ld_version" \
    --arg ff_configure "$ff_configure" \
    --arg ff_cflags "$ff_cflags" \
    --arg ff_cxxflags "$ff_cxxflags" \
    --arg ff_ldflags "$ff_ldflags" \
    --arg ff_ldexeflags "$ff_ldexeflags" \
    --arg ff_libs "$ff_libs" \
    '{
      schema_version: ($schema_version | tonumber),
      release: {
        tag: $release_tag,
        created_utc: $created_utc,
        package: {
          name: $package_name,
          sha256: $package_sha256,
          size_bytes: $package_size
        }
      },
      source: {
        ffmpeg: {
          repository: $ffmpeg_repo,
          commit: $ffmpeg_sha
        },
        builder: {
          repository: $builder_repo,
          commit: $builder_sha
        }
      },
      dependency_image: {
        input_commit: $image_input_sha,
        ref: $image_ref,
        image_id: $image_id,
        repository_digest: $image_repo_digest
      },
      build: {
        target: $target,
        variant: $variant,
        toolchain: {
          compiler: $cc_version,
          linker: $ld_version
        },
        ffmpeg: {
          configure: $ff_configure,
          cflags: $ff_cflags,
          cxxflags: $ff_cxxflags,
          ldflags: $ff_ldflags,
          ldexeflags: $ff_ldexeflags,
          libs: $ff_libs
        }
      },
      compatibility: {
        nvenc: {
          api: $nvenc_api,
          nv_codec_headers: {
            repository: $nv_codec_headers_repo,
            commit: $nv_codec_headers_commit,
            header_sha256: $nv_codec_headers_sha256
          }
        }
      },
      provenance: {
        metadata_generator: {
          github_run_id: $metadata_run_id,
          github_run_attempt: $metadata_run_attempt
        }
      }
    }' > "$BUILDINFO_PATH"

jq . "$BUILDINFO_PATH"
