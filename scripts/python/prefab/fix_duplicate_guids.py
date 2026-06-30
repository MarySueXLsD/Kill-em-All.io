"""Assign unique GUIDs to .meta files that share the same guid."""
from __future__ import annotations

import re
import uuid
from collections import defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
GUID_RE = re.compile(r'^guid:t="([^"]+)"', re.M)


def main() -> None:
    by_guid: dict[str, list[Path]] = defaultdict(list)
    for meta in PROJECT.rglob("*.meta"):
        text = meta.read_text(encoding="utf-8")
        m = GUID_RE.search(text)
        if m:
            by_guid[m.group(1)].append(meta)

    fixed = 0
    for guid, paths in by_guid.items():
        if len(paths) <= 1:
            continue
        # Keep the first file's guid; regenerate for the rest.
        for meta in sorted(paths)[1:]:
            new_guid = str(uuid.uuid4())
            text = meta.read_text(encoding="utf-8")
            text = GUID_RE.sub(f'guid:t="{new_guid}"', text, count=1)
            meta.write_text(text, encoding="utf-8", newline="\n")
            fixed += 1
            print(f"fixed {meta.relative_to(PROJECT)} -> {new_guid}")

    print(f"regenerated {fixed} duplicate meta guids in {len([g for g, p in by_guid.items() if len(p) > 1])} groups")


if __name__ == "__main__":
    main()
