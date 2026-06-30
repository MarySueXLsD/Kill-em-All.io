#!/usr/bin/env python3
"""Insert wall sprites under level_1.prefab walls node (prefab-only migration)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
_PREFAB_TOOLS = Path(__file__).resolve().parent
_BAKE = _TOOLS / "bake"
for _p in (_TOOLS, _BAKE, _PREFAB_TOOLS):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from bake_level_prefab import (
    border_wall_render_order,
    feet_grid_with_border_group_offset,
    load_texture_ref_ids,
    resolve_wall_parent_uid,
    Writer,
)
from lib.border_wall_hierarchy import (
    BORDER_WALL_GROUP_OFFSETS,
    COMPASS_BORDER_WALL_GROUPS,
    LEGACY_EDGE_ROOT_NAMES,
    OUTSIDE_BORDER_WALLS_ROOT,
    PLACEMENT_PREFIX_TO_COMPASS,
)
from lib.wall_placement import generate_border_wall_placements, generate_wall_placements

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"

WALLS_NODE_RE = re.compile(
    r'node\{\nname:t="walls"\nuid:i=(\d+)\nparent:i=\d+\n\}',
    re.MULTILINE,
)
NAME_RE = re.compile(r'name:t="([^"]+)"')
LEGACY_SHELL_RE = re.compile(
    r'\nnode\{\nname:t="(?P<name>Wall_edge_[^"]+|border_wall_[^"]+)"\n'
    r"uid:i=(?P<uid>\d+)\nparent:i=\d+\n(?:pos:p3=[^\n]+\n)?\}\n",
    re.MULTILINE,
)
POS_RE = re.compile(r"pos:p3=([^,]+), ([^,]+), ([^\n]+)")
BORDER_HIERARCHY_SHELL_RE = re.compile(
    r'\nnode\{\nname:t="(?P<name>outside_border_walls|'
    r"west_border_walls|east_border_walls|north_border_walls|south_border_walls)\"\n"
    r"uid:i=(?P<uid>\d+)\nparent:i=\d+\n(?:pos:p3=[^\n]+\n)?\}\n",
    re.MULTILINE,
)
HIERARCHY_ORDER = (OUTSIDE_BORDER_WALLS_ROOT, *COMPASS_BORDER_WALL_GROUPS)


def _format_shell_node(
    name: str, uid: int, parent: int, pos: tuple[float, float, float] | None = None
) -> str:
    lines = ["node{", f'name:t="{name}"', f"uid:i={uid}", f"parent:i={parent}"]
    if pos is not None:
        lines.append(f"pos:p3={pos[0]:.6f}, {pos[1]:.6f}, {pos[2]:.6f}")
    lines.append("}")
    return "\n".join(lines)


def _uid_for_name(prefab_text: str, name: str) -> int | None:
    m = re.search(rf'name:t="{re.escape(name)}"\nuid:i=(\d+)', prefab_text)
    return int(m.group(1)) if m else None


def reorder_border_wall_hierarchy(prefab_text: str) -> str:
    """Move outside_border_walls + compass shells directly under walls (parents before children)."""
    by_name: dict[str, str] = {}
    for m in BORDER_HIERARCHY_SHELL_RE.finditer(prefab_text):
        by_name[m.group("name")] = m.group(0).lstrip("\n")
    if not by_name:
        return prefab_text

    prefab_text = BORDER_HIERARCHY_SHELL_RE.sub("\n", prefab_text)
    m = WALLS_NODE_RE.search(prefab_text)
    if not m:
        return prefab_text

    blocks = [by_name[name] for name in HIERARCHY_ORDER if name in by_name]
    insert_at = m.end()
    return prefab_text[:insert_at] + "\n" + "\n".join(blocks) + "\n" + prefab_text[insert_at:]


def _insert_at_after_border_hierarchy(prefab_text: str) -> int:
    """Return byte offset to append new border wall sprites (after hierarchy shells)."""
    m = WALLS_NODE_RE.search(prefab_text)
    if not m:
        raise ValueError('walls node not found in level_1.prefab')
    walls_end = m.end()
    search_from = walls_end
    last_end = walls_end
    for name in HIERARCHY_ORDER:
        shell_m = re.search(
            rf'\nnode\{{\nname:t="{re.escape(name)}"\nuid:i=\d+\nparent:i=\d+\n(?:pos:p3=[^\n]+\n)?\}}\n',
            prefab_text[search_from:],
        )
        if shell_m:
            last_end = search_from + shell_m.end()
    return last_end


def ensure_border_wall_hierarchy(prefab_text: str, walls_uid: int) -> tuple[str, dict[str, int]]:
    """Ensure outside_border_walls + compass groups; migrate legacy Wall_edge_* shells."""
    legacy_offsets: dict[str, tuple[float, float, float]] = {}
    for m in LEGACY_SHELL_RE.finditer(prefab_text):
        compass = PLACEMENT_PREFIX_TO_COMPASS.get(m.group("name"))
        if compass is None:
            continue
        block = m.group(0)
        pos_m = POS_RE.search(block)
        if pos_m:
            legacy_offsets[compass] = (
                float(pos_m.group(1)),
                float(pos_m.group(2)),
                float(pos_m.group(3)),
            )

    group_uids: dict[str, int] = {}
    for group in COMPASS_BORDER_WALL_GROUPS:
        uid = _uid_for_name(prefab_text, group)
        if uid is not None:
            group_uids[group] = uid

    outside_uid = _uid_for_name(prefab_text, OUTSIDE_BORDER_WALLS_ROOT)
    max_uid = max(int(x) for x in re.findall(r"uid:i=(\d+)", prefab_text))
    insert_blocks: list[str] = []

    if outside_uid is None:
        max_uid += 1
        outside_uid = max_uid
        insert_blocks.append(_format_shell_node(OUTSIDE_BORDER_WALLS_ROOT, outside_uid, walls_uid))

    for group in COMPASS_BORDER_WALL_GROUPS:
        if group in group_uids:
            continue
        max_uid += 1
        group_uids[group] = max_uid
        off = legacy_offsets.get(group) or BORDER_WALL_GROUP_OFFSETS.get(group, (0.0, 0.0, 0.0))
        insert_blocks.append(_format_shell_node(group, max_uid, outside_uid, off))

    if insert_blocks:
        m = WALLS_NODE_RE.search(prefab_text)
        if not m:
            raise ValueError('walls node not found in level_1.prefab')
        insert_at = m.end()
        prefab_text = (
            prefab_text[:insert_at] + "\n" + "\n".join(insert_blocks) + "\n" + prefab_text[insert_at:]
        )

    for legacy in LEGACY_EDGE_ROOT_NAMES:
        legacy_uid = _uid_for_name(prefab_text, legacy)
        if legacy_uid is None:
            continue
        compass = PLACEMENT_PREFIX_TO_COMPASS.get(legacy)
        if compass and compass in group_uids:
            prefab_text = prefab_text.replace(
                f"parent:i={legacy_uid}\n",
                f"parent:i={group_uids[compass]}\n",
            )
    prefab_text = LEGACY_SHELL_RE.sub("\n", prefab_text)

    return reorder_border_wall_hierarchy(prefab_text), group_uids


def remove_legacy_border_shells(prefab_text: str) -> str:
    return LEGACY_SHELL_RE.sub("\n", prefab_text)


def format_wall_nodes(
    walls_uid: int,
    start_uid: int,
    texture_ref_ids: dict[str, int],
    placements,
    wall_group_uids: dict[str, int],
) -> tuple[list[str], int]:
    w = Writer(texture_ref_ids)
    w.uid = start_uid
    for placement in placements:
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
    return w.lines, w.uid


def patch_walls(prefab_text: str, texture_ref_ids: dict[str, int]) -> tuple[str, int]:
    m = WALLS_NODE_RE.search(prefab_text)
    if not m:
        raise ValueError('walls node not found in level_1.prefab')
    walls_uid = int(m.group(1))
    prefab_text, wall_group_uids = ensure_border_wall_hierarchy(prefab_text, walls_uid)

    existing_names = set(NAME_RE.findall(prefab_text))
    border_missing = [
        p for p in generate_border_wall_placements() if p.name not in existing_names
    ]
    if not border_missing:
        return prefab_text, 0

    max_uid = max(int(x) for x in re.findall(r"uid:i=(\d+)", prefab_text))
    lines, _ = format_wall_nodes(
        walls_uid, max_uid, texture_ref_ids, border_missing, wall_group_uids
    )
    block = "\n" + "\n".join(lines) + "\n"
    insert_at = _insert_at_after_border_hierarchy(prefab_text)
    out = prefab_text[:insert_at] + block + prefab_text[insert_at:]
    return remove_legacy_border_shells(out), len(border_missing)


def patch_all_walls(prefab_text: str, texture_ref_ids: dict[str, int]) -> tuple[str, int]:
    """Insert every wall placement when walls node has no children (initial migration)."""
    m = WALLS_NODE_RE.search(prefab_text)
    if not m:
        raise ValueError('walls node not found in level_1.prefab')
    walls_uid = int(m.group(1))
    prefab_text, wall_group_uids = ensure_border_wall_hierarchy(prefab_text, walls_uid)

    child_pat = re.compile(rf"parent:i={walls_uid}\n")
    if child_pat.search(prefab_text):
        return patch_walls(prefab_text, texture_ref_ids)

    max_uid = max(int(x) for x in re.findall(r"uid:i=(\d+)", prefab_text))
    lines, _ = format_wall_nodes(
        walls_uid,
        max_uid,
        texture_ref_ids,
        generate_wall_placements(),
        wall_group_uids,
    )
    block = "\n" + "\n".join(lines) + "\n"
    insert_at = _insert_at_after_border_hierarchy(prefab_text)
    out = prefab_text[:insert_at] + block + prefab_text[insert_at:]
    return remove_legacy_border_shells(out), len(generate_wall_placements())


def main() -> int:
    if not PREFAB.exists():
        print(f"missing {PREFAB}", file=sys.stderr)
        return 1

    texture_ref_ids = load_texture_ref_ids()
    text = PREFAB.read_text(encoding="utf-8")
    m = WALLS_NODE_RE.search(text)
    if not m:
        print("walls node not found", file=sys.stderr)
        return 1
    walls_uid = int(m.group(1))
    text, group_uids = ensure_border_wall_hierarchy(text, walls_uid)
    text = reorder_border_wall_hierarchy(text)
    print(f"border hierarchy groups: {len(group_uids)}")

    new_text, added = patch_walls(text, texture_ref_ids)
    new_text = reorder_border_wall_hierarchy(new_text)
    if added == 0 and new_text == text:
        print("border hierarchy ok; all border wall sprites already present")
    else:
        print(f"inserted {added} border wall nodes")

    from fix_prefab_pick_uids import fix_prefab_pick_uids

    PREFAB.write_text(new_text, encoding="utf-8", newline="\n")
    print("renumbering uids for editor parent resolution...")
    fix_prefab_pick_uids(PREFAB)
    print("run: python scripts/python/prefab/hydrate_prefab_texture_ids.py --hydrate-only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
