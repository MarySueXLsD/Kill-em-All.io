"""Wall placement — port of props.das spawn_border_walls / spawn_interior_walls."""
from __future__ import annotations

import math
from dataclasses import dataclass

from lib.prefab_node_names import wall_segment_node_name

MAP_WIDTH = 80
GROUND_TILE_WORLD_WIDTH = 1.0
GROUND_DIAMOND_FACE_HEIGHT_PX = 63.0
GROUND_DIAMOND_FACE_WIDTH_PX = 127.0
TILE_EDGE_ANGLE_DEG = math.degrees(
    math.atan(GROUND_DIAMOND_FACE_HEIGHT_PX / GROUND_DIAMOND_FACE_WIDTH_PX)
)
TILE_HALF_WIDTH = GROUND_TILE_WORLD_WIDTH * 0.5
TILE_HALF_HEIGHT = GROUND_TILE_WORLD_WIDTH * 0.5 * math.tan(math.radians(TILE_EDGE_ANGLE_DEG))


def grid_to_world(gx: float, gy: float) -> tuple[float, float]:
    return ((gx - gy) * TILE_HALF_WIDTH, (gx + gy) * TILE_HALF_HEIGHT)

WALL_B1_WORLD_WIDTH = 1.0
WALL_B2_WORLD_WIDTH = 1.0

# (crop, feet_px, world_width, bottom_a, bottom_b, bottom_span_px)
# bottom points omitted for b2 corners (use bottom_px list instead)
_W1 = WALL_B1_WORLD_WIDTH


@dataclass(frozen=True)
class WallSpec:
    prop_id: str
    crop: tuple[float, float, float, float]
    feet_px: tuple[float, float]
    world_w: float
    bottom_a: tuple[float, float] | None = None
    bottom_b: tuple[float, float] | None = None
    bottom_span: float | None = None
    bottom_triple: tuple[tuple[float, float], tuple[float, float], tuple[float, float]] | None = None


WALL_SPECS: dict[str, WallSpec] = {
    "wall_b1_e": WallSpec(
        "wall_b1_e", (0, 0, 100, 155), (50, 155), _W1,
        (19, 144), (90, 109), 79.2,
    ),
    "wall_b1_w": WallSpec(
        "wall_b1_w", (0, 0, 100, 155), (50, 155), _W1,
        (26, 141), (92, 111), 72.5,
    ),
    "wall_b1_n": WallSpec(
        "wall_b1_n", (0, 0, 98, 155), (49, 155), _W1,
        (90, 143), (21, 111), 76.1,
    ),
    "wall_b1_s": WallSpec(
        "wall_b1_s", (0, 0, 100, 155), (50, 155), _W1,
        (90, 143), (22, 110), 75.6,
    ),
    "wall_b2_e": WallSpec(
        "wall_b2_e", (0, 0, 96, 179), (48, 179), WALL_B2_WORLD_WIDTH,
        bottom_triple=((24, 113), (83, 137), (24, 166)),
    ),
    "wall_b2_w": WallSpec(
        "wall_b2_w", (0, 0, 90, 179), (45, 179), WALL_B2_WORLD_WIDTH,
        bottom_triple=((82, 109), (22, 137), (80, 165)),
    ),
    "wall_b2_n": WallSpec(
        "wall_b2_n", (0, 0, 146, 151), (73, 151), WALL_B2_WORLD_WIDTH,
        bottom_triple=((24, 138), (81, 112), (136, 137)),
    ),
    "wall_b2_s": WallSpec(
        "wall_b2_s", (0, 0, 149, 150), (74.5, 150), WALL_B2_WORLD_WIDTH,
        bottom_triple=((22, 111), (82, 140), (139, 109)),
    ),
}


@dataclass
class WallPlacement:
    name: str
    prop_id: str
    feet_gx: float
    feet_gy: float


def crop_wh(crop: tuple[float, float, float, float]) -> tuple[float, float]:
    return crop[2] - crop[0] + 1.0, crop[3] - crop[1] + 1.0


def prop_pixel_to_local(
    px: float, py: float, crop: tuple[float, float, float, float], world_width: float
) -> tuple[float, float]:
    cw, ch = crop_wh(crop)
    sprite_cx = (cw - 1.0) * 0.5
    sprite_cy = (ch - 1.0) * 0.5
    sw = world_width
    sh = world_width * (ch / cw)
    return (
        (px - crop[0] - sprite_cx) * sw / cw,
        (sprite_cy - (py - crop[1])) * sh / ch,
    )


def wall_sprite_point_world_offset(
    px: float, py: float, crop: tuple[float, float, float, float],
    feet_px: tuple[float, float], world_width: float,
) -> tuple[float, float]:
    feet_local = prop_pixel_to_local(feet_px[0], feet_px[1], crop, world_width)
    point_local = prop_pixel_to_local(px, py, crop, world_width)
    return point_local[0] - feet_local[0], point_local[1] - feet_local[1]


def wall_bottom_mid_world_offset(spec: WallSpec) -> tuple[float, float]:
    assert spec.bottom_a is not None and spec.bottom_b is not None
    oa = wall_sprite_point_world_offset(
        spec.bottom_a[0], spec.bottom_a[1], spec.crop, spec.feet_px, spec.world_w
    )
    ob = wall_sprite_point_world_offset(
        spec.bottom_b[0], spec.bottom_b[1], spec.crop, spec.feet_px, spec.world_w
    )
    return (oa[0] + ob[0]) * 0.5, (oa[1] + ob[1]) * 0.5


def wall_bottom_span_world(spec: WallSpec) -> float:
    assert spec.bottom_span is not None
    cw, _ = crop_wh(spec.crop)
    return spec.world_w * (spec.bottom_span / cw)


def world_to_grid(wx: float, wy: float) -> tuple[float, float]:
    return (
        (wx / TILE_HALF_WIDTH + wy / TILE_HALF_HEIGHT) * 0.5,
        (wy / TILE_HALF_HEIGHT - wx / TILE_HALF_WIDTH) * 0.5,
    )


def feet_grid_for_anchor_world_offset(
    anchor_world: tuple[float, float], anchor_offset_from_feet: tuple[float, float]
) -> tuple[float, float]:
    feet_world = (
        anchor_world[0] - anchor_offset_from_feet[0],
        anchor_world[1] - anchor_offset_from_feet[1],
    )
    return world_to_grid(feet_world[0], feet_world[1])


def _edge_placements(
    gx0: float, gy0: float, gx1: float, gy1: float,
    spec_a: WallSpec, spec_b: WallSpec,
    name_prefix: str,
) -> list[WallPlacement]:
    border_start = grid_to_world(gx0, gy0)
    border_end = grid_to_world(gx1, gy1)
    edge_vec = (border_end[0] - border_start[0], border_end[1] - border_start[1])
    edge_len = math.hypot(*edge_vec)
    span_a = wall_bottom_span_world(spec_a)
    span_b = wall_bottom_span_world(spec_b)
    avg_span = (span_a + span_b) * 0.5
    count = max(1, round(edge_len / avg_span))
    mid_a = wall_bottom_mid_world_offset(spec_a)
    mid_b = wall_bottom_mid_world_offset(spec_b)
    out: list[WallPlacement] = []
    for i in range(count):
        t = (float(i) + 0.5) / float(count)
        bottom_mid = (
            border_start[0] + edge_vec[0] * t,
            border_start[1] + edge_vec[1] * t,
        )
        if i % 2 == 0:
            fg = feet_grid_for_anchor_world_offset(bottom_mid, mid_a)
            out.append(
                WallPlacement(
                    wall_segment_node_name(spec_a.prop_id, name_prefix, i),
                    spec_a.prop_id,
                    fg[0],
                    fg[1],
                )
            )
        else:
            fg = feet_grid_for_anchor_world_offset(bottom_mid, mid_b)
            out.append(
                WallPlacement(
                    wall_segment_node_name(spec_b.prop_id, name_prefix, i),
                    spec_b.prop_id,
                    fg[0],
                    fg[1],
                )
            )
    return out


def _corner_placement(
    corner_gx: float, corner_gy: float, spec: WallSpec, name: str
) -> WallPlacement:
    assert spec.bottom_triple is not None
    corner_world = grid_to_world(corner_gx, corner_gy)
    apex = spec.bottom_triple[1]
    apex_offset = wall_sprite_point_world_offset(
        apex[0], apex[1], spec.crop, spec.feet_px, spec.world_w
    )
    fg = feet_grid_for_anchor_world_offset(corner_world, apex_offset)
    return WallPlacement(name, spec.prop_id, fg[0], fg[1])


def generate_border_wall_placements() -> list[WallPlacement]:
    """Border edge sprites only (no corners)."""
    b1e, b1w, b1n, b1s = WALL_SPECS["wall_b1_e"], WALL_SPECS["wall_b1_w"], WALL_SPECS["wall_b1_n"], WALL_SPECS["wall_b1_s"]

    min_g = -0.5
    max_g = float(MAP_WIDTH - 1) + 0.5
    out: list[WallPlacement] = []

    out.extend(_edge_placements(min_g, max_g, min_g, min_g, b1n, b1s, "Wall_edge_lt"))
    out.extend(_edge_placements(max_g, min_g, max_g, max_g, b1s, b1n, "Wall_edge_br"))
    out.extend(_edge_placements(min_g, min_g, max_g, min_g, b1e, b1w, "Wall_edge_tr"))
    out.extend(_edge_placements(max_g, max_g, min_g, max_g, b1w, b1e, "Wall_edge_bl"))
    return out


def generate_interior_wall_placements() -> list[WallPlacement]:
    b1e, b1w, b1n, b1s = WALL_SPECS["wall_b1_e"], WALL_SPECS["wall_b1_w"], WALL_SPECS["wall_b1_n"], WALL_SPECS["wall_b1_s"]
    out: list[WallPlacement] = []
    out.extend(_edge_placements(10.0, 30.0, 22.0, 30.0, b1e, b1w, "interior_wall_w_n"))
    out.extend(_edge_placements(58.0, 30.0, 70.0, 30.0, b1e, b1w, "interior_wall_e_n"))
    out.extend(_edge_placements(25.0, 60.0, 40.0, 60.0, b1w, b1e, "interior_wall_s"))
    out.extend(_edge_placements(10.0, 62.0, 10.0, 50.0, b1n, b1s, "interior_wall_w_v"))
    out.extend(_edge_placements(70.0, 50.0, 70.0, 62.0, b1n, b1s, "interior_wall_e_v"))
    return out


def generate_wall_placements() -> list[WallPlacement]:
    """All border + interior wall sprites (matches props.das spawn_walls_if_missing)."""
    out = generate_border_wall_placements()
    out.extend(generate_interior_wall_placements())
    return out
