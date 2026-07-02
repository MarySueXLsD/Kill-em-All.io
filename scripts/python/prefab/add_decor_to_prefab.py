"""Add tree and misc decorations to level_1.prefab under the props node."""
from __future__ import annotations

import argparse
import math
import random
import re
from pathlib import Path

from PIL import Image

from lib.environment_texture_names import (
    DIRECTION_TO_NAME,
    variant_family_from_filename,
)
from lib.prefab_node_names import parse_texture_path, decor_stem
from lib.resource_link_hash import parse_meta, ref_id_from_meta

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
ENV = PROJECT / "static" / "Environment"

# Match constants.das / iso_math.das
GRID_MIN_X = -8
GRID_MIN_Y = -8
GRID_WIDTH = 96
GRID_HEIGHT = 96
MAP_WIDTH = MAP_HEIGHT = 80
DEPTH_ENTITY_LAYER = 1000
DEPTH_TILE_STRIDE = 100
GROUND_TILE_WORLD_WIDTH = 1.0
GROUND_DIAMOND_FACE_HEIGHT_PX = 63.0
GROUND_DIAMOND_FACE_WIDTH_PX = 127.0
TILE_HALF_WIDTH = GROUND_TILE_WORLD_WIDTH * 0.5
TILE_HALF_HEIGHT = GROUND_TILE_WORLD_WIDTH * 0.5 * math.tan(
    math.atan(GROUND_DIAMOND_FACE_HEIGHT_PX / GROUND_DIAMOND_FACE_WIDTH_PX)
)
SPAWN_GX = 40.0
SPAWN_GY = 40.0
DIRS = ("E", "N", "S", "W")

# Gameplay props with collision — skip for random decor.
COLLISION_MISC = {
    f"Type_2_Variation_{v}"
    for v in (1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 14, 20, 25, 40)
}


def discover_types(category: str) -> list[str]:
    folder = ENV / category
    if not folder.is_dir():
        return []
    families = sorted(
        {
            family
            for p in folder.glob("*.png")
            if (family := variant_family_from_filename(p.name))
        }
    )
    return [
        name
        for name in families
        if any(
            (folder / f"{name}_{DIRECTION_TO_NAME[d]}.png").exists()
            for d in DIRS
        )
    ]


def discover_tree_types() -> list[str]:
    return discover_types("Tree")


def discover_misc_types() -> list[str]:
    return [
        name
        for name in discover_types("Misc")
        if name not in COLLISION_MISC
    ]


def grid_to_world(gx: float, gy: float) -> tuple[float, float]:
    return (
        (gx - gy) * TILE_HALF_WIDTH,
        (gx + gy) * TILE_HALF_HEIGHT,
    )


def depth_sort(gx: float, gy: float) -> int:
    min_sum = float(GRID_MIN_X + GRID_MIN_Y)
    return DEPTH_ENTITY_LAYER + int(((gx + gy) - min_sum) * DEPTH_TILE_STRIDE)


def image_size(texture_rel: str) -> tuple[int, int]:
    path = PROJECT / texture_rel
    with Image.open(path) as img:
        return img.size


def scale_for_sprite(texture_rel: str, world_width: float) -> tuple[float, float]:
    w, h = image_size(texture_rel)
    aspect = h / w if w else 1.0
    return world_width, world_width * aspect


def max_uid(text: str) -> int:
    return max(int(m) for m in re.findall(r"uid:i=(\d+)", text))


def find_props_uid(text: str) -> int:
    match = re.search(r'name:t="props"\s*\nuid:i=(\d+)', text)
    if not match:
        raise RuntimeError('Could not find props node uid in level_1.prefab')
    return int(match.group(1))


def find_insert_pos(text: str) -> int:
    for pattern in (
        r'\nnode\{\nname:t="walls"',
        r'\nnode\{\nname:t="map"',
        r'\nres\{',
    ):
        match = re.search(pattern, text)
        if match:
            return match.start()
    raise RuntimeError("Could not find insertion point in level_1.prefab")


def parse_grass_cells(text: str) -> set[tuple[int, int]]:
    """Cells with an active grass overlay in the authored prefab."""
    grass: set[tuple[int, int]] = set()
    blocks = text.split("node{")
    for block in blocks[1:]:
        cell = re.search(r'name:t="cell_(-?\d+)_(-?\d+)"', block)
        if not cell:
            continue
        gx, gy = int(cell.group(1)), int(cell.group(2))
        if 'name:t="grass"' not in block:
            continue
        grass.add((gx, gy))
    return grass


RES_RE = re.compile(
    r'res\{\s*guid:t="([^"]+)"\s*type:i=\d+\s*refId:i64=(-?\d+)\s*\}',
    re.MULTILINE,
)


def existing_res_guids(text: str) -> set[str]:
    return {guid for guid, _ in RES_RE.findall(text)}


def append_res_entries(text: str, entries: list[tuple[str, int]]) -> str:
    if not entries:
        return text
    block = "".join(
        f'res{{\nguid:t="{guid}"\ntype:i=2\nrefId:i64={ref_id}\n}}\n' for guid, ref_id in entries
    )
    pos = text.rfind("\nres{")
    if pos < 0:
        return text.rstrip() + "\n" + block
    return text[:pos] + "\n" + block + text[pos:]


def register_texture_res(texture_rel: str, have_guids: set[str], pending: list[tuple[str, int]]) -> int:
    meta = PROJECT / Path(texture_rel + ".meta")
    ref_id = ref_id_from_meta(meta)
    guid, _ = parse_meta(meta)
    if guid not in have_guids:
        pending.append((guid, ref_id))
        have_guids.add(guid)
    return ref_id


def resolve_sprite(category: str, family: str, direction: str) -> tuple[str, str]:
    for d in (direction, "E", "N", "S", "W"):
        filename = f"{family}_{DIRECTION_TO_NAME[d]}.png"
        path = ENV / category / filename
        if path.exists():
            rel = f"static/Environment/{category}/{filename}"
            return rel, rel
    raise FileNotFoundError(f"{category}/{family}")


def make_node(
    uid: int,
    parent_uid: int,
    name: str,
    wx: float,
    wy: float,
    sx: float,
    sy: float,
    depth: int,
    texture_rel: str,
    ref_id: int,
) -> str:
    return f"""node{{
name:t="{name}"
uid:i={uid}
parent:i={parent_uid}
pos:p3={wx:.4f}, {wy:.4f}, 0
scl:p3={sx:.4f}, {sy:.4f}, 1
SpriteRenderer{{
__textureId:i64={ref_id}
color:p4=1, 1, 1, 1
flipX:b=no
flipY:b=no
uvRect:p4=0, 0, 1, 1
useTextureSizeForScaling:b=no
renderOrder:i={depth}
}}
TileTextureHint{{texturePath:t="{texture_rel}";}}
}}
"""


def sample_positions(
    rng: random.Random,
    count: int,
    placed: list[tuple[float, float]],
    min_spacing: float,
    grass_cells: set[tuple[int, int]] | None,
) -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    attempts = 0
    max_attempts = count * 400
    while len(out) < count and attempts < max_attempts:
        attempts += 1
        if grass_cells:
            gx, gy = rng.choice(list(grass_cells))
            gx += rng.uniform(-0.35, 0.35)
            gy += rng.uniform(-0.35, 0.35)
        else:
            gx = rng.uniform(4.0, 76.0)
            gy = rng.uniform(4.0, 76.0)
        if gx < 0 or gy < 0 or gx >= MAP_WIDTH or gy >= MAP_HEIGHT:
            continue
        if abs(gx - SPAWN_GX) < 9.0 and abs(gy - SPAWN_GY) < 9.0:
            continue
        if any(abs(gx - px) < min_spacing and abs(gy - py) < min_spacing for px, py in placed):
            continue
        out.append((gx, gy))
        placed.append((gx, gy))
    return out


def decor_node_name(texture_rel: str, used: dict[str, int]) -> str:
    parsed = parse_texture_path(texture_rel)
    if parsed is None:
        return f"Decor_unknown_{len(used)}"
    cat, type_num, var_num, dir_letter = parsed
    stem = decor_stem(cat, type_num, var_num, dir_letter)
    count = used.get(stem, 0) + 1
    used[stem] = count
    return stem if count == 1 else f"{stem}_{count}"


def existing_decor_positions(text: str) -> list[tuple[float, float]]:
    placed: list[tuple[float, float]] = []
    for block in text.split("node{")[1:]:
        if not re.search(r'name:t="(Tree|Misc)_type\d+_var\d+_', block):
            continue
        pos = re.search(r"pos:p3=([^,\n]+), ([^,\n]+)", block)
        if not pos:
            continue
        wx, wy = float(pos.group(1)), float(pos.group(2))
        # invert grid_to_world approximately for spacing checks
        gy = (wy / TILE_HALF_HEIGHT - wx / TILE_HALF_WIDTH) * 0.5
        gx = (wx / TILE_HALF_WIDTH + wy / TILE_HALF_HEIGHT) * 0.5
        placed.append((gx, gy))
    return placed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trees", type=int, default=110, help="Number of trees to add")
    parser.add_argument("--misc", type=int, default=75, help="Number of misc decor props to add")
    parser.add_argument("--seed", type=int, default=20260626)
    args = parser.parse_args()

    tree_types = discover_tree_types()
    misc_types = discover_misc_types()
    if not tree_types:
        raise SystemExit("No tree textures found")
    if not misc_types:
        raise SystemExit("No misc decor textures found")

    rng = random.Random(args.seed)
    text = PREFAB.read_text(encoding="utf-8")
    insert_at = find_insert_pos(text)
    props_uid = find_props_uid(text)
    grass_cells = parse_grass_cells(text)

    next_uid = max_uid(text) + 1
    placed = existing_decor_positions(text)
    nodes: list[str] = []
    have_guids = existing_res_guids(text)
    pending_res: list[tuple[str, int]] = []
    decor_names_used: dict[str, int] = {}

    tree_positions = sample_positions(rng, args.trees, placed, 2.4, grass_cells)
    for i, (gx, gy) in enumerate(tree_positions):
        kind = rng.choice(tree_types)
        rel, _ = resolve_sprite("Tree", kind, rng.choice(DIRS))
        ref_id = register_texture_res(rel, have_guids, pending_res)
        ww = rng.uniform(1.5, 2.6)
        sx, sy = scale_for_sprite(rel, ww)
        wx, wy = grid_to_world(gx, gy)
        nodes.append(
            make_node(
                next_uid,
                props_uid,
                decor_node_name(rel, decor_names_used),
                wx,
                wy,
                sx,
                sy,
                depth_sort(gx, gy),
                rel,
                ref_id,
            )
        )
        next_uid += 1

    misc_positions = sample_positions(rng, args.misc, placed, 1.8, grass_cells)
    for i, (gx, gy) in enumerate(misc_positions):
        kind = rng.choice(misc_types)
        rel, _ = resolve_sprite("Misc", kind, rng.choice(DIRS))
        ref_id = register_texture_res(rel, have_guids, pending_res)
        ww = rng.uniform(0.8, 1.9)
        sx, sy = scale_for_sprite(rel, ww)
        wx, wy = grid_to_world(gx, gy)
        nodes.append(
            make_node(
                next_uid,
                props_uid,
                decor_node_name(rel, decor_names_used),
                wx,
                wy,
                sx,
                sy,
                depth_sort(gx, gy),
                rel,
                ref_id,
            )
        )
        next_uid += 1

    block = "\n" + "\n".join(nodes)
    updated = text[:insert_at] + block + text[insert_at:]
    updated = append_res_entries(updated, pending_res)
    PREFAB.write_text(updated, encoding="utf-8", newline="\n")
    from fix_prefab_pick_uids import fix_prefab_pick_uids

    fix_prefab_pick_uids(PREFAB)
    print(f"Tree types: {len(tree_types)} | Misc types: {len(misc_types)}")
    print(f"Added {len(tree_positions)} trees and {len(misc_positions)} misc props on grass")
    print(f"res entries added: {len(pending_res)}")
    print(f"Props parent uid: {props_uid}")
    print(f"UID range: {next_uid - len(nodes)} .. {next_uid - 1}")


if __name__ == "__main__":
    main()
