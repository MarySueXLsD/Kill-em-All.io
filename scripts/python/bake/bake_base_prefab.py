#!/usr/bin/env python3
"""Bake compact base.prefab — grass field, one road, walled courtyard at map corner."""
from __future__ import annotations

import math
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

from bake_level_prefab import (  # noqa: E402
    A1_CROPS,
    A2_CROPS,
    A3_CROPS,
    A4_CROPS,
    CAMERA_Z,
    DEPTH_BORDER_WALL_BELOW_BIAS,
    DEPTH_ENTITY_LAYER,
    DEPTH_FOREGROUND_OVERLAY_HEADROOM,
    DEPTH_TILE_GRASS_BIAS,
    DEPTH_TILE_ROAD_BIAS,
    DEPTH_TILE_STRIDE,
    ENTITY_SPRITE_Y_OFFSET_PX,
    GROUND_CROP_MAX_X,
    GROUND_CROP_MAX_Y,
    GROUND_CROP_MIN_X,
    GROUND_CROP_MIN_Y,
    GROUND_OUTSIDE_COLOR,
    GROUND_TILE_LAYOUT_CROP,
    GROUND_TILE_WORLD_WIDTH,
    PATHS,
    PLAYER_IDLE_PATH,
    PLAYER_SHEET_COLS,
    PLAYER_SHEET_FEET_X_PX,
    PLAYER_SHEET_FEET_Y_PX,
    PLAYER_SHEET_HEIGHT,
    PLAYER_SHEET_ROWS,
    PLAYER_SHEET_WIDTH,
    PLAYER_WORLD_HEIGHT,
    PROP_CROPS,
    TILE_LAYOUT,
    Writer,
    depth_sort_key,
    format_res_section,
    grid_hash,
    grid_to_world,
    load_path_to_guid,
    load_texture_ref_ids,
    player_sprite_world_position,
    tex_uv_for_key,
    tile_anchor,
    tile_scale,
    uv_precropped,
)
from lib.wall_placement import WallPlacement  # noqa: E402

PROJECT = Path(__file__).resolve().parents[3]
OUT = PROJECT / "prefabs" / "base.prefab"

BASE_GRID_WIDTH = 32
BASE_GRID_HEIGHT = 32
BASE_MAP_WIDTH = 24
BASE_MAP_HEIGHT = 24
BASE_GRID_MIN_X = -(BASE_GRID_WIDTH - BASE_MAP_WIDTH) // 2
BASE_GRID_MIN_Y = -(BASE_GRID_HEIGHT - BASE_MAP_HEIGHT) // 2
BASE_PLAYER_SPAWN_GRID_X = 5.0
BASE_PLAYER_SPAWN_GRID_Y = 5.0
BASE_COURTYARD_MIN = 2
BASE_COURTYARD_MAX = 8
BASE_ROAD_GX = 12

LAYOUT = (GROUND_CROP_MIN_X, GROUND_CROP_MIN_Y, GROUND_CROP_MAX_X, GROUND_CROP_MAX_Y)


def in_world(gx: int, gy: int) -> bool:
    return 0 <= gx < BASE_MAP_WIDTH and 0 <= gy < BASE_MAP_HEIGHT


def in_courtyard(gx: int, gy: int) -> bool:
    return (
        BASE_COURTYARD_MIN <= gx <= BASE_COURTYARD_MAX
        and BASE_COURTYARD_MIN <= gy <= BASE_COURTYARD_MAX
    )


def on_road(gx: int, gy: int) -> bool:
    return in_world(gx, gy) and gx == BASE_ROAD_GX


def pick_grass_overlay_key(gx: int, gy: int) -> str:
    """Simple edge/corner grass overlay from 4-neighbor mud contact."""
    ul = in_courtyard(gx - 1, gy - 1) or on_road(gx - 1, gy - 1)
    ur = in_courtyard(gx, gy - 1) or on_road(gx, gy - 1)
    dl = in_courtyard(gx - 1, gy) or on_road(gx - 1, gy)
    dr = in_courtyard(gx, gy) or on_road(gx, gy)
    mud_n = not ul and not ur
    mud_s = not dl and not dr
    mud_w = not ul and not dl
    mud_e = not ur and not dr
    if mud_n and mud_w:
        return "a4_3"
    if mud_n and mud_e:
        return "a4_2"
    if mud_s and mud_w:
        return "a4_0"
    if mud_s and mud_e:
        return "a4_1"
    if mud_n:
        return "a3_0"
    if mud_s:
        return "a3_2"
    if mud_w:
        return "a3_3"
    if mud_e:
        return "a3_1"
    return "a2_0"


def build_map_cell_layers() -> dict[tuple[int, int], dict[str, str]]:
    layers: dict[tuple[int, int], dict[str, str]] = {}
    for gy in range(BASE_GRID_MIN_Y, BASE_GRID_MIN_Y + BASE_GRID_HEIGHT):
        for gx in range(BASE_GRID_MIN_X, BASE_GRID_MIN_X + BASE_GRID_WIDTH):
            if not in_world(gx, gy):
                continue
            a1_dir = grid_hash(gx * 3 + 1, gy * 5 + 7) % 4
            cell: dict[str, str] = {"ground": f"a1_{a1_dir}"}
            if on_road(gx, gy):
                cell["road"] = f"road_{grid_hash(gx, gy) % 4}"
            elif not in_courtyard(gx, gy):
                cell["grass"] = pick_grass_overlay_key(gx, gy)
            layers[(gx, gy)] = cell
    return layers


def depth_sort_entity_from_grid(feet_gx: float, feet_gy: float) -> int:
    min_sum = float(BASE_GRID_MIN_X + BASE_GRID_MIN_Y)
    return DEPTH_ENTITY_LAYER + int(((feet_gx + feet_gy) - min_sum) * DEPTH_TILE_STRIDE)


def depth_sort_foreground_overlay_order() -> int:
    min_sum = float(BASE_GRID_MIN_X + BASE_GRID_MIN_Y)
    max_sum = float(BASE_GRID_MIN_X + BASE_GRID_MIN_Y + BASE_GRID_WIDTH + BASE_GRID_HEIGHT - 2)
    return (
        DEPTH_ENTITY_LAYER
        + int((max_sum - min_sum) * DEPTH_TILE_STRIDE)
        + DEPTH_FOREGROUND_OVERLAY_HEADROOM
    )


def border_wall_render_order(sprite_name: str, feet_gx: float, feet_gy: float) -> int:
    entity_depth = depth_sort_entity_from_grid(feet_gx, feet_gy)
    if (
        sprite_name.startswith("Wall_type2_var1_n_")
        or sprite_name.startswith("Wall_type2_var1_e_")
        or sprite_name in ("Wall_corner_nw", "Wall_corner_ne")
    ):
        return depth_sort_foreground_overlay_order() + depth_sort_key(feet_gx, feet_gy)
    if (
        sprite_name.startswith("Wall_type2_var1_s_")
        or sprite_name.startswith("Wall_type2_var1_w_")
        or sprite_name in ("Wall_corner_sw", "Wall_corner_se")
    ):
        return entity_depth + DEPTH_BORDER_WALL_BELOW_BIAS
    return entity_depth


def courtyard_wall_placements() -> list[WallPlacement]:
    placements: list[WallPlacement] = []
    cmin, cmax = BASE_COURTYARD_MIN, BASE_COURTYARD_MAX
    wall_row_n = float(cmin - 1)
    wall_row_s = float(cmax + 1)
    wall_col_w = float(cmin - 1)
    wall_col_e = float(cmax + 1)
    for gx in range(cmin - 1, cmax + 2):
        placements.append(WallPlacement(f"Wall_type2_var1_n_{gx}", "wall_b1_n", float(gx), wall_row_n))
        placements.append(WallPlacement(f"Wall_type2_var1_s_{gx}", "wall_b1_s", float(gx), wall_row_s))
    for gy in range(cmin, cmax + 1):
        placements.append(WallPlacement(f"Wall_type2_var1_w_{gy}", "wall_b1_w", wall_col_w, float(gy)))
        placements.append(WallPlacement(f"Wall_type2_var1_e_{gy}", "wall_b1_e", wall_col_e, float(gy)))
    placements.append(WallPlacement("Wall_corner_nw", "wall_b2_n", wall_col_w, wall_row_n))
    placements.append(WallPlacement("Wall_corner_ne", "wall_b2_e", wall_col_e, wall_row_n))
    placements.append(WallPlacement("Wall_corner_sw", "wall_b2_w", wall_col_w, wall_row_s))
    placements.append(WallPlacement("Wall_corner_se", "wall_b2_s", wall_col_e, wall_row_s))
    return placements


def bake_map(w: Writer, map_uid: int, cell_layers: dict[tuple[int, int], dict[str, str]]) -> None:
    ground_anchor = tile_anchor(LAYOUT)
    ground_scale = tile_scale(LAYOUT)
    grass_anchor, grass_scale = ground_anchor, ground_scale
    for gy in range(BASE_GRID_MIN_Y, BASE_GRID_MIN_Y + BASE_GRID_HEIGHT):
        for gx in range(BASE_GRID_MIN_X, BASE_GRID_MIN_X + BASE_GRID_WIDTH):
            wx, wy = grid_to_world(float(gx), float(gy))
            depth = depth_sort_key(float(gx), float(gy))
            tint = (
                GROUND_OUTSIDE_COLOR
                if not in_world(gx, gy)
                else (1.0, 1.0, 1.0, 1.0)
            )
            cell_uid = w.node(f"cell_{gx}_{gy}", map_uid, pos=(wx, wy, 0.0))
            layers = cell_layers.get((gx, gy), {})
            a1_dir = grid_hash(gx * 3 + 1, gy * 5 + 7) % 4

            if "road" in layers:
                road_key = layers["road"]
                w.sprite_child(
                    cell_uid,
                    "road_fill",
                    ground_anchor,
                    ground_scale,
                    road_key,
                    tex_uv_for_key(road_key),
                    depth + DEPTH_TILE_ROAD_BIAS,
                    tint,
                )
            elif "grass" in layers:
                grass_key = layers["grass"]
                w.sprite_child(
                    cell_uid,
                    "grass",
                    grass_anchor,
                    grass_scale,
                    grass_key,
                    tex_uv_for_key(grass_key),
                    depth + DEPTH_TILE_GRASS_BIAS,
                    tint,
                )

            ground_key = layers.get("ground", f"a1_{a1_dir}")
            w.sprite_child(
                cell_uid,
                "ground",
                ground_anchor,
                ground_scale,
                ground_key,
                tex_uv_for_key(ground_key),
                depth,
                tint,
            )


def player_node(w: Writer, parent: int, feet_gx: float, feet_gy: float) -> tuple[float, float]:
    tile_w = PLAYER_SHEET_WIDTH / PLAYER_SHEET_COLS
    tile_h = PLAYER_SHEET_HEIGHT / PLAYER_SHEET_ROWS
    world_w = PLAYER_WORLD_HEIGHT * (tile_w / tile_h)
    uv_x = 0.0
    uv_y = 1.0 - (0 + 1) * (1.0 / PLAYER_SHEET_ROWS)
    uv = (uv_x, uv_y, 1.0 / PLAYER_SHEET_COLS, 1.0 / PLAYER_SHEET_ROWS)
    pos = player_sprite_world_position(feet_gx, feet_gy)
    render_order = depth_sort_entity_from_grid(feet_gx, feet_gy)
    comp = w.sprite_renderer_block(uv, render_order, PLAYER_IDLE_PATH)
    uid = w.next_uid()
    w.lines += [
        "node{",
        'name:t="player"',
        f"uid:i={uid}",
        f"parent:i={parent}",
        f"pos:p3={pos[0]:.6f}, {pos[1]:.6f}, {pos[2]:.6f}",
        f"scl:p3={world_w:.6f}, {PLAYER_WORLD_HEIGHT:.6f}, 1",
        comp,
        "PlayerController{}",
        "}",
    ]
    return pos[0], pos[1]


def main() -> None:
    texture_ref_ids = load_texture_ref_ids()
    w = Writer(texture_ref_ids)
    cell_layers = build_map_cell_layers()
    player_cam_x, player_cam_y = player_sprite_world_position(
        BASE_PLAYER_SPAWN_GRID_X, BASE_PLAYER_SPAWN_GRID_Y
    )[:2]
    root = w.next_uid()
    w.lines = [
        "node{",
        'name:t="base"',
        f"uid:i={root}",
        "PrefabTextureHydrator{}",
        "}",
    ]
    w.uid = root
    cam = w.next_uid()
    w.lines += [
        "node{",
        'name:t="camera"',
        f"uid:i={cam}",
        f"parent:i={root}",
        f"pos:p3={player_cam_x:.6f}, {player_cam_y:.6f}, {CAMERA_Z:.6f}",
        "Camera{",
        "orthographic:b=yes",
        "orthographicSize:r=8",
        "backgroundColor:p3=0.08, 0.1, 0.12",
        "}",
        "}",
    ]
    render = w.next_uid()
    w.lines += [
        "node{",
        'name:t="render_settings"',
        f"uid:i={render}",
        "isRenderSettingsNode:b=yes",
        f"parent:i={root}",
        "ShadowSettings{active:b=yes;shadowStrength:r=1;numCascades:i=3;cascadeWidth:i=1024;maxDist:r=50}",
        "Sky{active:b=yes;isHdr:b=no}",
        "AmbientSettings{ambientColor:p3=0.4,0.4,0.4;ambientStrength:r=1}",
        "AntiAliasing{active:b=yes;mode:i=2}",
        "RenderPipeline{hdrMode:i=1}",
        "}",
    ]
    print("Baking player...")
    player_node(w, root, BASE_PLAYER_SPAWN_GRID_X, BASE_PLAYER_SPAWN_GRID_Y)
    props_uid = w.next_uid()
    w.lines += ["node{", 'name:t="props"', f"uid:i={props_uid}", f"parent:i={root}", "}"]
    walls_uid = w.next_uid()
    w.lines += ["node{", 'name:t="walls"', f"uid:i={walls_uid}", f"parent:i={root}", "}"]

    print("Baking courtyard walls...")
    for placement in courtyard_wall_placements():
        depth = border_wall_render_order(placement.name, placement.feet_gx, placement.feet_gy)
        w.prop_sprite(
            walls_uid,
            placement.name,
            placement.prop_id,
            placement.feet_gx,
            placement.feet_gy,
            render_order=depth,
        )

    map_uid = w.next_uid()
    w.lines += ["node{", 'name:t="map"', f"uid:i={map_uid}", f"parent:i={root}", "}"]
    print("Baking map tiles...")
    bake_map(w, map_uid, cell_layers)

    w.lines.extend(format_res_section(texture_ref_ids, load_path_to_guid()))

    print(f"Writing {OUT} ({len(w.lines)} lines)...")
    OUT.write_text("\n".join(w.lines) + "\n", encoding="utf-8", newline="\n")
    print("Done.")


if __name__ == "__main__":
    main()
