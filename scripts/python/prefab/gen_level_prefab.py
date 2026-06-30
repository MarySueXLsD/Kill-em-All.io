"""Deprecated: use scripts/python/bake/bake_level_prefab.py for full level bake."""
import math
from pathlib import Path

PI = math.pi
MAP_CENTER_GX = 40.0
MAP_CENTER_GY = 40.0
CAMERA_Z = -5.0
GROUND_TILE_WORLD_WIDTH = 1.0
GROUND_TILE_EDGE_ANGLE_DEG = math.degrees(math.atan(63.0 / 127.0))
TILE_HALF_WIDTH = GROUND_TILE_WORLD_WIDTH * 0.5
tile_half_height = GROUND_TILE_WORLD_WIDTH * 0.5 * math.tan(GROUND_TILE_EDGE_ANGLE_DEG * PI / 180.0)


def grid_to_world(gx, gy):
    return ((gx - gy) * TILE_HALF_WIDTH, (gx + gy) * tile_half_height)


markers = [
    ("misc_b12_e", 40.18, 40.78),
    ("misc_b12_e", 52.28, 52.18),
    ("misc_b5_e", 28.35, 58.22),
    ("misc_b5_e", 48.22, 65.18),
    ("misc_b5_e", 18.55, 62.28),
    ("misc_b10_e", 58.12, 25.35),
    ("misc_b10_e", 32.18, 28.35),
    ("misc_b8_e", 20.42, 40.15),
    ("misc_b8_e", 10.35, 35.22),
    ("misc_b8_e", 70.18, 35.28),
    ("misc_b25_e", 60.18, 40.28),
    ("misc_b3_e", 15.28, 18.35),
    ("misc_b14_e", 12.35, 52.18),
    ("misc_b14_e", 55.55, 58.12),
    ("misc_b11_e", 65.22, 22.18),
    ("misc_b2_e", 42.22, 18.35),
    ("misc_b7_e", 38.18, 62.22),
    ("misc_b9_e", 62.35, 48.22),
    ("misc_b40_e", 35.55, 12.18),
    ("misc_b20_e", 72.22, 62.18),
    ("misc_b1_e", 22.35, 28.42),
]

cam_wx, cam_wy = grid_to_world(MAP_CENTER_GX, MAP_CENTER_GY)

uid_root = 100001
uid_camera = 100002
uid_render = 100003
uid_map = 100004
uid_props = 100005

lines = [
    "node{",
    'name:t="level"',
    f"uid:i={uid_root}",
    "}",
    "node{",
    'name:t="camera"',
    f"uid:i={uid_camera}",
    f"parent:i={uid_root}",
    f"pos:p3={cam_wx:.6f}, {cam_wy:.6f}, {CAMERA_Z}",
    "Camera{",
    "orthographic:b=yes",
    "orthographicSize:r=8",
    "backgroundColor:p3=0.08, 0.1, 0.12",
    "}",
    "}",
    "node{",
    'name:t="render_settings"',
    f"uid:i={uid_render}",
    "isRenderSettingsNode:b=yes",
    f"parent:i={uid_root}",
    "ShadowSettings{",
    "active:b=yes",
    "shadowStrength:r=1",
    "numCascades:i=3",
    "cascadeWidth:i=1024",
    "maxDist:r=50",
    "}",
    "Sky{",
    "active:b=yes",
    "isHdr:b=no",
    "}",
    "AmbientSettings{",
    "ambientColor:p3=0.4, 0.4, 0.4",
    "ambientStrength:r=1",
    "}",
    "AntiAliasing{",
    "active:b=yes",
    "mode:i=2",
    "}",
    "RenderPipeline{",
    "hdrMode:i=1",
    "}",
    "}",
    "node{",
    'name:t="map"',
    f"uid:i={uid_map}",
    f"parent:i={uid_root}",
    "}",
    "node{",
    'name:t="props"',
    f"uid:i={uid_props}",
    f"parent:i={uid_root}",
    "}",
]

uid = 200000
for i, (prop_id, gx, gy) in enumerate(markers):
    wx, wy = grid_to_world(gx, gy)
    uid += 1
    lines += [
        "node{",
        f'name:t="{prop_id}_{i}"',
        f"uid:i={uid}",
        f"parent:i={uid_props}",
        f"pos:p3={wx:.6f}, {wy:.6f}, 0",
        "PropMarker{",
        f'propId:t="{prop_id}"',
        "}",
        "}",
    ]

out = Path(__file__).resolve().parents[3] / "prefabs" / "level_1.prefab"
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
print(f"Wrote {out} with camera, render_settings, map, props, and {len(markers)} markers")
