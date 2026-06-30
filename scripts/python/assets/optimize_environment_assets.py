"""Crop empty transparency and compress environment PNGs (streams one file at a time)."""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
ENV = PROJECT / "static" / "Environment"
CONSTANTS = PROJECT / "scripts" / "das" / "core" / "constants.das"

# Already pre-cropped; only recompress, never auto-crop (UV math uses 256-space SOURCE_CROPS).
SKIP_CROP_REL_PREFIXES = tuple(
    f"static/Environment/Ground/Type_1_Variation_{variation}_"
    for variation in (1, 2, 3, 4, 5)
) + ("static/Environment/Ground/Type_5_Variation_1_",)


def load_skip_crop_paths() -> set[str]:
  """Props/walls in constants.das are already pre-cropped to authored bounds."""
  skip: set[str] = set()
  if not CONSTANTS.exists():
    return skip
  text = CONSTANTS.read_text(encoding="utf-8")
  for m in re.finditer(r'((?:PROP_MISC|WALL)_[A-Z0-9_]+)_PATH = "(static/Environment/[^"]+)"', text):
    skip.add(m.group(2))
  return skip


def save_png(img: Image.Image, path: Path) -> int:
  buf = io.BytesIO()
  img.save(buf, format="PNG", optimize=True, compress_level=9)
  path.write_bytes(buf.getvalue())
  return len(buf.getvalue())


def should_crop(name: str, size: tuple[int, int], skip_paths: set[str], rel: str) -> bool:
  if rel in skip_paths:
    return False
  if any(rel.startswith(p) for p in SKIP_CROP_REL_PREFIXES):
    return False
  # Only crop standard 256 canvases; smaller files are already tight.
  return size == (256, 256)


def process_file(path: Path, skip_paths: set[str]) -> tuple[int, int, bool]:
  before = path.stat().st_size
  rel = path.relative_to(PROJECT).as_posix()
  img = Image.open(path)
  if img.mode not in ("RGBA", "RGB", "LA", "L"):
    img = img.convert("RGBA")
  elif img.mode != "RGBA":
    img = img.convert("RGBA")

  cropped = False
  if should_crop(path.name, img.size, skip_paths, rel):
    bb = img.getbbox()
    if bb and (bb[0] > 0 or bb[1] > 0 or bb[2] < img.size[0] or bb[3] < img.size[1]):
      img = img.crop(bb)
      cropped = True

  after = save_png(img, path)
  return before, after, cropped


def main() -> int:
  skip_paths = load_skip_crop_paths()
  total_before = 0
  total_after = 0
  cropped_count = 0
  compressed_count = 0
  count = 0

  pngs = sorted(ENV.rglob("*.png"))
  print(f"Processing {len(pngs)} environment PNGs...")

  for path in pngs:
    before, after, cropped = process_file(path, skip_paths)
    total_before += before
    total_after += after
    if cropped:
      cropped_count += 1
    if after < before:
      compressed_count += 1
    count += 1
    if count % 200 == 0:
      print(f"  {count}/{len(pngs)} ... saved {(total_before - total_after) / 1e6:.1f} MB so far")

  print()
  print(f"Done: {count} files")
  print(f"Cropped: {cropped_count}")
  print(f"Smaller after compress: {compressed_count}")
  print(f"Total: {total_before / 1e6:.1f} MB -> {total_after / 1e6:.1f} MB")
  print(f"Saved: {(total_before - total_after) / 1e6:.1f} MB")
  return 0


if __name__ == "__main__":
  sys.exit(main())
