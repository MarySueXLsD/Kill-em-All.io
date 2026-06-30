"""Compress PNGs and crop environment sprites to authored bounds (drops empty transparency)."""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONSTANTS_PATH = PROJECT_ROOT / "scripts" / "das" / "core" / "constants.das"
STATIC_ROOT = PROJECT_ROOT / "static"


def parse_float4(text: str) -> tuple[float, float, float, float]:
    nums = [float(x) for x in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", text)]
    if len(nums) != 4:
        raise ValueError(f"Expected float4, got {text!r}")
    return nums[0], nums[1], nums[2], nums[3]


def crop_box(crop: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    min_x, min_y, max_x, max_y = crop
    return int(min_x), int(min_y), int(max_x) + 1, int(max_y) + 1


def new_crop(crop: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    left, top, right, bottom = crop_box(crop)
    return 0.0, 0.0, float(right - left - 1), float(bottom - top - 1)


def shift_point(line: str, ox: float, oy: float) -> str:
    nums = [float(x) for x in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", line)]
    if len(nums) == 4:
        nums = [nums[0] - ox, nums[1] - oy, nums[2] - ox, nums[3] - oy]
        return re.sub(r"float4\([^)]+\)", f"float4({nums[0]}, {nums[1]}, {nums[2]}, {nums[3]})", line, count=1)
    if len(nums) == 2:
        nums = [nums[0] - ox, nums[1] - oy]
        return re.sub(r"float2\([^)]+\)", f"float2({nums[0]}, {nums[1]})", line, count=1)
    return line


def collect_crop_jobs(constants_text: str) -> dict[str, tuple[float, float, float, float]]:
    jobs: dict[str, tuple[float, float, float, float]] = {}

    for paths_name, crops_name in [
        ("GROUND_A1_PATHS", "GROUND_A1_CROPS"),
        ("GROUND_A2_PATHS", "GROUND_A2_CROPS"),
        ("GROUND_A3_PATHS", "GROUND_A3_CROPS"),
        ("GROUND_A4_PATHS", "GROUND_A4_CROPS"),
        ("GROUND_A5_PATHS", "GROUND_A5_CROPS"),
        ("GROUND_ROAD_PATHS", "GROUND_ROAD_CROPS"),
    ]:
        paths_block = re.search(rf"{paths_name}\s*<-\s*\[(.*?)\]", constants_text, re.S)
        crops_block = re.search(rf"{crops_name}\s*<-\s*\[(.*?)\]", constants_text, re.S)
        if not paths_block or not crops_block:
            continue
        paths = re.findall(r'"([^"]+\.png)"', paths_block.group(1))
        crops = re.findall(r"float4\(([^)]+)\)", crops_block.group(1))
        for path, crop_text in zip(paths, crops):
            jobs[path] = parse_float4(crop_text)

    for match in re.finditer(r"((?:PROP|WALL)_[A-Z0-9_]+)_PATH = \"([^\"]+\.png)\"", constants_text):
        prefix, path = match.group(1), match.group(2)
        crop_match = re.search(rf"{prefix}_CROP = float4\(([^)]+)\)", constants_text)
        if crop_match:
            jobs[path] = parse_float4(crop_match.group(1))

    return jobs


def path_to_prefix(path: str) -> str | None:
    from lib.environment_texture_names import decode_variant_filename

    decoded = decode_variant_filename(Path(path).name)
    if decoded is None:
        return None
    type_num, variation, direction = decoded
    if "/Ground/" in path and type_num == 1 and variation == 1:
        return None
    suffix = f"_{direction}"
    if type_num == 2 and "/Misc/" in path:
        return f"PROP_MISC_B{variation}{suffix}"
    if type_num == 2 and "/Wall/" in path:
        return f"WALL_B{variation}{suffix}"
    return None


def update_constants(
    constants_text: str,
    jobs: dict[str, tuple[float, float, float, float]],
) -> str:
    offsets = {path: (crop_box(crop)[0], crop_box(crop)[1]) for path, crop in jobs.items()}
    new_crops = {path: new_crop(crop) for path, crop in jobs.items()}

    for crops_name in [
        "GROUND_A1_CROPS",
        "GROUND_A2_CROPS",
        "GROUND_A3_CROPS",
        "GROUND_A4_CROPS",
        "GROUND_A5_CROPS",
        "GROUND_ROAD_CROPS",
    ]:
        paths_name = crops_name.replace("_CROPS", "_PATHS")
        paths_block = re.search(rf"{paths_name}\s*<-\s*\[(.*?)\]", constants_text, re.S)
        if not paths_block:
            continue
        paths = re.findall(r'"([^"]+\.png)"', paths_block.group(1))
        lines = []
        for path in paths:
            c = new_crops[path]
            lines.append(f"        float4({c[0]}, {c[1]}, {c[2]}, {c[3]}),")
        replacement = f"{crops_name} <- [\n" + "\n".join(lines) + "\n    ]"
        constants_text = re.sub(rf"{crops_name}\s*<-\s*\[.*?\]", replacement, constants_text, count=1, flags=re.S)

    for path, crop in new_crops.items():
        prefix = path_to_prefix(path)
        if prefix:
            ox, oy = offsets[path]
            constants_text = re.sub(
                rf"({prefix}_CROP = )float4\([^)]+\)",
                rf"\1float4({crop[0]}, {crop[1]}, {crop[2]}, {crop[3]})",
                constants_text,
                count=1,
            )
            for suffix in ("_FEET_PX", "_BOTTOM_PX_A", "_BOTTOM_PX_B"):
                pat = rf"({prefix}{suffix} = )float2\([^)]+\)"

                def repl(m: re.Match[str], ox=ox, oy=oy) -> str:
                    line = m.group(0)
                    return m.group(1) + shift_point(line.split("=", 1)[1].strip(), ox, oy).strip()

                constants_text = re.sub(pat, repl, constants_text, count=1)
            for suffix in ("_WALL_LINES_PX", "_BOTTOM_PX"):
                block_pat = rf"({prefix}{suffix} <- \[)(.*?)(\])"
                block = re.search(block_pat, constants_text, re.S)
                if not block:
                    continue
                shifted = []
                for line in block.group(2).splitlines():
                    stripped = line.strip()
                    if stripped.startswith("float"):
                        shifted.append("        " + shift_point(stripped, ox, oy))
                    elif stripped:
                        shifted.append(line)
                constants_text = constants_text.replace(
                    block.group(0),
                    block.group(1) + "\n" + "\n".join(shifted) + "\n    " + block.group(3),
                )

    a1 = new_crops.get("static/Environment/Ground/Type_1_Variation_1_East.png")
    if a1:
        constants_text = re.sub(r"GROUND_CROP_MIN_X = [\d.]+", f"GROUND_CROP_MIN_X = {a1[0]}", constants_text)
        constants_text = re.sub(r"GROUND_CROP_MIN_Y = [\d.]+", f"GROUND_CROP_MIN_Y = {a1[1]}", constants_text)
        constants_text = re.sub(r"GROUND_CROP_MAX_X = [\d.]+", f"GROUND_CROP_MAX_X = {a1[2]}", constants_text)
        constants_text = re.sub(r"GROUND_CROP_MAX_Y = [\d.]+", f"GROUND_CROP_MAX_Y = {a1[3]}", constants_text)

    constants_text = constants_text.replace(
        "GROUND_TEX_WIDTH = 256.0",
        "GROUND_TEX_WIDTH = GROUND_CROP_WIDTH",
    ).replace(
        "GROUND_TEX_HEIGHT = 256.0",
        "GROUND_TEX_HEIGHT = GROUND_CROP_HEIGHT",
    ).replace(
        "PROP_TEX_WIDTH = 256.0",
        "// Prop/wall textures are pre-cropped; UVs use crop extents directly.",
    ).replace(
        "PROP_TEX_HEIGHT = 256.0",
        "",
    )
    return constants_text


def save_png_compressed(img: Image.Image, path: Path) -> tuple[int, int]:
    before = path.stat().st_size
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True, compress_level=9)
    data = buf.getvalue()
    path.write_bytes(data)
    return before, len(data)


def main() -> int:
    constants_text = CONSTANTS_PATH.read_text(encoding="utf-8")
    crop_jobs = collect_crop_jobs(constants_text)

    orig_total = 0
    new_total = 0
    cropped_count = 0
    compressed_count = 0

    for rel_path, crop in sorted(crop_jobs.items()):
        path = PROJECT_ROOT / Path(rel_path)
        if not path.exists():
            print(f"skip missing: {rel_path}")
            continue
        before = path.stat().st_size
        orig_total += before
        img = Image.open(path).convert("RGBA").crop(crop_box(crop))
        _, after = save_png_compressed(img, path)
        new_total += after
        cropped_count += 1
        print(f"crop {rel_path}: {before // 1024}KB -> {after // 1024}KB")

    for path in STATIC_ROOT.rglob("*.png"):
        rel = path.relative_to(PROJECT_ROOT).as_posix()
        if rel in crop_jobs:
            continue
        before = path.stat().st_size
        orig_total += before
        img = Image.open(path)
        if img.mode not in ("RGBA", "RGB", "LA", "L"):
            img = img.convert("RGBA")
        elif img.mode == "P":
            img = img.convert("RGBA")
        b0, b1 = save_png_compressed(img, path)
        new_total += b1
        if b1 < b0:
            compressed_count += 1

    updated = update_constants(constants_text, crop_jobs)
    CONSTANTS_PATH.write_text(updated, encoding="utf-8", newline="\n")

    print()
    print(f"cropped: {cropped_count}, recompressed smaller: {compressed_count}")
    print(f"touched: {orig_total / 1e6:.1f} MB -> {new_total / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
