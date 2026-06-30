#!/usr/bin/env python3
"""Sync bake data from the authored level_1.prefab into scripts/python/data/."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_TOOLS_ROOT))

from lib.environment_texture_names import encode_variant_filename, environment_texture_rel
from lib.map_layers_io import save_map_layers
from lib.border_wall_hierarchy import COMPASS_BORDER_WALL_GROUPS, OUTSIDE_BORDER_WALLS_ROOT
from lib.wall_placement import world_to_grid

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
DATA_DIR = _TOOLS_ROOT / "data"
BAKE = _TOOLS_ROOT / "bake" / "bake_level_prefab.py"
HIERARCHY = _TOOLS_ROOT / "lib" / "border_wall_hierarchy.py"

GRID_MIN_X = GRID_MIN_Y = -(96 - 80) // 2
DIRS = "ENSW"
_GROUND_VARIANTS = (
    ("A", 1, "a1"),
    ("A", 2, "a2"),
    ("A", 3, "a3"),
    ("A", 4, "a4"),
    ("A", 5, "a5"),
    ("E", 1, "road"),
)
TEX_SUFFIX_TO_KEY = {
    encode_variant_filename(letter, variation, d): f"{key}_{i}"
    for letter, variation, key in _GROUND_VARIANTS
    for i, d in enumerate(DIRS)
}
PATH_TO_TEX_KEY = {
    environment_texture_rel("Ground", letter, variation, d): f"{key}_{i}"
    for letter, variation, key in _GROUND_VARIANTS
    for i, d in enumerate(DIRS)
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
            tex_m = re.search(r'texturePath:t="([^"]+)"', body)
            prop_m = re.search(r'propId:t="([^"]+)"', body)
            pos = (0.0, 0.0, 0.0)
            if pos_m:
                pos = tuple(float(x.strip()) for x in pos_m.group(1).split(","))
            nodes[int(uid_m.group(1))] = {
                "name": name_m.group(1),
                "parent": int(parent_m.group(1)) if parent_m else None,
                "pos": pos,
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


def crop_wh(crop: tuple[float, float, float, float]) -> tuple[float, float]:
    return crop[2] - crop[0] + 1.0, crop[3] - crop[1] + 1.0


def load_prop_crops() -> dict:
    path = DATA_DIR / "level_1_prop_crops.json"
    raw = json.loads(path.read_text(encoding="utf-8"))
    crops: dict = {}
    for prop_id, spec in raw.items():
        crops[prop_id] = (tuple(spec[0]), tuple(spec[1]), float(spec[2]))
    return crops


def sprite_world_to_feet_grid(
    sprite_wx: float, sprite_wy: float, prop_id: str, prop_crops: dict
) -> tuple[float, float]:
    crop, feet_px, world_w = prop_crops[prop_id]
    cw, ch = crop_wh(crop)
    sw = world_w
    sh = world_w * (ch / cw)
    sprite_cx = (cw - 1.0) * 0.5
    sprite_cy = (ch - 1.0) * 0.5
    px_off_x = sprite_cx - feet_px[0]
    px_off_y = sprite_cy - feet_px[1]
    feet_wx = sprite_wx - px_off_x * sw / cw
    feet_wy = sprite_wy - px_off_y * sh / ch
    return world_to_grid(feet_wx, feet_wy)


def extract_prop_markers(nodes: dict[int, dict], prop_crops: dict) -> list[list]:
    markers: list[list] = []
    for uid, n in nodes.items():
        if not n["name"].startswith("misc_"):
            continue
        prop_id = n.get("prop_id")
        if not prop_id or prop_id not in prop_crops:
            continue
        wx, wy, _ = world_pos(nodes, uid)
        gx, gy = sprite_world_to_feet_grid(wx, wy, prop_id, prop_crops)
        markers.append([prop_id, round(gx, 2), round(gy, 2)])
    markers.sort(key=lambda m: m[0])
    return markers


def extract_border_offsets(nodes: dict[int, dict]) -> dict[str, tuple[float, float, float]]:
    offsets: dict[str, tuple[float, float, float]] = {}
    outside_uid = next(
        (uid for uid, n in nodes.items() if n["name"] == OUTSIDE_BORDER_WALLS_ROOT),
        None,
    )
    for n in nodes.values():
        if n["name"] in COMPASS_BORDER_WALL_GROUPS:
            offsets[n["name"]] = n["pos"]
        elif n["name"] in ("border_wall_lt", "border_wall_br", "border_wall_tr", "border_wall_bl"):
            # Legacy prefab shells — map to compass names when present.
            legacy_map = {
                "border_wall_lt": "west_border_walls",
                "border_wall_br": "east_border_walls",
                "border_wall_tr": "north_border_walls",
                "border_wall_bl": "south_border_walls",
            }
            offsets[legacy_map[n["name"]]] = n["pos"]
    if outside_uid is not None:
        for child in nodes.values():
            if child["parent"] == outside_uid and child["name"] in COMPASS_BORDER_WALL_GROUPS:
                offsets[child["name"]] = child["pos"]
    return offsets


def extract_map_cells(nodes: dict[int, dict]) -> dict[tuple[int, int], dict[str, str]]:
    cells: dict[tuple[int, int], dict[str, str]] = {}
    for cell_uid, n in nodes.items():
        m = re.fullmatch(r"cell_(-?\d+)_(-?\d+)", n["name"])
        if not m:
            continue
        gx, gy = int(m.group(1)), int(m.group(2))
        layers: dict[str, str] = {}
        for child in nodes.values():
            if child["parent"] != cell_uid:
                continue
            tex = child.get("tex")
            if not tex:
                continue
            key = PATH_TO_TEX_KEY.get(tex)
            if key is None:
                continue
            if child["name"] in ("ground", "grass", "road_fill"):
                layer_name = "road" if child["name"] == "road_fill" else child["name"]
                layers[layer_name] = key
        if layers:
            cells[(gx, gy)] = layers
    return cells


def format_border_offsets(offsets: dict[str, tuple[float, float, float]]) -> str:
    lines = ["BORDER_WALL_GROUP_OFFSETS: dict[str, tuple[float, float, float]] = {"]
    for name in COMPASS_BORDER_WALL_GROUPS:
        off = offsets.get(name, (0.0, 0.0, 0.0))
        lines.append(f'    "{name}": ({off[0]:.6f}, {off[1]:.6f}, {off[2]:.6f}),')
    lines.append("}")
    return "\n".join(lines)


def patch_border_offsets(bake_text: str, offsets: dict[str, tuple[float, float, float]]) -> str:
    new_block = format_border_offsets(offsets)
    return re.sub(
        r"BORDER_WALL_GROUP_OFFSETS: dict\[str, tuple\[float, float, float\]\] = \{.*?\n\}",
        new_block,
        bake_text,
        count=1,
        flags=re.S,
    )


def cells_to_json(cells: dict[tuple[int, int], dict[str, str]]) -> dict[str, dict[str, str]]:
    return {f"({gx}, {gy})": layers for (gx, gy), layers in sorted(cells.items())}


def main() -> int:
    text = PREFAB.read_text(encoding="utf-8")
    nodes = parse_nodes(text)
    prop_crops = load_prop_crops()

    markers = extract_prop_markers(nodes, prop_crops)
    offsets = extract_border_offsets(nodes)
    cells = extract_map_cells(nodes)

    (DATA_DIR / "level_1_prop_markers.json").write_text(
        json.dumps(markers, indent=2), encoding="utf-8"
    )
    chunk_count = save_map_layers(DATA_DIR, cells_to_json(cells))

    bake_text = BAKE.read_text(encoding="utf-8")
    hierarchy_text = HIERARCHY.read_text(encoding="utf-8")
    hierarchy_text = patch_border_offsets(hierarchy_text, offsets)
    HIERARCHY.write_text(hierarchy_text, encoding="utf-8", newline="\n")
    BAKE.write_text(bake_text, encoding="utf-8", newline="\n")

    print(f"Synced {len(markers)} prop markers -> data/level_1_prop_markers.json")
    print(f"Synced {len(cells)} map cells -> {chunk_count} map layer chunk(s)")
    print(f"Synced {len(offsets)} border wall group offsets -> border_wall_hierarchy.py")
    print("Tip: if editor picks ground before props, run: python scripts/python/prefab/fix_prefab_pick_uids.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
