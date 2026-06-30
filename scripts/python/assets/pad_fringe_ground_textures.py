"""Pad A3/A4 ground fringe PNGs to the shared tile layout canvas.

Fringe UV math maps GROUND_TILE_LAYOUT_CROP (128x80 in 256-space) into each
pre-cropped texture. Tight crops leave UVs outside 0..1; Clamp addressing then
repeats edge texels and shows as straight line artifacts on edge/corner grass.
"""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
CONSTANTS = PROJECT / "scripts" / "das" / "core" / "constants.das"
LAYOUT = (64.0, 176.0, 191.0, 255.0)
LAYOUT_W = int(LAYOUT[2] - LAYOUT[0] + 1)
LAYOUT_H = int(LAYOUT[3] - LAYOUT[1] + 1)


def parse_float4(text: str) -> tuple[float, float, float, float]:
    nums = [float(x) for x in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", text)]
    return nums[0], nums[1], nums[2], nums[3]


def collect_jobs(text: str, paths_name: str, crops_name: str) -> list[tuple[str, tuple[float, float, float, float]]]:
    paths_block = re.search(rf"{paths_name}\s*<-\s*\[(.*?)\]", text, re.S)
    crops_block = re.search(rf"{crops_name}\s*<-\s*\[(.*?)\]", text, re.S)
    if not paths_block or not crops_block:
        return []
    paths = re.findall(r'"([^"]+\.png)"', paths_block.group(1))
    crops = [parse_float4(c) for c in re.findall(r"float4\(([^)]+)\)", crops_block.group(1))]
    return list(zip(paths, crops))


def pad_to_layout(path: Path, source_crop: tuple[float, float, float, float]) -> None:
    min_x, min_y, _, _ = source_crop
    offset_x = int(min_x - LAYOUT[0])
    offset_y = int(min_y - LAYOUT[1])
    cropped = Image.open(path).convert("RGBA")
    canvas = Image.new("RGBA", (LAYOUT_W, LAYOUT_H), (0, 0, 0, 0))
    canvas.paste(cropped, (offset_x, offset_y))
    buf = io.BytesIO()
    canvas.save(buf, format="PNG", optimize=True, compress_level=9)
    path.write_bytes(buf.getvalue())


def set_all_layout_crops(text: str, crops_name: str) -> str:
    layout_line = f"float4({LAYOUT[0]}, {LAYOUT[1]}, {LAYOUT[2]}, {LAYOUT[3]})"
    block = (
        f"    {crops_name} <- [\n"
        f"        {layout_line},\n"
        f"        {layout_line},\n"
        f"        {layout_line},\n"
        f"        {layout_line},\n"
        f"    ]"
    )
    return re.sub(rf"    {crops_name} <- \[.*?\n    \]", block, text, count=1, flags=re.S)


def main() -> int:
    text = CONSTANTS.read_text(encoding="utf-8")
    jobs: list[tuple[str, tuple[float, float, float, float]]] = []
    jobs += collect_jobs(text, "GROUND_A3_PATHS", "GROUND_A3_SOURCE_CROPS")
    jobs += collect_jobs(text, "GROUND_A4_PATHS", "GROUND_A4_SOURCE_CROPS")

    for rel, crop in jobs:
        path = PROJECT / Path(rel)
        if not path.exists():
            print("missing", rel)
            continue
        before = path.stat().st_size
        pad_to_layout(path, crop)
        after = path.stat().st_size
        print(f"padded {rel}: {before // 1024}KB -> {after // 1024}KB, size {Image.open(path).size}")

    text = set_all_layout_crops(text, "GROUND_A3_SOURCE_CROPS")
    text = set_all_layout_crops(text, "GROUND_A4_SOURCE_CROPS")
    CONSTANTS.write_text(text, encoding="utf-8", newline="\n")
    print("updated GROUND_A3_SOURCE_CROPS and GROUND_A4_SOURCE_CROPS to layout crop")
    return 0


if __name__ == "__main__":
    sys.exit(main())
