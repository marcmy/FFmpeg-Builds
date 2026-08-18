#!/bin/bash
set -xeo pipefail
cd "$(dirname "$0")"
source util/vars.sh

TMPCFG="$(mktemp --suffix=.toml)"
cat <<EOF >"$TMPCFG"
[worker.oci]
  max-parallelism = 4
EOF
trap "rm -f '$TMPCFG'" EXIT

docker buildx inspect ffbuilder &>/dev/null || docker buildx create \
    --bootstrap \
    --name ffbuilder \
    --config "$TMPCFG" \
    --driver-opt network=host \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=-1

hash_stage() {
    { find "$1" -type f -exec sha256sum {} + ; printf '%s\n' "$@"; } | sha256sum | cut -d" " -f1
}

prune_cache() {
    [[ -d "$1" ]] || return 0
    find "$1" -mindepth 1 -maxdepth 1 ! -name "$2" -exec rm -rf {} +
}

if [[ -z "$QUICKBUILD" ]]; then
    BASE_HASH="$(hash_stage images/base)"
    BASE_IMAGE_TARGET="${PWD}/.cache/images/base/${BASE_HASH}"
    prune_cache .cache/images/base "${BASE_HASH}"
    if [[ ! -d "${BASE_IMAGE_TARGET}" ]]; then
        docker buildx --builder ffbuilder build \
            --cache-from=type=local,src=.cache/"${BASE_IMAGE/:/_}" \
            --cache-to=type=local,mode=max,dest=.cache/"${BASE_IMAGE/:/_}" \
            --load --tag "${BASE_IMAGE}" \
            "images/base"
        mkdir -p "${BASE_IMAGE_TARGET}"
        docker image save "${BASE_IMAGE}" | tar -x -C "${BASE_IMAGE_TARGET}"
    fi

    TARGET_HASH="$(hash_stage "images/base-${TARGET}" "${BASE_HASH}" "${REGISTRY}/${REPO}")"
    IMAGE_TARGET="${PWD}/.cache/images/base-${TARGET}/${TARGET_HASH}"
    prune_cache .cache/images/base-"${TARGET}" "${TARGET_HASH}"
    if [[ ! -d "${IMAGE_TARGET}" ]]; then
        docker buildx --builder ffbuilder build \
            --cache-from=type=local,src=.cache/"${TARGET_IMAGE/:/_}" \
            --cache-to=type=local,mode=max,dest=.cache/"${TARGET_IMAGE/:/_}" \
            --build-arg GH_REPO="${REGISTRY}/${REPO}" \
            --build-context "${BASE_IMAGE}=oci-layout://${BASE_IMAGE_TARGET}" \
            --load --tag "${TARGET_IMAGE}" \
            "images/base-${TARGET}"
        mkdir -p "${IMAGE_TARGET}"
        docker image save "${TARGET_IMAGE}" | tar -x -C "${IMAGE_TARGET}"
    fi

    CONTEXT_SRC="oci-layout://${IMAGE_TARGET}"
else
    CONTEXT_SRC="docker-image://${TARGET_IMAGE}"
fi

./download.sh
./generate.sh "$TARGET" "$VARIANT" "${ADDINS[@]}"

FINAL_CACHE_ARGS=()

trim_cache_spec() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

if [[ "${FFBUILD_LOCAL_FINAL_CACHE:-1}" != 0 ]]; then
    FINAL_CACHE_ARGS+=(
        --cache-from=type=local,src=.cache/"${IMAGE/:/_}"
        --cache-to=type=local,mode=max,dest=.cache/"${IMAGE/:/_}"
    )
fi

if [[ -n "${FFBUILD_DOCKER_CACHE_FROM:-}" ]]; then
    while IFS= read -r cache_from; do
        cache_from="$(trim_cache_spec "$cache_from")"
        [[ -n "$cache_from" ]] || continue
        FINAL_CACHE_ARGS+=(--cache-from="$cache_from")
    done <<< "$FFBUILD_DOCKER_CACHE_FROM"
fi

if [[ -n "${FFBUILD_DOCKER_CACHE_TO:-}" ]]; then
    while IFS= read -r cache_to; do
        cache_to="$(trim_cache_spec "$cache_to")"
        [[ -n "$cache_to" ]] || continue
        FINAL_CACHE_ARGS+=(--cache-to="$cache_to")
    done <<< "$FFBUILD_DOCKER_CACHE_TO"
fi

docker buildx --builder ffbuilder build \
    "${FINAL_CACHE_ARGS[@]}" \
    --build-context "${TARGET_IMAGE}=${CONTEXT_SRC}" \
    --load --tag "$IMAGE" .

if [[ -z "$NOCLEAN" ]]; then
    docker buildx rm -f ffbuilder
    rm -rf .cache/images
fi
