#!/usr/bin/env python3
"""Set Point filtering on static/Environment texture .meta files (crisp pixels)."""
from __future__ import annotations

import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
ENV = PROJECT / "static" / "Environment"

OLD = 'filter:t="Bilinear"'
NEW = 'filter:t="Point"'
ALSO = ('addressing:t="Wrap"', 'addressing:t="Clamp"')
DISABLE_MIP = ('generateMipLevels:b=yes', 'generateMipLevels:b=no')


def patch_meta(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if OLD not in text:
        return False
    text = text.replace(OLD, NEW, 1)
    if 'addressing:t="Wrap"' in text:
        text = text.replace('addressing:t="Wrap"', 'addressing:t="Clamp"', 1)
    if "generateMipLevels:b=yes" in text:
        text = text.replace("generateMipLevels:b=yes", "generateMipLevels:b=no", 1)
    if "anisotropicLevel:i=4" in text:
        text = text.replace("anisotropicLevel:i=4", "anisotropicLevel:i=1", 1)
    path.write_text(text, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    count = 0
    for meta in sorted(ENV.rglob("*.png.meta")):
        if patch_meta(meta):
            count += 1
        if count and count % 500 == 0:
            print(f"  {count}...")
    print(f"updated {count} Environment .meta files to Point filter")
    return 0


if __name__ == "__main__":
    sys.exit(main())
