#!/usr/bin/env python3
"""Analyze sprite node uid ranges in level_1.prefab for editor pick order."""
from __future__ import annotations

import re
from pathlib import Path

PREFAB = Path(__file__).resolve().parents[3] / "prefabs" / "level_1.prefab"


def parse_nodes(text: str) -> list[tuple[int, str, int | None]]:
    out: list[tuple[int, str, int | None]] = []
    i = 0
    while True:
        start = text.find("node{", i)
        if start < 0:
            break
        depth = 0
        j = start
        while j < len(text):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        body = text[start + 5 : j - 1]
        name_m = re.search(r'name:t="([^"]+)"', body)
        uid_m = re.search(r"uid:i=(\d+)", body)
        parent_m = re.search(r"parent:i=(\d+)", body)
        if name_m and uid_m:
            out.append(
                (
                    int(uid_m.group(1)),
                    name_m.group(1),
                    int(parent_m.group(1)) if parent_m else None,
                )
            )
        i = j
    return out


def main() -> None:
    nodes = parse_nodes(PREFAB.read_text(encoding="utf-8"))
    categories: dict[str, list[int]] = {
        "misc_props": [],
        "wall_sprites": [],
        "ground": [],
        "grass": [],
        "road": [],
    }
    for uid, name, _parent in nodes:
        if name.startswith("misc_") or name.startswith("border_wall"):
            key = "misc_props" if name.startswith("misc_") else "wall_sprites"
            categories[key].append(uid)
        elif name == "ground":
            categories["ground"].append(uid)
        elif name == "grass":
            categories["grass"].append(uid)
        elif name == "road_fill":
            categories["road"].append(uid)

    for key, uids in categories.items():
        if not uids:
            continue
        print(f"{key}: count={len(uids)} min={min(uids)} max={max(uids)}")

  # overlaps: if ground min < misc max, pick order broken for some props
    if categories["ground"] and categories["misc_props"]:
        print(
            f"props max ({max(categories['misc_props'])}) < ground min ({min(categories['ground'])}) ?",
            max(categories["misc_props"]) < min(categories["ground"]),
        )
    high_misc = [u for u in categories["misc_props"] if u > min(categories["ground"])]
    if high_misc:
        print(f"misc props with uid > ground min: {len(high_misc)} (e.g. {sorted(high_misc)[:5]})")

    decor = [uid for uid, name, _ in nodes if name.startswith("decor_")]
    if decor:
        print(f"decor: count={len(decor)} min={min(decor)} max={max(decor)}")
        print(
            f"decor min < ground min ? {min(decor) < min(categories['ground'])}"
        )


if __name__ == "__main__":
    main()
