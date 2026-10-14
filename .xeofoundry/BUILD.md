# Build runbook

Scope: native `linux-x64`, `linux-arm64`, and `win-x64` builds. All three targets are verified by the CI workflow at `.github/workflows/ci.yml`.

## Prerequisites

Ubuntu 24.04 LTS host with:

- `clang`
- `libstdc++-14-dev`
- `libtbb-dev` (optional; without it the parallel execution policies run on the serial backend)
- `cmake` (>= 3.16)
- `python3`
- `git`

Windows x64 host with:

- Windows 10 SDK (10.0.17763+) or newer
- Visual Studio 2022 17.7+ Build Tools with the MSVC v143 toolset
- `clang-cl` (LLVM 16+, or the Visual Studio ClangCL toolset)
- `cmake` (>= 3.16)
- `git`

## Source delta

The build requires the C++23 source fixes listed in `.xeofoundry/SOURCE-DELTAS.md`. They are not upstream yet.

## Version

`POTREE_CONVERTER_VERSION` defaults to `v2.1.5` (the latest upstream version). Bump it by hand in sync with the `vX.Y.Z` release tag on `develop`.

## Build

```sh
.xeofoundry/scripts/build.sh linux-x64
.xeofoundry/scripts/build.sh linux-arm64 --clean
.xeofoundry/scripts/build.sh linux-x64 -DPOTREE_CONVERTER_VERSION=v2.1.7
```

```powershell
.\.xeofoundry\scripts\build.ps1 -PlatformTarget win-x64 -Clean
```

`build.ps1` imports the Visual Studio environment itself, so it does not need to be run from a developer prompt. It configures CMake with the `NMake Makefiles` generator and `clang-cl`.

Each platform target builds into its own directory. A platform target that does not match the host architecture is refused.

## Smoke test

Run from the target's build output directory:

```sh
cd .xeofoundry/build/linux-x64
../../scripts/test/smoke.sh ../../../Converter/libs/laszip/example
```

```powershell
cd .xeofoundry\build\win-x64
..\..\scripts\test\smoke.ps1 -FixtureFolder ..\..\..\Converter\libs\laszip\example
```

The script converts every `.las`/`.laz` in the given folder under `UNCOMPRESSED` and `BROTLI` and checks the output metadata. The converter anchors the output bounding box at the fixture header minimum and expands it to a cube whose side is the largest header extent; the smoke check asserts that expansion within one quantization step. Results are written under `.xeofoundry/scripts/test/result/` (gitignored), wiped at the start of each run.

## Preview

Generate a Potree viewer page for a fixture. Run from the target's build output directory:

```sh
cd .xeofoundry/build/linux-x64
../../scripts/test/preview.sh ../../../Converter/libs/laszip/example/5points_14.las demo
```

The script runs the converter with `--generate-page` and writes a self-contained page next to the dataset under `.xeofoundry/scripts/test/result/preview/<page-name>/` (gitignored):

```text
.xeofoundry/scripts/test/result/preview/<page-name>/
├── <page-name>.html
├── libs/
└── pointclouds/<page-name>/
    ├── metadata.json
    ├── hierarchy.bin
    └── octree.bin
```

The page is generated from the `resources/page_template` copied beside the built executable. Browsers block loading `metadata.json` over `file://`, so serve the directory over HTTP:

```sh
cd .xeofoundry/scripts/test/result/preview/<page-name>
python3 -m http.server 8000
```

Then open `http://localhost:8000/<page-name>.html`. The converter's `--title` option is currently unused by the page template, so the page keeps the template title.

## Outputs

Each platform target's build directory is self-contained:

```text
.xeofoundry/build/<platform-target>/
├── PotreeConverter[.exe]
├── liblaszip.so | laszip.dll
├── VERSION
├── resources/page_template
├── licenses/
└── README.md
```

The build directory also holds CMake state (`CMakeCache.txt`, `Makefile`, `CMakeFiles/`, and per-dependency subdirectories). The collect step below picks only the files that belong in a release.

## Collect

Collect the release files for a built target into `.xeofoundry/.release/<platform-target>/`, matching the upstream Potree release layout:

```sh
.xeofoundry/scripts/collect.sh linux-x64 --clean
```

```powershell
.\.xeofoundry\scripts\collect.ps1 -PlatformTarget win-x64 -Clean
```

The script copies the built executable, the `laszip` shared library, `VERSION`, `README.md`, `licenses/`, and `resources/page_template/` out of `.xeofoundry/build/<platform-target>/` into `.xeofoundry/.release/<platform-target>/`. It refuses to run when the target has not been built. `--clean` / `-Clean` wipes the existing release directory first. `.xeofoundry/.release/` is gitignored.

## Archive

Package a collected target into a release archive under `.xeofoundry/.release/`:

```sh
.xeofoundry/scripts/archive.sh linux-x64
.xeofoundry/scripts/archive.sh linux-arm64
.xeofoundry/scripts/archive.sh win-x64
```

```powershell
.\.xeofoundry\scripts\archive.ps1 -PlatformTarget win-x64
```

Linux targets produce `PotreeConverter_<version>_<platform-target>.tar.gz`, win-x64 produces `PotreeConverter_<version>_<platform-target>.zip`. `<version>` is the collected `VERSION` file with any leading `v` stripped, and each archive contains a single top-level directory named like the archive without its extension:

```text
PotreeConverter_2.1.5_linux-x64.tar.gz
└── PotreeConverter_2.1.5_linux-x64/
    ├── PotreeConverter
    ├── liblaszip.so
    ├── VERSION
    ├── README.md
    ├── licenses/
    └── resources/page_template/
```

The script refuses to run when the target has not been collected. The `zip` command must be available when archiving win-x64 from a non-Windows host.
