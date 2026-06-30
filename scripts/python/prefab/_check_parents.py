import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
res_start = text.find("\nres{")
nodes_text = text[:res_start] if res_start >= 0 else text
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
        nodes[int(uid_m.group(1))] = {
            "name": name_m.group(1),
            "parent": int(parent_m.group(1)) if parent_m else None,
            "file_pos": start,
        }
    i = j

missing = [
    (n["name"], uid, n["parent"])
    for uid, n in nodes.items()
    if n["parent"] is not None and n["parent"] not in nodes
]
print("total nodes", len(nodes))
print("missing parents", len(missing))
for row in missing[:20]:
    print(row)
if 125394 in nodes:
    print("125394", nodes[125394])
    kids = [nodes[u]["name"] for u, n in nodes.items() if n["parent"] == 125394]
    print("children of 125394", len(kids), kids[:3])
