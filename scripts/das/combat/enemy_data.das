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
require scripts/das/world/prefab_texture_hydrate

module enemy_data public

struct EnemySpriteLayout {
    uv : float4
    scale : float2
    worldHeight : float
}

struct EnemyTextures {
    idle : TextureId
    walk : TextureId
    attack1 : TextureId
    takeDamage : TextureId
    die : TextureId
}


var public enemy1Textures : EnemyTextures
var public enemy2Textures : EnemyTextures
var public enemy3Textures : EnemyTextures
var public enemy6Textures : EnemyTextures
var public enemy7Textures : EnemyTextures
var public enemy2Special1Texture : TextureId
var public enemy6Special1Texture : TextureId
var public enemy7CastSpellTexture : TextureId
var public enemy7Special1Texture : TextureId
var public enemy7RunTexture : TextureId
var public enemySpellProjectileTexture : TextureId


def enemy_textures_from_cache(idlePath, walkPath, attackPath, takeDamagePath, diePath : string) : EnemyTextures {
    let idle = texture_from_cache_only(idlePath)
    var walk = texture_from_cache_only(walkPath)
    var attack1 = texture_from_cache_only(attackPath)
    var takeDamage = texture_from_cache_only(takeDamagePath)
    var die = texture_from_cache_only(diePath)
    if (!texture_id_is_valid(idle)) {
        return EnemyTextures()
    }
    if (!texture_id_is_valid(walk)) {
        walk = idle
    }
    if (!texture_id_is_valid(attack1)) {
        attack1 = idle
    }
    if (!texture_id_is_valid(takeDamage)) {
        takeDamage = idle
    }
    if (!texture_id_is_valid(die)) {
        die = idle
    }
    return EnemyTextures(
        idle = idle,
        walk = walk,
        attack1 = attack1,
        takeDamage = takeDamage,
        die = die
    )
}


def enemy_textures_from_paths(idlePath, walkPath, attackPath, takeDamagePath, diePath : string) : EnemyTextures {
    let idle = request_texture_cached(idlePath)
    var walk = request_texture_cached(walkPath)
    var attack1 = request_texture_cached(attackPath)
    var takeDamage = request_texture_cached(takeDamagePath)
    var die = request_texture_cached(diePath)
    if (!texture_id_is_valid(walk)) {
        walk = idle
    }
    if (!texture_id_is_valid(attack1)) {
        attack1 = idle
    }
    if (!texture_id_is_valid(takeDamage)) {
        takeDamage = idle
    }
    if (!texture_id_is_valid(die)) {
        die = idle
    }
    return EnemyTextures(
        idle = idle,
        walk = walk,
        attack1 = attack1,
        takeDamage = takeDamage,
        die = die
    )
}


def public load_spawn_enemy_textures() {
    enemy1Textures = enemy_textures_from_cache(
        ENEMY1_IDLE_PATH, ENEMY1_WALK_PATH, ENEMY1_ATTACK1_PATH, ENEMY1_TAKE_DAMAGE_PATH, ENEMY1_DIE_PATH)
    enemy2Textures = enemy_textures_from_cache(
        ENEMY2_IDLE_PATH, ENEMY2_WALK_PATH, ENEMY2_ATTACK1_PATH, ENEMY2_IDLE_PATH, ENEMY2_DIE_PATH)
    enemy3Textures = enemy_textures_from_cache(
        ENEMY3_IDLE_PATH, ENEMY3_WALK_PATH, ENEMY3_ATTACK1_PATH, ENEMY3_TAKE_DAMAGE_PATH, ENEMY3_DIE_PATH)
    let fallback = enemy1Textures.idle
    enemy6Textures = EnemyTextures(idle = fallback, walk = fallback, attack1 = fallback, takeDamage = fallback, die = fallback)
    enemy7Textures = EnemyTextures(idle = fallback, walk = fallback, attack1 = fallback, takeDamage = fallback, die = fallback)
    enemy2Special1Texture = fallback
    enemy6Special1Texture = fallback
    enemy7CastSpellTexture = fallback
    enemy7Special1Texture = fallback
    enemy7RunTexture = fallback
    enemySpellProjectileTexture = fallback
}


def public refresh_spawn_enemy_textures_from_cache() {
    let enemy1 = enemy_textures_from_cache(
        ENEMY1_IDLE_PATH, ENEMY1_WALK_PATH, ENEMY1_ATTACK1_PATH, ENEMY1_TAKE_DAMAGE_PATH, ENEMY1_DIE_PATH)
    if (texture_id_is_valid(enemy1.idle)) {
        enemy1Textures = enemy1
    }
    let enemy2 = enemy_textures_from_cache(
        ENEMY2_IDLE_PATH, ENEMY2_WALK_PATH, ENEMY2_ATTACK1_PATH, ENEMY2_IDLE_PATH, ENEMY2_DIE_PATH)
    if (texture_id_is_valid(enemy2.idle)) {
        enemy2Textures = enemy2
    }
    let enemy3 = enemy_textures_from_cache(
        ENEMY3_IDLE_PATH, ENEMY3_WALK_PATH, ENEMY3_ATTACK1_PATH, ENEMY3_TAKE_DAMAGE_PATH, ENEMY3_DIE_PATH)
    if (texture_id_is_valid(enemy3.idle)) {
        enemy3Textures = enemy3
    }
}


def public refresh_extended_enemy_textures_from_cache() {
    let enemy6 = enemy_textures_from_cache(
        ENEMY6_IDLE_PATH, ENEMY6_WALK_PATH, ENEMY6_ATTACK1_PATH, ENEMY6_TAKE_DAMAGE_PATH, ENEMY6_DIE_PATH)
    if (texture_id_is_valid(enemy6.idle)) {
        enemy6Textures = enemy6
    }
    let enemy7 = enemy_textures_from_cache(
        ENEMY7_IDLE_PATH, ENEMY7_WALK_PATH, ENEMY7_ATTACK1_PATH, ENEMY7_TAKE_DAMAGE_PATH, ENEMY7_DIE_PATH)
    if (texture_id_is_valid(enemy7.idle)) {
        enemy7Textures = enemy7
    }
    let fallback = enemy1Textures.idle
    let enemy2Special = texture_from_cache_only(ENEMY2_SPECIAL1_PATH)
    if (texture_id_is_valid(enemy2Special)) {
        enemy2Special1Texture = enemy2Special
    }
    let enemy6Special = texture_from_cache_only(ENEMY6_SPECIAL1_PATH)
    if (texture_id_is_valid(enemy6Special)) {
        enemy6Special1Texture = enemy6Special
    }
    let enemy7Cast = texture_from_cache_only(ENEMY7_CAST_SPELL_PATH)
    if (texture_id_is_valid(enemy7Cast)) {
        enemy7CastSpellTexture = enemy7Cast
    }
    let enemy7Special = texture_from_cache_only(ENEMY7_SPECIAL1_PATH)
    if (texture_id_is_valid(enemy7Special)) {
        enemy7Special1Texture = enemy7Special
    }
    let enemy7Run = texture_from_cache_only(ENEMY7_RUN_PATH)
    if (texture_id_is_valid(enemy7Run)) {
        enemy7RunTexture = enemy7Run
    }
    let spellProjectile = texture_from_cache_only(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
    if (texture_id_is_valid(spellProjectile)) {
        enemySpellProjectileTexture = spellProjectile
    }
}


def public queue_spawn_enemy_texture_paths() {
    queue_texture_path(ENEMY1_IDLE_PATH)
    queue_texture_path(ENEMY2_IDLE_PATH)
    queue_texture_path(ENEMY3_IDLE_PATH)
}


def public queue_pump_enemy_texture_paths() {
    queue_texture_path(ENEMY1_WALK_PATH)
    queue_texture_path(ENEMY2_WALK_PATH)
    queue_texture_path(ENEMY3_WALK_PATH)
}


def public queue_background_enemy_texture_paths() {
    queue_texture_path(ENEMY1_ATTACK1_PATH)
    queue_texture_path(ENEMY1_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY1_DIE_PATH)
    queue_texture_path(ENEMY2_ATTACK1_PATH)
    queue_texture_path(ENEMY2_DIE_PATH)
    queue_texture_path(ENEMY3_ATTACK1_PATH)
    queue_texture_path(ENEMY3_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY3_DIE_PATH)
    queue_texture_path(ENEMY6_IDLE_PATH)
    queue_texture_path(ENEMY6_WALK_PATH)
    queue_texture_path(ENEMY6_ATTACK1_PATH)
    queue_texture_path(ENEMY6_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY6_DIE_PATH)
    queue_texture_path(ENEMY7_IDLE_PATH)
    queue_texture_path(ENEMY7_WALK_PATH)
    queue_texture_path(ENEMY7_ATTACK1_PATH)
    queue_texture_path(ENEMY7_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY7_DIE_PATH)
    queue_texture_path(ENEMY2_SPECIAL1_PATH)
    queue_texture_path(ENEMY6_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_CAST_SPELL_PATH)
    queue_texture_path(ENEMY7_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_RUN_PATH)
    queue_texture_path(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
}


def public load_background_enemy_textures() {
    enemy1Textures = enemy_textures_from_paths(
        ENEMY1_IDLE_PATH, ENEMY1_WALK_PATH, ENEMY1_ATTACK1_PATH, ENEMY1_TAKE_DAMAGE_PATH, ENEMY1_DIE_PATH)
    enemy2Textures = enemy_textures_from_paths(
        ENEMY2_IDLE_PATH, ENEMY2_WALK_PATH, ENEMY2_ATTACK1_PATH, ENEMY2_IDLE_PATH, ENEMY2_DIE_PATH)
    enemy3Textures = enemy_textures_from_paths(
        ENEMY3_IDLE_PATH, ENEMY3_WALK_PATH, ENEMY3_ATTACK1_PATH, ENEMY3_TAKE_DAMAGE_PATH, ENEMY3_DIE_PATH)
}


def public load_extended_enemy_textures() {
    enemy6Textures = enemy_textures_from_paths(
        ENEMY6_IDLE_PATH, ENEMY6_WALK_PATH, ENEMY6_ATTACK1_PATH, ENEMY6_TAKE_DAMAGE_PATH, ENEMY6_DIE_PATH)
    enemy7Textures = enemy_textures_from_paths(
        ENEMY7_IDLE_PATH, ENEMY7_WALK_PATH, ENEMY7_ATTACK1_PATH, ENEMY7_TAKE_DAMAGE_PATH, ENEMY7_DIE_PATH)
    enemy2Special1Texture = request_texture_cached(ENEMY2_SPECIAL1_PATH)
    enemy6Special1Texture = request_texture_cached(ENEMY6_SPECIAL1_PATH)
    enemy7CastSpellTexture = request_texture_cached(ENEMY7_CAST_SPELL_PATH)
    enemy7Special1Texture = request_texture_cached(ENEMY7_SPECIAL1_PATH)
    enemy7RunTexture = request_texture_cached(ENEMY7_RUN_PATH)
    enemySpellProjectileTexture = request_texture_cached(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
    let fallback = enemy1Textures.idle
    if (!texture_id_is_valid(enemy2Special1Texture)) {
        enemy2Special1Texture = fallback
    }
    if (!texture_id_is_valid(enemy6Special1Texture)) {
        enemy6Special1Texture = fallback
    }
    if (!texture_id_is_valid(enemy7CastSpellTexture)) {
        enemy7CastSpellTexture = fallback
    }
    if (!texture_id_is_valid(enemy7Special1Texture)) {
        enemy7Special1Texture = fallback
    }
    if (!texture_id_is_valid(enemy7RunTexture)) {
        enemy7RunTexture = fallback
    }
    if (!texture_id_is_valid(enemySpellProjectileTexture)) {
        enemySpellProjectileTexture = fallback
    }
}


def public load_enemy_textures() {
    enemy1Textures = enemy_textures_from_paths(
        ENEMY1_IDLE_PATH, ENEMY1_WALK_PATH, ENEMY1_ATTACK1_PATH, ENEMY1_TAKE_DAMAGE_PATH, ENEMY1_DIE_PATH)
    enemy2Textures = enemy_textures_from_paths(
        ENEMY2_IDLE_PATH, ENEMY2_WALK_PATH, ENEMY2_ATTACK1_PATH, ENEMY2_IDLE_PATH, ENEMY2_DIE_PATH)
    enemy3Textures = enemy_textures_from_paths(
        ENEMY3_IDLE_PATH, ENEMY3_WALK_PATH, ENEMY3_ATTACK1_PATH, ENEMY3_TAKE_DAMAGE_PATH, ENEMY3_DIE_PATH)
    enemy6Textures = enemy_textures_from_paths(
        ENEMY6_IDLE_PATH, ENEMY6_WALK_PATH, ENEMY6_ATTACK1_PATH, ENEMY6_TAKE_DAMAGE_PATH, ENEMY6_DIE_PATH)
    enemy7Textures = enemy_textures_from_paths(
        ENEMY7_IDLE_PATH, ENEMY7_WALK_PATH, ENEMY7_ATTACK1_PATH, ENEMY7_TAKE_DAMAGE_PATH, ENEMY7_DIE_PATH)
    enemy2Special1Texture = request_texture_cached(ENEMY2_SPECIAL1_PATH)
    enemy6Special1Texture = request_texture_cached(ENEMY6_SPECIAL1_PATH)
    enemy7CastSpellTexture = request_texture_cached(ENEMY7_CAST_SPELL_PATH)
    enemy7Special1Texture = request_texture_cached(ENEMY7_SPECIAL1_PATH)
    enemy7RunTexture = request_texture_cached(ENEMY7_RUN_PATH)
    enemySpellProjectileTexture = request_texture_cached(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
}


def public queue_enemy_texture_paths() {
    queue_spawn_enemy_texture_paths()
    queue_background_enemy_texture_paths()
}


def enemy_is_death_knight(kind : int) : bool {
    return kind == 7
}


def spell_cast_texture_for_kind(kind : int) : TextureId {
    if (kind == 6) {
        return enemy6Special1Texture
    }
    if (kind == 7) {
        return enemy7Special1Texture
    }
    return enemy2Special1Texture
}


def textures_for_kind(kind : int) : EnemyTextures {
    if (kind == 2) {
        return enemy2Textures
    }
    if (kind == 3) {
        return enemy3Textures
    }
    if (kind == 6) {
        return enemy6Textures
    }
    if (kind == 7) {
        return enemy7Textures
    }
    return enemy1Textures
}


def snap_feet_to_tile_center(feet : float2) : float2 {
    let grid = world_to_grid(feet.x, feet.y)
    return grid_to_world(floor(grid.x + 0.5), floor(grid.y + 0.5))
}


def push_death_knight_aoe_center(var centers : array<float2>; gx, gy : int) {
    if (!grid_cell_in_playfield(gx, gy)) {
        return
    }
    let pt = grid_to_world(float(gx), float(gy))
    for (existing in centers) {
        if (length_sq(existing - pt) < 0.0001) {
            return
        }
    }
    push(centers, pt)
}


def death_knight_aoe_centers_at_grid(gx, gy : int; bossFeet, playerFeet : float2) : array<float2> {
    var centers : array<float2>
    if (!grid_cell_in_playfield(gx, gy)) {
        push(centers, grid_to_world(float(gx), float(gy)))
        return <- centers
    }

    let toPlayer = playerFeet - bossFeet
    var forward = float2(1.0, 0.0)
    if (length_sq(toPlayer) > 0.0001) {
        forward = normalize(toPlayer)
    }
    let perp = float2(-forward.y, forward.x)
    let sideStep = grid_step_from_world_dir(perp, ENEMY7_AOE_SIDE_TILE_STEPS)
    let behindStep = grid_step_from_world_dir(forward, ENEMY7_AOE_BEHIND_TILE_STEPS)

    // Front row: player tile plus wider side telegraphs.
    push_death_knight_aoe_center(centers, gx, gy)
    push_death_knight_aoe_center(centers, gx + sideStep.x, gy + sideStep.y)
    push_death_knight_aoe_center(centers, gx - sideStep.x, gy - sideStep.y)

    // Back row: three more behind the front line, same lateral spread.
    push_death_knight_aoe_center(centers, gx + behindStep.x, gy + behindStep.y)
    push_death_knight_aoe_center(centers, gx + behindStep.x + sideStep.x, gy + behindStep.y + sideStep.y)
    push_death_knight_aoe_center(centers, gx + behindStep.x - sideStep.x, gy + behindStep.y - sideStep.y)

    return <- centers
}


def enemy_sprite_layout(row, col : int) : EnemySpriteLayout {
    let tileW = PLAYER_SHEET_WIDTH / float(PLAYER_SHEET_COLS)
    let tileH = PLAYER_SHEET_HEIGHT / float(PLAYER_SHEET_ROWS)
    let worldH = ENEMY_WORLD_HEIGHT
    let worldW = worldH * (tileW / tileH)
    return EnemySpriteLayout(
        uv = uv_rect_from_tile(col, row, PLAYER_SHEET_COLS, PLAYER_SHEET_ROWS),
        scale = float2(worldW, worldH),
        worldHeight = worldH
    )
}


def enemy_anchor_offset(layout : EnemySpriteLayout) : float2 {
    return entity_sprite_anchor_offset(
        layout.worldHeight,
        PLAYER_SHEET_HEIGHT,
        float(PLAYER_SHEET_ROWS),
        PLAYER_SHEET_WIDTH,
        float(PLAYER_SHEET_COLS)
    )
}


def facing_row_from_dir(dir : float2) : int {
    return direction_to_facing_row(dir)
}


def enemy_is_mage(kind : int) : bool {
    return kind == 2 || kind == 6
}


def enemy_hp_level_multiplier(level : int) : float {
    if (level <= 1) {
        return 1.0
    }
    return 1.0 + float(level - 1) * ENEMY_HP_SCALE_PER_LEVEL
}


def enemy_boss_hp_level_multiplier(level : int) : float {
    if (level <= 1) {
        return 1.0
    }
    return 1.0 + float(level - 1) * ENEMY7_HP_SCALE_PER_LEVEL
}


def scale_enemy_hp(baseHp : int; level : int; boss : bool) : int {
    let mult = (boss ? enemy_boss_hp_level_multiplier(level) : enemy_hp_level_multiplier(level))
    return max(1, int(float(baseHp) * mult + 0.5))
}


def enemy_max_hp(kind : int) : int {
    if (kind == 7) {
        return scale_enemy_hp(ENEMY7_MAX_HP, playerLevel, true)
    }
    if (enemy_is_mage(kind)) {
        return scale_enemy_hp(ENEMY_DISTANCE_MAX_HP, playerLevel, false)
    }
    if (kind == 3) {
        return scale_enemy_hp(ENEMY3_MAX_HP, playerLevel, false)
    }
    return scale_enemy_hp(ENEMY_CLOSE_MAX_HP, playerLevel, false)
}


def clamp_spawn_to_map(pos : float2) : float2 {
    let grid = world_to_grid(pos.x, pos.y)
    let gx = clamp(grid.x, 4.0, float(MAP_WIDTH - 4))
    let gy = clamp(grid.y, 4.0, float(MAP_HEIGHT - 4))
    return grid_to_world(gx, gy)
}


def is_world_position_on_screen(pos : float2) : bool {
    if (!cameraNode.isAlive) {
        return true
    }
    let cam = cameraNode?.Camera
    let screen = cam.worldToScreen(float3(pos.x, pos.y, 0.1)).xy
    let res = get_resolution()
    return screen.x >= 0.0 && screen.x <= float(res.x) && screen.y >= 0.0 && screen.y <= float(res.y)
}


def random_unit_float() : float {
    return float(random_range(0, 9999)) / 9999.0
}


def random_offscreen_spawn_position() : float2 {
    var center = playerWorldPosition
    if (cameraNode.isAlive) {
        center = cameraNode.localPosition.xy
    }
    let half = camera_visible_half_extents()
    let cornerReach = length(half) + ENEMY_OFFSCREEN_SPAWN_MARGIN
    for (attempt in range(32)) {
        let angle = random_unit_float() * 6.2831853
        let dist = cornerReach + random_unit_float() * 4.0
        let pos = clamp_spawn_to_map(center + float2(cos(angle), sin(angle)) * dist)
        if (!is_world_position_on_screen(pos)) {
            return pos
        }
    }
    return clamp_spawn_to_map(center + float2(cornerReach + 2.0, 0.0))
}


def random_enemy_spawn_position() : float2 {
    let playerPos = grid_to_world(PLAYER_SPAWN_GRID_X, PLAYER_SPAWN_GRID_Y)
    for (attempt in range(24)) {
        let gx = float(random_range(4, MAP_WIDTH - 4))
        let gy = float(random_range(4, MAP_HEIGHT - 4))
        let pos = grid_to_world(gx, gy)
        if (length(pos - playerPos) >= ENEMY_MIN_SPAWN_DISTANCE) {
            return pos
        }
    }
    return grid_to_world(PLAYER_SPAWN_GRID_X + 12.0, PLAYER_SPAWN_GRID_Y + 12.0)
}


def enemy_attack_cooldown(kind : int) : float {
    if (kind == 7) {
        return ENEMY7_SPELL_ATTACK_COOLDOWN
    }
    if (kind == 6) {
        return ENEMY6_MAGE_ATTACK_COOLDOWN
    }
    if (kind == 2) {
        return ENEMY_MAGE_ATTACK_COOLDOWN
    }
    return ENEMY_SKELETON_ATTACK_COOLDOWN
}


def enemy_spell_spawn_position(feet : float2; aimDir : float2) : float2 {
    let forward = normalize(aimDir)
    let pixelToWorld = ENEMY_WORLD_HEIGHT / (PLAYER_SHEET_HEIGHT / float(PLAYER_SHEET_ROWS))
    return feet + forward * (28.0 * pixelToWorld) + float2(0.0, 18.0 * pixelToWorld)
}


def mage_has_los_to_player(feet, playerPos : float2) : bool {
    let toPlayer = playerPos - feet
    let dist = length(toPlayer)
    if (dist > ENEMY2_SPELL_MAX_DISTANCE) {
        return false
    }
    if (dist < 0.0001) {
        return false
    }
    return !blocks_projectile_path(feet, playerPos, ENEMY_SPELL_PROJECTILE_HIT_RADIUS)
}


def mage_can_shoot_player_from(feet, playerPos : float2) : bool {
    if (!mage_has_los_to_player(feet, playerPos)) {
        return false
    }
    let toPlayer = playerPos - feet
    let aimDir = toPlayer / length(toPlayer)
    let spawnPos = enemy_spell_spawn_position(feet, aimDir)
    return !blocks_projectile_path(spawnPos, playerPos, ENEMY_SPELL_PROJECTILE_HIT_RADIUS)
}


def pick_mage_ring_point(playerPos, current : float2; radius : float; blockers : array<float2>) : float2 {
    var toward = current - playerPos
    if (length_sq(toward) < 0.0001) {
        toward = float2(1.0, 0.0)
    } else {
        toward = normalize(toward)
    }
    let baseAngle = atan2(toward.y, toward.x)
    var bestPoint = playerPos + toward * radius
    var bestScore = -1000000.0
    let minSep = entity_min_separation()
    for (i in range(8)) {
        let angle = baseAngle + (float(i) - 3.5) * (PI / 8.0)
        let point = playerPos + float2(cos(angle), sin(angle)) * radius
        var score = -length(point - current) * 2.0
        for (blocker in blockers) {
            if (length_sq(blocker - playerPos) < 0.0001) {
                continue
            }
            score += min(length(point - blocker), minSep * 2.0) * 0.1
        }
        if (score > bestScore) {
            bestScore = score
            bestPoint = point
        }
    }
    return bestPoint
}


struct MageLosRingPick {
    valid : bool = false
    point : float2
}


def pick_mage_los_ring_point(playerPos, current : float2; radius : float; blockers : array<float2>) : MageLosRingPick {
    var result = MageLosRingPick()
    var bestScore = -1000000.0
    let minSep = entity_min_separation()
    for (i in range(8)) {
        let angle = float(i) * (PI / 4.0)
        let point = playerPos + float2(cos(angle), sin(angle)) * radius
        if (!is_feet_in_grid_bounds(point)) {
            continue
        }
        if (!mage_has_los_to_player(point, playerPos)) {
            continue
        }
        var score = 0.0
        for (blocker in blockers) {
            if (length_sq(blocker - playerPos) < 0.0001) {
                continue
            }
            score += min(length(point - blocker), minSep * 2.0)
        }
        score -= length(point - current) * 0.5
        if (score > bestScore) {
            bestScore = score
            result.point = point
            result.valid = true
        }
    }
    return result
}
