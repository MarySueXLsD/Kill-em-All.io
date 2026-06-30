#!/usr/bin/env python3
"""Insert player spawn node into level_1.prefab (editable in Scene view)."""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from lib.resource_link_hash import ref_id_from_meta

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
STATIC = PROJECT / "static"

PLAYER_WORLD_HEIGHT = 4.0
PLAYER_SHEET_WIDTH = 1845.0
PLAYER_SHEET_HEIGHT = 1024.0
PLAYER_SHEET_COLS = 15
PLAYER_SHEET_ROWS = 8
PLAYER_SHEET_FEET_X_PX = 60.0
PLAYER_SHEET_FEET_Y_PX = 89.0
ENTITY_SPRITE_Y_OFFSET_PX = -10.0
GROUND_TILE_WORLD_WIDTH = 1.0
GROUND_DIAMOND_FACE_HEIGHT_PX = 63.0
GROUND_DIAMOND_FACE_WIDTH_PX = 127.0
PLAYER_SPAWN_GRID_X = PLAYER_SPAWN_GRID_Y = 40.0
GRID_WIDTH = GRID_HEIGHT = 96
GRID_MIN_X = GRID_MIN_Y = -(GRID_WIDTH - 80) // 2
DEPTH_ENTITY_LAYER = 1000
DEPTH_TILE_STRIDE = 100
IDLE_PATH = "static/Characters/playable_character_kreol/Idle.png"

TILE_EDGE_ANGLE_DEG = math.degrees(
    math.atan(GROUND_DIAMOND_FACE_HEIGHT_PX / GROUND_DIAMOND_FACE_WIDTH_PX)
)
TILE_HALF_WIDTH = GROUND_TILE_WORLD_WIDTH * 0.5
TILE_HALF_HEIGHT = GROUND_TILE_WORLD_WIDTH * 0.5 * math.tan(math.radians(TILE_EDGE_ANGLE_DEG))

CAMERA_RE = re.compile(
    r'node\{\nname:t="camera"\n.*?^}\n',
    re.DOTALL | re.MULTILINE,
)
PLAYER_RE = re.compile(r'name:t="player"')
PLAYER_NODE_RE = re.compile(
    r'(node\{\nname:t="player"\n.*?TileTextureHint\{texturePath:t=")[^"]+(";\})',
    re.DOTALL,
)


def grid_to_world(gx: float, gy: float) -> tuple[float, float]:
    return ((gx - gy) * TILE_HALF_WIDTH, (gx + gy) * TILE_HALF_HEIGHT)


def player_sprite_layout() -> tuple[tuple[float, float, float, float], tuple[float, float]]:
    tile_w = PLAYER_SHEET_WIDTH / PLAYER_SHEET_COLS
    tile_h = PLAYER_SHEET_HEIGHT / PLAYER_SHEET_ROWS
    world_h = PLAYER_WORLD_HEIGHT
    world_w = world_h * (tile_w / tile_h)
    uv = (0.0, 1.0 - 1.0 / PLAYER_SHEET_ROWS, 1.0 / PLAYER_SHEET_COLS, 1.0 / PLAYER_SHEET_ROWS)
    return uv, (world_w, world_h)


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


def depth_sort_entity(feet_gx: float, feet_gy: float) -> int:
    max_sum = float(GRID_MIN_X + GRID_MIN_Y + GRID_WIDTH + GRID_HEIGHT - 2)
    return DEPTH_ENTITY_LAYER + int((max_sum - (feet_gx + feet_gy)) * DEPTH_TILE_STRIDE)


def format_player_node(uid: int, level_uid: int, texture_id: int) -> str:
    feet = grid_to_world(PLAYER_SPAWN_GRID_X, PLAYER_SPAWN_GRID_Y)
    anchor = player_anchor_offset()
    pos = (feet[0] + anchor[0], feet[1] + anchor[1], 0.1)
    uv, scale = player_sprite_layout()
    depth = depth_sort_entity(PLAYER_SPAWN_GRID_X, PLAYER_SPAWN_GRID_Y)
    return "\n".join([
        "node{",
        'name:t="player"',
        f"uid:i={uid}",
        f"parent:i={level_uid}",
        f"pos:p3={pos[0]:.6f}, {pos[1]:.6f}, {pos[2]:.6f}",
        f"scl:p3={scale[0]:.6f}, {scale[1]:.6f}, 1",
        "SpriteRenderer{",
        f"__textureId:i64={texture_id}",
        "color:p4=1, 1, 1, 1",
        "flipX:b=no",
        "flipY:b=no",
        f"uvRect:p4={uv[0]:.6f}, {uv[1]:.6f}, {uv[2]:.6f}, {uv[3]:.6f}",
        "useTextureSizeForScaling:b=no",
        f"renderOrder:i={depth}",
        "}",
        f'TileTextureHint{{texturePath:t="{IDLE_PATH}";}}',
        "PlayerController{}",
        "}",
    ])


def patch_player_texture(prefab_text: str) -> tuple[str, bool]:
    """Point existing player node at Kreol idle (editor + spawn default sprite)."""
    if not PLAYER_RE.search(prefab_text):
        return prefab_text, False

    def repl(match: re.Match[str]) -> str:
        return f"{match.group(1)}{IDLE_PATH}{match.group(2)}"

    new_text, n = PLAYER_NODE_RE.subn(repl, prefab_text, count=1)
    if n == 0:
        return prefab_text, False
    if new_text == prefab_text:
        return prefab_text, False
    return new_text, True


def patch_player(prefab_text: str) -> tuple[str, bool]:
    if PLAYER_RE.search(prefab_text):
        return prefab_text, False

    cam_m = CAMERA_RE.search(prefab_text)
    if not cam_m:
        raise ValueError("camera node not found in level_1.prefab")

    level_uid = int(re.search(r'name:t="level"\nuid:i=(\d+)', prefab_text).group(1))
    max_uid = max(int(x) for x in re.findall(r"uid:i=(\d+)", prefab_text))
    idle_meta = STATIC / "Characters" / "playable_character_kreol" / "Idle.png.meta"
    texture_id = ref_id_from_meta(idle_meta)
    block = "\n" + format_player_node(max_uid + 1, level_uid, texture_id) + "\n"
    insert_at = cam_m.end()
    return prefab_text[:insert_at] + block + prefab_text[insert_at:], True


def main() -> int:
    if not PREFAB.exists():
        print(f"missing {PREFAB}", file=sys.stderr)
        return 1
    text = PREFAB.read_text(encoding="utf-8")
    text, texture_updated = patch_player_texture(text)
    if texture_updated:
        print("updated player TileTextureHint to Kreol Idle")
    new_text, added = patch_player(text)
    if added:
        text = new_text
        print("inserted player node (move in Scene to change spawn)")
    if texture_updated or added:
        PREFAB.write_text(text, encoding="utf-8", newline="\n")
        print("run: python scripts/python/prefab/hydrate_prefab_texture_ids.py --hydrate-only")
    elif not texture_updated:
        print("player node already present — skipping")
    return 0


if __name__ == "__main__":
    sys.exit(main())
