# Module reference

All game modules live under `scripts/das/`. `require core/...` paths resolve via `plugin.das_project`.

## Entry

| File | Responsibility |
|------|----------------|
| `main.das` | `on_initialize` / `on_update` / `on_resolution_changed`, cheats, prefab texture hydrate guard |

## scripts/das/core/

| File | Responsibility |
|------|----------------|
| `constants.das` | Re-exports all `constants_*.das` |
| `constants_grid.das` | Grid, tile geometry, depth layers |
| `constants_player.das` | Player movement, animation, combat stats |
| `constants_camera.das` | Camera zoom and follow |
| `constants_world.das` | Ground texture paths and crops |
| `constants_props.das` | Prop/wall definitions and base level layout |
| `constants_combat.das` | AOE tuning |
| `constants_enemies.das` | Enemy AI, spawn, rewards |
| `constants_ui.das` | HUD and upgrade picker |
| `game_state.das` | Shared mutable runtime state |
| `iso_math.das` | Grid/world transforms, depth sort |
| `input.das` | Action set setup |
| `camera.das` | Ortho zoom and look-ahead follow |

## scripts/das/world/

| File | Responsibility |
|------|----------------|
| `world.das` | Facade for terrain + map |
| `world_terrain.das` | Grass/road masks, terrain speed, overlay picking |
| `world_map.das` | Map cells, visibility culling, `build_map` |
| `level.das` | Prefab paths, scene node binding |
| `level_switch.das` | Runtime level swap |
| `level_bake.das` | Editor bake hooks |
| `props.das` | Facade for prop subsystems |
| `props_collision.das` | Blockers, wall segments, shared prop state |
| `props_walls.das` | Border/interior walls |
| `props_sprites.das` | Prop sprites, prefab indexing, visibility |
| `collision.das` | Feet movement vs grid/props |
| `prefab_texture_hydrate.das` | Apply prefab texture hints at load |
| `tile_texture_hint.das` | Prefab texture path component |
| `prop_footprint.das` | Prop id footprint component |

## scripts/das/combat/

| File | Responsibility |
|------|----------------|
| `player.das` | `PlayerController`, spawn, dash ghosts |
| `enemies.das` | Facade for enemy subsystems |
| `enemy_data.das` | Textures, layouts, kind helpers |
| `enemy_spells.das` | Enemy spell projectiles |
| `enemy_ai.das` | `EnemyController`, frame cache, hit resolution |
| `enemy_spawn.das` | Wave spawn, death knight boss |
| `combat.das` | Hitboxes, slash shapes |
| `projectiles.das` | Player bow projectiles |
| `aoe_effects.das` | Player special AOE |
| `weapon_combat.das` | Weapon damage helpers |
| `exp_progression.das` | EXP and level-up queue |

## scripts/das/ui/

| File | Responsibility |
|------|----------------|
| `loading.das` | Staged startup |
| `disclaimer.das` | Opening screen |
| `player_hud.das` | HUD layout orchestration |
| `hud_bottom_bar.das` | Bottom bar chrome |
| `hud_health.das` | Health bar |
| `hud_weapons.das` | Weapon icon + cooldown bars |
| `hud_exp.das` | EXP bar |
| `hud_character.das` | Portrait + name/level |
| `hud_wave.das` | Wave title |
| `enemy_hud.das` | Enemy heart bars |
| `upgrade_picker.das` | Upgrade UI |
| `upgrade_defs.das` | Upgrade kinds and apply logic |

## scripts/das/debug/

| File | Responsibility |
|------|----------------|
| `debug_draw.das` | Hitbox overlay |
