#!/bin/bash

# Final dependency root. Preserve the repository's previous root stage for every
# variant, then attach Marc Shared-only additions here so new standalone stages
# cannot silently fall outside generate.sh's dependency walk.
ffbuild_depends() {
    local self_name previous_entry previous_stage entry

    self_name="$(basename "$SELF")"
    previous_entry="$({
        for entry in scripts.d/*; do
            [[ "$(basename "$entry")" == "$self_name" ]] && continue
            basename "$entry"
        done
    } | LC_ALL=C sort | tail -n 1)"

    if [[ -z "$previous_entry" ]]; then
        echo "Unable to resolve the previous scripts.d root stage." >&2
        return 1
    fi

    previous_stage="${previous_entry#??-}"
    previous_stage="${previous_stage%.sh}"
    echo "$previous_stage"

    if [[ $VARIANT == *marc-shared* ]]; then
        echo tesseract
        echo opencolorio
        echo vapoursynth
        echo libklvanc
    fi
}

ffbuild_enabled() {
    return 0
}

# This is an aggregation node only; its dependencies provide all build output.
ffbuild_dockerbuild() {
    :
}
