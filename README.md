# Marcshared FFmpeg Builds

This is my opinionated FFmpeg build fork: a Windows x64 shared FFmpeg package meant to be the practical "just give me the all-in-one build" option.

The goal is simple: keep an hourly-updated FFmpeg master build around with as many useful codecs, filters, demuxers, muxers, hardware paths, and helper libraries enabled as is reasonably maintainable. Give or take the occasional upstream breakage, weird dependency, or library that needs extra care.

This repository is based on BtbN FFmpeg-Builds, but the `marcshared` variant is tuned for my own Windows use case rather than small download size or a minimal dependency set.

## Main Build

The main custom build is:

- Target: `win64`
- Variant: `nonfree-marcshared`
- Platform: Windows x86_64
- FFmpeg source: upstream FFmpeg `master`
- Linking style: shared FFmpeg libraries

In plain English: this is meant to be the maximum-useful Windows FFmpeg build I actually want to run locally.

## What It Tries To Include

The `nonfree-marcshared` variant starts from the normal shared Windows dependency set, then layers on additional libraries that are useful but not always present in generic builds.

Examples include:

- Common codec, filter, subtitle, image, audio, hardware, and analysis libraries from the base build system
- Additional Marcshared libraries such as `libspeex`, `libgsm`, `libcodec2`, `liblc3`, `libqrencode`, and `libquirc`

The exact list lives in `scripts.d/` and may change as FFmpeg master and upstream dependencies change. The intent is broad usefulness, not a frozen minimal matrix.

## Release Cadence

The release workflow checks upstream FFmpeg hourly.

Scheduled runs skip rebuilding when the latest release already contains the current upstream FFmpeg master SHA. Image rebuilds can also trigger a release build directly when the dependency image changes.

Release versions are timestamp-based:

```text
YYYYMMDD.HHMMSS
```

Release tags and assets use this pattern:

```text
ffmpeg-YYYYMMDD.HHMMSS-win64-nonfree-marcshared
ffmpeg-YYYYMMDD.HHMMSS-win64-nonfree-marcshared.zip
```

That keeps Scoop version comparisons sane while still recording the upstream FFmpeg SHA in the release notes.

## Install With Scoop

The intended install path is my Scoop bucket:

```powershell
scoop bucket add marcmy https://github.com/marcmy/scoop-bucket
scoop install ffmpeg-nonfree-marcshared
```

Update normally with:

```powershell
scoop update
scoop update ffmpeg-nonfree-marcshared
```

After installing, you can verify the build config with:

```powershell
ffmpeg -hide_banner -buildconf
```

## Manual Build

### Prerequisites

- Bash
- Docker

### Build the Marcshared Image

```bash
./makeimage.sh win64 nonfree-marcshared
```

### Build FFmpeg From the Image

```bash
./build.sh win64 nonfree-marcshared
```

On success, the resulting zip file will be in the `artifacts` directory.

## Targets, Variants, and Addins

The upstream build system still supports the broader target/variant matrix, but this fork's custom automation is focused on `win64 nonfree-marcshared`.

Common targets include:

- `win64` - x86_64 Windows
- `win32` - x86 Windows
- `linux64` - x86_64 Linux, glibc >= 2.28, linux >= 4.18
- `linuxarm64` - arm64/aarch64 Linux, glibc >= 2.28, linux >= 4.18

Common variants include:

- `gpl`
- `lgpl`
- `nonfree`
- `gpl-shared`
- `lgpl-shared`
- `nonfree-shared`
- `nonfree-marcshared` - my custom all-in-one shared Windows variant

Optional addins from the base project may still be used where supported, such as release-branch addins or debug builds.

## Notes

This is not an official FFmpeg build, and it is not trying to be the smallest package. It is a personal all-in-one build aimed at having almost everything I am likely to need in one constantly refreshed Windows FFmpeg install.

If a dependency breaks against FFmpeg master, the fix is usually to patch the dependency script, temporarily disable the problematic library, or wait for upstream to settle down. That is the tradeoff of tracking master with a broad dependency set.
