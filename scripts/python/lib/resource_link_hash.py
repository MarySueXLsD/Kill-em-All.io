#!/usr/bin/env python3
"""Compute Eden prefab __textureId:i64 (resource link hash) from asset .meta GUID."""

from __future__ import annotations

import re
from pathlib import Path

import xxhash

# AssetFabriqueType (.meta `assetType`) -> ResourceFabriqueType (resourceTypes.h)
ASSET_TO_RESOURCE = {
    0: 2,    # Texture        -> Texture
    1: 1,    # DasMesh        -> Mesh
    2: 3,    # Material       -> Material
    3: 4,    # Model          -> Model
    4: 5,    # Sound          -> Sound
    5: 10,   # Text           -> Text
    6: 11,   # Font           -> Font
    8: 12,   # Prefab         -> Prefab
    9: 2,    # CubeMap        -> Texture
    10: 2,   # Texture2DArray -> Texture
    11: 14,  # ShaderGraph    -> UserShader
    12: 14,  # DasShader      -> UserShader
}


def parse_meta(path: Path | str) -> tuple[str, int]:
    text = Path(path).read_text(encoding="utf-8")
    guid = re.search(r'guid\s*:\s*t\s*=\s*"([^"]*)"', text).group(1)
    asset_type = int(re.search(r"assetType\s*:\s*i\s*=\s*(-?\d+)", text).group(1))
    return guid, asset_type


def guid_to_bytes(guid_str: str) -> bytes:
    return bytes.fromhex(guid_str.replace("-", ""))


def resource_link_hash(guid: bytes, name: str, res_type: int) -> int:
    h = xxhash.xxh3_64()
    h.update(guid)
    h.update(name.encode("utf-8"))
    h.update(bytes([res_type]))
    value = h.intdigest()
    return value - 2**64 if value >= 2**63 else value


def ref_id_from_meta(meta_path: Path | str, name: str = "") -> int:
    guid_str, asset_type = parse_meta(meta_path)
    res_type = ASSET_TO_RESOURCE[asset_type]
    return resource_link_hash(guid_to_bytes(guid_str), name, res_type)
