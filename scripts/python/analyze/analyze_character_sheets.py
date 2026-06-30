"""Analyze used character sprite sheets for safe repacking."""
from __future__ import annotations

import glob
import re
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
CHAR_ROOT = PROJECT / "static" / "Characters"
DAS_CORE = PROJECT / "scripts" / "das" / "core"
COLS, ROWS = 15, 8
FEET_X, FEET_Y = 64, 89


def used_paths() -> set[str]:
    used: set[str] = set()
    for das in DAS_CORE.glob("constants*.das"):
        text = das.read_text(encoding="utf-8")
        used.update(re.findall(r'"(static/Characters/[^"]+\.png)"', text))
    return used


def analyze_sheet(path: Path, tw: int, th: int) -> dict:
    img = Image.open(path).convert("RGBA")
    max_l = max_r = max_u = max_d = 0
    last_col = 0
    for r in range(ROWS):
        for c in range(COLS):
            tile = img.crop((c * tw, r * th, (c + 1) * tw, (r + 1) * th))
            bb = tile.getbbox()
            if not bb:
                continue
            last_col = max(last_col, c)
            l, t, rt, b = bb
            max_l = max(max_l, FEET_X - l)
            max_r = max(max_r, rt - FEET_X)
            max_u = max(max_u, FEET_Y - t)
            max_d = max(max_d, b - FEET_Y)
    return {
        "max_l": max_l,
        "max_r": max_r,
        "max_u": max_u,
        "max_d": max_d,
        "last_col": last_col,
        "tile_w": max_l + max_r + 1,
        "tile_h": max_u + max_d + 1,
        "new_feet_x": max_l,
    }


def main() -> None:
    used = used_paths()
    all_pngs = list(CHAR_ROOT.rglob("*.png"))
    used_bytes = sum(p.stat().st_size for p in all_pngs if _rel(p) in used)
    unused_bytes = sum(p.stat().st_size for p in all_pngs if _rel(p) not in used)
    print(f"used sheets: {len(used)}, {used_bytes / 1e6:.1f} MB")
    print(f"unused sheets: {len(all_pngs) - len(used)}, {unused_bytes / 1e6:.1f} MB")

    stats = []
    for rel in sorted(used):
        path = PROJECT / Path(rel)
        if not path.exists():
            print("MISSING", rel)
            continue
        img = Image.open(path)
        w, h = img.size
        tw, th = w // COLS, h // ROWS
        s = analyze_sheet(path, tw, th)
        s["rel"] = rel
        s["size"] = (w, h)
        s["tile"] = (tw, th)
        stats.append(s)

    max_l = max(s["max_l"] for s in stats)
    max_r = max(s["max_r"] for s in stats)
    max_u = max(s["max_u"] for s in stats)
    max_d = max(s["max_d"] for s in stats)
    print(f"\nGlobal tile bounds from feet ({FEET_X},{FEET_Y}):")
    print(f"  L={max_l} R={max_r} U={max_u} D={max_d}")
    print(f"  min tile {max_l + max_r + 1}x{max_u + max_d + 1}, new feet_x={max_l}")
    print(f"  sheet {COLS * (max_l + max_r + 1)}x{ROWS * (max_u + max_d + 1)}")

    odd = [s for s in stats if s["tile"] != (128, 128)]
    if odd:
        print("\nNon-128 tile sheets:")
        for s in odd:
            print(f"  {s['rel']} tile={s['tile']} size={s['size']}")


def _rel(p: Path) -> str:
    return p.relative_to(PROJECT).as_posix()


if __name__ == "__main__":
    main()
