#!/usr/bin/env python3
"""Extract wall sprite world positions from level_1.prefab."""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.wall_placement import (
    WALL_SPECS,
    crop_wh,
    generate_wall_placements,
    grid_to_world,
    prop_pixel_to_local,
    world_to_grid,
)

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"

TEX_TO_PROP = {
    "static/Environment/Wall/Type_2_Variation_1_East.png": "wall_b1_e",
    "static/Environment/Wall/Type_2_Variation_1_West.png": "wall_b1_w",
    "static/Environment/Wall/Type_2_Variation_1_North.png": "wall_b1_n",
    "static/Environment/Wall/Type_2_Variation_1_South.png": "wall_b1_s",
    "static/Environment/Wall/Type_2_Variation_2_East.png": "wall_b2_e",
    "static/Environment/Wall/Type_2_Variation_2_West.png": "wall_b2_w",
    "static/Environment/Wall/Type_2_Variation_2_North.png": "wall_b2_n",
    "static/Environment/Wall/Type_2_Variation_2_South.png": "wall_b2_s",
}

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
        if name_m and uid_m:
            parent_m = re.search(r"parent:i=(\d+)", body)
            pos_m = re.search(r"pos:p3=([^\n]+)", body)
            render_m = re.search(r"renderOrder:i=(\d+)", body)
            tex_m = re.search(r'texturePath:t="([^"]+)"', body)
            prop_m = re.search(r'propId:t="([^"]+)"', body)
            pos = (0.0, 0.0, 0.0)
            if pos_m:
                pos = tuple(float(x.strip()) for x in pos_m.group(1).split(","))
            nodes[int(uid_m.group(1))] = {
                "name": name_m.group(1),
                "parent": int(parent_m.group(1)) if parent_m else None,
                "pos": pos,
                "render": int(render_m.group(1)) if render_m else None,
                "tex": tex_m.group(1) if tex_m else None,
                "prop_id": prop_m.group(1) if prop_m else None,
            }
        i = j
    return nodes


def world_pos(nodes: dict[int, dict], uid: int) -> tuple[float, float, float]:
    x = y = z = 0.0
    while uid is not None:
        n = nodes[uid]
        px, py, pz = n["pos"]
        x += px
        y += py
        z += pz
        uid = n["parent"]
    return x, y, z


def sprite_world_to_feet_grid(
    sprite_wx: float, sprite_wy: float, prop_id: str
) -> tuple[float, float]:
    spec = WALL_SPECS[prop_id]
    cw, ch = crop_wh(spec.crop)
    sw = spec.world_w
    sh = spec.world_w * (ch / cw)
    feet_local = prop_pixel_to_local(spec.feet_px[0], spec.feet_px[1], spec.crop, spec.world_w)
    sprite_cx = (cw - 1.0) * 0.5
    sprite_cy = (ch - 1.0) * 0.5
    # sprite node position = feet_world + anchor; anchor = feet_local negated from center
    anchor_x = (spec.feet_px[0] - spec.crop[0] - sprite_cx) * sw / cw
    anchor_y = (sprite_cy - (spec.feet_px[1] - spec.crop[1])) * sh / ch
    feet_wx = sprite_wx - anchor_x
    feet_wy = sprite_wy - anchor_y
    return world_to_grid(feet_wx, feet_wy)


def main() -> int:
    text = PREFAB.read_text(encoding="utf-8")
    nodes = parse_nodes(text)

    group_offsets: dict[str, tuple[float, float, float]] = {}
    for uid, n in nodes.items():
        if n["name"] in ("border_wall_lt", "border_wall_br", "border_wall_tr", "border_wall_bl"):
            group_offsets[n["name"]] = n["pos"]

    walls: list[dict] = []
    for uid, n in nodes.items():
        nm = n["name"]
        if not (
            re.match(r"border_wall_(lt|br|tr|bl)_\d+", nm)
            or nm.startswith("interior_wall_")
            or nm.startswith("border_corner_")
        ):
            continue
        wx, wy, _ = world_pos(nodes, uid)
        prop_id = n.get("prop_id") or TEX_TO_PROP.get(n["tex"] or "", n["tex"] or "")
        if prop_id not in WALL_SPECS:
            continue
        fg = sprite_world_to_feet_grid(wx, wy, prop_id)
        walls.append(
            {
                "name": nm,
                "sprite_wx": wx,
                "sprite_wy": wy,
                "feet_gx": fg[0],
                "feet_gy": fg[1],
                "prop_id": prop_id,
                "render": n["render"],
            }
        )

    walls.sort(key=lambda w: w["name"])
    gen = generate_wall_placements()
    gen_by_name = {p.name: p for p in gen}

    print(f"Prefab walls: {len(walls)} (corners: {sum(1 for w in walls if 'corner' in w['name'])})")
    print(f"Generated walls: {len(gen)} (corners: {sum(1 for p in gen if 'corner' in p.name)})")
    print("\nGroup offsets:")
    for k, v in sorted(group_offsets.items()):
        print(f"  {k}: {v}")

    print("\nBR render orders (first/mid/last):")
    br = [w for w in walls if w["name"].startswith("border_wall_br_")]
    for w in (br[0], br[len(br) // 2], br[-1]):
        print(f"  {w['name']}: render={w['render']} feet=({w['feet_gx']:.3f}, {w['feet_gy']:.3f})")

    print("\nPosition deltas vs generated (first 5 per edge):")
    for prefix in ("border_wall_lt", "border_wall_br", "border_wall_tr", "border_wall_bl"):
        edge = [w for w in walls if w["name"].startswith(prefix + "_")]
        print(f"\n{prefix} ({len(edge)} segments):")
        for w in edge[:5]:
            g = gen_by_name.get(w["name"])
            if g is None:
                print(f"  {w['name']}: MISSING in generated")
                continue
            gwx, gwy = grid_to_world(g.feet_gx, g.feet_gy)
            spec = WALL_SPECS[w["prop_id"]]
            cw, ch = crop_wh(spec.crop)
            sw = spec.world_w
            sh = spec.world_w * (ch / cw)
            sprite_cx = (cw - 1.0) * 0.5
            sprite_cy = (ch - 1.0) * 0.5
            anchor_x = (spec.feet_px[0] - spec.crop[0] - sprite_cx) * sw / cw
            anchor_y = (sprite_cy - (spec.feet_px[1] - spec.crop[1])) * sh / ch
            gen_sprite = (gwx + anchor_x, gwy + anchor_y)
            dx = w["sprite_wx"] - gen_sprite[0]
            dy = w["sprite_wy"] - gen_sprite[1]
            print(
                f"  {w['name']}: delta=({dx:.4f}, {dy:.4f}) "
                f"prefab_sprite=({w['sprite_wx']:.3f},{w['sprite_wy']:.3f})"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
