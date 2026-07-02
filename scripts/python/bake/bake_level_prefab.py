#!/usr/bin/env python3
"""Bake full level_1.prefab with map tiles, walls, and props (prefab-only migration).

After editing level_1.prefab in the editor, run:
  python scripts/python/sync_bake_from_prefab.py
to refresh PROP_MARKERS, MAP_CELL_LAYERS, and border offsets in this file.
"""
from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent.parent
if str(_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(_TOOLS_ROOT))

from lib.environment_texture_names import environment_texture_rel
from lib.grass_overlay import GrassOverlayKind, pick_grass_overlay
from lib.resource_link_hash import ref_id_from_meta
from lib.border_wall_hierarchy import (
    BORDER_WALL_GROUP_OFFSETS,
    COMPASS_BORDER_WALL_GROUPS,
    OUTSIDE_BORDER_WALLS_ROOT,
    compass_group_for_segment_name,
)

PROJECT = Path(__file__).resolve().parents[3]
OUT = PROJECT / "prefabs" / "level_1.prefab"
REF_IDS_JSON = _TOOLS_ROOT / "data" / "texture_ref_ids.json"
ENV = PROJECT / "static" / "Environment"
GUID_RE = re.compile(r'^guid:t="([^"]+)"', re.MULTILINE)
RES_RE = re.compile(
    r"res\{\s*guid:t=\"([^\"]+)\"\s*type:i=\d+\s*refId:i64=(-?\d+)\s*\}",
    re.MULTILINE,
)

# --- grid / map constants (from constants.das) ---
GRID_WIDTH = GRID_HEIGHT = 96
MAP_WIDTH = MAP_HEIGHT = 80
GRID_MIN_X = GRID_MIN_Y = -(GRID_WIDTH - MAP_WIDTH) // 2
PLAYER_SPAWN_GRID_X = PLAYER_SPAWN_GRID_Y = 40.0
PLAYER_IDLE_PATH = "static/Characters/playable_character_kreol/Idle.png"
PLAYER_WORLD_HEIGHT = 4.0
PLAYER_SHEET_WIDTH = 1845.0
PLAYER_SHEET_HEIGHT = 1024.0
PLAYER_SHEET_COLS = 15
PLAYER_SHEET_ROWS = 8
PLAYER_SHEET_FEET_X_PX = 60.0
PLAYER_SHEET_FEET_Y_PX = 89.0
ENTITY_SPRITE_Y_OFFSET_PX = -10.0
CAMERA_Z = -5.0
GROUND_TILE_WORLD_WIDTH = 1.0
GROUND_DIAMOND_FACE_HEIGHT_PX = 63.0
GROUND_DIAMOND_FACE_WIDTH_PX = 127.0
GROUND_CROP_MIN_X, GROUND_CROP_MIN_Y = 0.0, 0.0
GROUND_CROP_MAX_X, GROUND_CROP_MAX_Y = 127.0, 79.0
GROUND_TILE_LAYOUT_CROP = (64.0, 176.0, 191.0, 255.0)
GROUND_OUTSIDE_COLOR = (0.72, 0.72, 0.72, 1.0)
GROUND_GRASS_NOISE_PATCH = 7
GROUND_GRASS_NOISE_THRESHOLD = 0.35
GROUND_SPAWN_GRASS_RADIUS = 10
GROUND_GRASS_MIN_NEIGHBORS = 2
GROUND_A5_CANDIDATE_CHANCE = 0.10
GROUND_A5_MIN_SPACING = 8
GROUND_ROAD_WAVE_AMPLITUDE = 6.0
GROUND_ROAD_WAVE_SCALE = 10.0
GROUND_ROAD_HALF_WIDTH = 2.0
DEPTH_TILE_OVERLAY_BIAS = 1
DEPTH_TILE_GRASS_BIAS = 199  # DEPTH_TILE_STRIDE * 2 - 1
DEPTH_TILE_ROAD_BIAS = 200
DEPTH_TILE_STRIDE = 100
DEPTH_ENTITY_LAYER = 1000
DEPTH_BORDER_WALL_BELOW_BIAS = -50
DEPTH_FOREGROUND_OVERLAY_HEADROOM = 50
TILE_HALF_WIDTH = GROUND_TILE_WORLD_WIDTH * 0.5
TILE_EDGE_ANGLE_DEG = math.degrees(math.atan(GROUND_DIAMOND_FACE_HEIGHT_PX / GROUND_DIAMOND_FACE_WIDTH_PX))
TILE_HALF_HEIGHT = GROUND_TILE_WORLD_WIDTH * 0.5 * math.tan(math.radians(TILE_EDGE_ANGLE_DEG))


def grid_to_world(gx: float, gy: float) -> tuple[float, float]:
    return ((gx - gy) * TILE_HALF_WIDTH, (gx + gy) * TILE_HALF_HEIGHT)


def grid_hash(a: int, b: int) -> int:
    h = a * 92837111 + b * 689287499
    return abs(h)


def depth_sort_key(gx: float, gy: float) -> int:
    max_sum = float(GRID_MIN_X + GRID_MIN_Y + GRID_WIDTH + GRID_HEIGHT - 2)
    return int(max_sum - (gx + gy))


def crop_wh(crop: tuple[float, float, float, float]) -> tuple[float, float]:
    return crop[2] - crop[0] + 1.0, crop[3] - crop[1] + 1.0


def tile_scale(crop: tuple[float, float, float, float]) -> tuple[float, float]:
    _, h = crop_wh(crop)
    diamond_h = GROUND_TILE_WORLD_WIDTH * math.tan(math.radians(TILE_EDGE_ANGLE_DEG))
    return GROUND_TILE_WORLD_WIDTH, diamond_h * (h / GROUND_DIAMOND_FACE_HEIGHT_PX)


def tile_anchor(crop: tuple[float, float, float, float]) -> tuple[float, float]:
    w, h = crop_wh(crop)
    diamond_cx = (0.0 + 127.0) * 0.5
    diamond_cy = (0.0 + 63.0) * 0.5
    sprite_cx = (w - 1.0) * 0.5
    sprite_cy = (h - 1.0) * 0.5
    px_off_x = sprite_cx - diamond_cx
    px_off_y = sprite_cy - diamond_cy
    sw, sh = tile_scale(crop)
    return px_off_x * sw / w, px_off_y * sh / h


def uv_precropped(source_crop: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    w, h = crop_wh(source_crop)
    return 0.0, 0.0, (w - 1.0) / w, (h - 1.0) / h


def uv_layout_in_texture(layout_crop, texture_crop) -> tuple[float, float, float, float]:
    tw, th = crop_wh(texture_crop)
    lx0 = layout_crop[0] - texture_crop[0]
    ly0 = layout_crop[1] - texture_crop[1]
    lx1 = layout_crop[2] - texture_crop[0]
    ly1 = layout_crop[3] - texture_crop[1]
    return lx0 / tw, ly0 / th, lx1 / tw, ly1 / th


def uv_rect_from_crop(
    min_x: float,
    min_y: float,
    max_x: float,
    max_y: float,
    tex_w: float,
    tex_h: float,
) -> tuple[float, float, float, float]:
    """Match iso_math.das uv_rect_from_crop (u, v, width, height; image Y-down)."""
    width = max_x - min_x + 1.0
    height = max_y - min_y + 1.0
    uv_y = 1.0 - (max_y + 1.0) / tex_h
    return min_x / tex_w, uv_y, width / tex_w, height / tex_h


def tile_uv_rect_for_layout_in_texture(
    layout_crop: tuple[float, float, float, float],
    texture_crop: tuple[float, float, float, float],
) -> tuple[float, float, float, float]:
    """Match world.das tile_uv_rect_for_layout_in_texture."""
    tw, th = crop_wh(texture_crop)
    lx0 = layout_crop[0] - texture_crop[0]
    ly0 = layout_crop[1] - texture_crop[1]
    lx1 = layout_crop[2] - texture_crop[0]
    ly1 = layout_crop[3] - texture_crop[1]
    return uv_rect_from_crop(lx0, ly0, lx1, ly1, tw, th)


# Pre-cropped diamond bounds used for tile scale/anchor (matches GROUND_CROP_* in constants.das).
LAYOUT = (GROUND_CROP_MIN_X, GROUND_CROP_MIN_Y, GROUND_CROP_MAX_X, GROUND_CROP_MAX_Y)
# Layout window in original 256x256 tex space — required for grass/fringe UV into pre-cropped A2 sheets.
TILE_LAYOUT = GROUND_TILE_LAYOUT_CROP

def _load_map_cell_layers() -> dict[tuple[int, int], dict[str, str]]:
    from lib.map_layers_io import load_map_layers

    raw = load_map_layers(_TOOLS_ROOT / "data")
    out: dict[tuple[int, int], dict[str, str]] = {}
    for key, layers in raw.items():
        gx, gy = key.strip("()").split(",")
        out[(int(gx), int(gy))] = layers
    return out


def _load_prop_crops() -> dict[str, tuple]:
    path = _TOOLS_ROOT / "data" / "level_1_prop_crops.json"
    raw = json.loads(path.read_text(encoding="utf-8"))
    out: dict[str, tuple] = {}
    for prop_id, spec in raw.items():
        crop = tuple(spec[0])
        feet = tuple(spec[1])
        width = spec[2]
        out[prop_id] = (crop, feet, width)
    return out


def _load_prop_markers() -> list[tuple]:
    path = _TOOLS_ROOT / "data" / "level_1_prop_markers.json"
    return [tuple(x) for x in json.loads(path.read_text(encoding="utf-8"))]


MAP_CELL_LAYERS = _load_map_cell_layers()
PROP_CROPS = _load_prop_crops()
PROP_MARKERS = _load_prop_markers()

A1_CROPS = [(64.0, 176.0, 191.0, 255.0)] * 4
A2_CROPS = [
    (61.0, 171.0, 192.0, 241.0),
    (61.0, 171.0, 193.0, 241.0),
    (63.0, 169.0, 193.0, 241.0),
    (63.0, 171.0, 193.0, 241.0),
]
A3_CROPS = [TILE_LAYOUT] * 4
A4_CROPS = [TILE_LAYOUT] * 4
A5_CROPS = list(A2_CROPS)

ROAD_CROPS = [
    (68.0, 179.0, 187.0, 238.0),
    (70.0, 178.0, 189.0, 238.0),
    (66.0, 178.0, 185.0, 237.0),
    (68.0, 176.0, 187.0, 236.0),
]

TEXTURE_PATHS = {
    "a1": [environment_texture_rel("Ground", "A", 1, d) for d in "ENSW"],
    "a2": [environment_texture_rel("Ground", "A", 2, d) for d in "ENSW"],
    "a3": [environment_texture_rel("Ground", "A", 3, d) for d in "ENSW"],
    "a4": [environment_texture_rel("Ground", "A", 4, d) for d in "ENSW"],
    "a5": [environment_texture_rel("Ground", "A", 5, d) for d in "ENSW"],
    "road": [environment_texture_rel("Ground", "E", 1, d) for d in "ENSW"],
    "misc_b12_e": ["static/Environment/Misc/Type_2_Variation_12_East.png"],
    "misc_b5_e": ["static/Environment/Misc/Type_2_Variation_5_East.png"],
    "misc_b10_e": ["static/Environment/Misc/Type_2_Variation_10_East.png"],
    "misc_b8_e": ["static/Environment/Misc/Type_2_Variation_8_East.png"],
    "misc_b25_e": ["static/Environment/Misc/Type_2_Variation_25_East.png"],
    "misc_b3_e": ["static/Environment/Misc/Type_2_Variation_3_East.png"],
    "misc_b14_e": ["static/Environment/Misc/Type_2_Variation_14_East.png"],
    "misc_b11_e": ["static/Environment/Misc/Type_2_Variation_11_East.png"],
    "misc_b2_e": ["static/Environment/Misc/Type_2_Variation_2_East.png"],
    "misc_b7_e": ["static/Environment/Misc/Type_2_Variation_7_East.png"],
    "misc_b9_e": ["static/Environment/Misc/Type_2_Variation_9_East.png"],
    "misc_b40_e": ["static/Environment/Misc/Type_2_Variation_40_East.png"],
    "misc_b20_e": ["static/Environment/Misc/Type_2_Variation_20_East.png"],
    "misc_b1_e": ["static/Environment/Misc/Type_2_Variation_1_East.png"],
    "wall_b1_e": ["static/Environment/Wall/Type_2_Variation_1_East.png"],
    "wall_b1_w": ["static/Environment/Wall/Type_2_Variation_1_West.png"],
    "wall_b1_n": ["static/Environment/Wall/Type_2_Variation_1_North.png"],
    "wall_b1_s": ["static/Environment/Wall/Type_2_Variation_1_South.png"],
    "wall_b2_e": ["static/Environment/Wall/Type_2_Variation_2_East.png"],
    "wall_b2_w": ["static/Environment/Wall/Type_2_Variation_2_West.png"],
    "wall_b2_n": ["static/Environment/Wall/Type_2_Variation_2_North.png"],
    "wall_b2_s": ["static/Environment/Wall/Type_2_Variation_2_South.png"],
}

PATHS: dict[str, str] = {}
for key, paths in TEXTURE_PATHS.items():
    if len(paths) == 1:
        PATHS[key] = paths[0]
    else:
        for i, path in enumerate(paths):
            PATHS[f"{key}_{i}"] = path

def load_path_to_guid() -> dict[str, str]:
    out: dict[str, str] = {}
    for meta in (PROJECT / "static").rglob("*.png.meta"):
        rel = meta.relative_to(PROJECT / "static").as_posix()
        path = f"static/{rel[:-5]}"
        m = GUID_RE.search(meta.read_text(encoding="utf-8"))
        if m:
            out[path] = m.group(1)
    return out


def uv_rect_from_tile(col: int, row: int, cols: int, rows: int) -> tuple[float, float, float, float]:
    tile_w = 1.0 / cols
    tile_h = 1.0 / rows
    uv_x = col * tile_w
    uv_y = 1.0 - (row + 1) * tile_h
    return uv_x, uv_y, tile_w, tile_h


def player_sprite_layout(row: int = 0, col: int = 0) -> tuple[float, float, tuple[float, float, float, float]]:
    tile_w = PLAYER_SHEET_WIDTH / PLAYER_SHEET_COLS
    tile_h = PLAYER_SHEET_HEIGHT / PLAYER_SHEET_ROWS
    world_w = PLAYER_WORLD_HEIGHT * (tile_w / tile_h)
    uv = uv_rect_from_tile(col, row, PLAYER_SHEET_COLS, PLAYER_SHEET_ROWS)
    return world_w, PLAYER_WORLD_HEIGHT, uv


def player_anchor_offset() -> tuple[float, float]:
    tile_w = PLAYER_SHEET_WIDTH / PLAYER_SHEET_COLS
    tile_h = PLAYER_SHEET_HEIGHT / PLAYER_SHEET_ROWS
    world_w = PLAYER_WORLD_HEIGHT * (tile_w / tile_h)
    px_to_world_x = world_w / tile_w
    px_to_world_y = PLAYER_WORLD_HEIGHT / tile_h
    return (
        (PLAYER_SHEET_FEET_X_PX - tile_w * 0.5) * px_to_world_x,
        (PLAYER_SHEET_FEET_Y_PX - tile_h * 0.5 + ENTITY_SPRITE_Y_OFFSET_PX) * px_to_world_y,
    )


def player_sprite_world_position(feet_gx: float, feet_gy: float) -> tuple[float, float, float]:
    feet_wx, feet_wy = grid_to_world(feet_gx, feet_gy)
    anchor = player_anchor_offset()
    return feet_wx + anchor[0], feet_wy + anchor[1], 0.1


def load_texture_ref_ids() -> dict[str, int]:
    if REF_IDS_JSON.exists():
        data = json.loads(REF_IDS_JSON.read_text(encoding="utf-8"))
        cached = {str(k): int(v) for k, v in data.items()}
        if cached:
            return cached
    out: dict[str, int] = {}
    for meta in (PROJECT / "static").rglob("*.png.meta"):
        rel = meta.relative_to(PROJECT / "static").as_posix()
        path = f"static/{rel[:-5]}"
        out[path] = ref_id_from_meta(meta)
    return out


def format_res_section(path_to_refid: dict[str, int], path_to_guid: dict[str, str]) -> list[str]:
    guid_to_ref = {path_to_guid[p]: r for p, r in path_to_refid.items() if p in path_to_guid}
    lines: list[str] = []
    for guid in sorted(guid_to_ref):
        lines += [
            "res{",
            f'guid:t="{guid}"',
            "type:i=2",
            f"refId:i64={guid_to_ref[guid]}",
            "}",
        ]
    return lines


WALL_CROPS = {
    "wall_b1_e": ((0, 0, 100, 155), (50, 155), 1.0),
    "wall_b1_w": ((0, 0, 100, 155), (50, 155), 1.0),
    "wall_b1_n": ((0, 0, 98, 155), (49, 155), 1.0),
    "wall_b1_s": ((0, 0, 100, 155), (50, 155), 1.0),
    "wall_b2_e": ((0, 0, 96, 179), (48, 179), 1.0),
    "wall_b2_w": ((0, 0, 90, 179), (45, 179), 1.0),
    "wall_b2_n": ((0, 0, 146, 151), (73, 151), 1.0),
    "wall_b2_s": ((0, 0, 149, 150), (74.5, 150), 1.0),
}


class Writer:
    def __init__(self, texture_ref_ids: dict[str, int] | None = None) -> None:
        self.lines: list[str] = []
        self.uid = 100000
        self.texture_ref_ids = texture_ref_ids or {}

    def next_uid(self) -> int:
        self.uid += 1
        return self.uid

    def node(self, name: str, parent: int, pos=None, scale=None, extra: str = "") -> int:
        uid = self.next_uid()
        self.lines.append("node{")
        self.lines.append(f'name:t="{name}"')
        self.lines.append(f"uid:i={uid}")
        self.lines.append(f"parent:i={parent}")
        if pos is not None:
            self.lines.append(f"pos:p3={pos[0]:.6f}, {pos[1]:.6f}, {pos[2]:.6f}")
        if scale is not None:
            self.lines.append(f"scl:p3={scale[0]:.6f}, {scale[1]:.6f}, {scale[2]:.6f}")
        if extra:
            self.lines.append(extra)
        self.lines.append("}")
        return uid

    def sprite_renderer_block(
        self,
        uv: tuple[float, float, float, float],
        render_order: int,
        texture_path: str,
        color=(1.0, 1.0, 1.0, 1.0),
    ) -> str:
        ref_id = self.texture_ref_ids.get(texture_path, 0)
        uv_s = f"uvRect:p4={uv[0]:.6f}, {uv[1]:.6f}, {uv[2]:.6f}, {uv[3]:.6f}"
        return "\n".join([
            "SpriteRenderer{",
            f"__textureId:i64={ref_id}",
            f"color:p4={color[0]:.6f}, {color[1]:.6f}, {color[2]:.6f}, {color[3]:.6f}",
            "flipX:b=no",
            "flipY:b=no",
            uv_s,
            "useTextureSizeForScaling:b=no",
            f"renderOrder:i={render_order}",
            "}",
            f'TileTextureHint{{texturePath:t="{texture_path}";}}',
        ])

    def sprite_child(
        self,
        parent: int,
        name: str,
        local_pos: tuple[float, float],
        local_scale: tuple[float, float],
        tex_key: str,
        uv: tuple[float, float, float, float],
        render_order: int,
        color=(1.0, 1.0, 1.0, 1.0),
    ) -> None:
        comp = self.sprite_renderer_block(uv, render_order, PATHS[tex_key], color)
        self.node(
            name,
            parent,
            pos=(local_pos[0], local_pos[1], 0.0),
            scale=(local_scale[0], local_scale[1], 1.0),
            extra=comp,
        )

    def player_node(
        self,
        parent: int,
        feet_gx: float,
        feet_gy: float,
    ) -> tuple[float, float]:
        world_w, world_h, uv = player_sprite_layout()
        pos = player_sprite_world_position(feet_gx, feet_gy)
        render_order = depth_sort_entity_from_grid(feet_gx, feet_gy)
        comp = self.sprite_renderer_block(uv, render_order, PLAYER_IDLE_PATH)
        uid = self.next_uid()
        self.lines += [
            "node{",
            'name:t="player"',
            f"uid:i={uid}",
            f"parent:i={parent}",
            f"pos:p3={pos[0]:.6f}, {pos[1]:.6f}, {pos[2]:.6f}",
            f"scl:p3={world_w:.6f}, {world_h:.6f}, 1",
            comp,
            "PlayerController{}",
            "}",
        ]
        return pos[0], pos[1]

    def prop_sprite(
        self,
        parent: int,
        name: str,
        prop_id: str,
        feet_gx: float,
        feet_gy: float,
        render_order: int | None = None,
    ) -> None:
        crop_data = PROP_CROPS.get(prop_id) or WALL_CROPS.get(prop_id)
        if crop_data is None:
            raise KeyError(f"unknown prop_id: {prop_id}")
        crop, feet_px, world_w = crop_data
        cw, ch = crop_wh(crop)
        feet_wx, feet_wy = grid_to_world(feet_gx, feet_gy)
        sw = world_w
        sh = world_w * (ch / cw)
        sprite_cx = (cw - 1) * 0.5
        sprite_cy = (ch - 1) * 0.5
        px_off_x = sprite_cx - feet_px[0]
        px_off_y = sprite_cy - feet_px[1]
        pos_x = feet_wx + px_off_x * sw / cw
        pos_y = feet_wy + px_off_y * sh / ch
        if render_order is None:
            render_order = depth_sort_entity_from_grid(feet_gx, feet_gy)
        path = PATHS[prop_id]
        comp = self.sprite_renderer_block((0.0, 0.0, 1.0, 1.0), render_order, path)
        comp += f'\nPropFootprint{{propId:t="{prop_id}";}}'
        self.node(name, parent, pos=(pos_x, pos_y, 0.0), scale=(sw, sh, 1.0), extra=comp)


def grass_noise(gx: int, gy: int) -> float:
    cx = gx // GROUND_GRASS_NOISE_PATCH
    cy = gy // GROUND_GRASS_NOISE_PATCH
    return float(grid_hash(cx, cy) % 1000) / 1000.0


def generate_grass_mask() -> list[bool]:
    cells = [[False] * MAP_WIDTH for _ in range(MAP_HEIGHT)]
    for gy in range(MAP_HEIGHT):
        for gx in range(MAP_WIDTH):
            spawn_dx = abs(float(gx) - PLAYER_SPAWN_GRID_X)
            spawn_dy = abs(float(gy) - PLAYER_SPAWN_GRID_Y)
            if spawn_dx <= GROUND_SPAWN_GRASS_RADIUS and spawn_dy <= GROUND_SPAWN_GRASS_RADIUS:
                cells[gy][gx] = True
            else:
                cells[gy][gx] = grass_noise(gx, gy) >= GROUND_GRASS_NOISE_THRESHOLD
    for gy in range(MAP_HEIGHT):
        for gx in range(MAP_WIDTH):
            if not cells[gy][gx]:
                continue
            spawn_dx = abs(float(gx) - PLAYER_SPAWN_GRID_X)
            spawn_dy = abs(float(gy) - PLAYER_SPAWN_GRID_Y)
            if spawn_dx <= GROUND_SPAWN_GRASS_RADIUS and spawn_dy <= GROUND_SPAWN_GRASS_RADIUS:
                continue
            n = sum(
                1
                for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))
                if 0 <= gx + dx < MAP_WIDTH
                and 0 <= gy + dy < MAP_HEIGHT
                and cells[gy + dy][gx + dx]
            )
            if n < GROUND_GRASS_MIN_NEIGHBORS:
                cells[gy][gx] = False
    return [cells[gy][gx] for gy in range(MAP_HEIGHT) for gx in range(MAP_WIDTH)]


def on_vertical_road(gx: int, gy: int) -> bool:
    diff = float(gx - gy)
    wave = math.sin((gx + gy) / GROUND_ROAD_WAVE_SCALE) * GROUND_ROAD_WAVE_AMPLITUDE
    return abs(diff - wave) <= GROUND_ROAD_HALF_WIDTH


def on_horizontal_road(gx: int, gy: int) -> bool:
    s = float(gx + gy)
    center = float(MAP_WIDTH + MAP_HEIGHT - 2) * 0.5
    wave = math.sin((gx - gy) / GROUND_ROAD_WAVE_SCALE) * GROUND_ROAD_WAVE_AMPLITUDE
    return abs(s - center - wave) <= GROUND_ROAD_HALF_WIDTH


def generate_road_mask() -> list[bool]:
    return [
        on_vertical_road(gx, gy) or on_horizontal_road(gx, gy)
        for gy in range(MAP_HEIGHT)
        for gx in range(MAP_WIDTH)
    ]


def is_grass_cell(gx: int, gy: int, grass: list[bool]) -> bool:
    if gx < 0 or gy < 0 or gx >= MAP_WIDTH or gy >= MAP_HEIGHT:
        return grass_noise(gx, gy) >= GROUND_GRASS_NOISE_THRESHOLD
    return grass[gy * MAP_WIDTH + gx]


def is_road_cell(gx: int, gy: int, roads: list[bool]) -> bool:
    if gx < 0 or gy < 0 or gx >= MAP_WIDTH or gy >= MAP_HEIGHT:
        return False
    return roads[gy * MAP_WIDTH + gx]


def overlay_texture(overlay) -> tuple[str, tuple[float, float, float, float]] | None:
    d = overlay.dir
    if overlay.kind == GrassOverlayKind.INTERIOR:
        return f"a2_{d}", A2_CROPS[d]
    if overlay.kind == GrassOverlayKind.EDGE:
        return f"a3_{d}", A3_CROPS[d]
    if overlay.kind == GrassOverlayKind.CORNER:
        return f"a4_{d}", A4_CROPS[d]
    return None


def tex_uv_for_key(tex_key: str) -> tuple[float, float, float, float]:
  """UV rect for a baked tile texture key (a1_0, a3_2, road_1, ...)."""
  family, dir_s = tex_key.rsplit("_", 1)
  d = int(dir_s)
  if family == "a1":
    return uv_precropped(A1_CROPS[d])
  if family == "road":
    return uv_precropped(ROAD_CROPS[d])
  if family == "a2":
    return tile_uv_rect_for_layout_in_texture(TILE_LAYOUT, A2_CROPS[d])
  if family == "a5":
    return tile_uv_rect_for_layout_in_texture(TILE_LAYOUT, A5_CROPS[d])
  if family == "a3":
    return tile_uv_rect_for_layout_in_texture(TILE_LAYOUT, A3_CROPS[d])
  if family == "a4":
    return tile_uv_rect_for_layout_in_texture(TILE_LAYOUT, A4_CROPS[d])
  raise KeyError(tex_key)


def bake_map(w: Writer, map_uid: int, grass: list[bool], roads: list[bool]) -> None:
    # Eden prefab editor picks the lowest node uid among overlapping sprites (not renderOrder).
    # Bake back layers last within each cell so they get higher uids and lose selection.
    # MAP_CELL_LAYERS is synced from level_1.prefab via scripts/python/prefab/sync_bake_from_prefab.py.
    del grass, roads
    ground_anchor = tile_anchor(LAYOUT)
    ground_scale = tile_scale(LAYOUT)
    grass_anchor, grass_scale = ground_anchor, ground_scale
    for gy in range(GRID_MIN_Y, GRID_MIN_Y + GRID_HEIGHT):
        for gx in range(GRID_MIN_X, GRID_MIN_X + GRID_WIDTH):
            wx, wy = grid_to_world(float(gx), float(gy))
            depth = depth_sort_key(float(gx), float(gy))
            tint = GROUND_OUTSIDE_COLOR if gx < 0 or gy < 0 or gx >= MAP_WIDTH or gy >= MAP_HEIGHT else (1, 1, 1, 1)
            cell_uid = w.node(f"cell_{gx}_{gy}", map_uid, pos=(wx, wy, 0.0))
            layers = MAP_CELL_LAYERS.get((gx, gy), {})
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


def depth_sort_key(gx: float, gy: float) -> int:
    max_sum = float(GRID_MIN_X + GRID_MIN_Y + GRID_WIDTH + GRID_HEIGHT - 2)
    return int(max_sum - (gx + gy))


def depth_sort_entity_from_grid(feet_gx: float, feet_gy: float) -> int:
    min_sum = float(GRID_MIN_X + GRID_MIN_Y)
    return DEPTH_ENTITY_LAYER + int(((feet_gx + feet_gy) - min_sum) * DEPTH_TILE_STRIDE)


def depth_sort_foreground_overlay_order() -> int:
    min_sum = float(GRID_MIN_X + GRID_MIN_Y)
    max_sum = float(GRID_MIN_X + GRID_MIN_Y + GRID_WIDTH + GRID_HEIGHT - 2)
    return (
        DEPTH_ENTITY_LAYER
        + int((max_sum - min_sum) * DEPTH_TILE_STRIDE)
        + DEPTH_FOREGROUND_OVERLAY_HEADROOM
    )


def border_wall_render_order(sprite_name: str, feet_gx: float, feet_gy: float) -> int:
    """Match props.das border_wall_render_order_for_name."""
    entity_depth = depth_sort_entity_from_grid(feet_gx, feet_gy)
    if "_lt_" in sprite_name or "_tr_" in sprite_name or sprite_name in (
        "Wall_corner_n",
        "Wall_corner_e",
    ):
        return depth_sort_foreground_overlay_order() + depth_sort_key(feet_gx, feet_gy)
    if "_bl_" in sprite_name or "_br_" in sprite_name or sprite_name in (
        "Wall_corner_s",
        "Wall_corner_w",
    ):
        return entity_depth + DEPTH_BORDER_WALL_BELOW_BIAS
    return entity_depth


def resolve_wall_parent_uid(
    walls_uid: int, group_uids: dict[str, int], sprite_name: str
) -> int:
    group = compass_group_for_segment_name(sprite_name)
    if group is not None:
        return group_uids[group]
    return walls_uid


def border_wall_group_for_name(sprite_name: str) -> str | None:
    return compass_group_for_segment_name(sprite_name)


def feet_grid_with_border_group_offset(
    feet_gx: float, feet_gy: float, sprite_name: str
) -> tuple[float, float]:
    from lib.wall_placement import world_to_grid

    group = border_wall_group_for_name(sprite_name)
    if group is None:
        return feet_gx, feet_gy
    off = BORDER_WALL_GROUP_OFFSETS.get(group, (0.0, 0.0, 0.0))
    feet_wx, feet_wy = grid_to_world(feet_gx, feet_gy)
    return world_to_grid(feet_wx + off[0], feet_wy + off[1])


def main() -> None:
    texture_ref_ids = load_texture_ref_ids()
    w = Writer(texture_ref_ids)
    player_cam_x, player_cam_y = player_sprite_world_position(
        PLAYER_SPAWN_GRID_X, PLAYER_SPAWN_GRID_Y
    )[:2]
    root = w.next_uid()
    w.lines = [
        "node{",
        'name:t="level_1"',
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
    w.player_node(root, PLAYER_SPAWN_GRID_X, PLAYER_SPAWN_GRID_Y)
    props_uid = w.next_uid()
    w.lines += ["node{", 'name:t="props"', f"uid:i={props_uid}", f"parent:i={root}", "}"]
    walls_uid = w.next_uid()
    w.lines += ["node{", 'name:t="walls"', f"uid:i={walls_uid}", f"parent:i={root}", "}"]
    map_uid = w.next_uid()
    w.lines += ["node{", 'name:t="map"', f"uid:i={map_uid}", f"parent:i={root}", "}"]

    grass = generate_grass_mask()
    roads = generate_road_mask()

    print("Baking props...")
    prop_stem_counts: dict[str, int] = {}
    for i, (prop_id, gx, gy) in enumerate(PROP_MARKERS):
        tex = PATHS[prop_id][0]
        from lib.prefab_node_names import node_name_from_prop_texture

        stem = node_name_from_prop_texture(prop_id, tex, i)
        count = prop_stem_counts.get(stem, 0) + 1
        prop_stem_counts[stem] = count
        node_name = stem if count == 1 else f"{stem}_{count}"
        w.prop_sprite(props_uid, node_name, prop_id, gx, gy)

    print("Baking walls...")
    from lib.wall_placement import generate_wall_placements

    wall_group_uids: dict[str, int] = {}
    outside_uid = w.next_uid()
    w.lines += [
        "node{",
        f'name:t="{OUTSIDE_BORDER_WALLS_ROOT}"',
        f"uid:i={outside_uid}",
        f"parent:i={walls_uid}",
        "}",
    ]
    for group in COMPASS_BORDER_WALL_GROUPS:
        group_uid = w.next_uid()
        wall_group_uids[group] = group_uid
        off = BORDER_WALL_GROUP_OFFSETS.get(group, (0.0, 0.0, 0.0))
        w.lines += [
            "node{",
            f'name:t="{group}"',
            f"uid:i={group_uid}",
            f"parent:i={outside_uid}",
            f"pos:p3={off[0]:.6f}, {off[1]:.6f}, {off[2]:.6f}",
            "}",
        ]

    for placement in generate_wall_placements():
        parent_uid = resolve_wall_parent_uid(walls_uid, wall_group_uids, placement.name)
        feet_gx, feet_gy = feet_grid_with_border_group_offset(
            placement.feet_gx, placement.feet_gy, placement.name
        )
        depth = border_wall_render_order(placement.name, feet_gx, feet_gy)
        w.prop_sprite(
            parent_uid,
            placement.name,
            placement.prop_id,
            placement.feet_gx,
            placement.feet_gy,
            render_order=depth,
        )

    print("Baking map tiles...")
    bake_map(w, map_uid, grass, roads)

    w.lines.extend(format_res_section(texture_ref_ids, load_path_to_guid()))

    print(f"Writing {OUT} ({len(w.lines)} lines)...")
    OUT.write_text("\n".join(w.lines) + "\n", encoding="utf-8", newline="\n")
    mapped = sum(1 for p in PATHS.values() if p in texture_ref_ids)
    print(
        f"Done. __textureId set for {mapped}/{len(set(PATHS.values()))} texture paths "
        f"({len(texture_ref_ids)} known refIds). "
        "Run scripts/python/prefab/hydrate_prefab_texture_ids.py after assigning missing textures in editor."
    )


if __name__ == "__main__":
    main()
