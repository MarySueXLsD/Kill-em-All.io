"""One-use: rename Environment variant PNGs to Type_N_Variation_N_Direction style.

Examples:
  Ground/A1_N.png       ->  Ground/Type_1_Variation_1_North.png
  Misc/B12_E.png          ->  Misc/Type_2_Variation_12_East.png
  Shadow10/E.png          ->  Shadow10/Type_1_Variation_10_East.png
  Torch/East.png          ->  Torch/Type_1_Variation_1_East.png

Also rewrites every reference under the project (das, prefab, json, py, blk, md).

Usage:
  python scripts/python/assets/rename_environment_variants.py --dry-run
  python scripts/python/assets/rename_environment_variants.py
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_TOOLS_ROOT))

from lib.environment_texture_names import new_filename_for_asset

PROJECT = Path(__file__).resolve().parents[3]
ENV = PROJECT / "static" / "Environment"

REF_SUFFIXES = {".das", ".prefab", ".json", ".py", ".blk", ".md", ".txt", ".csv"}


def collect_renames() -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []
    for path in sorted(ENV.rglob("*.png")):
        new_name = new_filename_for_asset(path, ENV)
        if new_name is None or new_name == path.name:
            continue
        dest = path.with_name(new_name)
        if dest.exists():
            raise FileExistsError(f"destination exists: {dest}")
        moves.append((path, dest))
        meta = path.with_name(path.name + ".meta")
        if meta.is_file():
            dest_meta = dest.with_name(new_name + ".meta")
            if dest_meta.exists():
                raise FileExistsError(f"meta destination exists: {dest_meta}")
            moves.append((meta, dest_meta))
    return moves


def path_mapping(moves: list[tuple[Path, Path]]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for src, dest in moves:
        if src.suffix == ".meta":
            continue
        mapping[src.relative_to(PROJECT).as_posix()] = dest.relative_to(PROJECT).as_posix()
    return mapping


def iter_reference_files() -> list[Path]:
    self_path = Path(__file__).resolve()
    lib_path = (_TOOLS_ROOT / "lib" / "environment_texture_names.py").resolve()
    files: list[Path] = []
    for path in PROJECT.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in REF_SUFFIXES:
            continue
        resolved = path.resolve()
        if resolved in {self_path, lib_path}:
            continue
        files.append(path)
    return files


def update_references(mapping: dict[str, str], dry_run: bool) -> int:
    if not mapping:
        return 0
    replacements = sorted(mapping.items(), key=lambda kv: len(kv[0]), reverse=True)
    touched = 0
    for path in iter_reference_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        new_text = text
        for old, new in replacements:
            new_text = new_text.replace(old, new)
        if new_text != text:
            touched += 1
            if not dry_run:
                path.write_text(new_text, encoding="utf-8", newline="\n")
    return touched


def apply_renames(moves: list[tuple[Path, Path]], dry_run: bool) -> None:
    for src, dest in moves:
        if dry_run:
            print(f"  {src.relative_to(PROJECT)}  ->  {dest.name}")
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        src.rename(dest)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    moves = collect_renames()
    mapping = path_mapping(moves)
    png_count = len([m for m in moves if m[0].suffix == ".png"])

    print(f"PNG renames: {png_count}")
    print(f"Path mapping entries: {len(mapping)}")

    if args.dry_run:
        print("\nSample renames:")
        for src, dest in moves[:12]:
            if src.suffix == ".png":
                print(f"  {src.relative_to(PROJECT)}  ->  {dest.name}")
        if png_count > 12:
            print(f"  ... and {png_count - 12} more")

    apply_renames(moves, args.dry_run)
    ref_count = update_references(mapping, args.dry_run)
    print(f"Reference files {'to update' if args.dry_run else 'updated'}: {ref_count}")

    if args.dry_run:
        print("\nDry run only — no files changed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
