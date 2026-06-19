#!/bin/bash
# Marc's custom nonfree shared Windows build variant.
# Starts as BtbN win64-nonfree-shared; extra deps are layered in by the marc-shared aggregator.
source "$(dirname "$BASH_SOURCE")"/win64-nonfree-shared.sh

# librsvg and rav1e are both Rust static libraries built by the same toolchain.
# Each archive carries an identical copy of the Rust runtime, so GNU ld otherwise
# rejects the final FFmpeg DLL link with duplicate std/core/gimli/object symbols.
FF_LDFLAGS+=" -Wl,--allow-multiple-definition"
