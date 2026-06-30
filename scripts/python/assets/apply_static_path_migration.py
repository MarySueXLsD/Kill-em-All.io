#!/usr/bin/env python3
"""Rewrite static asset paths across das, prefab, json, py, and docs."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_TOOLS_ROOT))

from lib.static_path_migration import rewrite_text

PROJECT = Path(__file__).resolve().parents[3]
REF_SUFFIXES = {".das", ".prefab", ".json", ".py", ".blk", ".md", ".txt", ".csv"}
SKIP_NAMES = {"apply_static_path_migration.py", "static_path_migration.py"}


def iter_files() -> list[Path]:
    files: list[Path] = []
    for path in PROJECT.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in REF_SUFFIXES:
            continue
        if path.name in SKIP_NAMES:
            continue
        if ".project" in path.parts:
            continue
        files.append(path)
    return files


def migrate_texture_ref_ids(dry_run: bool) -> int:
    path = PROJECT / "scripts" / "python" / "data" / "texture_ref_ids.json"
    if not path.exists():
        return 0
    raw = json.loads(path.read_text(encoding="utf-8"))
    new_raw: dict[str, int] = {}
    changed = 0
    for key, val in raw.items():
        new_key = rewrite_text(key)
        if new_key != key:
            changed += 1
        if new_key in new_raw and new_raw[new_key] != val:
            print(f"warning: duplicate ref id key {new_key}", file=sys.stderr)
        new_raw[new_key] = val
    if changed and not dry_run:
        path.write_text(json.dumps(new_raw, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    touched = 0
    for path in iter_files():
        if path.name == "texture_ref_ids.json":
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        new_text = rewrite_text(text)
        if new_text != text:
            touched += 1
            rel = path.relative_to(PROJECT)
            print(f"{'would update' if args.dry_run else 'updated'} {rel}")
            if not args.dry_run:
                path.write_text(new_text, encoding="utf-8", newline="\n")

    ref_changes = migrate_texture_ref_ids(args.dry_run)
    print(f"texture_ref_ids keys rewritten: {ref_changes}")
    print(f"files touched: {touched}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
