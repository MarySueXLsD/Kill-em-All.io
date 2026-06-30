"""Remove unused character sheets and repack used full-res grids to tight tile bounds."""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
CHAR_ROOT = PROJECT / "static" / "Characters"
DAS_CORE = PROJECT / "scripts" / "das" / "core"
CONSTANTS_PLAYER_PATH = DAS_CORE / "constants_player.das"

COLS, ROWS = 15, 8
OLD_FEET_X, OLD_FEET_Y = 64, 89
MAX_L, MAX_R, MAX_U, MAX_D = 60, 62, 89, 38
NEW_TILE_W = MAX_L + MAX_R + 1
NEW_TILE_H = MAX_U + MAX_D + 1
NEW_SHEET_W = NEW_TILE_W * COLS
NEW_SHEET_H = NEW_TILE_H * ROWS
NEW_FEET_X = MAX_L
CROP_LEFT = OLD_FEET_X - MAX_L
CROP_TOP = OLD_FEET_Y - MAX_U


def used_paths() -> set[str]:
    used: set[str] = set()
    for das in DAS_CORE.glob("constants*.das"):
        text = das.read_text(encoding="utf-8")
        used.update(re.findall(r'"(static/Characters/[^"]+\.png)"', text))
    return used


def save_png_compressed(img: Image.Image, path: Path) -> tuple[int, int]:
    before = path.stat().st_size if path.exists() else 0
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True, compress_level=9)
    path.write_bytes(buf.getvalue())
    return before, path.stat().st_size


def remove_unused(used: set[str]) -> tuple[int, int]:
    removed_files = 0
    removed_bytes = 0
    for path in sorted(CHAR_ROOT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(PROJECT).as_posix()
        if path.suffix.lower() == ".png":
            if rel in used:
                continue
        elif path.name.endswith(".png.meta"):
            png_rel = rel[:-5]  # strip ".meta"
            if png_rel in used:
                continue
        else:
            continue
        removed_bytes += path.stat().st_size
        path.unlink()
        removed_files += 1

    for path in sorted(CHAR_ROOT.rglob("*"), reverse=True):
        if path.is_dir():
            try:
                path.rmdir()
            except OSError:
                pass
    return removed_files, removed_bytes


def repack_full_res(path: Path) -> bool:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    old_tw, old_th = w // COLS, h // ROWS
    if old_tw != 128 or old_th != 128:
        return False

    out = Image.new("RGBA", (NEW_SHEET_W, NEW_SHEET_H), (0, 0, 0, 0))
    for r in range(ROWS):
        for c in range(COLS):
            sx = c * old_tw + CROP_LEFT
            sy = r * old_th + CROP_TOP
            tile = img.crop((sx, sy, sx + NEW_TILE_W, sy + NEW_TILE_H))
            out.paste(tile, (c * NEW_TILE_W, r * NEW_TILE_H))

    before, after = save_png_compressed(out, path)
    print(f"  repack {path.relative_to(PROJECT).as_posix()}: {before // 1024}KB -> {after // 1024}KB")
    return True


def update_constants() -> None:
    text = CONSTANTS_PLAYER_PATH.read_text(encoding="utf-8")
    text = re.sub(
        r"PLAYER_SHEET_WIDTH = [\d.]+",
        f"PLAYER_SHEET_WIDTH = {float(NEW_SHEET_W)}",
        text,
        count=1,
    )
    text = re.sub(
        r"PLAYER_SHEET_FEET_X_PX = [\d.]+",
        f"PLAYER_SHEET_FEET_X_PX = {float(NEW_FEET_X)}",
        text,
        count=1,
    )
    CONSTANTS_PLAYER_PATH.write_text(text, encoding="utf-8", newline="\n")


def recompress_used(used: set[str]) -> tuple[int, int]:
    before_total = 0
    after_total = 0
    for rel in sorted(used):
        path = PROJECT / Path(rel)
        if not path.exists():
            continue
        img = Image.open(path).convert("RGBA")
        before, after = save_png_compressed(img, path)
        before_total += before
        after_total += after
    return before_total, after_total


def main() -> int:
    used = used_paths()
    print(f"Used character sheets: {len(used)}")

    repacked = 0
    print("Repacking full-res sheets (1920x1024 -> 1845x1024):")
    for rel in sorted(used):
        path = PROJECT / Path(rel)
        if not path.exists():
            print(f"  missing {rel}")
            continue
        if repack_full_res(path):
            repacked += 1

    print(f"Repacked {repacked} sheets")

    update_constants()
    print(f"Updated constants: PLAYER_SHEET_WIDTH={NEW_SHEET_W}, PLAYER_SHEET_FEET_X_PX={NEW_FEET_X}")

    before, after = recompress_used(used)
    print(f"Final used sheet size: {before / 1e6:.2f} MB -> {after / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
