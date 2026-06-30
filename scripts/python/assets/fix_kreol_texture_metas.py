#!/usr/bin/env python3
"""Align Kreol sprite .meta files with other 2D character imports (Point + Clamp)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
KREOL = PROJECT / "static" / "Characters" / "playable_character_kreol"

TEMPLATE = """guid:t="{guid}"
assetType:i=0
filter:t="Point"
addressing:t="Clamp"
anisotropicLevel:i=1
sRGB:b=yes
generateMipLevels:b=no
format:t="A8R8G8B8"
"""


def main() -> int:
    if not KREOL.is_dir():
        print(f"missing {KREOL}", file=sys.stderr)
        return 1
    updated = 0
    for meta in sorted(KREOL.glob("*.png.meta")):
        text = meta.read_text(encoding="utf-8")
        match = re.search(r'guid:t="([^"]+)"', text)
        if not match:
            print(f"skip (no guid): {meta.name}", file=sys.stderr)
            continue
        meta.write_text(TEMPLATE.format(guid=match.group(1)), encoding="utf-8", newline="\n")
        updated += 1
    print(f"updated {updated} kreol texture metas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
