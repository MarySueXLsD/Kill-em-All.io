"""Restore ground/road PNGs to 256x256 sheets with original crop placement."""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
CONSTANTS = PROJECT / "scripts" / "das" / "core" / "constants.das"
CANVAS = 256

ORIGINAL_CROPS: dict[str, tuple[float, float, float, float]] = {
    # A1
    "static/Environment/Ground/Type_1_Variation_1_East.png": (64.0, 176.0, 191.0, 255.0),
    "static/Environment/Ground/Type_1_Variation_1_North.png": (64.0, 176.0, 191.0, 255.0),
    "static/Environment/Ground/Type_1_Variation_1_South.png": (64.0, 176.0, 191.0, 255.0),
    "static/Environment/Ground/Type_1_Variation_1_West.png": (64.0, 176.0, 191.0, 255.0),
    # A2
    "static/Environment/Ground/Type_1_Variation_2_East.png": (61.0, 171.0, 192.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_2_North.png": (61.0, 171.0, 193.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_2_South.png": (63.0, 169.0, 193.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_2_West.png": (63.0, 171.0, 193.0, 241.0),
    # A3
    "static/Environment/Ground/Type_1_Variation_3_East.png": (62.0, 194.0, 193.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_3_North.png": (109.0, 171.0, 191.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_3_South.png": (64.0, 171.0, 146.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_3_West.png": (62.0, 171.0, 193.0, 214.0),
    # A4
    "static/Environment/Ground/Type_1_Variation_4_East.png": (113.0, 189.0, 191.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_4_North.png": (101.0, 172.0, 191.0, 212.0),
    "static/Environment/Ground/Type_1_Variation_4_South.png": (64.0, 196.0, 154.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_4_West.png": (64.0, 172.0, 142.0, 217.0),
    # A5
    "static/Environment/Ground/Type_1_Variation_5_East.png": (61.0, 171.0, 192.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_5_North.png": (61.0, 171.0, 193.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_5_South.png": (63.0, 169.0, 193.0, 241.0),
    "static/Environment/Ground/Type_1_Variation_5_West.png": (63.0, 171.0, 193.0, 241.0),
    # Roads
    "static/Environment/Ground/Type_5_Variation_1_East.png": (68.0, 179.0, 187.0, 238.0),
    "static/Environment/Ground/Type_5_Variation_1_North.png": (70.0, 178.0, 189.0, 238.0),
    "static/Environment/Ground/Type_5_Variation_1_South.png": (66.0, 178.0, 185.0, 237.0),
    "static/Environment/Ground/Type_5_Variation_1_West.png": (68.0, 176.0, 187.0, 236.0),
}

ORIGINAL_A1_CROPS = "    GROUND_A1_CROPS <- [\n        float4(64.0, 176.0, 191.0, 255.0),\n        float4(64.0, 176.0, 191.0, 255.0),\n        float4(64.0, 176.0, 191.0, 255.0),\n        float4(64.0, 176.0, 191.0, 255.0),\n    ]"
ORIGINAL_A2_CROPS = "    GROUND_A2_CROPS <- [\n        float4(61.0, 171.0, 192.0, 241.0),\n        float4(61.0, 171.0, 193.0, 241.0),\n        float4(63.0, 169.0, 193.0, 241.0),\n        float4(63.0, 171.0, 193.0, 241.0),\n    ]"
ORIGINAL_A3_CROPS = "    GROUND_A3_CROPS <- [\n        float4(62.0, 194.0, 193.0, 241.0),\n        float4(109.0, 171.0, 191.0, 241.0),\n        float4(64.0, 171.0, 146.0, 241.0),\n        float4(62.0, 171.0, 193.0, 214.0),\n    ]"
ORIGINAL_A4_CROPS = "    GROUND_A4_CROPS <- [\n        float4(113.0, 189.0, 191.0, 241.0),\n        float4(101.0, 172.0, 191.0, 212.0),\n        float4(64.0, 196.0, 154.0, 241.0),\n        float4(64.0, 172.0, 142.0, 217.0),\n    ]"
ORIGINAL_A5_CROPS = "    GROUND_A5_CROPS <- [\n        float4(61.0, 171.0, 192.0, 241.0),\n        float4(61.0, 171.0, 193.0, 241.0),\n        float4(63.0, 169.0, 193.0, 241.0),\n        float4(63.0, 171.0, 193.0, 241.0),\n    ]"
ORIGINAL_ROAD_CROPS = "    GROUND_ROAD_CROPS <- [\n        float4(68.0, 179.0, 187.0, 238.0),\n        float4(70.0, 178.0, 189.0, 238.0),\n        float4(66.0, 178.0, 185.0, 237.0),\n        float4(68.0, 176.0, 187.0, 236.0),\n    ]"


def pad_to_canvas(path: Path, crop: tuple[float, float, float, float]) -> None:
    min_x, min_y, max_x, max_y = crop
    left, top = int(min_x), int(min_y)
    cropped = Image.open(path).convert("RGBA")
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(cropped, (left, top))
    buf = io.BytesIO()
    canvas.save(buf, format="PNG", optimize=True, compress_level=9)
    path.write_bytes(buf.getvalue())


def restore_constants() -> None:
    text = CONSTANTS.read_text(encoding="utf-8")
    text = re.sub(
        r"    // Ground A1_S\.png diamond bounds in pixels \(pre-cropped source image\)\.\n"
        r"    GROUND_CROP_MIN_X = [\d.]+\n"
        r"    GROUND_CROP_MIN_Y = [\d.]+\n"
        r"    GROUND_CROP_MAX_X = [\d.]+\n"
        r"    GROUND_CROP_MAX_Y = [\d.]+\n",
        "    // Ground A1_S.png diamond bounds in pixels (256x256 source image).\n"
        "    GROUND_TEX_WIDTH = 256.0\n"
        "    GROUND_TEX_HEIGHT = 256.0\n"
        "    GROUND_CROP_MIN_X = 64.0\n"
        "    GROUND_CROP_MIN_Y = 176.0\n"
        "    GROUND_CROP_MAX_X = 191.0\n"
        "    GROUND_CROP_MAX_Y = 255.0\n",
        text,
        count=1,
    )
    for name, block in [
        ("GROUND_A1_CROPS", ORIGINAL_A1_CROPS),
        ("GROUND_A2_CROPS", ORIGINAL_A2_CROPS),
        ("GROUND_A3_CROPS", ORIGINAL_A3_CROPS),
        ("GROUND_A4_CROPS", ORIGINAL_A4_CROPS),
        ("GROUND_A5_CROPS", ORIGINAL_A5_CROPS),
        ("GROUND_ROAD_CROPS", ORIGINAL_ROAD_CROPS),
    ]:
        text = re.sub(rf"    {name} <- \[.*?\n    \]", block, text, count=1, flags=re.S)
    text = text.replace(
        "    // Opaque sprite bounds per direction (pre-cropped); A1 matches GROUND_CROP_*.",
        "    // Opaque sprite bounds per direction (256x256 source); A1 matches GROUND_CROP_*.",
    )
    CONSTANTS.write_text(text, encoding="utf-8", newline="\n")


def main() -> int:
    for rel, crop in ORIGINAL_CROPS.items():
        path = PROJECT / Path(rel)
        if not path.exists():
            print("missing", rel)
            continue
        before = path.stat().st_size
        pad_to_canvas(path, crop)
        after = path.stat().st_size
        print(f"padded {rel}: {before // 1024}KB -> {after // 1024}KB, size {Image.open(path).size}")
    restore_constants()
    print("restored ground crop constants")
    return 0


if __name__ == "__main__":
    sys.exit(main())
