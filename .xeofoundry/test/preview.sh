#!/usr/bin/env bash
set -euo pipefail

FIXTURE="${1:-}"
PAGE_NAME="${2:-}"

if [[ -z "$FIXTURE" ]]; then
	echo "usage: $0 <fixture.las|fixture.laz> [page-name]" >&2
	exit 1
fi

if [[ ! -f "$FIXTURE" ]]; then
	echo "fixture not found: $FIXTURE" >&2
	exit 1
fi

CONVERTER="$PWD/PotreeConverter"
if [[ ! -x "$CONVERTER" ]]; then
	echo "PotreeConverter not found in $PWD; run this from the target build directory" >&2
	exit 1
fi

if [[ -z "$PAGE_NAME" ]]; then
	PAGE_NAME="$(basename "${FIXTURE%.*}")"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$SCRIPT_DIR/result/preview/$PAGE_NAME"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

"$CONVERTER" "$FIXTURE" -o "$OUTDIR" -p "$PAGE_NAME"

echo "preview: page written to $OUTDIR/$PAGE_NAME.html"
echo "preview: serve with: (cd \"$OUTDIR\" && python3 -m http.server 8000)"
echo "preview: then open:  http://localhost:8000/$PAGE_NAME.html"
