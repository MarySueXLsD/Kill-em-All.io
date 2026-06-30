#!/usr/bin/env python3
"""Scan Environment assets and seed collision_data.json from constants_props.das."""
from __future__ import annotations

import json
import re
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
EDITOR = Path(__file__).resolve().parent
ENV_ROOT = PROJECT / "static" / "Environment"
CONSTANTS = PROJECT / "scripts" / "das" / "core" / "constants_props.das"
PROP_CROPS = PROJECT / "scripts" / "python" / "data" / "level_1_prop_crops.json"

DIR_LETTER = {"East": "e", "North": "n", "South": "s", "West": "w"}
VARIANT_RE = re.compile(
    r"^Type_(\d+)_Variation_(\d+)_(East|North|South|West)\.png$", re.I
)


def type_num_to_letter(type_num: int) -> str:
    return chr(ord("a") + type_num - 1)


def prop_id_from_path(rel: str) -> str | None:
    """static/Environment/Misc/Type_2_Variation_5_East.png -> misc_b5_e"""
    parts = rel.split("/")
    if len(parts) < 4:
        return None
    category = parts[2].lower()
    m = VARIANT_RE.match(parts[-1])
    if not m:
        return None
    type_num, variation, direction = int(m.group(1)), int(m.group(2)), m.group(3)
    letter = type_num_to_letter(type_num)
    d = DIR_LETTER.get(direction.title(), direction[0].lower())
    if category == "misc":
        return f"misc_{letter}{variation}_{d}"
    if category == "wall":
        return f"wall_{letter}{variation}_{d}"
    return None


def parse_constants_props(text: str) -> dict[str, dict]:
    """Extract authored collision from constants_props.das."""
    out: dict[str, dict] = {}

    path_re = re.compile(r'(\w+)_PATH = "([^"]+)"')
    paths = {m.group(1): m.group(2) for m in path_re.finditer(text)}

    def prefix_for_path(path: str) -> str | None:
        for prefix, p in paths.items():
            if p == path:
                return prefix.rsplit("_", 1)[0] if prefix.endswith("_PATH") else prefix.replace("_PATH", "")
        for prefix, p in paths.items():
            if path in p or p.endswith(path.split("/")[-1]):
                return prefix.replace("_PATH", "")
        return None

    wall_lines_re = re.compile(
        r"(\w+)_WALL_LINES_PX <- \[\s*((?:float4\([^)]+\),?\s*)+)\]",
        re.S,
    )
    float2_arr_re = re.compile(
        r"(\w+)_BOTTOM_PX <- \[\s*((?:float2\([^)]+\),?\s*)+)\]",
        re.M,
    )
    scalar_re = re.compile(
        r"(\w+)_(CROP|FEET_PX|WORLD_WIDTH|BOTTOM_PX_A|BOTTOM_PX_B) = (float[24]\([^)]+\)|[\d.]+)",
        re.M,
    )

    entries: dict[str, dict] = {}

    def parse_floats(raw: str, count: int) -> list[float]:
        m = re.search(rf"float{count}\(([^)]+)\)", raw)
        if m:
            return [float(x.strip()) for x in m.group(1).split(",")][:count]
        nums = re.findall(r"-?[\d.]+", raw)
        return [float(x) for x in nums[:count]]

    for m in scalar_re.finditer(text):
        key = m.group(1)
        field = m.group(2)
        raw = m.group(3)
        entries.setdefault(key, {})
        if field == "CROP":
            entries[key]["crop"] = parse_floats(raw, 4)
        elif field == "FEET_PX":
            entries[key]["feetPx"] = parse_floats(raw, 2)
        elif field == "WORLD_WIDTH":
            wm = re.search(r"\*\s*([\d.]+)", raw)
            entries[key]["worldWidth"] = float(wm.group(1)) if wm else parse_floats(raw, 1)[0]
        elif field == "BOTTOM_PX_A":
            entries[key].setdefault("bottomA", parse_floats(raw, 2))
        elif field == "BOTTOM_PX_B":
            entries[key].setdefault("bottomB", parse_floats(raw, 2))

    for m in wall_lines_re.finditer(text):
        key = m.group(1)
        segs = []
        for seg in re.findall(r"float4\(([^)]+)\)", m.group(2)):
            nums = [float(x.strip()) for x in seg.split(",")]
            segs.append(nums)
        entries.setdefault(key, {})["segments"] = segs

    for m in float2_arr_re.finditer(text):
        key = m.group(1)
        pts = []
        for pt in re.findall(r"float2\(([^)]+)\)", m.group(2)):
            nums = [float(x.strip()) for x in pt.split(",")]
            pts.append(nums)
        segs = []
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            segs.append([a[0], a[1], b[0], b[1]])
        entries.setdefault(key, {})["segments"] = segs

    for prefix, data in entries.items():
        path = paths.get(prefix)
        if not path:
            continue
        if "bottomA" in data and "bottomB" in data:
            a, b = data.pop("bottomA"), data.pop("bottomB")
            data.setdefault("segments", []).append([a[0], a[1], b[0], b[1]])
        if data.get("segments") or data.get("crop"):
            prop_id = prefix.lower().removeprefix("prop_")
            out[path] = {
                "propId": prop_id,
                "kind": "wall" if prop_id.startswith("wall_") else "misc",
                "crop": data.get("crop"),
                "feetPx": data.get("feetPx"),
                "worldWidth": data.get("worldWidth"),
                "segments": data.get("segments", []),
                "low": False,
                "edited": bool(data.get("segments")),
            }
    return out


def load_prop_crops() -> dict[str, tuple]:
    if not PROP_CROPS.is_file():
        return {}
    raw = json.loads(PROP_CROPS.read_text(encoding="utf-8"))
    return {k: tuple(v) for k, v in raw.items()}


def image_size(path: Path) -> tuple[int, int]:
    try:
        with path.open("rb") as f:
            f.read(16)
            w, h = int.from_bytes(f.read(4), "big"), int.from_bytes(f.read(4), "big")
            return w, h
    except Exception:
        return (0, 0)


def default_crop_feet(w: int, h: int) -> tuple[list[float], list[float]]:
    return [0.0, 0.0, float(w), float(h)], [w / 2.0, float(h)]


def main() -> None:
    constants_text = CONSTANTS.read_text(encoding="utf-8") if CONSTANTS.is_file() else ""
    authored = parse_constants_props(constants_text)
    prop_crops = load_prop_crops()

    manifest: list[dict] = []
    collision: dict[str, dict] = {}

    for png in sorted(ENV_ROOT.rglob("*.png")):
        rel = "static/Environment/" + png.relative_to(ENV_ROOT).as_posix()
        category = png.parent.name
        prop_id = prop_id_from_path(rel)
        w, h = image_size(png)

        entry = {
            "path": rel,
            "name": png.name,
            "category": category,
            "propId": prop_id,
            "width": w,
            "height": h,
        }
        manifest.append(entry)

        if rel in authored:
            collision[rel] = dict(authored[rel])
            collision[rel]["edited"] = bool(authored[rel].get("segments"))
            if prop_id and prop_id in prop_crops:
                spec = prop_crops[prop_id]
                collision[rel]["crop"] = list(spec[0])
                collision[rel]["feetPx"] = list(spec[1])
                collision[rel]["worldWidth"] = spec[2]
            continue

        crop, feet, world_w = None, None, 1.5
        if prop_id and prop_id in prop_crops:
            spec = prop_crops[prop_id]
            crop = list(spec[0])
            feet = list(spec[1])
            world_w = spec[2]
        elif w and h:
            crop, feet = default_crop_feet(w, h)

        collision[rel] = {
            "propId": prop_id,
            "kind": category.lower(),
            "crop": crop,
            "feetPx": feet,
            "worldWidth": world_w,
            "segments": [],
            "low": False,
            "edited": False,
        }

    (EDITOR / "asset_manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    (EDITOR / "collision_data.json").write_text(
        json.dumps(collision, indent=2), encoding="utf-8"
    )
    edited = sum(1 for v in collision.values() if v.get("edited"))
    print(f"Wrote {len(manifest)} assets, {edited} with collision segments")


if __name__ == "__main__":
    main()
