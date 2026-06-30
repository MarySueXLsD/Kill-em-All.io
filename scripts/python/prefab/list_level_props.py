#!/usr/bin/env python3
"""List every prop/decor sprite in level_1.prefab with texture and grid feet."""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from lib.wall_placement import world_to_grid

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
OUT_CSV = PROJECT / "tools" / "level_1_props_inventory.csv"


def parse_nodes(text: str) -> dict[int, dict]:
    nodes: dict[int, dict] = {}
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
        prop_m = re.search(r'propId:t="([^"]+)"', body)
        tex_m = re.search(r'texturePath:t="([^"]+)"', body)
        pos_m = re.search(r"pos:p3=([^,\n]+), ([^,\n]+)", body)
        if name_m and uid_m:
            wx = wy = 0.0
            if pos_m:
                wx, wy = float(pos_m.group(1)), float(pos_m.group(2))
            nodes[int(uid_m.group(1))] = {
                "name": name_m.group(1),
                "parent": int(parent_m.group(1)) if parent_m else None,
                "prop_id": prop_m.group(1) if prop_m else "",
                "tex": tex_m.group(1) if tex_m else "",
                "wx": wx,
                "wy": wy,
                "sprite": "SpriteRenderer{" in body,
                "footprint": "PropFootprint{" in body,
            }
        i = j
    return nodes


def world_pos(nodes: dict[int, dict], uid: int) -> tuple[float, float]:
    x = y = 0.0
    while uid is not None:
        n = nodes[uid]
        x += n["wx"]
        y += n["wy"]
        uid = n["parent"]
    return x, y


def descendants(nodes: dict[int, dict], root_uid: int) -> list[int]:
    kids: dict[int, list[int]] = {}
    for uid, n in nodes.items():
        p = n["parent"]
        if p is not None:
            kids.setdefault(p, []).append(uid)
    out: list[int] = []
    stack = [root_uid]
    seen: set[int] = set()
    while stack:
        uid = stack.pop()
        if uid in seen:
            continue
        seen.add(uid)
        out.append(uid)
        stack.extend(kids.get(uid, []))
    return out


def texture_label(tex: str) -> str:
    if not tex:
        return ""
    return tex.replace("static/Environment/", "").replace(".png", "")


def main() -> int:
    if not PREFAB.exists():
        print(f"missing {PREFAB}", file=sys.stderr)
        return 1

    nodes = parse_nodes(PREFAB.read_text(encoding="utf-8"))
    by_name = {n["name"]: uid for uid, n in nodes.items()}
    props_uid = by_name.get("props")
    walls_uid = by_name.get("walls")
    if props_uid is None:
        print("missing props node", file=sys.stderr)
        return 1

    rows: list[dict[str, str | float]] = []

    for uid in descendants(nodes, props_uid):
        n = nodes[uid]
        if not n["sprite"]:
            continue
        wx, wy = world_pos(nodes, uid)
        gx, gy = world_to_grid(wx, wy)
        has_collision = bool(n["footprint"] and n["prop_id"])
        rows.append(
            {
                "node_name": n["name"],
                "texture": texture_label(n["tex"]),
                "prop_id": n["prop_id"],
                "collision": "yes" if has_collision else "no",
                "grid_x": round(gx, 2),
                "grid_y": round(gy, 2),
                "world_x": round(wx, 4),
                "world_y": round(wy, 4),
            }
        )

    if walls_uid is not None:
        for uid in descendants(nodes, walls_uid):
            n = nodes[uid]
            if not n["sprite"]:
                continue
            wx, wy = world_pos(nodes, uid)
            gx, gy = world_to_grid(wx, wy)
            rows.append(
                {
                    "node_name": n["name"],
                    "texture": texture_label(n["tex"]),
                    "prop_id": n["prop_id"],
                    "collision": "yes" if n["footprint"] else "wall",
                    "grid_x": round(gx, 2),
                    "grid_y": round(gy, 2),
                    "world_x": round(wx, 4),
                    "world_y": round(wy, 4),
                }
            )

    rows.sort(key=lambda r: (r["collision"], r["texture"], r["node_name"]))

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "node_name",
                "texture",
                "prop_id",
                "collision",
                "grid_x",
                "grid_y",
                "world_x",
                "world_y",
            ],
        )
        w.writeheader()
        w.writerows(rows)

    no_col = [r for r in rows if r["collision"] == "no"]
    yes_col = [r for r in rows if r["collision"] == "yes"]
    walls = [r for r in rows if r["collision"] == "wall"]

    print(f"Full inventory written to: {OUT_CSV}")
    print(f"Total sprites: {len(rows)}")
    print(f"  collision=yes (gameplay props): {len(yes_col)}")
    print(f"  collision=no (trees/decor):     {len(no_col)}")
    print(f"  walls:                          {len(walls)}")
    print()
    print("=== NO COLLISION (trees + misc decor) — send coords for these ===")
    for r in no_col:
        print(
            f"  {r['node_name']:22} {r['texture']:18} "
            f"grid=({r['grid_x']}, {r['grid_y']})"
        )
    print()
    print("=== WITH COLLISION (gameplay props) ===")
    for r in yes_col:
        print(
            f"  {r['node_name']:22} {r['prop_id']:12} "
            f"grid=({r['grid_x']}, {r['grid_y']})"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
