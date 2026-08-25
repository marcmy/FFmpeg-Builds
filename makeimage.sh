#!/bin/bash
set -xeo pipefail
cd "$(dirname "$0")"
source util/vars.sh

docker buildx inspect ffbuilder &>/dev/null || docker buildx create \
    --bootstrap \
    --name ffbuilder \
    --buildkitd-flags "--oci-max-parallelism=4" \
    --driver-opt network=host \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=-1

if [[ -z "$NOCLEAN" ]]; then
    trap "docker buildx rm -f ffbuilder" EXIT
fi

GH_REPO="${REGISTRY}/${REPO}"
BAKE_TARGETS=( image )

if [[ -z "$QUICKBUILD" ]]; then
    BAKE_TARGETS+=( target-base )
fi

to_bake() {
    printf "$@"
    echo
}

trim_cache_spec() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

to_bake_list() {
    local key="$1"
    shift

    printf '  %s = [' "$key"
    local separator=""
    local value
    for value in "$@"; do
        printf '%s"%s"' "$separator" "$value"
        separator=', '
    done
    printf ']\n'
}

bake_images() {
    local -; set +x

    local final_cache_from=()
    local final_cache_to=()
    local cache_spec

    if [[ "${FFBUILD_LOCAL_FINAL_CACHE:-1}" != 0 ]]; then
        final_cache_from+=("type=local,src=.cache/${IMAGE/:/_}")
        final_cache_to+=("type=local,mode=max,dest=.cache/${IMAGE/:/_}")
    fi

    if [[ -n "${FFBUILD_DOCKER_CACHE_FROM:-}" ]]; then
        while IFS= read -r cache_spec; do
            cache_spec="$(trim_cache_spec "$cache_spec")"
            [[ -n "$cache_spec" ]] || continue
            final_cache_from+=("$cache_spec")
        done <<< "$FFBUILD_DOCKER_CACHE_FROM"
    fi

    if [[ -n "${FFBUILD_DOCKER_CACHE_TO:-}" ]]; then
        while IFS= read -r cache_spec; do
            cache_spec="$(trim_cache_spec "$cache_spec")"
            [[ -n "$cache_spec" ]] || continue
            final_cache_to+=("$cache_spec")
        done <<< "$FFBUILD_DOCKER_CACHE_TO"
    fi

    {
        if [[ -z "$QUICKBUILD" ]]; then
            to_bake 'target "base" {'
            to_bake '  context    = "images/base"'
            to_bake '  tags       = ["%s"]' "$BASE_IMAGE"
            to_bake '  output     = ["type=docker"]'
            to_bake '  cache-from = ["type=local,src=.cache/%s"]' "${BASE_IMAGE/:/_}"
            to_bake '  cache-to   = ["type=local,mode=max,dest=.cache/%s"]' "${BASE_IMAGE/:/_}"
            to_bake '}'

            to_bake 'target "target-base" {'
            to_bake '  context    = "images/base-%s"' "$TARGET"
            to_bake '  args       = { GH_REPO = "%s" }' "$GH_REPO"
            to_bake '  contexts   = { "%s/base" = "target:base" }' "$GH_REPO"
            to_bake '  tags       = ["%s"]' "$TARGET_IMAGE"
            to_bake '  output     = ["type=docker"]'
            to_bake '  cache-from = ["type=local,src=.cache/%s"]' "${TARGET_IMAGE/:/_}"
            to_bake '  cache-to   = ["type=local,mode=max,dest=.cache/%s"]' "${TARGET_IMAGE/:/_}"
            to_bake '}'
        fi

        to_bake 'target "image" {'
        to_bake '  context    = "."'
        if [[ -z "$QUICKBUILD" ]]; then
            to_bake '  contexts   = { "%s/base-%s" = "target:target-base" }' "$GH_REPO" "$TARGET"
        fi
        to_bake '  tags       = ["%s"]' "$IMAGE"
        to_bake '  output     = ["type=docker"]'
        if (( ${#final_cache_from[@]} )); then
            to_bake_list 'cache-from' "${final_cache_from[@]}"
        fi
        if (( ${#final_cache_to[@]} )); then
            to_bake_list 'cache-to' "${final_cache_to[@]}"
        fi
        to_bake '}'
    } | tee /dev/stderr | docker buildx --builder ffbuilder bake -f - "$@"
}

if [[ -z "$QUICKBUILD" ]]; then
    bake_images base
fi

./download.sh
./generate.sh "$TARGET" "$VARIANT" "${ADDINS[@]}"

bake_images "${BAKE_TARGETS[@]}"
