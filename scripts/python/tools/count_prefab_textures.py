import re
from collections import Counter
from pathlib import Path

prefab = Path(__file__).resolve().parents[3] / "prefabs" / "level_1.prefab"
text = prefab.read_text(encoding="utf-8")
paths = re.findall(r'texturePath:t="([^"]+)"', text)
print("nodes with texturePath:", len(paths))
print("unique paths:", len(set(paths)))
by_prefix = Counter()
for p in set(paths):
    if "/Ground/" in p:
        by_prefix["Ground"] += 1
    elif "/Misc/" in p:
        by_prefix["Misc"] += 1
    elif "/Wall/" in p:
        by_prefix["Wall"] += 1
    elif "/Characters/" in p:
        by_prefix["Characters"] += 1
    else:
        by_prefix["Other"] += 1
print("unique by category:", dict(by_prefix))
others = sorted(p for p in set(paths) if "/Ground/" not in p and "/Misc/" not in p and "/Wall/" not in p and "/Characters/" not in p)
print("Other paths ({}):".format(len(others)))
for p in others[:15]:
    print(" ", p)
if len(others) > 15:
    print("  ...")
non_ground = [p for p in set(paths) if "/Ground/" not in p]
print("non-ground unique:", len(non_ground))

try:
    from PIL import Image
    root = prefab.parent.parent / "static"
    env_paths = [p for p in set(paths) if "/Ground/" not in p and "/Characters/" not in p]
    env_total = 0
    for rel in env_paths:
        p = root / rel.replace("static/", "")
        if p.exists():
            im = Image.open(p)
            env_total += im.size[0] * im.size[1] * 4
    print("env prop/wall/tree decoded MB:", round(env_total / 1024 / 1024, 2), "count:", len(env_paths))
    mx = 0
    mp = ""
    for rel in sorted(set(paths)):
        p = root / rel.replace("static/", "")
        if not p.exists():
            print("missing", rel)
            continue
        im = Image.open(p)
        b = im.size[0] * im.size[1] * 4
        total += b
        if b > mx:
            mx = b
            mp = rel
    print("decoded total MB:", round(total / 1024 / 1024, 2))
    print("largest MB:", round(mx / 1024 / 1024, 2), mp)
    ng = [p for p in set(paths) if "/Ground/" not in p]
    ng_total = 0
    for rel in ng:
        p = root / rel.replace("static/", "")
        if p.exists():
            im = Image.open(p)
            ng_total += im.size[0] * im.size[1] * 4
    print("non-ground decoded MB:", round(ng_total / 1024 / 1024, 2))
except ImportError:
    print("PIL not installed, skip decoded size estimate")

