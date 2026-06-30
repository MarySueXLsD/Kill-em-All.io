"""Grass overlay picking (interior A2, edge A3, corner A4) — port of world.das."""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, auto

GRID_MIN_X = GRID_MIN_Y = -(96 - 80) // 2
GRID_WIDTH = GRID_HEIGHT = 96
MAP_WIDTH = MAP_HEIGHT = 80
GROUND_GRASS_NOISE_PATCH = 7
GROUND_GRASS_NOISE_THRESHOLD = 0.35


class GrassOverlayKind(Enum):
    NONE = auto()
    INTERIOR = auto()
    EDGE = auto()
    CORNER = auto()


@dataclass(frozen=True)
class GrassOverlayChoice:
    kind: GrassOverlayKind
    dir: int


def grid_hash(a: int, b: int) -> int:
    return abs(a * 92837111 + b * 689287499)


def grass_noise(gx: int, gy: int) -> float:
    cx = gx // GROUND_GRASS_NOISE_PATCH
    cy = gy // GROUND_GRASS_NOISE_PATCH
    return float(grid_hash(cx, cy) % 1000) / 1000.0


def is_grass_cell(gx: int, gy: int, grass: list[bool]) -> bool:
    if gx < 0 or gy < 0 or gx >= MAP_WIDTH or gy >= MAP_HEIGHT:
        return grass_noise(gx, gy) >= GROUND_GRASS_NOISE_THRESHOLD
    return grass[gy * MAP_WIDTH + gx]


def mud_neighbor(gx: int, gy: int, dgx: int, dgy: int, grass: list[bool]) -> bool:
    nx = gx + dgx
    ny = gy + dgy
    if (
        nx < GRID_MIN_X
        or ny < GRID_MIN_Y
        or nx >= GRID_MIN_X + GRID_WIDTH
        or ny >= GRID_MIN_Y + GRID_HEIGHT
    ):
        return True
    return not is_grass_cell(nx, ny, grass)


def pick_interior_grass_direction(gx: int, gy: int) -> int:
    cx = gx // GROUND_GRASS_NOISE_PATCH
    cy = gy // GROUND_GRASS_NOISE_PATCH
    return grid_hash(cx, cy) % 4


def mud_screen_offset(dgx: int, dgy: int) -> tuple[float, float]:
    return float(dgx - dgy), float(dgx + dgy)


def accumulate_mud_screen_offset(
    v: tuple[float, float], dgx: int, dgy: int, has_mud: bool
) -> tuple[float, float]:
    if not has_mud:
        return v
    step = mud_screen_offset(dgx, dgy)
    return v[0] + step[0], v[1] + step[1]


def mud_screen_vector(ul: bool, ur: bool, dl: bool, dr: bool, nw: bool, ne: bool, sw: bool, se: bool) -> tuple[float, float]:
    v = (0.0, 0.0)
    v = accumulate_mud_screen_offset(v, 0, 1, ul)
    v = accumulate_mud_screen_offset(v, 1, 0, ur)
    v = accumulate_mud_screen_offset(v, -1, 0, dl)
    v = accumulate_mud_screen_offset(v, 0, -1, dr)
    v = accumulate_mud_screen_offset(v, -1, 1, nw)
    v = accumulate_mud_screen_offset(v, 1, 1, ne)
    v = accumulate_mud_screen_offset(v, -1, -1, sw)
    v = accumulate_mud_screen_offset(v, 1, -1, se)
    return v


def pick_a3_from_mud_screen_vector(v: tuple[float, float]) -> GrassOverlayChoice:
    ax = abs(v[0])
    ay = abs(v[1])
    if ax > ay:
        if v[0] < 0.0:
            return GrassOverlayChoice(GrassOverlayKind.EDGE, 1)  # N
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 2)  # S
    if v[1] < 0.0:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 3)  # W
    return GrassOverlayChoice(GrassOverlayKind.EDGE, 0)  # E


def pick_a3_for_opening_grass(grass_ul: bool, grass_ur: bool, grass_dl: bool, grass_dr: bool) -> GrassOverlayChoice:
    if grass_dr:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 1)
    if grass_ul:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 2)
    if grass_ur:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 0)
    if grass_dl:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 3)
    return GrassOverlayChoice(GrassOverlayKind.INTERIOR, 2)


def pick_fringe_overlay(
    ul: bool,
    ur: bool,
    dl: bool,
    dr: bool,
    nw: bool,
    ne: bool,
    sw: bool,
    se: bool,
    interior_dir: int,
    interior_only_when_isolated: bool,
) -> GrassOverlayChoice:
    mud_top = ul and ur
    mud_bottom = dl and dr
    mud_left = ul and dl
    mud_right = ur and dr
    mud_count = sum((ul, ur, dl, dr))
    if ul and dr and not ur and not dl:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 0)
    if ur and dl and not ul and not dr:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 2)
    mud_vec = mud_screen_vector(ul, ur, dl, dr, nw, ne, sw, se)
    is_interior_vec = abs(mud_vec[0]) < 0.001 and abs(mud_vec[1]) < 0.001
    if interior_only_when_isolated:
        if mud_count == 0 and is_interior_vec:
            return GrassOverlayChoice(GrassOverlayKind.INTERIOR, interior_dir)
    elif is_interior_vec:
        return GrassOverlayChoice(GrassOverlayKind.INTERIOR, interior_dir)
    if mud_count == 3:
        return pick_a3_for_opening_grass(not ul, not ur, not dl, not dr)
    if mud_top and mud_left:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 1)
    if mud_top and mud_right:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 0)
    if mud_bottom and mud_left:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 3)
    if mud_bottom and mud_right:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 2)
    if mud_top:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 0)
    if mud_bottom:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 3)
    if mud_left:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 1)
    if mud_right:
        return GrassOverlayChoice(GrassOverlayKind.EDGE, 2)
    if mud_count == 0:
        if nw:
            return pick_a3_from_mud_screen_vector(mud_screen_offset(-1, 1))
        if ne:
            return pick_a3_from_mud_screen_vector(mud_screen_offset(1, 1))
        if sw:
            return pick_a3_from_mud_screen_vector(mud_screen_offset(-1, -1))
        if se:
            return pick_a3_from_mud_screen_vector(mud_screen_offset(1, -1))
    if ul:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 0)
    if ur:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 2)
    if dl:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 1)
    if dr:
        return GrassOverlayChoice(GrassOverlayKind.CORNER, 3)
    return GrassOverlayChoice(GrassOverlayKind.INTERIOR, interior_dir)


def pick_grass_overlay(gx: int, gy: int, grass: list[bool]) -> GrassOverlayChoice:
    if not is_grass_cell(gx, gy, grass):
        return GrassOverlayChoice(GrassOverlayKind.NONE, 0)
    ul = mud_neighbor(gx, gy, 0, 1, grass)
    ur = mud_neighbor(gx, gy, 1, 0, grass)
    dl = mud_neighbor(gx, gy, -1, 0, grass)
    dr = mud_neighbor(gx, gy, 0, -1, grass)
    nw = mud_neighbor(gx, gy, -1, 1, grass)
    ne = mud_neighbor(gx, gy, 1, 1, grass)
    sw = mud_neighbor(gx, gy, -1, -1, grass)
    se = mud_neighbor(gx, gy, 1, -1, grass)
    return pick_fringe_overlay(
        ul, ur, dl, dr, nw, ne, sw, se, pick_interior_grass_direction(gx, gy), False
    )
