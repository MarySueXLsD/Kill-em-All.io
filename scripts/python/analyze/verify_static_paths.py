#!/usr/bin/env python3
"""Verify all static texture paths referenced in .das files exist on disk."""
from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
LEGACY_MARKERS = (
    "static/Characters/Player/",
    "static/Characters/skeleton_sword",
    "static/Characters/skeleton_mage",
    "static/Characters/death_knight/",
    "Bars and HPs",
)


def main() -> int:
    paths: set[str] = set()
    for das in (PROJECT / "scripts" / "das").rglob("*.das"):
        paths.update(re.findall(r'"(static/[^"]+\.png)"', das.read_text(encoding="utf-8")))

    missing = sorted(p for p in paths if not (PROJECT / p).exists())
    legacy = sorted(p for p in paths if any(m in p for m in LEGACY_MARKERS))

    print(f"Total static PNG refs: {len(paths)}")
    print(f"Missing on disk: {len(missing)}")
    for p in missing:
        print(f"  MISSING {p}")
    print(f"Legacy paths still in code: {len(legacy)}")
    for p in legacy:
        print(f"  LEGACY {p}")

    return 1 if missing or legacy else 0


if __name__ == "__main__":
    raise SystemExit(main())
