#!/usr/bin/env python3
"""Renumber level_1.prefab node uids for correct editor pick order.

Eden picks the lowest uid among overlapping sprites. Order must be:
  props/decor -> walls -> map (per cell: road, grass, ground last).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from lib.border_wall_hierarchy import (
    COMPASS_BORDER_WALL_GROUPS,
    OUTSIDE_BORDER_WALLS_ROOT,
)

PROJECT = Path(__file__).resolve().parents[3]
DEFAULT_PREFAB = PROJECT / "prefabs" / "level_1.prefab"

CELL_RE = re.compile(r"^cell_(-?\d+)_(-?\d+)$")
LAYER_ORDER = {"road_fill": 0, "grass": 1, "ground": 2}
STRUCTURE_NAMES = frozenset(
    {"level_1", "level", "base", "camera", "render_settings", "player", "props", "walls", "map"}
)
WALL_GROUP_NAMES = frozenset(
    {OUTSIDE_BORDER_WALLS_ROOT, *COMPASS_BORDER_WALL_GROUPS, "Wall_edge_lt", "Wall_edge_br", "Wall_edge_tr", "Wall_edge_bl"}
)
WALL_SHELL_ORDER = (OUTSIDE_BORDER_WALLS_ROOT, *COMPASS_BORDER_WALL_GROUPS)
WALL_SHELL_RANK = {name: idx for idx, name in enumerate(WALL_SHELL_ORDER)}


def parse_node_blocks(text: str) -> tuple[list[str], dict[int, dict]]:
    """Return (res_section_lines, uid -> node info with raw block)."""
    res_start = text.find("\nres{")
    if res_start < 0:
        res_start = len(text)
    nodes_text = text[:res_start]
    res_section = text[res_start:].lstrip("\n")

    nodes: dict[int, dict] = {}
    i = 0
    while True:
        start = nodes_text.find("node{", i)
        if start < 0:
            break
        depth = 0
        j = start
        while j < len(nodes_text):
            if nodes_text[j] == "{":
                depth += 1
            elif nodes_text[j] == "}":
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        block = nodes_text[start:j]
        body = block[5:-1]
        name_m = re.search(r'name:t="([^"]+)"', body)
        uid_m = re.search(r"uid:i=(\d+)", body)
        parent_m = re.search(r"parent:i=(\d+)", body)
        if name_m and uid_m:
            uid = int(uid_m.group(1))
            nodes[uid] = {
                "name": name_m.group(1),
                "parent": int(parent_m.group(1)) if parent_m else None,
                "raw": block,
                "has_sprite": "SpriteRenderer{" in body,
            }
        i = j
    return res_section, nodes


def descendants(nodes: dict[int, dict], root_uid: int) -> set[int]:
    kids: dict[int, list[int]] = {}
    for uid, n in nodes.items():
        p = n["parent"]
        if p is not None:
            kids.setdefault(p, []).append(uid)

    out: set[int] = set()
    stack = [root_uid]
    while stack:
        uid = stack.pop()
        if uid in out:
            continue
        out.add(uid)
        stack.extend(kids.get(uid, []))
    return out


def cell_sort_key(name: str) -> tuple[int, int, int]:
    m = CELL_RE.match(name)
    if not m:
        return (2, 0, 0)
    return (0, int(m.group(1)), int(m.group(2)))


def layer_sort_key(name: str) -> int:
    return LAYER_ORDER.get(name, 9)


def ordered_uids(nodes: dict[int, dict]) -> list[int]:
    by_name = {n["name"]: uid for uid, n in nodes.items()}
    props_uid = by_name.get("props")
    walls_uid = by_name.get("walls")
    map_uid = by_name.get("map")
    if props_uid is None or walls_uid is None or map_uid is None:
        raise RuntimeError("prefab missing props, walls, or map root nodes")

    root_uid = next(uid for uid, n in nodes.items() if n["parent"] is None)
    props_set = descendants(nodes, props_uid)
    walls_set = descendants(nodes, walls_uid)
    map_set = descendants(nodes, map_uid)

    prop_sprites = sorted(
        (uid for uid in props_set if nodes[uid]["has_sprite"]),
        key=lambda u: nodes[u]["name"],
    )

    wall_shells = sorted(
        (
            uid
            for uid in walls_set
            if not nodes[uid]["has_sprite"] and nodes[uid]["name"] in WALL_GROUP_NAMES
        ),
        key=lambda u: (WALL_SHELL_RANK.get(nodes[u]["name"], 99), nodes[u]["name"]),
    )
    wall_sprites = sorted(
        (uid for uid in walls_set if nodes[uid]["has_sprite"]),
        key=lambda u: nodes[u]["name"],
    )

    map_cells = sorted(
        (uid for uid in map_set if CELL_RE.match(nodes[uid]["name"])),
        key=lambda u: cell_sort_key(nodes[u]["name"]),
    )
    cell_children: dict[int, list[int]] = {c: [] for c in map_cells}
    for uid, n in nodes.items():
        p = n["parent"]
        if p in cell_children:
            cell_children[p].append(uid)
    for cell in map_cells:
        cell_children[cell].sort(key=lambda u: layer_sort_key(nodes[u]["name"]))

    ordered: list[int] = [root_uid]
    for name in ("camera", "render_settings", "player", "props", "walls", "map"):
        if name in by_name:
            ordered.append(by_name[name])
    ordered.extend(wall_shells)
    ordered.extend(prop_sprites)
    ordered.extend(wall_sprites)
    for cell in map_cells:
        ordered.append(cell)
        ordered.extend(cell_children[cell])

    seen = set(ordered)
    leftover = sorted(
        (uid for uid in nodes if uid not in seen),
        key=lambda u: nodes[u]["name"],
    )
    if leftover:
        ordered.extend(leftover)

    if len(ordered) != len(nodes):
        missing = [nodes[u]["name"] for u in nodes if u not in seen and u not in leftover]
        raise RuntimeError(f"ordering mismatch: {len(nodes)} nodes, {len(ordered)} ordered, missing={missing[:5]}")
    return ordered


def rewrite_block(block: str, new_uid: int, parent_uid: int | None) -> str:
    block = re.sub(r"uid:i=\d+", f"uid:i={new_uid}", block, count=1)
    if parent_uid is None:
        block = re.sub(r"\nparent:i=\d+\n", "\n", block)
    else:
        if "parent:i=" in block:
            block = re.sub(r"parent:i=\d+", f"parent:i={parent_uid}", block, count=1)
        else:
            block = block.replace(
                f"uid:i={new_uid}\n",
                f"uid:i={new_uid}\nparent:i={parent_uid}\n",
                1,
            )
    return block


def fix_prefab_pick_uids(prefab_path: Path, start_uid: int = 100001) -> None:
    text = prefab_path.read_text(encoding="utf-8")
    res_section, nodes = parse_node_blocks(text)
    order = ordered_uids(nodes)
    by_name = {n["name"]: uid for uid, n in nodes.items()}

    uid_map: dict[int, int] = {}
    next_uid = start_uid
    for old in order:
        uid_map[old] = next_uid
        next_uid += 1

    lines: list[str] = []
    for old in order:
        n = nodes[old]
        parent_old = n["parent"]
        parent_new = uid_map[parent_old] if parent_old is not None else None
        lines.append(rewrite_block(n["raw"], uid_map[old], parent_new))

    out = "\n".join(lines)
    if res_section:
        out += "\n" + res_section.rstrip("\n") + "\n"
    else:
        out += "\n"
    prefab_path.write_text(out, encoding="utf-8", newline="\n")

    prop_uids = [uid_map[u] for u in order if u in descendants(nodes, by_name["props"]) and nodes[u]["has_sprite"]]
    ground_uids = [uid_map[u] for u in order if nodes[u]["name"] == "ground"]
    print(f"Wrote {prefab_path}")
    print(f"Nodes renumbered: {len(order)} ({start_uid}..{next_uid - 1})")
    if prop_uids and ground_uids:
        print(
            f"Prop sprite uids {min(prop_uids)}..{max(prop_uids)}; "
            f"ground uids {min(ground_uids)}..{max(ground_uids)}; "
            f"props before ground: {max(prop_uids) < min(ground_uids)}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prefab", type=Path, default=DEFAULT_PREFAB)
    parser.add_argument("--start-uid", type=int, default=100001)
    args = parser.parse_args()
    if not args.prefab.exists():
        print(f"missing {args.prefab}", file=__import__("sys").stderr)
        return 1
    fix_prefab_pick_uids(args.prefab, args.start_uid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
