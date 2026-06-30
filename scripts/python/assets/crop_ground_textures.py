"""Crop ground/road PNGs using GROUND_*_SOURCE_CROPS from constants.das."""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
CONSTANTS = PROJECT / "scripts" / "das" / "core" / "constants.das"


def parse_float4(text: str) -> tuple[float, float, float, float]:
    nums = [float(x) for x in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", text)]
    return nums[0], nums[1], nums[2], nums[3]


def crop_box(crop: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    min_x, min_y, max_x, max_y = crop
    return int(min_x), int(min_y), int(max_x) + 1, int(max_y) + 1


def collect_jobs(text: str) -> dict[str, tuple[float, float, float, float]]:
    jobs: dict[str, tuple[float, float, float, float]] = {}
    for paths_name, crops_name in [
        ("GROUND_A1_PATHS", "GROUND_A1_SOURCE_CROPS"),
        ("GROUND_A2_PATHS", "GROUND_A2_SOURCE_CROPS"),
        ("GROUND_A3_PATHS", "GROUND_A3_SOURCE_CROPS"),
        ("GROUND_A4_PATHS", "GROUND_A4_SOURCE_CROPS"),
        ("GROUND_A5_PATHS", "GROUND_A5_SOURCE_CROPS"),
        ("GROUND_ROAD_PATHS", "GROUND_ROAD_SOURCE_CROPS"),
    ]:
        paths_block = re.search(rf"{paths_name}\s*<-\s*\[(.*?)\]", text, re.S)
        crops_block = re.search(rf"{crops_name}\s*<-\s*\[(.*?)\]", text, re.S)
        if not paths_block or not crops_block:
            continue
        paths = re.findall(r'"([^"]+\.png)"', paths_block.group(1))
        crops = re.findall(r"float4\(([^)]+)\)", crops_block.group(1))
        for path, crop_text in zip(paths, crops):
            jobs[path] = parse_float4(crop_text)
    return jobs


def main() -> int:
    text = CONSTANTS.read_text(encoding="utf-8")
    jobs = collect_jobs(text)
    for rel, crop in sorted(jobs.items()):
        path = PROJECT / Path(rel)
        img = Image.open(path).convert("RGBA")
        # If already cropped (smaller than 256), extract from current 256 canvas or re-crop from embedded content
        if img.size == (256, 256):
            cropped = img.crop(crop_box(crop))
        else:
            # Already pre-cropped: assume full image matches source crop bounds
            cropped = img
        buf = io.BytesIO()
        cropped.save(buf, format="PNG", optimize=True, compress_level=9)
        path.write_bytes(buf.getvalue())
        print(f"{rel}: {cropped.size[0]}x{cropped.size[1]}, {len(buf.getvalue()) // 1024}KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
