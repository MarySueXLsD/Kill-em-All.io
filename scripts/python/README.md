# Kill'em All.io — Python Tools

Run scripts from the **project root** (`019ed1ae-4c54-720c-b8a6-52d62157ca6a`).

## Layout

| Folder | Purpose |
|--------|---------|
| `lib/` | Shared helpers (`grass_overlay`, `wall_placement`, `map_layers_io`, `resource_link_hash`, `das_constants`) |
| `data/` | Level bake data (`level_1_map_layers_*.json`, `level_1_prop_crops.json`, `level_1_prop_markers.json`, `texture_ref_ids.json`) |
| `bake/` | Full prefab bakers |
| `prefab/` | Prefab patch/sync/fix scripts |
| `assets/` | Texture optimization and crop utilities |
| `analyze/` | One-off inspection scripts |

## Common commands

```bash
# Rebake level_1.prefab from JSON data + procedural helpers
python scripts/python/bake/bake_level_prefab.py

# After hand-editing level_1.prefab in the editor — sync map/prop data back to JSON
python scripts/python/prefab/sync_bake_from_prefab.py

# Fix editor pick order after prefab edits
python scripts/python/prefab/fix_prefab_pick_uids.py

# Hydrate texture ref IDs on prefab nodes
python scripts/python/prefab/hydrate_prefab_texture_ids.py
```

## Notes

- Map layer bake data is split across `data/level_1_map_layers_*.json` (under 3000 lines each); `bake_level_prefab.py` merges them at load time.
- Keep `lib/das_constants.py` in sync when changing grid/tile constants in `scripts/das/core/constants_*.das`.
