# Level authoring

## Prefabs

| Prefab | Purpose |
|--------|---------|
| `prefabs/level_1.prefab` | Full 80×80 combat map |
| `prefabs/base.prefab` | Small hub (walk/run/dash only) |

Switch at runtime via cheats `level.1` / `level.base` or [`scripts/das/world/level_switch.das`](../scripts/das/world/level_switch.das).

## Scene structure (level_1)

Expected child nodes under the level root (bound in `level.das`):

- `map` — ground/grass/road tile cells
- `walls` — border and interior walls
- `props` — gameplay and decor sprites with `PropFootprint` / `TileTextureHint`
- `player` — spawn transform
- `enemies`, `effects` — runtime roots

## Textures on prefab nodes

Author texture paths on `TileTextureHint.texturePath`. At load, [`scripts/das/world/prefab_texture_hydrate.das`](../scripts/das/world/prefab_texture_hydrate.das) applies `__textureId` from asset GUIDs.

Cheat `level.prefab_help` prints the current workflow commands.

## Rebake workflow

1. **Procedural/layout bake** — edit JSON in `scripts/python/data/` or run `sync_bake_from_prefab.py` after editor changes, then:

   ```bash
   python scripts/python/bake/bake_level_prefab.py
   ```

2. **Pick order** — after adding/reordering sprite nodes:

   ```bash
   python scripts/python/prefab/fix_prefab_pick_uids.py
   ```

3. **Verify in Eden** — open project, check map rendering and prop collision.

## Prop placement debug

Cheats:

- `props.print_cursor` — feet grid at cursor
- `props.spawn_at_cursor <prop_id>` — print placement coords for a prop type
- `props.list_types` — list misc prop ids

Props/walls baked into the prefab should use **lower uids** than map tiles so editor picks hit props first.
