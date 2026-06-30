#!/usr/bin/env python3
"""Rename prop/wall/decor sprite nodes to Misc_type2_var1_e style."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from lib.prefab_node_names import new_node_name

PROJECT = Path(__file__).resolve().parents[3]


def parse_nodes(text: str) -> list[tuple[str, dict]]:
    blocks: list[tuple[str, dict]] = []
    i = 0
    while True:
        start = text.find("node{", i)
        if start < 0:
            break
        depth = 0
        j = start
        while j < len(text):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        block = text[start:j]
        body = block[5:-1]
        name_m = re.search(r'name:t="([^"]+)"', body)
        tex_m = re.search(r'texturePath:t="([^"]+)"', body)
        prop_m = re.search(r'propId:t="([^"]+)"', body)
        if name_m:
            blocks.append(
                (
                    block,
                    {
                        "name": name_m.group(1),
                        "tex": tex_m.group(1) if tex_m else "",
                        "prop_id": prop_m.group(1) if prop_m else "",
                    },
                )
            )
        i = j
    return blocks


def is_decor_like(old_name: str) -> bool:
    return bool(
        re.match(r"^(decor_|misc_b)", old_name)
        and not re.match(r"^(border_wall_|interior_wall_|base_wall_)", old_name)
    )


def new_names_in_order(blocks: list[tuple[str, dict]]) -> list[str | None]:
    stem_counts: dict[str, int] = {}
    names: list[str | None] = []
    for _, info in blocks:
        old = info["name"]
        stem = new_node_name(old, info["tex"], info["prop_id"])
        if stem is None:
            names.append(None)
            continue
        if is_decor_like(old):
            count = stem_counts.get(stem, 0) + 1
            stem_counts[stem] = count
            names.append(stem if count == 1 else f"{stem}_{count}")
        else:
            names.append(stem)
    return names


def rename_prefab(prefab_path: Path, dry_run: bool = False) -> int:
    text = prefab_path.read_text(encoding="utf-8")
    blocks = parse_nodes(text)
    new_names = new_names_in_order(blocks)
    changes = [
        (info["name"], new)
        for (_, info), new in zip(blocks, new_names, strict=True)
        if new is not None and new != info["name"]
    ]
    if not changes:
        print(f"No renames for {prefab_path}")
        return 0

    new_blocks = [
        block.replace(f'name:t="{info["name"]}"', f'name:t="{new}"', 1)
        if new is not None and new != info["name"]
        else block
        for (block, info), new in zip(blocks, new_names, strict=True)
    ]

    if dry_run:
        print(f"Would rename {len(changes)} nodes in {prefab_path}")
        for old, new in changes[:20]:
            print(f"  {old} -> {new}")
        if len(changes) > 20:
            print(f"  ... and {len(changes) - 20} more")
        return len(changes)

    res_start = text.find("\nres{")
    if res_start < 0:
        res_start = len(text)
    nodes_text = text[:res_start]
    res_section = text[res_start:]

    out_parts: list[str] = []
    i = 0
    block_idx = 0
    while True:
        start = nodes_text.find("node{", i)
        if start < 0:
            out_parts.append(nodes_text[i:])
            break
        out_parts.append(nodes_text[i:start])
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
        out_parts.append(new_blocks[block_idx])
        block_idx += 1
        i = j

    new_text = "".join(out_parts)
    if res_section:
        new_text += res_section
    prefab_path.write_text(new_text, encoding="utf-8", newline="\n")
    print(f"Renamed {len(changes)} nodes in {prefab_path}")
    return len(changes)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prefab", type=Path, action="append")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    prefabs = args.prefab or [
        PROJECT / "prefabs" / "level_1.prefab",
        PROJECT / "prefabs" / "base.prefab",
    ]
    total = 0
    for path in prefabs:
        if not path.exists():
            print(f"missing {path}", file=sys.stderr)
            return 1
        total += rename_prefab(path, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
