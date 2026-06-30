"""Outside border wall scene hierarchy: outside_border_walls / *_border_walls."""
from __future__ import annotations

OUTSIDE_BORDER_WALLS_ROOT = "outside_border_walls"

EDGE_TO_COMPASS_GROUP: dict[str, str] = {
    "lt": "west_border_walls",
    "br": "east_border_walls",
    "tr": "north_border_walls",
    "bl": "south_border_walls",
}

PLACEMENT_PREFIX_TO_COMPASS: dict[str, str] = {
    f"Wall_edge_{edge}": group for edge, group in EDGE_TO_COMPASS_GROUP.items()
} | {
    f"border_wall_{edge}": group for edge, group in EDGE_TO_COMPASS_GROUP.items()
}

COMPASS_BORDER_WALL_GROUPS: tuple[str, ...] = tuple(EDGE_TO_COMPASS_GROUP.values())

LEGACY_EDGE_ROOT_NAMES: frozenset[str] = frozenset(
    f"Wall_edge_{edge}" for edge in EDGE_TO_COMPASS_GROUP
) | frozenset(f"border_wall_{edge}" for edge in EDGE_TO_COMPASS_GROUP)

# Scene-tuned parent offsets (move whole border edge in prefab editor).
BORDER_WALL_GROUP_OFFSETS: dict[str, tuple[float, float, float]] = {
    "west_border_walls": (0.000000, 1.533500, 0.000000),
    "east_border_walls": (0.000000, 1.559100, 0.000000),
    "north_border_walls": (0.000000, 1.559100, 0.000000),
    "south_border_walls": (0.000000, 1.559100, 0.000000),
}

BORDER_WALL_SHELL_NAMES: frozenset[str] = frozenset(
    {OUTSIDE_BORDER_WALLS_ROOT, *COMPASS_BORDER_WALL_GROUPS, *LEGACY_EDGE_ROOT_NAMES}
)


def compass_group_for_placement_prefix(prefix: str) -> str | None:
    return PLACEMENT_PREFIX_TO_COMPASS.get(prefix)


def compass_group_for_segment_name(sprite_name: str) -> str | None:
    if "_in_" in sprite_name:
        return None
    for edge, group in EDGE_TO_COMPASS_GROUP.items():
        if f"_{edge}_" in sprite_name:
            return group
    return None


def edge_tag_for_compass_group(group_name: str) -> str | None:
    for edge, group in EDGE_TO_COMPASS_GROUP.items():
        if group == group_name:
            return edge
    return None
