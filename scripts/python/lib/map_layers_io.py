"""Load/save level_1 map layer JSON (single file or chunked parts)."""
from __future__ import annotations

import json
from pathlib import Path


def load_map_layers(data_dir: Path) -> dict[str, dict[str, str]]:
    chunk_paths = sorted(data_dir.glob("level_1_map_layers_*.json"))
    if chunk_paths:
        raw: dict[str, dict[str, str]] = {}
        for path in chunk_paths:
            raw.update(json.loads(path.read_text(encoding="utf-8")))
        return raw
    path = data_dir / "level_1_map_layers.json"
    return json.loads(path.read_text(encoding="utf-8"))


def save_map_layers(data_dir: Path, raw: dict[str, dict[str, str]], max_lines: int = 2800) -> int:
    for path in data_dir.glob("level_1_map_layers*.json"):
        path.unlink()
    chunks: list[dict[str, dict[str, str]]] = []
    current: dict[str, dict[str, str]] = {}
    est_lines = 2
    for key, val in raw.items():
        entry_lines = max(3, len(json.dumps({key: val}, indent=2).splitlines()))
        if current and est_lines + entry_lines > max_lines:
            chunks.append(current)
            current = {}
            est_lines = 2
        current[key] = val
        est_lines += entry_lines
    if current:
        chunks.append(current)
    for i, chunk in enumerate(chunks):
        out = data_dir / f"level_1_map_layers_{i:02d}.json"
        out.write_text(json.dumps(chunk, indent=2, sort_keys=True), encoding="utf-8")
    return len(chunks)
