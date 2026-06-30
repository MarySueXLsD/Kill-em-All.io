"""Encode/decode static/Environment variant texture filenames."""
from __future__ import annotations

import re
from pathlib import Path

DIRECTION_TO_NAME = {"E": "East", "N": "North", "S": "South", "W": "West"}
NAME_TO_DIRECTION = {v: k for k, v in DIRECTION_TO_NAME.items()}

OLD_VARIANT_RE = re.compile(r"^([A-Z])(\d+)_([ENSW])\.png$", re.IGNORECASE)
OLD_DIRECTION_ONLY_RE = re.compile(r"^([ENSW])\.png$", re.IGNORECASE)
NEW_VARIANT_RE = re.compile(
    r"^Type_(\d+)_Variation_(\d+)_(East|North|South|West)\.png$",
    re.IGNORECASE,
)
SHADOW_FOLDER_RE = re.compile(r"^Shadow(\d+)$", re.IGNORECASE)


def type_letter_to_num(letter: str) -> int:
    return ord(letter.upper()) - ord("A") + 1


def num_to_type_letter(type_num: int) -> str:
    return chr(ord("A") + type_num - 1)


def variant_stem(type_num: int, variation: int) -> str:
    return f"Type_{type_num}_Variation_{variation}"


def encode_variant_filename(letter: str, variation: int, direction: str) -> str:
    type_num = type_letter_to_num(letter)
    dir_name = DIRECTION_TO_NAME[direction.upper()]
    return f"{variant_stem(type_num, variation)}_{dir_name}.png"


def environment_texture_rel(category: str, letter: str, variation: int, direction: str) -> str:
    return f"static/Environment/{category}/{encode_variant_filename(letter, variation, direction)}"


def encode_variant_basename(letter: str, variation: int, direction: str) -> str:
    return encode_variant_filename(letter, variation, direction)[:-4]


def decode_variant_filename(filename: str) -> tuple[int, int, str] | None:
    """Return (type_num, variation, direction_letter) or None."""
    m = NEW_VARIANT_RE.match(filename)
    if not m:
        return None
    type_num, variation, dir_name = int(m.group(1)), int(m.group(2)), m.group(3)
    direction = NAME_TO_DIRECTION.get(dir_name.title())
    if not direction:
        return None
    return type_num, variation, direction


def variant_family_from_filename(filename: str) -> str | None:
    """Stem shared by all facings, e.g. Type_2_Variation_12."""
    m = NEW_VARIANT_RE.match(filename)
    if not m:
        return None
    return variant_stem(int(m.group(1)), int(m.group(2)))


def new_filename_for_asset(path: Path, env_root: Path) -> str | None:
    """Map an on-disk Environment PNG to its new filename, or None to keep."""
    name = path.name
    folder = path.parent.name if path.parent != env_root else ""

    m = OLD_VARIANT_RE.match(name)
    if m:
        letter, variation, direction = m.group(1), int(m.group(2)), m.group(3).upper()
        return encode_variant_filename(letter, variation, direction)

    shadow = SHADOW_FOLDER_RE.match(folder)
    if shadow:
        dm = OLD_DIRECTION_ONLY_RE.match(name)
        if dm:
            variation = int(shadow.group(1))
            return encode_variant_filename("A", variation, dm.group(1).upper())

    if folder == "Torch":
        if name == "East.png":
            return encode_variant_filename("A", 1, "E")
        if name == "West.png":
            return encode_variant_filename("A", 1, "W")

    if name == "Torch2.png":
        return f"{variant_stem(1, 2)}.png"

    if name in {"FirePlace.png", "TilePreview.png", "TreeTrunkBroken.png", "Shadow.png"}:
        return f"{variant_stem(1, 1)}.png"

    return None
