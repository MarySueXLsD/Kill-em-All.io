#!/usr/bin/env python3
"""Ensure .meta sidecars for referenced textures and rebuild texture_ref_ids.json."""
from __future__ import annotations

import json
import re
import sys
import uuid
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_TOOLS_ROOT))

from lib.resource_link_hash import ref_id_from_meta

PROJECT = Path(__file__).resolve().parents[3]
DAS_CORE = PROJECT / "scripts" / "das" / "core"
REF_IDS_JSON = PROJECT / "scripts" / "python" / "data" / "texture_ref_ids.json"

META_TEMPLATE = """guid:t="{guid}"
assetType:i=0
filter:t="Point"
addressing:t="Clamp"
anisotropicLevel:i=1
sRGB:b=yes
generateMipLevels:b=no
format:t="A8R8G8B8"
"""


def referenced_texture_paths() -> set[str]:
    used: set[str] = set()
    for das in DAS_CORE.glob("constants*.das"):
        text = das.read_text(encoding="utf-8")
        used.update(re.findall(r'"(static/(?:Characters|UI|Effects)/[^"]+\.png)"', text))
    return used


def ensure_metas(paths: set[str]) -> int:
    created = 0
    for rel in sorted(paths):
        png = PROJECT / Path(rel)
        meta = Path(str(png) + ".meta")
        if not png.exists():
            print(f"warning: missing PNG {rel}", file=sys.stderr)
            continue
        if meta.exists():
            continue
        meta.write_text(META_TEMPLATE.format(guid=str(uuid.uuid4())), encoding="utf-8", newline="\n")
        created += 1
    return created


def build_ref_ids() -> dict[str, int]:
    out: dict[str, int] = {}
    for meta in sorted((PROJECT / "static").rglob("*.png.meta")):
        rel = meta.relative_to(PROJECT / "static").as_posix()
        path = f"static/{rel[:-5]}"
        out[path] = ref_id_from_meta(meta)
    return out


def main() -> int:
    paths = referenced_texture_paths()
    created = ensure_metas(paths)
    ref_ids = build_ref_ids()
    REF_IDS_JSON.write_text(json.dumps(ref_ids, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"created {created} meta files")
    print(f"wrote {len(ref_ids)} texture ref IDs to {REF_IDS_JSON.relative_to(PROJECT)}")
    missing = [p for p in sorted(paths) if p not in ref_ids]
    if missing:
        print("still missing ref IDs:", file=sys.stderr)
        for p in missing:
            print(f"  {p}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
