"""Patch A3/A4 grass/fringe uvRects in level_1.prefab after fringe texture padding."""
from __future__ import annotations

import re
import sys
from pathlib import Path

from lib.environment_texture_names import DIRECTION_TO_NAME, variant_stem

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
LAYOUT = (64.0, 176.0, 191.0, 255.0)


def uv_layout_in_texture(layout_crop, texture_crop) -> tuple[float, float, float, float]:
    tw = texture_crop[2] - texture_crop[0] + 1
    th = texture_crop[3] - texture_crop[1] + 1
    lx0 = layout_crop[0] - texture_crop[0]
    ly0 = layout_crop[1] - texture_crop[1]
    lx1 = layout_crop[2] - texture_crop[0]
    ly1 = layout_crop[3] - texture_crop[1]
    width = lx1 - lx0 + 1
    height = ly1 - ly0 + 1
    uv_y = 1.0 - (ly1 + 1.0) / th
    return lx0 / tw, uv_y, width / tw, height / th


def main() -> int:
    text = PREFAB.read_text(encoding="utf-8")
    new_uv = uv_layout_in_texture(LAYOUT, LAYOUT)
    uv_str = f"{new_uv[0]:.6f}, {new_uv[1]:.6f}, {new_uv[2]:.6f}, {new_uv[3]:.6f}"
    print("new uv", uv_str)

    a3a4 = tuple(
        f"static/Environment/Ground/{variant_stem(1, variation)}_{DIRECTION_TO_NAME[direction]}.png"
        for variation in (3, 4)
        for direction in "ENSW"
    )
    count = 0
    blocks = text.split("node{")
    out = [blocks[0]]
    for block in blocks[1:]:
        hint = re.search(r'TileTextureHint\{texturePath:t="([^"]+)";\}', block)
        if hint and hint.group(1) in a3a4:
            block2, n = re.subn(
                r"uvRect:p4=[^\n]+",
                f"uvRect:p4={uv_str}",
                block,
                count=1,
            )
            if n:
                count += 1
                block = block2
        out.append("node{" + block)

    if count:
        PREFAB.write_text("".join(out), encoding="utf-8", newline="\n")
    print("patched", count, "A3/A4 sprite uvRects")
    return 0


if __name__ == "__main__":
    sys.exit(main())
