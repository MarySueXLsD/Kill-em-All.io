"""One-use: move static/Environment assets into category subfolders and shorten names.

Example:
  Ground A1_E.png  ->  Ground/A1_E.png
  Chest A1_N.png   ->  Chest/A1_N.png
  Shadow10_E.png   ->  Shadow10/E.png
  BLACK TILE.png   ->  BLACK/TILE.png

Removes the first word (before the first underscore, or before the first space)
from the filename when moving into a folder named after that word.

Usage:
  python scripts/python/assets/reorganize_environment_assets.py --dry-run
  python scripts/python/assets/reorganize_environment_assets.py
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
ENV = PROJECT / "static" / "Environment"

REF_GLOBS = ("*.das", "*.prefab", "*.json", "*.py", "*.blk")


def categorize(filename: str) -> tuple[str, str] | None:
    """Return (folder_name, new_filename) or None to skip."""
    stem, ext = Path(filename).stem, Path(filename).suffix
    if not stem:
        return None

    if "_" in stem:
        first_word = stem.split("_", 1)[0].split()[0]
        new_stem = stem[len(first_word) :].lstrip(" _")
        if not new_stem:
            return None
        return first_word, f"{new_stem}{ext}"

    if " " in stem:
        first_word, rest = stem.split(" ", 1)
        return first_word, f"{rest}{ext}"

    return stem, filename


def collect_moves() -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []
    for path in sorted(ENV.iterdir()):
        if not path.is_file():
            continue
        if path.name.endswith(".meta"):
            continue

        cat = categorize(path.name)
        if cat is None:
            print(f"skip (unparsed): {path.name}", file=sys.stderr)
            continue

        folder, new_name = cat
        dest_dir = ENV / folder
        dest = dest_dir / new_name
        if dest == path:
            continue
        if dest.exists():
            raise FileExistsError(f"destination already exists: {dest}")

        moves.append((path, dest))

        meta = path.with_name(path.name + ".meta")
        if meta.is_file():
            dest_meta = dest_dir / f"{new_name}.meta"
            if dest_meta.exists():
                raise FileExistsError(f"meta destination already exists: {dest_meta}")
            moves.append((meta, dest_meta))

    return moves


def path_mapping(moves: list[tuple[Path, Path]]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for src, dest in moves:
        if src.suffix == ".meta":
            continue
        old_rel = src.relative_to(PROJECT).as_posix()
        new_rel = dest.relative_to(PROJECT).as_posix()
        mapping[old_rel] = new_rel
    return mapping


def update_references(mapping: dict[str, str], dry_run: bool) -> int:
    if not mapping:
        return 0

    files: list[Path] = []
    for pattern in REF_GLOBS:
        files.extend(PROJECT.rglob(pattern))

    # Skip this script so a second dry-run still sees old paths in its docstring examples.
    self_path = Path(__file__).resolve()
    files = [p for p in files if p.resolve() != self_path]

    replacements = sorted(mapping.items(), key=lambda kv: len(kv[0]), reverse=True)
    touched = 0
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        new_text = text
        for old, new in replacements:
            new_text = new_text.replace(old, new)
        if new_text != text:
            touched += 1
            if not dry_run:
                path.write_text(new_text, encoding="utf-8", newline="\n")
    return touched


def apply_moves(moves: list[tuple[Path, Path]], dry_run: bool) -> None:
    for src, dest in moves:
        if dry_run:
            print(f"  {src.relative_to(PROJECT)}  ->  {dest.relative_to(PROJECT)}")
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        src.rename(dest)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print planned moves and reference updates without writing",
    )
    args = parser.parse_args()

    moves = collect_moves()
    mapping = path_mapping(moves)

    print(f"Assets to move: {len([m for m in moves if not m[0].name.endswith('.meta')])}")
    print(f"Folders: {len({m[1].parent for m in moves})}")
    print(f"Path rewrites: {len(mapping)}")

    if args.dry_run:
        print("\nMoves:")
    apply_moves(moves, args.dry_run)

    ref_files = update_references(mapping, args.dry_run)
    print(f"Reference files {'to update' if args.dry_run else 'updated'}: {ref_files}")

    if args.dry_run:
        print("\nDry run only — no files changed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
