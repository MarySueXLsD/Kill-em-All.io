#!/usr/bin/env python3
"""Rename map base tile nodes from a1 to ground in level_1.prefab."""
from pathlib import Path

PREFAB = Path(__file__).resolve().parents[3] / "prefabs" / "level_1.prefab"
OLD = 'name:t="a1"'
NEW = 'name:t="ground"'


def main() -> int:
    text = PREFAB.read_text(encoding="utf-8")
    count = text.count(OLD)
    if count == 0:
        print("no a1 nodes found")
        return 0
    PREFAB.write_text(text.replace(OLD, NEW), encoding="utf-8", newline="\n")
    print(f"renamed {count} nodes: a1 -> ground")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
