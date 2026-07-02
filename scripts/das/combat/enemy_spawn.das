require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/world/collision
require scripts/das/world/props
require scripts/das/combat/combat
require scripts/das/core/game_state
require scripts/das/combat/exp_progression
require scripts/das/ui/enemy_hud
require scripts/das/world/world
require scripts/das/combat/weapon_combat
require scripts/das/combat/aoe_effects
require scripts/das/combat/enemy_data
require scripts/das/combat/enemy_ai

module enemy_spawn public

var private enemySpawnTimer : float = 0.0
var private enemySpawnSeq : int = 0

def enemy_spawn_count_for_level(level : int) : int {
    return ENEMY_SPAWN_BATCH_COUNT + (level - 1) * ENEMY_SPAWN_COUNT_PER_LEVEL
}


def enemy_spawn_period_for_level(level : int) : float {
    let period = ENEMY_SPAWN_PERIOD_SECONDS - float(level - 1) * ENEMY_SPAWN_PERIOD_DECREASE_PER_LEVEL
    return max(ENEMY_SPAWN_PERIOD_MIN_SECONDS, period)
}


def prime_enemy_spawn_timer() {
    enemySpawnTimer = enemy_spawn_period_for_level(playerLevel)
}


def ensure_enemies_root() {
    if (!enemiesRootNode.isAlive) {
        enemiesRootNode = create_node(NodeData(name = "enemies"))
        prime_enemy_spawn_timer()
    }
}


def death_knight_tier_for_level(level : int) : int {
    if (level >= ENEMY7_SPAWN_LEVEL_TIER_THREE) {
        return 3
    }
    if (level >= ENEMY7_SPAWN_LEVEL_TIER_TWO) {
        return 2
    }
    if (level >= ENEMY7_SPAWN_LEVEL_FIRST) {
        return 1
    }
    return 0
}


def death_knight_spawn_count_for_tier(tier : int) : int {
    if (tier == 3) {
        return ENEMY7_TIER_THREE_COUNT
    }
    if (tier == 2) {
        return ENEMY7_TIER_TWO_COUNT
    }
    if (tier == 1) {
        return ENEMY7_TIER_ONE_COUNT
    }
    return 0
}


def spawn_death_knight_bosses(count : int) {
    for (i in range(count)) {
        spawn_enemy(7, random_offscreen_spawn_position())
    }
}


def public update_death_knight_boss_spawning() {
    if (!enemiesActive || !gameReady) {
        return
    }
    ensure_enemies_root()
    let targetTier = death_knight_tier_for_level(playerLevel)
    if (targetTier <= deathKnightBossTierSpawned) {
        return
    }
    let spawnCount = death_knight_spawn_count_for_tier(targetTier)
    if (spawnCount > 0) {
        spawn_death_knight_bosses(spawnCount)
    }
    deathKnightBossTierSpawned = targetTier
}


def public update_enemy_spawning() {
    if (!enemiesActive || !gameReady) {
        return
    }
    ensure_enemies_root()
    enemySpawnTimer += get_delta_time()
    let period = enemy_spawn_period_for_level(playerLevel)
    while (enemySpawnTimer >= period) {
        enemySpawnTimer -= period
        let batchCount = enemy_spawn_count_for_level(playerLevel)
        let room = ENEMY_MAX_ON_SCREEN - count_living_enemies()
        if (room <= 0) {
            continue
        }
        let spawnCount = min(batchCount, room)
        for (i in range(spawnCount)) {
            spawn_enemy(random_enemy_kind(), random_offscreen_spawn_position())
        }
    }
}


def public clear_all_enemies() {
    if (!enemiesRootNode.isAlive) {
        return
    }
    var inscope children = enemiesRootNode.get_children()
    for (child in children) {
        if (child.isAlive) {
            remove_node(child)
        }
    }
}


def public respawn_all_enemies() {
    ensure_enemies_root()
    prime_enemy_spawn_timer()
}


def spawn_enemy(kind : int; spawnPos : float2) {
    let textures = textures_for_kind(kind)
    let layout = enemy_sprite_layout(0, 0)
    let anchor = enemy_anchor_offset(layout)

    enemySpawnSeq++
    let spawnId = enemySpawnSeq
    let node = create_node(NodeData(
        name = "enemy_{kind}_{spawnId}",
        position = float3(spawnPos.x + anchor.x, spawnPos.y + anchor.y, SPRITE_DRAW_Z),
        scale = float3(layout.scale.x, layout.scale.y, 1.0),
        parent = enemiesRootNode
    ))
    add_component(node, new SpriteRenderer(
        textureId = textures.idle,
        uvRect = layout.uv,
        useTextureSizeForScaling = false,
        renderOrder = depth_sort_entity_from_world(spawnPos)
    ))
    add_component(node, new EnemyController(
        kind = kind,
        position = spawnPos,
        textures = textures
    ))
}


def public spawn_enemies() {
    enemiesRootNode = create_node(NodeData(name = "enemies"))
    prime_enemy_spawn_timer()
}
