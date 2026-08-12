#!/bin/bash
# Compatibility policy for the win64-marc-shared distribution.
# Keep this file declarative: build scripts and release metadata consume it.
# Marc Shared follows the current nv-codec-headers snapshot selected by
# scripts.d/50-ffnvcodec.sh instead of pinning a separate SDK branch.

MARC_NVENC_API="13.1"
MARC_NVIDIA_MIN_DRIVER="610.0"
