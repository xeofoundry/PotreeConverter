#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PLATFORM_TARGET=""
CLEAN=0

for arg in "$@"; do
	case "$arg" in
		--clean)
			CLEAN=1
			;;
		--*)
			echo "unknown option: $arg" >&2
			exit 1
			;;
		*)
			if [[ -z "$PLATFORM_TARGET" ]]; then
				PLATFORM_TARGET="$arg"
			else
				echo "unexpected argument: $arg" >&2
				exit 1
			fi
			;;
	esac
done

if [[ -z "$PLATFORM_TARGET" ]]; then
	echo "usage: $0 <linux-x64|linux-arm64|win-x64> [--clean]" >&2
	exit 1
fi

case "$PLATFORM_TARGET" in
	linux-x64|linux-arm64)
		EXECUTABLE="PotreeConverter"
		;;
	win-x64)
		EXECUTABLE="PotreeConverter.exe"
		;;
	*)
		echo "unknown platform target: $PLATFORM_TARGET" >&2
		exit 1
		;;
esac

BUILD_DIR="$ROOT_DIR/build/$PLATFORM_TARGET"
RELEASE_DIR="$ROOT_DIR/.release/$PLATFORM_TARGET"

if [[ ! -d "$BUILD_DIR" ]]; then
	echo "build directory not found: $BUILD_DIR" >&2
	echo "build it first with: $SCRIPT_DIR/build.sh $PLATFORM_TARGET" >&2
	exit 1
fi

if [[ ! -f "$BUILD_DIR/$EXECUTABLE" ]]; then
	echo "executable not found: $BUILD_DIR/$EXECUTABLE" >&2
	exit 1
fi

if [[ "$CLEAN" -eq 1 ]]; then
	rm -rf "$RELEASE_DIR"
fi

mkdir -p "$RELEASE_DIR"

cp -p "$BUILD_DIR/$EXECUTABLE" "$RELEASE_DIR/"

for file in VERSION README.md; do
	if [[ -f "$BUILD_DIR/$file" ]]; then
		cp -p "$BUILD_DIR/$file" "$RELEASE_DIR/"
	fi
done

for dir in licenses resources; do
	if [[ -d "$BUILD_DIR/$dir" ]]; then
		cp -rp "$BUILD_DIR/$dir" "$RELEASE_DIR/"
	fi
done

while IFS= read -r -d '' shared_lib; do
	cp -p "$shared_lib" "$RELEASE_DIR/"
done < <(find "$BUILD_DIR" -maxdepth 1 \( -name 'liblaszip.so*' -o -name 'laszip.dll' \) -print0)

echo "collected $PLATFORM_TARGET release files at $RELEASE_DIR"
find "$RELEASE_DIR" -maxdepth 1 -mindepth 1 -printf '  %f\n' | sort
