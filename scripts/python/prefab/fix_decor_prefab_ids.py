#!/usr/bin/env python3
"""Set __textureId and res{} entries for decor_tree/decor_misc prefab nodes only."""
from __future__ import annotations

import re
import sys
from pathlib import Path

from lib.resource_link_hash import parse_meta, ref_id_from_meta

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
STATIC = PROJECT / "static"

DECOR_NODE_RE = re.compile(
    r'(node\{\nname:t="decor_(?:tree|misc)_\d+".*?'
    r'SpriteRenderer\{\n__textureId:i64=)(-?\d+)('
    r'.*?TileTextureHint\{texturePath:t="([^"]+)";\}\n\})',
    re.DOTALL,
)
RES_RE = re.compile(
    r'res\{\s*guid:t="([^"]+)"\s*type:i=\d+\s*refId:i64=(-?\d+)\s*\}',
    re.MULTILINE,
)
GUID_RE = re.compile(r'^guid:t="([^"]+)"', re.MULTILINE)


def meta_for_path(texture_path: str) -> Path | None:
    if not texture_path.startswith("static/"):
        return None
    meta = STATIC / (texture_path[7:] + ".meta")
    return meta if meta.is_file() else None


def existing_res_guids(text: str) -> set[str]:
    return set(RES_RE.findall(text))


def append_res_entries(text: str, entries: list[tuple[str, int]]) -> str:
    if not entries:
        return text
    block = "".join(
        f'res{{\nguid:t="{guid}"\ntype:i=2\nrefId:i64={ref_id}\n}}\n' for guid, ref_id in entries
    )
    pos = text.rfind("\nres{")
    if pos < 0:
        return text.rstrip() + "\n" + block
    # Insert before first res{ in trailing res section
    return text[:pos] + "\n" + block + text[pos:]


def main() -> int:
    if not PREFAB.is_file():
        print("missing level_1.prefab", file=sys.stderr)
        return 1

    text = PREFAB.read_text(encoding="utf-8")
    have_guids = {g for g, _ in RES_RE.findall(text)}
    to_add: list[tuple[str, int]] = []
    path_cache: dict[str, tuple[str, int]] = {}
    updated = 0
    missing_meta: list[str] = []

    def replace(m: re.Match[str]) -> str:
        nonlocal updated
        prefix, _old_id, mid, path = m.group(1), m.group(2), m.group(3), m.group(4)
        if path not in path_cache:
            meta = meta_for_path(path)
            if meta is None:
                missing_meta.append(path)
                path_cache[path] = ("", 0)
            else:
                guid, _ = parse_meta(meta)
                ref_id = ref_id_from_meta(meta)
                path_cache[path] = (guid, ref_id)
                if guid not in have_guids:
                    to_add.append((guid, ref_id))
                    have_guids.add(guid)
        guid, ref_id = path_cache[path]
        if ref_id == 0:
            return m.group(0)
        updated += 1
        return f"{prefix}{ref_id}{mid}"

    new_text = DECOR_NODE_RE.sub(replace, text)
    new_text = append_res_entries(new_text, to_add)
    PREFAB.write_text(new_text, encoding="utf-8", newline="\n")

    print(f"decor nodes updated: {updated}")
    print(f"res entries added: {len(to_add)}")
    if missing_meta:
        print(f"missing .meta ({len(missing_meta)}):")
        for p in missing_meta[:10]:
            print(f"  {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
