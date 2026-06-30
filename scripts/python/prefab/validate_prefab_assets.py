#!/usr/bin/env python3
"""Validate level prefab texture paths, parent uids, and res section consistency."""
from __future__ import annotations

import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from lib.resource_link_hash import ref_id_from_meta

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
STATIC = PROJECT / "static"

GUID_RE = re.compile(r'^guid:t="([^"]+)"', re.M)
SPRITE_HINT_RE = re.compile(
    r"SpriteRenderer\{[^}]*__textureId:i64=(-?\d+)[^}]*\}\s*"
    r'TileTextureHint\{texturePath:t="([^"]+)";\}',
    re.DOTALL,
)


def validate_prefab(prefab_path: Path) -> int:
    text = prefab_path.read_text(encoding="utf-8")
    res_start = text.find("\nres{")
    nodes_text = text[:res_start] if res_start >= 0 else text
    res_text = text[res_start:] if res_start >= 0 else ""

    uids: set[int] = set()
    parents: dict[int, int] = {}
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
        body = nodes_text[start + 5 : j - 1]
        um = re.search(r"uid:i=(\d+)", body)
        pm = re.search(r"parent:i=(\d+)", body)
        if um:
            uid = int(um.group(1))
            uids.add(uid)
            if pm:
                parents[uid] = int(pm.group(1))
        i = j

    missing_parents = sorted({p for p in parents.values() if p not in uids})
    print(f"[{prefab_path.name}] nodes: {len(uids)}")
    print(f"missing parent uids: {len(missing_parents)}")
    if missing_parents[:10]:
        print("  examples:", missing_parents[:10])

    hints = re.findall(r'TileTextureHint\{texturePath:t="([^"]+)";\}', text)
    unique_hints = sorted(set(hints))
    missing_png: list[str] = []
    missing_meta: list[str] = []
    for h in unique_hints:
        png = PROJECT / h
        if not png.exists():
            missing_png.append(h)
        if not Path(str(png) + ".meta").exists():
            missing_meta.append(h)
    print(f"texture hints: {len(unique_hints)} unique")
    print(f"missing png: {len(missing_png)}")
    print(f"missing meta: {len(missing_meta)}")
    for path in (missing_png + missing_meta)[:20]:
        print(f"  {path}")

    res_ref_ids = {int(m.group(1)) for m in re.finditer(r"refId:i64=(-?\d+)", res_text)}
    sprite_ref_ids = {int(m.group(1)) for m in re.finditer(r"__textureId:i64=(-?\d+)", nodes_text)}
    orphan_sprites = sorted(sprite_ref_ids - res_ref_ids)
    zero_sprites = sum(1 for m in re.finditer(r"__textureId:i64=0", nodes_text))
    print(f"res entries: {len(res_ref_ids)}")
    print(f"sprite refIds not in res: {len(orphan_sprites)}")
    print(f"zero texture ids: {zero_sprites}")
    if orphan_sprites[:10]:
        print("  orphan examples:", orphan_sprites[:10])

    res_bloat = len(res_ref_ids) - len(unique_hints)
    print(f"res bloat (res entries - unique hints): {res_bloat}")
    if res_bloat > 0:
        print(f"  warning: res{{}} has {res_bloat} more entries than unique TileTextureHint paths")

    guid_to_meta: dict[str, Path] = {}
    for meta in STATIC.rglob("*.png.meta"):
        m = GUID_RE.search(meta.read_text(encoding="utf-8"))
        if m:
            guid_to_meta[m.group(1)] = meta

    res_guids = re.findall(r'guid:t="([^"]+)"', res_text)
    missing_res_meta = [g for g in res_guids if g not in guid_to_meta]
    print(f"res guids without .meta: {len(missing_res_meta)}")
    for g in missing_res_meta[:10]:
        print(f"  {g}")

    refid_mismatch: list[tuple[str, int, int]] = []
    for m in SPRITE_HINT_RE.finditer(nodes_text):
        sprite_id, path = int(m.group(1)), m.group(2)
        meta = PROJECT / Path(path)
        meta_path = Path(str(meta) + ".meta")
        if not meta_path.exists():
            continue
        expected = ref_id_from_meta(meta_path)
        if expected != sprite_id:
            refid_mismatch.append((path, sprite_id, expected))
    print(f"sprite __textureId vs meta hash mismatches: {len(refid_mismatch)}")
    for path, got, expected in refid_mismatch[:10]:
        print(f"  {path}: prefab={got}, meta={expected}")

    res_refid_mismatch = 0
    for guid, ref_id in re.findall(
        r'guid:t="([^"]+)".*?refId:i64=(-?\d+)', res_text, re.S
    ):
        meta = guid_to_meta.get(guid)
        if meta is None:
            continue
        expected = ref_id_from_meta(meta)
        if int(ref_id) != expected:
            res_refid_mismatch += 1
            if res_refid_mismatch <= 10:
                print(f"  res mismatch {guid}: prefab={ref_id}, meta={expected}")
    print(f"res refId vs meta hash mismatches: {res_refid_mismatch}")

    failed = bool(
        missing_parents
        or missing_png
        or missing_meta
        or orphan_sprites
        or missing_res_meta
        or refid_mismatch
        or res_refid_mismatch
        or res_bloat > 0
    )
    return 1 if failed else 0


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--prefab",
        type=Path,
        action="append",
        help="Prefab to validate (default: level_1.prefab)",
    )
    args = parser.parse_args()
    prefabs = args.prefab or [PREFAB]
    rc = 0
    for path in prefabs:
        if validate_prefab(path) != 0:
            rc = 1
        print()
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
