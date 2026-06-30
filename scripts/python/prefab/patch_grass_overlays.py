#!/usr/bin/env python3
"""Patch grass sprites in level_1.prefab to use A2 interior / A3 edge / A4 corner overlays."""
from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from lib.grass_overlay import GrassOverlayKind, pick_grass_overlay

# Import bake helpers (same directory).
from bake_level_prefab import (
    PATHS,
    TILE_LAYOUT,
    generate_grass_mask,
    generate_road_mask,
    is_grass_cell,
    is_road_cell,
    load_texture_ref_ids,
    overlay_texture,
    tile_uv_rect_for_layout_in_texture,
)

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"


def patch_grass_overlays(prefab_text: str) -> tuple[str, Counter[str], int]:
    grass = generate_grass_mask()
    roads = generate_road_mask()
    ref_ids = load_texture_ref_ids()
    kinds: Counter[str] = Counter()
    missing_refs: set[str] = set()
    updated = 0

    cell_re = re.compile(
        r'(node\{\nname:t="cell_(-?\d+)_(-?\d+)".*?)(?=\nnode\{\nname:t="cell_|\nres\{)',
        re.S,
    )

    def fix_cell(match: re.Match[str]) -> str:
        nonlocal updated
        gx = int(match.group(2))
        gy = int(match.group(3))
        cell = match.group(1)
        if 'name:t="grass"' not in cell:
            return cell
        if not is_grass_cell(gx, gy, grass) or is_road_cell(gx, gy, roads):
            return cell

        overlay = pick_grass_overlay(gx, gy, grass)
        sprite = overlay_texture(overlay)
        if sprite is None:
            return cell

        tex_key, crop = sprite
        path = PATHS[tex_key]
        ref_id = ref_ids.get(path, 0)
        if ref_id == 0:
            missing_refs.add(path)
        uv = tile_uv_rect_for_layout_in_texture(TILE_LAYOUT, crop)
        uv_s = f"uvRect:p4={uv[0]:.6f}, {uv[1]:.6f}, {uv[2]:.6f}, {uv[3]:.6f}"
        kinds[overlay.kind.name] += 1

        def repl_grass(grass_m: re.Match[str]) -> str:
            nonlocal updated
            block = grass_m.group(0)
            block = re.sub(
                r'TileTextureHint\{texturePath:t="[^"]+";\}',
                f'TileTextureHint{{texturePath:t="{path}";}}',
                block,
                count=1,
            )
            block = re.sub(r"__textureId:i64=-?\d+", f"__textureId:i64={ref_id}", block, count=1)
            block = re.sub(r"uvRect:p4=[^\n]+", uv_s, block, count=1)
            updated += 1
            return block

        return re.sub(
            r'node\{\nname:t="grass".*?TileTextureHint\{texturePath:t="[^"]+";\}\n\}',
            repl_grass,
            cell,
            count=1,
            flags=re.S,
        )

    out = cell_re.sub(fix_cell, prefab_text)
    if missing_refs:
        print("missing __textureId refIds (assign once in editor, save, run hydrate):")
        for path in sorted(missing_refs):
            print(f"  {path}")
    return out, kinds, updated


def main() -> int:
    if not PREFAB.exists():
        print(f"missing {PREFAB}", file=sys.stderr)
        return 1
    text = PREFAB.read_text(encoding="utf-8")
    new_text, kinds, updated = patch_grass_overlays(text)
    PREFAB.write_text(new_text, encoding="utf-8", newline="\n")
    print(f"patched {updated} grass sprites")
    for kind, count in sorted(kinds.items()):
        print(f"  {kind}: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
