#!/usr/bin/env python3
"""Verify every node's parent appears earlier in the prefab file (Eden load order)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
res_start = text.find("\nres{")
nodes_text = text[:res_start] if res_start >= 0 else text
order: list[int] = []
nodes: dict[int, dict] = {}
i = 0
while True:
    start = nodes_text.find("node{", i)
    if start < 0:
        break
    depth = 0
    j = start
    while j < len(nodes_text):
        if nodes_text[j] == "{":
            depth += 1
        elif nodes_text[j] == "}":
            depth -= 1
            if depth == 0:
                j += 1
                break
        j += 1
    block = nodes_text[start:j]
    name_m = re.search(r'name:t="([^"]+)"', block)
    uid_m = re.search(r"uid:i=(\d+)", block)
    parent_m = re.search(r"parent:i=(\d+)", block)
    if name_m and uid_m:
        uid = int(uid_m.group(1))
        nodes[uid] = {
            "name": name_m.group(1),
            "pos": start,
            "parent": int(parent_m.group(1)) if parent_m else None,
        }
        order.append(uid)
    i = j

bad = [
    (nodes[uid]["name"], uid, nodes[uid]["parent"], nodes[nodes[uid]["parent"]]["name"])
    for uid in order
    if nodes[uid]["parent"] is not None and nodes[nodes[uid]["parent"]]["pos"] > nodes[uid]["pos"]
]
print("load-order parent issues:", len(bad))
for row in bad[:20]:
    print(row)
