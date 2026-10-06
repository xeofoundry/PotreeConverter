#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLATFORM_TARGET=""
CLEAN=0
CMAKE_ARGS=()

for arg in "$@"; do
	case "$arg" in
		--clean)
			CLEAN=1
			;;
		--*)
			CMAKE_ARGS+=("$arg")
			;;
		*)
			if [[ -z "$PLATFORM_TARGET" ]]; then
				PLATFORM_TARGET="$arg"
			else
				CMAKE_ARGS+=("$arg")
			fi
			;;
	esac
done

if [[ -z "$PLATFORM_TARGET" ]]; then
	echo "usage: $0 <linux-x64|linux-arm64> [--clean] [cmake args...]" >&2
	exit 1
fi

case "$PLATFORM_TARGET" in
	linux-x64)
		EXPECTED_ARCH="x86_64"
		;;
	linux-arm64)
		EXPECTED_ARCH="aarch64"
		;;
	*)
		echo "unknown platform target: $PLATFORM_TARGET" >&2
		exit 1
		;;
esac

HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" != "$EXPECTED_ARCH" ]]; then
	echo "platform target $PLATFORM_TARGET requires host architecture $EXPECTED_ARCH, found $HOST_ARCH" >&2
	exit 1
fi

BUILD_DIR="$SCRIPT_DIR/build/$PLATFORM_TARGET"

if [[ "$CLEAN" -eq 1 ]]; then
	rm -rf "$BUILD_DIR"
fi

export CC="${CC:-clang}"
export CXX="${CXX:-clang++}"

cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" "${CMAKE_ARGS[@]}"
cmake --build "$BUILD_DIR" --config Release
