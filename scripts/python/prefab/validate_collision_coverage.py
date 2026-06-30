#!/usr/bin/env python3
"""Report level prefab sprites missing baked collision library entries."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
PREFAB = PROJECT / "prefabs" / "level_1.prefab"
MANIFEST = PROJECT / "scripts" / "python" / "data" / "collision_library_manifest.json"
LIBRARY_DAS = PROJECT / "scripts" / "das" / "data" / "collision_library_data.das"

HINT_RE = re.compile(r'TileTextureHint\{texturePath:t="([^"]+)";\}')
PATH_RE = re.compile(r'"([^"]+)"')


def load_library_paths() -> set[str]:
    if not LIBRARY_DAS.is_file():
        return set()
    text = LIBRARY_DAS.read_text(encoding="utf-8")
    start = text.find("COLLISION_TEX_PATHS")
    if start < 0:
        return set()
    block = text[start : text.find("]", start) + 1]
    return set(PATH_RE.findall(block))


def main() -> int:
    if not PREFAB.is_file():
        print(f"missing {PREFAB}", file=sys.stderr)
        return 1

    prefab_text = PREFAB.read_text(encoding="utf-8")
    hints = HINT_RE.findall(prefab_text)
    unique_hints = sorted(set(hints))
    library_paths = load_library_paths()

    covered = [p for p in unique_hints if p in library_paths]
    missing = [p for p in unique_hints if p not in library_paths]

    manifest_note = ""
    if MANIFEST.is_file():
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest_note = (
            f"library manifest: {manifest.get('asset_count', '?')} assets "
            f"(baked {manifest.get('baked_at', '?')})"
        )

    print(f"level_1.prefab unique TileTextureHint paths: {len(unique_hints)}")
    print(f"with baked collision segments: {len(covered)}")
    print(f"missing collision data: {len(missing)}")
    if manifest_note:
        print(manifest_note)

    if missing:
        print("\nMissing paths (first 40):")
        for path in missing[:40]:
            print(f"  {path}")
        if len(missing) > 40:
            print(f"  ... and {len(missing) - 40} more")
        return 1

    print("all placed texture paths have collision library entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
