# Build runbook

Scope: native `linux-x64` and `linux-arm64` builds. `win-x64` is deferred. The decision record lives under `.scratch/custom-builds/`.

## Prerequisites

Ubuntu 24.04 LTS host with:

- `clang`
- `libstdc++-14-dev`
- `libtbb-dev`
- `cmake` (>= 3.16)
- `python3`
- `git`

## Source delta

The build requires the C++23 source fixes listed in `.xeofoundry/SOURCE-DELTAS.md`. They are not upstream yet.

## Version

`POTREE_CONVERTER_VERSION` defaults to `v2.1.6`. Bump it by hand in sync with the `vX.Y.Z` release tag on `develop`.

## Build

```sh
.xeofoundry/build.sh linux-x64
.xeofoundry/build.sh linux-arm64 --clean
.xeofoundry/build.sh linux-x64 -DPOTREE_CONVERTER_VERSION=v2.1.7
```

Each platform target builds into its own directory. A platform target that does not match `uname -m` is refused.

## Smoke test

Run from the target's build output directory:

```sh
cd .xeofoundry/build/linux-x64
../../../.xeofoundry/test/smoke.sh ../../../Converter/libs/laszip/example
```

The script converts every `.las`/`.laz` in the given folder under `UNCOMPRESSED` and `BROTLI` and checks the output metadata. The converter anchors the output bounding box at the fixture header minimum and expands it to a cube whose side is the largest header extent; the smoke check asserts that expansion within one quantization step.

## Outputs

Each platform target's build directory is self-contained:

```text
.xeofoundry/build/<platform-target>/
├── PotreeConverter
├── VERSION
├── resources/page_template
├── licenses/
└── README.md
```
