"""Trim empty/black margins and downscale loading book + text animation frames."""
from __future__ import annotations

import io
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
BOOK_DIR = PROJECT / "static" / "UI" / "loading_book"
TEXT_DIR = PROJECT / "static" / "UI" / "loading_text"

BOOK_MAX_WIDTH = 720
TEXT_MAX_WIDTH = 480
BLACK_THRESHOLD = 24
PADDING = 8


def save_png_compressed(img: Image.Image, path: Path) -> tuple[int, int]:
    before = path.stat().st_size if path.exists() else 0
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True, compress_level=9)
    path.write_bytes(buf.getvalue())
    return before, path.stat().st_size


def content_bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    min_x, min_y = w, h
    max_x, max_y = -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 8:
                continue
            if r <= BLACK_THRESHOLD and g <= BLACK_THRESHOLD and b <= BLACK_THRESHOLD:
                continue
            if x < min_x:
                min_x = x
            if y < min_y:
                min_y = y
            if x > max_x:
                max_x = x
            if y > max_y:
                max_y = y
    if max_x < min_x or max_y < min_y:
        return None
    return min_x, min_y, max_x + 1, max_y + 1


def union_bbox(boxes: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    left = min(b[0] for b in boxes)
    top = min(b[1] for b in boxes)
    right = max(b[2] for b in boxes)
    bottom = max(b[3] for b in boxes)
    return left, top, right, bottom


def pad_bbox(box: tuple[int, int, int, int], w: int, h: int, pad: int) -> tuple[int, int, int, int]:
    left, top, right, bottom = box
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(w, right + pad)
    bottom = min(h, bottom + pad)
    return left, top, right, bottom


def scale_to_max_width(img: Image.Image, max_width: int) -> Image.Image:
    w, h = img.size
    if w <= max_width:
        return img
    new_w = max_width
    new_h = max(1, int(round(h * (new_w / float(w)))))
    return img.resize((new_w, new_h), Image.Resampling.LANCZOS)


def optimize_sequence(
    directory: Path,
    pattern: str,
    max_width: int,
    label: str,
) -> tuple[int, int, int]:
    paths = sorted(directory.glob(pattern))
    if not paths:
        print(f"no files for {label} in {directory}")
        return 0, 0, 0

    images: list[Image.Image] = []
    boxes: list[tuple[int, int, int, int]] = []
    for path in paths:
        img = Image.open(path).convert("RGBA")
        images.append(img)
        box = content_bbox(img)
        if box is not None:
            boxes.append(box)

    if not boxes:
        print(f"no content found for {label}")
        return 0, 0, 0

    ref_w, ref_h = images[0].size
    crop = pad_bbox(union_bbox(boxes), ref_w, ref_h, PADDING)

    before_total = 0
    after_total = 0
    for path, img in zip(paths, images):
        before_total += path.stat().st_size
        cropped = img.crop(crop)
        scaled = scale_to_max_width(cropped, max_width)
        before, after = save_png_compressed(scaled, path)
        after_total += after

    print(
        f"{label}: {len(paths)} frames, crop {crop[2] - crop[0]}x{crop[3] - crop[1]} "
        f"@ max width {max_width}, {before_total / 1e6:.2f} MB -> {after_total / 1e6:.2f} MB"
    )
    return len(paths), before_total, after_total


def main() -> int:
    total_before = 0
    total_after = 0
    total_frames = 0

    for count, before, after in [
        optimize_sequence(BOOK_DIR, "Book_White*.png", BOOK_MAX_WIDTH, "loading_book"),
        optimize_sequence(TEXT_DIR, "Loading Text*.png", TEXT_MAX_WIDTH, "loading_text"),
    ]:
        total_frames += count
        total_before += before
        total_after += after

    if total_frames == 0:
        return 1

    print()
    print(f"optimized {total_frames} frames: {total_before / 1e6:.2f} MB -> {total_after / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
