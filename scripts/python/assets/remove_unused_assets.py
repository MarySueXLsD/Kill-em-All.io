"""Remove static PNG assets not referenced by any .das file."""
from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
STATIC = PROJECT / "static"


def referenced_paths() -> set[str]:
    used: set[str] = set()
    for das in PROJECT.glob("*.das"):
        text = das.read_text(encoding="utf-8")
        for m in re.findall(r'"static/[^"]+"', text):
            used.add(m.strip('"'))
    return used


def remove_unused(used: set[str]) -> tuple[int, int]:
    removed_files = 0
    removed_bytes = 0
    for path in sorted(STATIC.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(PROJECT).as_posix()
        if path.suffix.lower() == ".png":
            if rel in used:
                continue
        elif path.name.endswith(".png.meta"):
            if rel[:-5] in used:
                continue
        else:
            continue
        removed_bytes += path.stat().st_size
        path.unlink()
        removed_files += 1

    for path in sorted(STATIC.rglob("*"), reverse=True):
        if path.is_dir():
            try:
                path.rmdir()
            except OSError:
                pass
    return removed_files, removed_bytes


def main() -> int:
    used = referenced_paths()
    print(f"Referenced asset paths: {len(used)}")
    removed_files, removed_bytes = remove_unused(used)
    print(f"Removed: {removed_files} files ({removed_bytes / 1e6:.1f} MB)")

    remaining = list(STATIC.rglob("*.png"))
    remain_bytes = sum(p.stat().st_size for p in remaining)
    print(f"Remaining PNGs: {len(remaining)} ({remain_bytes / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
