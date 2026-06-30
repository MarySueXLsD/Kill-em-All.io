#!/usr/bin/env python3
"""Apply __textureId:i64 values to level_1.prefab from asset GUID/ref table."""
from __future__ import annotations

import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from lib.environment_texture_names import environment_texture_rel
from lib.resource_link_hash import ref_id_from_meta

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
ENV = PROJECT / "static" / "Environment"
STATIC = PROJECT / "static"
REF_IDS_JSON = Path(__file__).resolve().parent.parent / "data" / "texture_ref_ids.json"

RES_RE = re.compile(
    r"res\{\s*guid:t=\"([^\"]+)\"\s*type:i=\d+\s*refId:i64=(-?\d+)\s*\}",
    re.MULTILINE,
)
GUID_RE = re.compile(r'^guid:t="([^"]+)"', re.MULTILINE)
SPRITE_HINT_RE = re.compile(
    r"SpriteRenderer\{[^}]*__textureId:i64=(-?\d+)[^}]*\}\s*"
    r'TileTextureHint\{texturePath:t="([^"]+)";\}',
    re.DOTALL,
)
HINT_RE = re.compile(r'TileTextureHint\{texturePath:t="([^"]+)";\}')

GROUND_TILE_LAYOUT_CROP = (64.0, 176.0, 191.0, 255.0)
_A2 = [
    (61.0, 171.0, 192.0, 241.0),
    (61.0, 171.0, 193.0, 241.0),
    (63.0, 169.0, 193.0, 241.0),
    (63.0, 171.0, 193.0, 241.0),
]
_A3 = [
    (62.0, 194.0, 193.0, 241.0),
    (109.0, 171.0, 191.0, 241.0),
    (64.0, 171.0, 146.0, 241.0),
    (62.0, 171.0, 193.0, 214.0),
]
_A4 = [
    (113.0, 189.0, 191.0, 241.0),
    (101.0, 172.0, 191.0, 212.0),
    (64.0, 196.0, 154.0, 241.0),
    (64.0, 172.0, 142.0, 217.0),
]
OVERLAY_CROPS: dict[str, tuple[float, float, float, float]] = {}
for _variation, _crops in ((2, _A2), (3, _A3), (4, _A4)):
    for i, d in enumerate("ENSW"):
        OVERLAY_CROPS[environment_texture_rel("Ground", "A", _variation, d)] = _crops[i]
DEPTH_TILE_GRASS_BIAS = 199  # DEPTH_TILE_STRIDE * 2 - 1


def crop_wh(crop: tuple[float, float, float, float]) -> tuple[float, float]:
    return crop[2] - crop[0] + 1.0, crop[3] - crop[1] + 1.0


def uv_layout_in_texture(
    layout_crop: tuple[float, float, float, float],
    texture_crop: tuple[float, float, float, float],
) -> tuple[float, float, float, float]:
    tw, th = crop_wh(texture_crop)
    lx0 = layout_crop[0] - texture_crop[0]
    ly0 = layout_crop[1] - texture_crop[1]
    lx1 = layout_crop[2] - texture_crop[0]
    ly1 = layout_crop[3] - texture_crop[1]
    return lx0 / tw, ly0 / th, lx1 / tw, ly1 / th


def uv_rect_from_crop(
    min_x: float,
    min_y: float,
    max_x: float,
    max_y: float,
    tex_w: float,
    tex_h: float,
) -> tuple[float, float, float, float]:
    """Match iso_math.das uv_rect_from_crop (u, v, width, height; image Y-down)."""
    width = max_x - min_x + 1.0
    height = max_y - min_y + 1.0
    uv_y = 1.0 - (max_y + 1.0) / tex_h
    return min_x / tex_w, uv_y, width / tex_w, height / tex_h


def tile_uv_rect_for_layout_in_texture(
    layout_crop: tuple[float, float, float, float],
    texture_crop: tuple[float, float, float, float],
) -> tuple[float, float, float, float]:
    """Match world.das tile_uv_rect_for_layout_in_texture."""
    tw, th = crop_wh(texture_crop)
    lx0 = layout_crop[0] - texture_crop[0]
    ly0 = layout_crop[1] - texture_crop[1]
    lx1 = layout_crop[2] - texture_crop[0]
    ly1 = layout_crop[3] - texture_crop[1]
    return uv_rect_from_crop(lx0, ly0, lx1, ly1, tw, th)


def load_path_to_guid() -> dict[str, str]:
    out: dict[str, str] = {}
    for meta in STATIC.rglob("*.png.meta"):
        text = meta.read_text(encoding="utf-8")
        m = GUID_RE.search(text)
        if not m:
            continue
        rel = meta.relative_to(STATIC).as_posix()
        out[f"static/{rel[:-5]}"] = m.group(1)
    return out


def iter_texture_metas():
    return STATIC.rglob("*.png.meta")


def load_guid_to_refid(prefab_text: str) -> dict[str, int]:
    return {m.group(1): int(m.group(2)) for m in RES_RE.finditer(prefab_text)}


def scan_nonzero_path_refs(prefab_text: str) -> dict[str, int]:
    out: dict[str, int] = {}
    for m in SPRITE_HINT_RE.finditer(prefab_text):
        ref_id = int(m.group(1))
        path = m.group(2)
        if ref_id == 0:
            continue
        prev = out.get(path)
        if prev is not None and prev != ref_id:
            print(f"warning: conflicting refId for {path}: {prev} vs {ref_id}", file=sys.stderr)
            continue
        out[path] = ref_id
    return out


def collect_referenced_texture_paths(prefab_text: str) -> set[str]:
    """Paths this prefab needs in its res{{}} table (editor texture resolution)."""
    paths = set(HINT_RE.findall(prefab_text))
    for m in SPRITE_HINT_RE.finditer(prefab_text):
        paths.add(m.group(2))
    return paths


def build_full_texture_catalog() -> dict[str, int]:
    """Map every static texture path -> refId (for texture_ref_ids.json)."""
    out: dict[str, int] = {}
    for meta in iter_texture_metas():
        rel = meta.relative_to(STATIC).as_posix()
        path = f"static/{rel[:-5]}"
        out[path] = ref_id_from_meta(meta)
    return out


def build_path_to_refid(prefab_text: str, catalog: dict[str, int] | None = None) -> dict[str, int]:
    """Map referenced texture paths in this prefab -> refId from .meta GUIDs."""
    full = catalog if catalog is not None else build_full_texture_catalog()
    referenced = collect_referenced_texture_paths(prefab_text)
    out = {path: full[path] for path in sorted(referenced) if path in full}
    missing = sorted(referenced - out.keys())
    if missing:
        print(f"warning: {len(missing)} referenced texture path(s) have no .meta:", file=sys.stderr)
        for path in missing[:10]:
            print(f"  {path}", file=sys.stderr)

    scanned = scan_nonzero_path_refs(prefab_text)
    for path, ref_id in scanned.items():
        expected = out.get(path)
        if expected is not None and expected != ref_id:
            print(
                f"warning: hash refId for {path} is {expected}, prefab had {ref_id}",
                file=sys.stderr,
            )
    return out


def format_res_entries(path_to_refid: dict[str, int], path_to_guid: dict[str, str]) -> str:
    guid_to_ref = {path_to_guid[p]: r for p, r in path_to_refid.items() if p in path_to_guid}
    lines: list[str] = []
    for guid in sorted(guid_to_ref):
        lines.append("res{")
        lines.append(f'guid:t="{guid}"')
        lines.append("type:i=2")
        lines.append(f"refId:i64={guid_to_ref[guid]}")
        lines.append("}")
    return "\n".join(lines)


def hydrate_prefab(prefab_text: str, path_to_refid: dict[str, int]) -> tuple[str, int, int]:
    updated = 0
    skipped = 0

    def replace_sprite_block(match: re.Match[str]) -> str:
        nonlocal updated, skipped
        block = match.group(0)
        path_m = HINT_RE.search(block)
        if not path_m:
            return block
        path = path_m.group(1)
        ref_id = path_to_refid.get(path)
        if ref_id is None:
            skipped += 1
            return block
        new_block, n = re.subn(
            r"__textureId:i64=-?\d+",
            f"__textureId:i64={ref_id}",
            block,
            count=1,
        )
        if n:
            updated += 1
        return new_block

    # Each sprite child ends with SpriteRenderer + optional TileTextureHint (+ optional PropFootprint)
    block_re = re.compile(
        r"SpriteRenderer\{.*?^\}(?:\nTileTextureHint\{texturePath:t=\"[^\"]+\";\})?",
        re.MULTILINE | re.DOTALL,
    )
    out = block_re.sub(replace_sprite_block, prefab_text)

    # res{{}} only lists textures referenced in this prefab (not the full static catalog).
    path_to_guid = load_path_to_guid()
    res_body = format_res_entries(path_to_refid, path_to_guid)
    if re.search(r"\nres\{", out):
        out = re.sub(r"\nres\{.*", "\n" + res_body, out, count=1, flags=re.DOTALL)
    else:
        out = out.rstrip() + "\n" + res_body + "\n"

    return out, updated, skipped


def fix_grass_uv_rects(prefab_text: str) -> tuple[str, int]:
    fixed = 0

    def replace_block(match: re.Match[str]) -> str:
        nonlocal fixed
        block = match.group(0)
        path_m = HINT_RE.search(block)
        if not path_m:
            return block
        crop = OVERLAY_CROPS.get(path_m.group(1))
        if crop is None:
            return block
        uv = tile_uv_rect_for_layout_in_texture(GROUND_TILE_LAYOUT_CROP, crop)
        uv_s = f"uvRect:p4={uv[0]:.6f}, {uv[1]:.6f}, {uv[2]:.6f}, {uv[3]:.6f}"
        new_block, n = re.subn(r"uvRect:p4=[^\n]+", uv_s, block, count=1)
        if n:
            fixed += 1
        return new_block

    block_re = re.compile(
        r"SpriteRenderer\{.*?^\}(?:\nTileTextureHint\{texturePath:t=\"[^\"]+\";\})?",
        re.MULTILINE | re.DOTALL,
    )
    out = block_re.sub(replace_block, prefab_text)
    return out, fixed


def fix_grass_render_orders(prefab_text: str) -> tuple[str, int]:
    """Raise grass renderOrder into overlay band above all ground tiles."""
    fixed = 0
    cell_re = re.compile(
        r'(node\{\nname:t="cell_(-?\d+)_(-?\d+)".*?)(?=\nnode\{\nname:t="cell_|\nres\{)',
        re.S,
    )

    def fix_cell(match: re.Match[str]) -> str:
        nonlocal fixed
        cell = match.group(1)
        ground = re.search(r'name:t="ground".*?renderOrder:i=(\d+)', cell, re.S)
        if not ground:
            return cell
        target = int(ground.group(1)) + DEPTH_TILE_GRASS_BIAS

        def repl_grass(m: re.Match[str]) -> str:
            nonlocal fixed
            current = int(m.group(2))
            if current != target:
                fixed += 1
            return f"{m.group(1)}{target}"

        new_cell = re.sub(
            r'(name:t="grass".*?renderOrder:i=)(-?\d+)',
            repl_grass,
            cell,
            count=1,
            flags=re.S,
        )
        return new_cell

    out = cell_re.sub(fix_cell, prefab_text)
    return out, fixed


def save_ref_ids_json(path_to_refid: dict[str, int]) -> None:
    import json

    merged = dict(path_to_refid)
    if REF_IDS_JSON.exists():
        existing = json.loads(REF_IDS_JSON.read_text(encoding="utf-8"))
        for key, val in existing.items():
            merged.setdefault(key, val)

    REF_IDS_JSON.write_text(
        json.dumps(merged, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def hydrate_prefab_file(prefab_path: Path, *, patches: bool = True) -> int:
    if not prefab_path.exists():
        print(f"missing {prefab_path}", file=sys.stderr)
        return 1

    prefab_text = prefab_path.read_text(encoding="utf-8")
    catalog = build_full_texture_catalog()
    save_ref_ids_json(catalog)
    path_to_refid = build_path_to_refid(prefab_text, catalog)
    referenced = collect_referenced_texture_paths(prefab_text)

    print(
        f"[{prefab_path.name}] referenced textures: {len(referenced)}, "
        f"res{{}} entries: {len(path_to_refid)} (catalog: {len(catalog)})"
    )

    if patches and prefab_path.name == "level_1.prefab":
        from patch_grass_overlays import patch_grass_overlays

        prefab_text, overlay_kinds, overlay_patched = patch_grass_overlays(prefab_text)
        print(f"patched grass overlays: {overlay_patched}")

        from patch_walls_prefab import patch_walls

        prefab_text, walls_added = patch_walls(prefab_text, catalog)
        print(f"inserted border wall nodes: {walls_added}" if walls_added else "border walls already present")

        from patch_player_prefab import patch_player, patch_player_texture

        prefab_text, player_texture_updated = patch_player_texture(prefab_text)
        if player_texture_updated:
            print("updated player texture to Kreol Idle")
        prefab_text, player_added = patch_player(prefab_text)
        print("inserted player node" if player_added else "player node already present")

    new_text, updated, skipped = hydrate_prefab(prefab_text, path_to_refid)
    if patches and prefab_path.name == "level_1.prefab":
        new_text, grass_fixed = fix_grass_uv_rects(new_text)
        new_text, grass_depth_fixed = fix_grass_render_orders(new_text)
        print(f"fixed grass uvRect: {grass_fixed}, renderOrder: {grass_depth_fixed}")
    else:
        grass_fixed = grass_depth_fixed = 0

    prefab_path.write_text(new_text, encoding="utf-8", newline="\n")
    print(f"updated SpriteRenderer blocks: {updated}, skipped: {skipped}")
    return 0


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--prefab",
        type=Path,
        action="append",
        help="Prefab to hydrate (default: level_1.prefab and base.prefab)",
    )
    parser.add_argument(
        "--hydrate-only",
        action="store_true",
        help="Only refresh __textureId and res{{}} entries (no grass/wall/player patches)",
    )
    args = parser.parse_args()

    prefabs = args.prefab or [
        PROJECT / "prefabs" / "level_1.prefab",
        PROJECT / "prefabs" / "base.prefab",
    ]
    rc = 0
    for path in prefabs:
        if hydrate_prefab_file(path, patches=not args.hydrate_only) != 0:
            rc = 1
    return rc


def _main_legacy() -> int:
    if not PREFAB.exists():
        print(f"missing {PREFAB}", file=sys.stderr)
        return 1

    prefab_text = PREFAB.read_text(encoding="utf-8")
    catalog = build_full_texture_catalog()
    save_ref_ids_json(catalog)
    path_to_refid = build_path_to_refid(prefab_text, catalog)

    print(f"referenced texture path -> refId mappings: {len(path_to_refid)}")
    for path in sorted(path_to_refid):
        print(f"  {path} -> {path_to_refid[path]}")

    hints = set(HINT_RE.findall(prefab_text))
    unmapped = sorted(h for h in hints if h not in path_to_refid)
    if unmapped:
        print(f"unmapped texture paths ({len(unmapped)}):")
        for path in unmapped:
            print(f"  {path}")

    from patch_grass_overlays import patch_grass_overlays

    prefab_text, overlay_kinds, overlay_patched = patch_grass_overlays(prefab_text)
    print(f"patched grass overlays: {overlay_patched}")
    for kind, count in sorted(overlay_kinds.items()):
        print(f"  {kind}: {count}")

    from patch_walls_prefab import patch_walls

    prefab_text, walls_added = patch_walls(prefab_text, path_to_refid)
    if walls_added:
        print(f"inserted ~{walls_added} wall nodes")
    else:
        print("walls node already populated")

    from patch_player_prefab import patch_player

    prefab_text, player_added = patch_player(prefab_text)
    if player_added:
        print("inserted player node")
    else:
        print("player node already present")

    new_text, updated, skipped = hydrate_prefab(prefab_text, path_to_refid)
    new_text, grass_fixed = fix_grass_uv_rects(new_text)
    new_text, grass_depth_fixed = fix_grass_render_orders(new_text)
    PREFAB.write_text(new_text, encoding="utf-8", newline="\n")
    print(f"updated SpriteRenderer blocks: {updated}")
    print(f"fixed grass uvRect values: {grass_fixed}")
    print(f"fixed grass renderOrder values: {grass_depth_fixed}")
    print(f"left unchanged (no mapping): {skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
