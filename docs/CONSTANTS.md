# Constants

All gameplay tunables use `let public UPPER_SNAKE` in `scripts/das/core/constants_*.das`. Import via `require core/constants` — never duplicate magic numbers in domain files.

## Files

| File | Examples |
|------|----------|
| `constants_grid.das` | `GRID_WIDTH`, `TILE_HALF_WIDTH`, `DEPTH_ENTITY_LAYER` |
| `constants_player.das` | `PLAYER_SPEED`, `PLAYER_DASH_COOLDOWN`, `PLAYER_BOW_DAMAGE` |
| `constants_camera.das` | `CAMERA_ORTHO_SIZE`, `CAMERA_LOOK_AHEAD_BLEND` |
| `constants_world.das` | `GROUND_A1_PATHS`, `GROUND_ROAD_HALF_WIDTH` |
| `constants_props.das` | `PROP_MISC_*`, `WALL_B1_*`, `BASE_*` |
| `constants_combat.das` | `AOE_HIT_RADIUS`, `AOE_ANIM_FPS` |
| `constants_enemies.das` | `ENEMY_SPAWN_PERIOD_SECONDS`, `ENEMY7_MAX_HP` |
| `constants_ui.das` | `UPGRADE_VITALITY_HP_BONUS`, `PLAYER_HEALTH_HUD_SIZE` |

## Conventions

- **Static** values → `constants_*.das`
- **Runtime** values shared by 2+ modules → `game_state.das`
- **Per-entity** state → fields on Components

## Python mirror

Bake scripts mirror grid/tile numbers in [`scripts/python/lib/das_constants.py`](../scripts/python/lib/das_constants.py). Update both when changing core grid constants in [`scripts/das/core/constants_*.das`](../scripts/das/core/).
