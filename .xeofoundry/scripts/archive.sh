#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PLATFORM_TARGET=""

for arg in "$@"; do
	case "$arg" in
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
	echo "usage: $0 <linux-x64|linux-arm64|win-x64>" >&2
	exit 1
fi

case "$PLATFORM_TARGET" in
	linux-x64|linux-arm64|win-x64)
		;;
	*)
		echo "unknown platform target: $PLATFORM_TARGET" >&2
		exit 1
		;;
esac

RELEASE_ROOT="$ROOT_DIR/.release"
RELEASE_DIR="$RELEASE_ROOT/$PLATFORM_TARGET"

if [[ ! -d "$RELEASE_DIR" ]]; then
	echo "release directory not found: $RELEASE_DIR" >&2
	echo "collect it first with: $SCRIPT_DIR/collect.sh $PLATFORM_TARGET" >&2
	exit 1
fi

if [[ ! -f "$RELEASE_DIR/VERSION" ]]; then
	echo "version file not found: $RELEASE_DIR/VERSION" >&2
	exit 1
fi

VERSION_VALUE="$(tr -d '[:space:]' < "$RELEASE_DIR/VERSION")"
VERSION_VALUE="${VERSION_VALUE#v}"

ARCHIVE_BASE="PotreeConverter_${VERSION_VALUE}_${PLATFORM_TARGET}"

case "$PLATFORM_TARGET" in
	win-x64)
		if ! command -v zip >/dev/null 2>&1; then
			echo "zip is required to archive win-x64" >&2
			exit 1
		fi
		ARCHIVE_PATH="$RELEASE_ROOT/$ARCHIVE_BASE.zip"
		;;
	*)
		ARCHIVE_PATH="$RELEASE_ROOT/$ARCHIVE_BASE.tar.gz"
		;;
esac

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
mkdir -p "$STAGING_DIR/$ARCHIVE_BASE"
cp -rp "$RELEASE_DIR"/. "$STAGING_DIR/$ARCHIVE_BASE"/

rm -f "$ARCHIVE_PATH"

case "$PLATFORM_TARGET" in
	win-x64)
		(cd "$STAGING_DIR" && zip -qr "$ARCHIVE_PATH" "$ARCHIVE_BASE")
		;;
	*)
		tar -czf "$ARCHIVE_PATH" -C "$STAGING_DIR" "$ARCHIVE_BASE"
		;;
esac

echo "archived $PLATFORM_TARGET release at $ARCHIVE_PATH"
ls -lh "$ARCHIVE_PATH"
