"""Prefab sprite node names: Misc_type2_var1_e, Wall_type2_var1_n_lt_0, etc."""
from __future__ import annotations

import re

TEXTURE_RE = re.compile(
    r"static/Environment/(\w+)/Type_(\d+)_Variation_(\d+)_(East|North|South|West)\.png"
)
DIR_LETTER = {"East": "e", "North": "n", "South": "s", "West": "w"}

from lib.border_wall_hierarchy import (
    BORDER_WALL_SHELL_NAMES,
    COMPASS_BORDER_WALL_GROUPS,
    EDGE_TO_COMPASS_GROUP,
    LEGACY_EDGE_ROOT_NAMES,
    OUTSIDE_BORDER_WALLS_ROOT,
    PLACEMENT_PREFIX_TO_COMPASS,
    compass_group_for_segment_name,
    compass_group_for_placement_prefix,
)

STRUCTURE_NAMES = frozenset(
    {
        "level_1",
        "level",
        "base",
        "camera",
        "render_settings",
        "player",
        "props",
        "walls",
        "map",
        OUTSIDE_BORDER_WALLS_ROOT,
        *COMPASS_BORDER_WALL_GROUPS,
        "road_fill",
        "grass",
        "ground",
    }
)

BORDER_WALL_EDGE_RE = re.compile(r"^border_wall_(lt|br|tr|bl)_(\d+)$")
INTERIOR_WALL_RE = re.compile(r"^interior_wall_([\w]+)_(\d+)$")
BASE_WALL_RE = re.compile(r"^base_wall_([nsew])_(\d+)$", re.I)
OLD_DECOR_RE = re.compile(r"^decor_(tree|misc)_\d+$")
OLD_MISC_PROP_RE = re.compile(r"^misc_b\d+_[ensw]_\d+$", re.I)


def parse_texture_path(tex: str) -> tuple[str, int, int, str] | None:
    m = TEXTURE_RE.match(tex)
    if not m:
        return None
    cat, type_num, var_num, dir_name = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
    return cat, type_num, var_num, DIR_LETTER[dir_name]


def prop_id_direction(prop_id: str) -> str:
    if not prop_id:
        return ""
    return prop_id[-1].lower()


def decor_stem(cat: str, type_num: int, var_num: int, dir_letter: str) -> str:
    return f"{cat}_type{type_num}_var{var_num}_{dir_letter}"


def wall_stem(type_num: int, var_num: int, dir_letter: str) -> str:
    return f"Wall_type{type_num}_var{var_num}_{dir_letter}"


def wall_edge_root_name(old_or_new: str) -> str | None:
    if old_or_new in LEGACY_EDGE_ROOT_NAMES:
        return PLACEMENT_PREFIX_TO_COMPASS.get(old_or_new, old_or_new)
    if old_or_new in COMPASS_BORDER_WALL_GROUPS or old_or_new == OUTSIDE_BORDER_WALLS_ROOT:
        return old_or_new
    return None


def new_node_name(
    old_name: str,
    texture_path: str = "",
    prop_id: str = "",
) -> str | None:
    """Return new node name, or None to keep old_name."""
    if old_name in STRUCTURE_NAMES:
        return None
    if old_name.startswith("cell_"):
        return None

    edge_root = wall_edge_root_name(old_name)
    if edge_root is not None:
        return edge_root

    parsed = parse_texture_path(texture_path) if texture_path else None
    if parsed is None and prop_id.startswith("wall_b1_"):
        parsed = ("Wall", 2, 1, prop_id_direction(prop_id))
    if parsed is None and prop_id.startswith("misc_b"):
        # misc_b11_e -> type 2 var 11 east
        m = re.match(r"misc_b(\d+)_([ensw])", prop_id, re.I)
        if m:
            parsed = ("Misc", 2, int(m.group(1)), m.group(2).lower())

    if parsed is None:
        return None

    cat, type_num, var_num, dir_letter = parsed

    m = BORDER_WALL_EDGE_RE.match(old_name)
    if m:
        edge, idx = m.group(1), m.group(2)
        d = dir_letter or prop_id_direction(prop_id)
        return f"{wall_stem(type_num, var_num, d)}_{edge}_{idx}"

    m = INTERIOR_WALL_RE.match(old_name)
    if m:
        tag, idx = m.group(1), m.group(2)
        d = dir_letter or prop_id_direction(prop_id)
        return f"{wall_stem(type_num, var_num, d)}_in_{tag}_{idx}"

    m = BASE_WALL_RE.match(old_name)
    if m:
        d, idx = m.group(1).lower(), m.group(2)
        return f"{wall_stem(type_num, var_num, d)}_{idx}"

    if (
        OLD_DECOR_RE.match(old_name)
        or OLD_MISC_PROP_RE.match(old_name)
        or old_name.startswith(("decor_", "misc_b"))
    ):
        return decor_stem(cat, type_num, var_num, dir_letter)

    return None


def wall_segment_node_name(prop_id: str, prefix: str, index: int) -> str:
    """border_wall_lt / Wall_edge_lt / interior_wall_w_n -> Wall_type2_var1_n_lt_0 etc."""
    d = prop_id_direction(prop_id)
    if prefix.startswith("Wall_edge_"):
        edge = prefix[len("Wall_edge_") :]
        return f"Wall_type2_var1_{d}_{edge}_{index}"
    compass_edge = None
    for edge_tag, group in EDGE_TO_COMPASS_GROUP.items():
        if prefix == group:
            compass_edge = edge_tag
            break
    if compass_edge is not None:
        return f"Wall_type2_var1_{d}_{compass_edge}_{index}"
    if prefix.startswith("border_wall_"):
        edge = prefix[len("border_wall_") :]
        return f"Wall_type2_var1_{d}_{edge}_{index}"
    if prefix.startswith("interior_wall_"):
        tag = prefix[len("interior_wall_") :]
        return f"Wall_type2_var1_{d}_in_{tag}_{index}"
    if prefix.startswith("base_wall_"):
        tag = prefix[len("base_wall_") :]
        return f"Wall_type2_var1_{d}_{tag}"
    return f"Wall_type2_var1_{d}_{prefix}_{index}"


def border_wall_group_for_segment_name(sprite_name: str) -> str | None:
    return compass_group_for_segment_name(sprite_name)


def node_name_from_prop_texture(prop_id: str, texture_path: str, index: int = 0) -> str:
    parsed = parse_texture_path(texture_path)
    if parsed is None and prop_id.startswith("misc_b"):
        m = re.match(r"misc_b(\d+)_([ensw])", prop_id, re.I)
        if m:
            parsed = ("Misc", 2, int(m.group(1)), m.group(2).lower())
    if parsed is None:
        return f"{prop_id}_{index}"
    cat, type_num, var_num, dir_letter = parsed
    return decor_stem(cat, type_num, var_num, dir_letter)
