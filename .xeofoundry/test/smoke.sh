#!/usr/bin/env bash
set -euo pipefail

FIXTURE_DIR="${1:-}"

if [[ -z "$FIXTURE_DIR" ]]; then
	echo "usage: $0 <fixture-folder>" >&2
	exit 1
fi

if [[ ! -d "$FIXTURE_DIR" ]]; then
	echo "fixture folder not found: $FIXTURE_DIR" >&2
	exit 1
fi

CONVERTER="$PWD/PotreeConverter"
if [[ ! -x "$CONVERTER" ]]; then
	echo "PotreeConverter not found in $PWD; run this from the target build directory" >&2
	exit 1
fi

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

shopt -s nullglob nocaseglob
FIXTURES=("$FIXTURE_DIR"/*.las "$FIXTURE_DIR"/*.laz)
shopt -u nocaseglob nullglob

if [[ "${#FIXTURES[@]}" -eq 0 ]]; then
	echo "no .las or .laz fixtures in $FIXTURE_DIR" >&2
	exit 1
fi

for fixture in "${FIXTURES[@]}"; do
	name="$(basename "$fixture")"

	for encoding in UNCOMPRESSED BROTLI; do
		outdir="$TMP_ROOT/${name}-${encoding}"
		mkdir -p "$outdir"

		echo "smoke: $name ($encoding)"

		if ! "$CONVERTER" "$fixture" -o "$outdir" --encoding "$encoding" > "$outdir/conversion.log" 2>&1; then
			echo "conversion failed for $name ($encoding)" >&2
			cat "$outdir/conversion.log" >&2
			exit 1
		fi

		for artifact in metadata.json hierarchy.bin octree.bin; do
			if [[ ! -s "$outdir/$artifact" ]]; then
				echo "missing or empty $artifact for $name ($encoding)" >&2
				exit 1
			fi
		done

		python3 - "$fixture" "$outdir/metadata.json" "$encoding" <<'PY'
import json
import struct
import sys

fixture_path, metadata_path, expected_encoding = sys.argv[1], sys.argv[2], sys.argv[3]

with open(fixture_path, "rb") as handle:
    header = handle.read(375)

if header[:4] != b"LASF":
    raise SystemExit(f"{fixture_path}: not a LAS file")

version = (header[24], header[25])


def u32(offset):
    return struct.unpack_from("<I", header, offset)[0]


def u64(offset):
    return struct.unpack_from("<Q", header, offset)[0]


def f64(offset):
    return struct.unpack_from("<d", header, offset)[0]


legacy_count = u32(107)
if version >= (1, 4):
    declared_count = u64(247) or legacy_count
else:
    declared_count = legacy_count

fixture_scale = [f64(131), f64(139), f64(147)]
fixture_min = [f64(187), f64(203), f64(219)]
fixture_max = [f64(179), f64(195), f64(211)]

with open(metadata_path) as handle:
    metadata = json.load(handle)

if metadata.get("points") != declared_count:
    raise SystemExit(f"points {metadata.get('points')} != fixture count {declared_count}")

if metadata.get("encoding") != expected_encoding:
    raise SystemExit(f"encoding {metadata.get('encoding')} != {expected_encoding}")

if not metadata.get("attributes"):
    raise SystemExit("attributes list is empty")

bounding_box = metadata["boundingBox"]
bbox_min = bounding_box["min"]
bbox_max = bounding_box["max"]

cube_size = max(fixture_max[i] - fixture_min[i] for i in range(3))
expected_min = fixture_min
expected_max = [fixture_min[i] + cube_size for i in range(3)]

for i in range(3):
    step = fixture_scale[i]
    if bbox_min[i] > bbox_max[i]:
        raise SystemExit(f"boundingBox min > max on axis {i}")
    if abs(bbox_min[i] - expected_min[i]) > step:
        raise SystemExit(f"boundingBox.min[{i}]={bbox_min[i]} not within {step} of {expected_min[i]}")
    if abs(bbox_max[i] - expected_max[i]) > step:
        raise SystemExit(f"boundingBox.max[{i}]={bbox_max[i]} not within {step} of {expected_max[i]}")
PY

	done
done

echo "smoke: all conversions passed"
