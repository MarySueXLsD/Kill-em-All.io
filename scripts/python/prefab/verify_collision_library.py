#!/usr/bin/env python3
"""Sanity checks for baked collision library integration."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
COLLISION_JSON = PROJECT / "tools" / "collision-editor" / "collision_data.json"
LIBRARY_DAS = PROJECT / "scripts" / "das" / "data" / "collision_library_data.das"
PREFAB = PROJECT / "prefabs" / "level_1.prefab"


def main() -> int:
    raw = json.loads(COLLISION_JSON.read_text(encoding="utf-8"))
    with_segments = {
        k: v for k, v in raw.items() if isinstance(v, dict) and (v.get("segments") or [])
    }
    das = LIBRARY_DAS.read_text(encoding="utf-8")
    count_match = re.search(r"COLLISION_ASSET_COUNT = (\d+)", das)
    if not count_match:
        print("COLLISION_ASSET_COUNT missing in generated das", file=sys.stderr)
        return 1
    baked_count = int(count_match.group(1))
    if baked_count != len(with_segments):
        print(
            f"asset count mismatch: baked {baked_count} vs json segments {len(with_segments)}",
            file=sys.stderr,
        )
        return 1

    prefab = PREFAB.read_text(encoding="utf-8")
    wall_hints = {
        m.group(1)
        for m in re.finditer(r'TileTextureHint\{texturePath:t="([^"]+)";\}', prefab)
        if "/Wall/" in m.group(1)
    }
    paths_in_das = set(re.findall(r'"([^"]+)"', das))
    missing_walls = sorted(wall_hints - paths_in_das)
    if missing_walls:
        print("wall textures in prefab without baked collision:", file=sys.stderr)
        for p in missing_walls[:10]:
            print(f"  {p}", file=sys.stderr)
        return 1

    low_count = len([v for v in with_segments.values() if v.get("low")])
    print(f"ok: {baked_count} baked assets, {low_count} low obstacles")
    print(f"ok: all {len(wall_hints)} wall texture paths in level_1 have collision data")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
