#!/bin/bash

ffbuild_enabled() {
    [[ $VARIANT == *marcshared* ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    return 0
}

# This helper does not build a normal dependency layer. It only injects ccache
# into the final marcshared builder image so release builds can persist compiler
# objects outside the container.
ffbuild_dockerstage() {
    return 0
}

ffbuild_dockerlayer() {
    return 0
}

ffbuild_dockerfinal() {
    to_df "RUN apt-get -y update && apt-get -y install --no-install-recommends ccache && apt-get -y clean autoclean && rm -rf /var/lib/apt/lists/*"
}
