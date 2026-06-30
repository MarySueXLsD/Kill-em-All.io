#!/usr/bin/env python3
"""Analyze grass vs ground renderOrder in level_1.prefab."""
import re
from pathlib import Path

text = Path(__file__).resolve().parents[3] / "prefabs" / "level_1.prefab"
text = text.read_text(encoding="utf-8")

cell_re = re.compile(
    r'node\{\nname:t="cell_(-?\d+)_(-?\d+)"(.*?)(?=\nnode\{\nname:t="cell_|\nres\{)',
    re.S,
)
bad_same = []
low_grass = []
for m in cell_re.finditer(text):
    gx, gy, body = m.group(1), m.group(2), m.group(3)
    g = re.search(r'name:t="ground".*?renderOrder:i=(\d+)', body, re.S)
    gr = re.search(r'name:t="grass".*?renderOrder:i=(\d+)', body, re.S)
    if not gr:
        continue
    grd = int(gr.group(1))
    gd = int(g.group(1)) if g else None
    if gd is not None and grd <= gd:
        bad_same.append((gx, gy, gd, grd))
    if grd < 120:
        low_grass.append((gx, gy, gd, grd))

print(f"cells with grass <= ground: {len(bad_same)}")
for item in bad_same[:10]:
    print(" ", item)
print(f"cells with grass renderOrder < 120: {len(low_grass)}")
for item in low_grass[:15]:
    print(" ", item)

# min/max grass orders
orders = [int(m.group(1)) for m in re.finditer(r'name:t="grass".*?renderOrder:i=(\d+)', text, re.S)]
print(f"grass renderOrder min={min(orders)} max={max(orders)} count={len(orders)}")
