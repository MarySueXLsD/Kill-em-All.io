"""Find static assets not referenced by any .das file."""
from __future__ import annotations

import re
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


def main() -> None:
    used = referenced_paths()
    all_pngs = list(STATIC.rglob("*.png"))
    unused = [p for p in all_pngs if p.relative_to(PROJECT).as_posix() not in used]
    used_pngs = [p for p in all_pngs if p.relative_to(PROJECT).as_posix() in used]

    unused_bytes = sum(p.stat().st_size for p in unused)
    used_bytes = sum(p.stat().st_size for p in used_pngs)

    print(f"Referenced paths in .das: {len(used)}")
    print(f"PNG files on disk: {len(all_pngs)}")
    print(f"Used PNGs: {len(used_pngs)} ({used_bytes / 1e6:.1f} MB)")
    print(f"Unused PNGs: {len(unused)} ({unused_bytes / 1e6:.1f} MB)")

    by_dir: dict[str, tuple[int, int]] = {}
    for p in unused:
        top = p.relative_to(STATIC).parts[0] if p.relative_to(STATIC).parts else "."
        n, b = by_dir.get(top, (0, 0))
        by_dir[top] = (n + 1, b + p.stat().st_size)

    print("\nUnused by top-level folder:")
    for name, (n, b) in sorted(by_dir.items(), key=lambda x: -x[1][1]):
        print(f"  {name}: {n} files, {b / 1e6:.1f} MB")

    print("\nSample unused paths (first 20):")
    for p in sorted(unused)[:20]:
        print(f"  {p.relative_to(PROJECT).as_posix()}")

    print("\nUnused by subfolder (top 25):")
    by_sub: dict[str, tuple[int, int]] = {}
    for p in unused:
        parts = p.relative_to(STATIC).parts
        key = "/".join(parts[:2]) if len(parts) > 1 else parts[0]
        n, b = by_sub.get(key, (0, 0))
        by_sub[key] = (n + 1, b + p.stat().st_size)
    for name, (n, b) in sorted(by_sub.items(), key=lambda x: -x[1][1])[:25]:
        print(f"  {name}: {n} files, {b / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
