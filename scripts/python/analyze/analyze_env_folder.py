"""Analyze environment PNGs and prefab references."""
from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
ENV = PROJECT / "static" / "Environment"
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
CONSTANTS = PROJECT / "scripts" / "das" / "core" / "constants.das"


def referenced_in_das() -> set[str]:
    used: set[str] = set()
    for das in (PROJECT / "scripts" / "das").rglob("*.das"):
        for m in re.findall(r'"static/Environment/[^"]+\.png"', das.read_text(encoding="utf-8")):
            used.add(m.strip('"'))
    return used


def referenced_in_prefab() -> set[str]:
    text = PREFAB.read_text(encoding="utf-8", errors="replace")
    return set(re.findall(r'static/Environment/[^"]+\.png', text))


def main() -> None:
    das_refs = referenced_in_das()
    prefab_refs = referenced_in_prefab()
    all_pngs = list(ENV.rglob("*.png"))

    sizes = Counter()
    crop_savings = 0
    file_savings_est = 0
    for p in all_pngs:
        img = Image.open(p)
        w, h = img.size
        sizes[(w, h)] += 1
        bb = img.getbbox()
        if not bb:
            continue
        l, t, r, b = bb
        cw, ch = r - l, b - t
        if cw < w or ch < h:
            crop_savings += w * h - cw * ch
            file_savings_est += p.stat().st_size * (1 - (cw * ch) / (w * h))

    on_disk = {p.relative_to(PROJECT).as_posix() for p in all_pngs}
    unused_on_disk = on_disk - prefab_refs - das_refs
    in_prefab_not_disk = prefab_refs - on_disk

    print(f"Environment PNGs: {len(all_pngs)}")
    print(f"Total size: {sum(p.stat().st_size for p in all_pngs) / 1e6:.1f} MB")
    print(f"Referenced in .das: {len(das_refs)}")
    print(f"Referenced in prefab: {len(prefab_refs)}")
    print(f"On disk but unreferenced: {len(unused_on_disk)}")
    print(f"In prefab but missing: {len(in_prefab_not_disk)}")
    print(f"Top sizes: {sizes.most_common(8)}")
    print(f"Est crop pixel savings: {crop_savings / 1e6:.1f} Mpx")
    print(f"Est file savings from crop: {file_savings_est / 1e6:.1f} MB")

    # Folder breakdown
    by_folder: dict[str, tuple[int, int]] = {}
    for p in all_pngs:
        parts = p.relative_to(ENV).parts
        key = parts[0] if len(parts) > 1 else "(root)"
        n, b = by_folder.get(key, (0, 0))
        by_folder[key] = (n + 1, b + p.stat().st_size)
    print("\nBy folder:")
    for k, (n, b) in sorted(by_folder.items(), key=lambda x: -x[1][1]):
        print(f"  {k}: {n} files, {b / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
