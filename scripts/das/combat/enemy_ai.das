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
require scripts/das/combat/enemy_data public

module enemy_ai public

var private cachedStaticBlockers : array<float2>
var private cachedBlockerStamp : int = -1
var private cachedLiveEnemyNodes : array<NodeId>
var private cachedLiveEnemyFeet : array<float2>
var private cachedLiveEnemyAlive : array<bool>
var private otherFeetScratch : array<float2>

class EnemyController : Component {
    kind : int = 1
    position : float2
    textures : EnemyTextures
    locomotionAnimTimer : float = 0.0
    dashCooldownTimer : float = 0.0
    dashing : bool = false
    dashDirection : float2
    dashRow : int = 0
    dashAnimTimer : float = 0.0
    dead : bool = false
    hp : int = 1
    maxHp : int = 1
    healthBar : EnemyHealthBarNodes = EnemyHealthBarNodes()
    takingDamage : bool = false
    damageRow : int = 0
    damageAnimTimer : float = 0.0
    dieRow : int = 0
    dieAnimTimer : float = 0.0
    hitFlashTimer : float = 0.0
    lastHitByPlayerAttackGen : int = -1
    attacking : bool = false
    castingSpell : bool = false
    attackRow : int = 0
    attackAnimTimer : float = 0.0
    attackCooldownTimer : float = 0.0
    attackHitDealt : bool = false
    spellProjectileSpawned : bool = false
    spellCastAimDir : float2
    facingRow : int = 0
    losCheckTimer : float = 0.0
    cachedHasLos : bool = false
    pathDetourTimer : float = 0.0
    cachedApproachGoal : float2
    cachedApproachTarget : float2
    cachedApproachValid : bool = false
    cachedFlankSign : float = 0.0
    losSeekTimer : float = 0.0
    cachedLosSeekAnchor : float2
    cachedLosSeekTarget : float2
    cachedLosSeekValid : bool = false
    depthSortKey : int = -99999999
    cacheIndex : int = -1
    castingBossAoe : bool = false
    bossAoeCharging : bool = false
    bossAoeChargeTimer : float = 0.0
    bossAoeCooldownTimer : float = 0.0
    bossAoeSpawned : bool = false
    bossAoeWarningNodes : array<NodeId>
    bossAoeTargetFeet : float2
    bossAoeGridX : int = 0
    bossAoeGridY : int = 0
    bossAoeCenterTiles : array<float2>
    bossAoeCastAnimTimer : float = 0.0
    bossOpeningAoePending : bool = false

    def kill(facingRow : int) {
        if (dead) {
            return
        }
        dead = true
        invalidate_enemy_cache_entry(cacheIndex)
        takingDamage = false
        hide_enemy_health_bar(healthBar)
        clear_boss_aoe_warnings()
        dieRow = facingRow
        dieAnimTimer = 0.0
        dashing = false
        depthSortKey = -99999999
        grant_enemy_kill_exp(kind, position)
        sync_sprite(textures.die, dieRow, 0)
    }

    def take_damage(facingRow : int; amount : int) {
        if (dead) {
            return
        }
        hp -= amount
        notify_enemy_health_damage(healthBar)
        sync_health_bar()
        if (hp <= 0) {
            kill(facingRow)
            return
        }
        hitFlashTimer = ENEMY_HIT_FLASH_DURATION
        if (attacking || castingSpell || castingBossAoe || bossAoeCharging) {
            return
        }
        takingDamage = true
        damageRow = facingRow
        damageAnimTimer = 0.0
        dashing = false
    }

    def clear_boss_aoe_warnings() {
        for (node in bossAoeWarningNodes) {
            if (node.isAlive) {
                remove_node(node)
            }
        }
        clear(bossAoeWarningNodes)
    }

    def melee_damage_amount() : int {
        if (kind == 7) {
            return ENEMY7_MELEE_DAMAGE
        }
        return ENEMY_MELEE_DAMAGE
    }

    def charge_melee_cooldown() : float {
        if (bossAoeCharging) {
            return ENEMY7_CHARGE_MELEE_COOLDOWN
        }
        return ENEMY7_MELEE_ATTACK_COOLDOWN
    }

    def apply_knockback(fromFeet : float2; strength : float) {
        if (dead || strength <= 0.0) {
            return
        }
        var away = position - fromFeet
        if (length_sq(away) < 0.0001) {
            away = float2(1.0, 0.0)
        } else {
            away = normalize(away)
        }
        apply_feet_move(position + away * strength)
    }

    def start_melee_attack(playerPos : float2) {
        attacking = true
        attackRow = facing_row_from_dir(playerPos - position)
        attackAnimTimer = 0.0
        attackHitDealt = false
    }

    def update_melee_attack(playerPos : float2; dt : float) {
        attackAnimTimer += dt * ENEMY_ATTACK_ANIM_FPS
        let col = int(attackAnimTimer)
        if (!attackHitDealt && attack_slash_active(attackRow, col)) {
            if (slash_hits_feet(position, playerPos, attackRow, col, PLAYER_ATTACK_MAX_REACH)) {
                queue_player_damage(melee_damage_amount(), position)
                attackHitDealt = true
            }
        }
        if (col >= PLAYER_SHEET_COLS) {
            attacking = false
            attackAnimTimer = 0.0
            if (kind == 7) {
                attackCooldownTimer = charge_melee_cooldown()
            } else {
                attackCooldownTimer = enemy_attack_cooldown(kind)
            }
            return
        }
        sync_sprite(textures.attack1, attackRow, col)
    }

    def start_spell_cast(playerPos : float2) {
        castingSpell = true
        let toPlayer = playerPos - position
        attackRow = facing_row_from_dir(toPlayer)
        if (length_sq(toPlayer) > 0.0001) {
            spellCastAimDir = normalize(toPlayer)
        } else {
            spellCastAimDir = facing_dir_from_row(attackRow)
        }
        attackAnimTimer = 0.0
        spellProjectileSpawned = false
    }

    def update_spell_cast(playerPos : float2; dt : float) {
        attackAnimTimer += dt * ENEMY_ATTACK_ANIM_FPS
        let col = int(attackAnimTimer)
        if (!spellProjectileSpawned && col >= ENEMY2_SPELL_PROJECTILE_COL) {
            let speed = spell_projectile_speed()
            if (kind == 6) {
                spawn_enemy_spell_volley(position, spellCastAimDir, speed, 3, ENEMY6_SPELL_SPREAD_DEG)
            } elif (kind == 7) {
                spawn_enemy_spell_volley(position, spellCastAimDir, speed, 5, ENEMY7_SPELL_SPREAD_DEG)
            } else {
                spawn_enemy_spell_projectile(position, spellCastAimDir, speed)
            }
            spellProjectileSpawned = true
        }
        if (col >= PLAYER_SHEET_COLS) {
            castingSpell = false
            attackAnimTimer = 0.0
            attackCooldownTimer = enemy_attack_cooldown(kind)
            return
        }
        sync_sprite(spell_cast_texture_for_kind(kind), attackRow, col)
    }

    def start_boss_aoe_cast() {
        castingBossAoe = true
        bossAoeSpawned = false
        let playerFeet = player_feet_from_scene_node()
        bossAoeTargetFeet = snap_feet_to_tile_center(playerFeet)
        let playerGrid = world_to_grid(playerFeet.x, playerFeet.y)
        bossAoeGridX = int(floor(playerGrid.x + 0.5))
        bossAoeGridY = int(floor(playerGrid.y + 0.5))
        clear(bossAoeCenterTiles)
        let centers = death_knight_aoe_centers_at_grid(bossAoeGridX, bossAoeGridY, position, playerFeet)
        for (center in centers) {
            push(bossAoeCenterTiles, center)
        }
        attackRow = facing_row_from_dir(playerFeet - position)
        bossAoeCastAnimTimer = 0.0
        clear_boss_aoe_warnings()
        for (center in bossAoeCenterTiles) {
            let node = spawn_aoe_warning_outline(center)
            if (node.isAlive) {
                push(bossAoeWarningNodes, node)
            }
        }
    }

    def finish_boss_aoe_cast() {
        if (bossAoeSpawned) {
            return
        }
        for (center in bossAoeCenterTiles) {
            spawn_enemy_aoe(center, position, ENEMY7_AOE_DAMAGE)
        }
        bossAoeSpawned = true
        clear_boss_aoe_warnings()
        castingBossAoe = false
        bossAoeCharging = true
        bossAoeChargeTimer = 0.0
        bossAoeCooldownTimer = ENEMY7_AOE_COOLDOWN
        attackCooldownTimer = 0.0
    }

    def update_boss_aoe_cast(playerPos : float2; dt : float) {
        bossAoeCastAnimTimer += dt * ENEMY7_CAST_SPELL_FPS
        let col = int(bossAoeCastAnimTimer)
        if (col >= ENEMY7_CAST_SPELL_COLS) {
            finish_boss_aoe_cast()
            bossAoeCastAnimTimer = 0.0
            return
        }
        sync_sprite(enemy7CastSpellTexture, attackRow, col)
    }

    def invalidate_approach_path() {
        cachedApproachValid = false
        pathDetourTimer = 0.0
    }

    def clear_flank_commitment() {
        cachedFlankSign = 0.0
    }

    def resolve_move_target(goal : float2; others : array<float2>) : float2 {
        let distToGoal = length(goal - position)
        if (distToGoal > AI_OBSTACLE_ROUTE_RANGE) {
            clear_flank_commitment()
            return goal
        }
        if (!blocks_feet_path(position, goal)) {
            clear_flank_commitment()
            cachedApproachGoal = goal
            cachedApproachTarget = goal
            cachedApproachValid = true
            pathDetourTimer = AI_PATH_RECOMPUTE_INTERVAL
            return goal
        }
        if (cachedFlankSign == 0.0) {
            let toGoal = goal - position
            let goalDir = toGoal / length(toGoal)
            cachedFlankSign = detour_preferred_side(position, goal, goalDir)
        }
        pathDetourTimer -= get_delta_time()
        let goalMoved = length_sq(cachedApproachGoal - goal) > AI_GOAL_MOVE_THRESHOLD * AI_GOAL_MOVE_THRESHOLD
        let step = ai_detour_step()
        let atWaypoint = cachedApproachValid && length_sq(cachedApproachTarget - goal) > AI_GOAL_MOVE_THRESHOLD * AI_GOAL_MOVE_THRESHOLD && length_sq(position - cachedApproachTarget) < step * step * 0.25
        let needRoute = !cachedApproachValid || pathDetourTimer <= 0.0 || goalMoved || atWaypoint
        if (!needRoute) {
            return cachedApproachTarget
        }
        pathDetourTimer = AI_PATH_RECOMPUTE_INTERVAL
        cachedApproachGoal = goal
        cachedApproachTarget = pick_obstacle_route(position, goal, others, cachedFlankSign)
        cachedApproachValid = true
        return cachedApproachTarget
    }

    def try_flank_slide(faceTarget : float2; speed, dt : float; before : float2) : bool {
        if (cachedFlankSign == 0.0) {
            return false
        }
        let toGoal = faceTarget - position
        let goalDist = length(toGoal)
        if (goalDist < 0.0001) {
            return false
        }
        let goalDir = toGoal / goalDist
        let perp = float2(-goalDir.y, goalDir.x) * cachedFlankSign
        let effectiveSpeed = terrain_adjusted_speed(speed, position)
        apply_feet_move(position + perp * effectiveSpeed * dt)
        return !movement_step_blocked(before, effectiveSpeed, dt)
    }

    def simple_move_toward(moveTarget, faceTarget : float2; speed : float; useRunTex : bool) {
        let dt = get_delta_time()
        let toTarget = moveTarget - position
        let dist = length(toTarget)
        if (dist <= entity_min_separation() * 0.5) {
            show_idle_toward(faceTarget)
            return
        }
        var dir = toTarget / dist
        let routingAroundCover = blocks_feet_path(position, faceTarget)
        if (!routingAroundCover) {
            dir = steer_away_from_live_entities(position, dir, nodeId)
        }
        let effectiveSpeed = terrain_adjusted_speed(speed, position)
        let before = position
        apply_feet_move(position + dir * effectiveSpeed * dt)
        var moved = !movement_step_blocked(before, effectiveSpeed, dt)
        if (!moved && routingAroundCover) {
            moved = try_flank_slide(faceTarget, speed, dt, before)
        }
        if (!moved) {
            invalidate_approach_path()
            show_idle_toward(faceTarget)
            return
        }
        locomotionAnimTimer += dt * ENEMY_WALK_ANIM_FPS
        let col = int(locomotionAnimTimer) % PLAYER_SHEET_COLS
        let row = facing_row_from_dir(faceTarget - position)
        if (useRunTex) {
            sync_sprite(enemy7RunTexture, row, col)
        } else {
            sync_sprite(textures.walk, row, col)
        }
    }

    def chase_player(playerPos : float2; speed : float) {
        fill_other_enemy_feet_from_cache(nodeId)
        let target = resolve_move_target(playerPos, otherFeetScratch)
        simple_move_toward(target, playerPos, speed, false)
    }

    def run_toward(target : float2; speed : float) {
        fill_other_enemy_feet_from_cache(nodeId)
        let moveTarget = resolve_move_target(target, otherFeetScratch)
        simple_move_toward(moveTarget, target, speed, true)
    }

    def los_seek_target(playerPos : float2) : float2 {
        losSeekTimer -= get_delta_time()
        let anchorMoved = length_sq(cachedLosSeekAnchor - playerPos) > AI_GOAL_MOVE_THRESHOLD * AI_GOAL_MOVE_THRESHOLD
        if (!cachedLosSeekValid || losSeekTimer <= 0.0 || anchorMoved) {
            losSeekTimer = AI_LOS_SEEK_RECOMPUTE_INTERVAL
            cachedLosSeekAnchor = playerPos
            cachedLosSeekTarget = find_mage_approach_point(position, playerPos, nodeId)
            cachedLosSeekValid = true
        }
        return cachedLosSeekTarget
    }

    def update_boss_aoe_charge(playerPos : float2; dt : float) {
        bossAoeChargeTimer += dt

        if (attacking) {
            update_melee_attack(playerPos, dt)
            return
        }

        if (attackCooldownTimer > 0.0) {
            attackCooldownTimer -= dt
        }

        let dist = length(playerPos - position)
        if (dist <= ENEMY_MELEE_ATTACK_DISTANCE && attackCooldownTimer <= 0.0) {
            start_melee_attack(playerPos)
            update_melee_attack(playerPos, dt)
            return
        }

        run_toward(playerPos, ENEMY7_CHARGE_SPEED)

        if (bossAoeChargeTimer >= ENEMY7_AOE_CHARGE_DURATION) {
            bossAoeCharging = false
            bossAoeChargeTimer = 0.0
        }
    }

    def update_death_knight(playerPos : float2) {
        let dt = get_delta_time()

        if (castingBossAoe) {
            update_boss_aoe_cast(playerPos, dt)
            return
        }

        if (bossAoeCharging) {
            update_boss_aoe_charge(playerPos, dt)
            return
        }

        if (castingSpell) {
            update_spell_cast(playerPos, dt)
            return
        }

        if (attackCooldownTimer > 0.0) {
            attackCooldownTimer -= dt
        }
        if (bossAoeCooldownTimer > 0.0) {
            bossAoeCooldownTimer -= dt
        }

        if (bossOpeningAoePending) {
            bossOpeningAoePending = false
            start_boss_aoe_cast()
            update_boss_aoe_cast(playerPos, dt)
            return
        }

        let dist = length(playerPos - position)
        if (bossAoeCooldownTimer <= 0.0 && dist <= ENEMY2_SPELL_MAX_DISTANCE && random_unit_float() < ENEMY7_AOE_TRY_CHANCE) {
            start_boss_aoe_cast()
            update_boss_aoe_cast(playerPos, dt)
            return
        }

        losCheckTimer -= dt
        if (losCheckTimer <= 0.0) {
            losCheckTimer = 0.6
            cachedHasLos = mage_has_los_to_player(position, playerPos)
        }
        let hasLos = cachedHasLos

        if (hasLos && attackCooldownTimer <= 0.0) {
            start_spell_cast(playerPos)
            update_spell_cast(playerPos, dt)
            return
        }

        if (!hasLos) {
            mage_seek_los(playerPos)
            return
        }

        if (dist > ENEMY2_PREFERRED_DISTANCE + ENEMY2_APPROACH_MARGIN) {
            chase_player(playerPos, ENEMY7_WALK_SPEED)
            return
        }

        if (dist < ENEMY2_PREFERRED_DISTANCE - ENEMY2_APPROACH_MARGIN) {
            walk_away_from(playerPos, ENEMY7_WALK_SPEED)
            return
        }

        show_idle_toward(playerPos)
    }

    def update_take_damage(playerPos : float2) {
        let dt = get_delta_time()
        let slowSpeed = terrain_adjusted_speed(ENEMY_SPEED / ENEMY_TAKE_DAMAGE_SPEED_DIVISOR, position)
        let toTarget = playerPos - position
        let dist = length(toTarget)
        if (dist > entity_min_separation() && dist > 0.0001) {
            fill_other_enemy_feet_from_cache(nodeId)
            let target = resolve_move_target(playerPos, otherFeetScratch)
            let toMove = target - position
            let moveDist = length(toMove)
            if (moveDist > 0.0001) {
                var dir = toMove / moveDist
                dir = steer_away_from_live_entities(position, dir, nodeId)
                apply_feet_move(position + dir * slowSpeed * dt)
            }
        }

        damageAnimTimer += dt * ENEMY_TAKE_DAMAGE_ANIM_FPS
        let col = int(damageAnimTimer)
        if (col >= PLAYER_SHEET_COLS) {
            takingDamage = false
            damageAnimTimer = 0.0
            return
        }
        let damageFaceRow = enemy_is_mage(kind) ? facing_row_from_dir(playerPos - position) : damageRow
        sync_sprite(textures.takeDamage, damageFaceRow, col)
    }

    def update_die() {
        let dt = get_delta_time()
        dieAnimTimer += dt * ENEMY_DIE_ANIM_FPS
        var col = int(dieAnimTimer)
        if (col >= PLAYER_SHEET_COLS - 1) {
            col = PLAYER_SHEET_COLS - 1
        }
        sync_sprite(textures.die, dieRow, col)
    }

    def apply_feet_move(desired : float2) {
        ensure_enemy_frame_cache(enemyFrameStamp)
        var pos = resolve_feet_move(position, desired, cachedStaticBlockers)
        if (playerNode.isAlive) {
            var playerBlockers : array<float2>
            push(playerBlockers, playerWorldPosition)
            pos = resolve_entity_separation(pos, position, playerBlockers)
        }
        position = resolve_live_entity_separation(pos, nodeId)
        sync_live_enemy_cache_feet(cacheIndex, position)
    }

    def apply_feet_move_with_blockers(desired : float2; blockers : array<float2>) {
        position = resolve_feet_move(position, desired, blockers)
    }

    def movement_step_blocked(before : float2; speed, dt : float) : bool {
        let expected = speed * dt
        if (expected <= 0.0001) {
            return true
        }
        return length(position - before) < expected * 0.2
    }

    def locomotion_speed() : float {
        if (kind == 6) {
            return ENEMY6_SPEED
        }
        if (kind == 7) {
            return ENEMY7_WALK_SPEED
        }
        return ENEMY_SPEED
    }

    def spell_projectile_speed() : float {
        return ENEMY_SPELL_PROJECTILE_SPEED
    }

    def dash_speed() : float {
        if (kind == 6) {
            return ENEMY6_DASH_SPEED
        }
        return ENEMY2_DASH_SPEED
    }

    def dash_cooldown_duration() : float {
        if (kind == 6) {
            return ENEMY6_DASH_COOLDOWN
        }
        return ENEMY2_DASH_COOLDOWN
    }

    def override on_initialize {
        maxHp = enemy_max_hp(kind)
        hp = maxHp
        healthBar = create_enemy_health_bar(kind)
        ensure_enemy_frame_cache(enemyFrameStamp)
        position = resolve_feet_move(position, position, cachedStaticBlockers)
        sync_health_bar()
        if (kind == 7) {
            bossOpeningAoePending = true
        }
    }

    def sync_health_bar() {
        if (dead) {
            hide_enemy_health_bar(healthBar)
            return
        }
        update_enemy_health_bar(healthBar, position, hp, maxHp)
    }

    def sync_sprite(tex : TextureId; row, col : int) {
        facingRow = row
        let layout = enemy_sprite_layout(row, col)
        let anchor = enemy_anchor_offset(layout)
        let depth = dead ? depth_sort_corpse_from_world(position) : depth_sort_entity_from_world(position)

        nodeId.localPosition = float3(position.x + anchor.x, position.y + anchor.y, 0.1)
        nodeId.localScale = float3(layout.scale.x, layout.scale.y, 1.0)
        nodeId?.SpriteRenderer.textureId = tex
        nodeId?.SpriteRenderer.uvRect = layout.uv
        nodeId?.SpriteRenderer.useTextureSizeForScaling = false
        let grid = world_to_grid(position.x, position.y)
        depthSortKey = int(grid.x + grid.y)
        if (dead) {
            nodeId?.SpriteRenderer.renderOrder = depth
        }
        if (hitFlashTimer > 0.0) {
            let flash = hitFlashTimer / ENEMY_HIT_FLASH_DURATION
            nodeId?.SpriteRenderer.color = float4(1.0, 0.35 + 0.65 * flash, 0.35 + 0.65 * flash, 1.0)
        } else {
            nodeId?.SpriteRenderer.color = float4(1.0, 1.0, 1.0, 1.0)
        }
    }

    def override on_destroy {
        destroy_enemy_health_bar(healthBar)
        clear_boss_aoe_warnings()
    }

    def show_idle_toward(target : float2) {
        locomotionAnimTimer += get_delta_time() * ENEMY_IDLE_ANIM_FPS
        let col = int(locomotionAnimTimer) % PLAYER_SHEET_COLS
        let row = facing_row_from_dir(target - position)
        sync_sprite(textures.idle, row, col)
    }

    def mage_step_toward(moveTarget : float2; speed : float) {
        fill_other_enemy_feet_from_cache(nodeId)
        let target = resolve_move_target(moveTarget, otherFeetScratch)
        simple_move_toward(target, moveTarget, speed, false)
    }

    def mage_seek_los(playerPos : float2) {
        fill_other_enemy_feet_from_cache(nodeId)
        let seekGoal = los_seek_target(playerPos)
        let target = resolve_move_target(seekGoal, otherFeetScratch)
        simple_move_toward(target, playerPos, locomotion_speed(), false)
    }

    def walk_toward(target : float2; speed : float) {
        fill_other_enemy_feet_from_cache(nodeId)
        let moveTarget = resolve_move_target(target, otherFeetScratch)
        simple_move_toward(moveTarget, target, speed, false)
    }

    def walk_away_from(target : float2; speed : float) {
        let dt = get_delta_time()
        let away = position - target
        let dist = length(away)
        if (dist <= 0.0001) {
            show_idle_toward(target)
            return
        }
        var dir = away / dist
        dir = steer_away_from_live_entities(position, dir, nodeId)
        let effectiveSpeed = terrain_adjusted_speed(speed, position)
        let before = position
        apply_feet_move(position + dir * effectiveSpeed * dt)
        if (movement_step_blocked(before, effectiveSpeed, dt)) {
            show_idle_toward(target)
            return
        }
        locomotionAnimTimer += dt * ENEMY_WALK_ANIM_FPS
        let col = int(locomotionAnimTimer) % PLAYER_SHEET_COLS
        sync_sprite(textures.walk, facing_row_from_dir(target - position), col)
    }

    def start_retreat_dash(playerPos : float2) {
        var away = position - playerPos
        if (length_sq(away) < 0.0001) {
            away = float2(1.0, 0.0)
        } else {
            away = normalize(away)
        }
        dashing = true
        dashDirection = away
        dashRow = facing_row_from_dir(dashDirection)
        dashAnimTimer = 0.0
    }

    def start_dash(playerPos : float2) {
        let toPlayer = playerPos - position
        if (length_sq(toPlayer) < 0.0001) {
            return
        }
        let forward = normalize(toPlayer)
        let side = random_bool() ? float2(forward.y, -forward.x) : float2(-forward.y, forward.x)
        dashing = true
        dashDirection = normalize(side)
        dashRow = facing_row_from_dir(dashDirection)
        dashAnimTimer = 0.0
    }

    def update_dash(dt : float) {
        let dashMoveSpeed = terrain_adjusted_speed(dash_speed(), position)
        apply_feet_move(position + dashDirection * dashMoveSpeed * dt)
        dashAnimTimer += dt * ENEMY_ATTACK_ANIM_FPS
        let col = int(dashAnimTimer)
        if (col >= PLAYER_SHEET_COLS) {
            dashing = false
            dashCooldownTimer = dash_cooldown_duration()
            return
        }
        sync_sprite(textures.attack1, dashRow, col)
    }

    def update_chaser(playerPos : float2) {
        let dt = get_delta_time()

        if (attacking) {
            update_melee_attack(playerPos, dt)
            return
        }

        if (attackCooldownTimer > 0.0) {
            attackCooldownTimer -= dt
        }

        let dist = length(playerPos - position)
        if (dist <= ENEMY_MELEE_ATTACK_DISTANCE && attackCooldownTimer <= 0.0) {
            start_melee_attack(playerPos)
            update_melee_attack(playerPos, dt)
            return
        }

        chase_player(playerPos, ENEMY_SPEED)
    }

    def update_stalker(playerPos : float2) {
        let dt = get_delta_time()
        let speed = locomotion_speed()

        if (dashing) {
            update_dash(dt)
            return
        }

        if (castingSpell) {
            update_spell_cast(playerPos, dt)
            return
        }

        if (dashCooldownTimer > 0.0) {
            dashCooldownTimer -= dt
        }

        if (attackCooldownTimer > 0.0) {
            attackCooldownTimer -= dt
        }

        let dist = length(playerPos - position)

        if (kind == 6 && dist < ENEMY6_DASH_TRIGGER_DISTANCE && dashCooldownTimer <= 0.0) {
            start_retreat_dash(playerPos)
            update_dash(dt)
            return
        }

        losCheckTimer -= dt
        if (losCheckTimer <= 0.0) {
            losCheckTimer = 0.6
            cachedHasLos = mage_has_los_to_player(position, playerPos)
        }
        let hasLos = cachedHasLos

        if (hasLos && attackCooldownTimer <= 0.0) {
            start_spell_cast(playerPos)
            update_spell_cast(playerPos, dt)
            return
        }

        if (!hasLos) {
            mage_seek_los(playerPos)
            return
        }

        if (dist > ENEMY2_PREFERRED_DISTANCE + ENEMY2_APPROACH_MARGIN) {
            chase_player(playerPos, speed)
            return
        }

        if (dist < ENEMY2_PREFERRED_DISTANCE - ENEMY2_APPROACH_MARGIN) {
            walk_away_from(playerPos, speed)
            return
        }

        show_idle_toward(playerPos)
    }

    def override on_update {
        if (dead) {
            update_die()
            return
        }
        if (hitFlashTimer > 0.0) {
            hitFlashTimer = max(0.0, hitFlashTimer - get_delta_time())
        }
        if (!playerNode.isAlive) {
            return
        }
        let playerPos = playerWorldPosition
        if (takingDamage) {
            update_take_damage(playerPos)
            return
        }
        if (enemy_is_death_knight(kind)) {
            update_death_knight(playerPos)
        } elif (enemy_is_mage(kind)) {
            update_stalker(playerPos)
        } else {
            update_chaser(playerPos)
        }
    }
}


class EnemySpellProjectile : Component {
    position : float2
    direction : float2
    fromFeet : float2
    speed : float = ENEMY_SPELL_PROJECTILE_SPEED
    traveled : float = 0.0
    consumed : bool = false
    deflected : bool = false

    def sync_visual() {
        nodeId.localPosition = float3(position.x, position.y, 0.12)
        nodeId.localRotation = quat4(0.0, 0.0, atan2(direction.y, direction.x))
        nodeId?.SpriteRenderer.renderOrder = depth_sort_projectile_from_world(position, ENEMY_SPELL_PROJECTILE_HIT_RADIUS)
    }

    def deflect(playerFeet : float2) {
        if (consumed || deflected) {
            return
        }
        deflected = true
        let away = position - playerFeet
        if (length_sq(away) > 0.0001) {
            direction = normalize(away)
        } else {
            direction = -direction
        }
        fromFeet = playerFeet
        traveled = 0.0
        sync_visual()
    }

    def try_hit_obstacles(prevPos : float2) {
        if (consumed) {
            return
        }
        if (projectile_segment_hits_obstacle(prevPos, position, ENEMY_SPELL_PROJECTILE_HIT_RADIUS)) {
            consumed = true
            remove_node(nodeId)
        }
    }

    def try_hit_player() {
        if (consumed || deflected || playerHp <= 0 || playerDashing) {
            return
        }
        if (circle_intersects_legs_box(position, ENEMY_SPELL_PROJECTILE_HIT_RADIUS, playerWorldPosition, PLAYER_WORLD_HEIGHT)) {
            consumed = true
            queue_player_damage(ENEMY_SPELL_DAMAGE, fromFeet)
            remove_node(nodeId)
        }
    }

    def try_hit_enemies() {
        if (consumed || !deflected || !enemiesRootNode.isAlive) {
            return
        }
        let hitRadius = ENEMY_SPELL_PROJECTILE_HIT_RADIUS
        for (i in range(cached_live_enemy_count())) {
            if (consumed) {
                return
            }
            let child = cached_live_enemy_node(i)
            if (!child.isAlive) {
                continue
            }
            get_component(child) $(var ctrl : EnemyController?) {
                if (ctrl != null && !ctrl.dead) {
                    if (circle_intersects_legs_box(position, hitRadius, ctrl.position, ENEMY_WORLD_HEIGHT)) {
                        consumed = true
                        var hitDir = position - ctrl.position
                        if (length_sq(hitDir) < 0.0001) {
                            hitDir = direction
                        }
                        ctrl.take_damage(facing_row_from_dir(hitDir), ENEMY_SPELL_DAMAGE)
                        remove_node(nodeId)
                    }
                }
            }
            if (consumed) {
                return
            }
        }
    }

    def override on_update {
        if (consumed) {
            return
        }

        let dt = get_delta_time()
        let step = direction * speed * dt
        let prevPos = position
        position += step
        traveled += length(step)

        sync_visual()

        try_hit_obstacles(prevPos)
        if (consumed) {
            return
        }

        if (deflected) {
            try_hit_enemies()
        } else {
            try_hit_player()
        }
        if (consumed) {
            return
        }

        if (!is_feet_in_grid_bounds(position) || traveled >= ENEMY_SPELL_PROJECTILE_MAX_RANGE) {
            remove_node(nodeId)
        }
    }
}


def spawn_enemy_spell_projectile(fromFeet : float2; aimDir : float2; speed : float) {
    if (!effectsRootNode.isAlive) {
        return
    }
    if (length_sq(aimDir) < 0.0001) {
        return
    }
    let direction = normalize(aimDir)
    let spawnPos = enemy_spell_spawn_position(fromFeet, direction)
    let node = create_node(NodeData(
        name = "enemy_spell",
        position = float3(spawnPos.x, spawnPos.y, 0.12),
        rotation = quat4(0.0, 0.0, atan2(direction.y, direction.x)),
        scale = float3(ENEMY_SPELL_PROJECTILE_WORLD_SIZE, ENEMY_SPELL_PROJECTILE_WORLD_SIZE, 1.0),
        parent = effectsRootNode
    ))
    add_component(node, new SpriteRenderer(
        textureId = enemySpellProjectileTexture,
        uvRect = float4(0.0, 0.0, 1.0, 1.0),
        useTextureSizeForScaling = false,
        renderOrder = depth_sort_projectile_from_world(spawnPos, ENEMY_SPELL_PROJECTILE_HIT_RADIUS)
    ))
    add_component(node, new EnemySpellProjectile(
        position = spawnPos,
        direction = direction,
        fromFeet = fromFeet,
        speed = speed
    ))
}


def rotate_dir2(dir : float2; radians : float) : float2 {
    let c = cos(radians)
    let s = sin(radians)
    return float2(dir.x * c - dir.y * s, dir.x * s + dir.y * c)
}


def spawn_enemy_spell_volley(fromFeet : float2; aimDir : float2; speed : float; count : int; spreadDeg : float) {
    if (length_sq(aimDir) < 0.0001) {
        return
    }
    let baseDir = normalize(aimDir)
    if (count <= 1) {
        spawn_enemy_spell_projectile(fromFeet, baseDir, speed)
        return
    }
    let totalSpread = spreadDeg * (PI / 180.0)
    for (i in range(count)) {
        let t = (float(i) / float(count - 1) - 0.5) * 2.0
        let angle = t * (totalSpread * 0.5)
        spawn_enemy_spell_projectile(fromFeet, rotate_dir2(baseDir, angle), speed)
    }
}


def refresh_enemy_frame_cache() {
    clear(cachedStaticBlockers)
    append_grid_wall_blockers(cachedStaticBlockers)
    append_prop_blockers(cachedStaticBlockers)
}


def refresh_live_enemy_cache() {
    clear(cachedLiveEnemyNodes)
    clear(cachedLiveEnemyFeet)
    clear(cachedLiveEnemyAlive)
    if (!enemiesRootNode.isAlive) {
        return
    }
    var inscope children = enemiesRootNode.get_children()
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var ctrl : EnemyController?) {
            if (ctrl != null) {
                ctrl.cacheIndex = -1
            }
        }
    }
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead) {
                let index = length(cachedLiveEnemyNodes)
                ctrl.cacheIndex = index
                push(cachedLiveEnemyNodes, child)
                push(cachedLiveEnemyFeet, ctrl.position)
                push(cachedLiveEnemyAlive, true)
            }
        }
    }
}


def sync_live_enemy_cache_feet(index : int; feet : float2) {
    if (index < 0 || index >= length(cachedLiveEnemyFeet)) {
        return
    }
    if (!cachedLiveEnemyAlive[index]) {
        return
    }
    cachedLiveEnemyFeet[index] = feet
}


def invalidate_enemy_cache_entry(index : int) {
    if (index < 0 || index >= length(cachedLiveEnemyAlive)) {
        return
    }
    cachedLiveEnemyAlive[index] = false
}


def fill_other_enemy_feet_from_cache(selfNode : NodeId) {
    clear(otherFeetScratch)
    for (i in range(length(cachedLiveEnemyNodes))) {
        if (cachedLiveEnemyNodes[i] != selfNode && cachedLiveEnemyAlive[i]) {
            push(otherFeetScratch, cachedLiveEnemyFeet[i])
        }
    }
}


def find_mage_approach_point(current, playerPos : float2; selfNode : NodeId) : float2 {
    fill_other_enemy_feet_from_cache(selfNode)
    var losPick = pick_mage_los_ring_point(playerPos, current, ENEMY2_PREFERRED_DISTANCE, otherFeetScratch)
    if (losPick.valid) {
        return losPick.point
    }
    losPick = pick_mage_los_ring_point(playerPos, current, ENEMY2_SPELL_MAX_DISTANCE, otherFeetScratch)
    if (losPick.valid) {
        return losPick.point
    }
    return playerPos
}


def steer_away_from_live_entities(from, desiredDir : float2; selfNode : NodeId) : float2 {
    if (length_sq(desiredDir) < 0.0001) {
        return desiredDir
    }
    var dir = desiredDir
    let minSep = entity_min_separation()
    let steerRadius = minSep * 2.5
    let steerRadiusSq = steerRadius * steerRadius
    for (i in range(length(cachedLiveEnemyNodes))) {
        if (cachedLiveEnemyNodes[i] == selfNode || !cachedLiveEnemyAlive[i]) {
            continue
        }
        let feet = cachedLiveEnemyFeet[i]
        let away = from - feet
        let distSq = length_sq(away)
        if (distSq < steerRadiusSq && distSq > 0.000001) {
            let dist = sqrt(distSq)
            let strength = (steerRadius - dist) / steerRadius
            dir += normalize(away) * strength
        }
    }
    if (length_sq(dir) < 0.0001) {
        return normalize(desiredDir)
    }
    return normalize(dir)
}


def resolve_live_entity_separation(pos : float2; selfNode : NodeId) : float2 {
    var result = pos
    let minSep = entity_min_separation()
    let minSepSq = minSep * minSep

    for (_ in range(2)) {
        for (i in range(length(cachedLiveEnemyNodes))) {
            if (cachedLiveEnemyNodes[i] == selfNode || !cachedLiveEnemyAlive[i]) {
                continue
            }
            let feet = cachedLiveEnemyFeet[i]
            let delta = result - feet
            let distSq = length_sq(delta)
            if (distSq < minSepSq) {
                if (distSq > 0.000001) {
                    let dist = sqrt(distSq)
                    result = feet + delta / dist * minSep
                } else {
                    result = feet + float2(minSep, 0.0)
                }
            }
        }
        result = clamp_feet_to_grid(result)
    }
    return clamp_feet_to_grid(result)
}


def public ensure_enemy_frame_cache(stamp : int) {
    if (cachedBlockerStamp == stamp) {
        return
    }
    cachedBlockerStamp = stamp
    refresh_enemy_frame_cache()
    refresh_live_enemy_cache()
}


def public refresh_enemy_hud_cache() {
    refresh_live_enemy_cache()
}


def public gather_blocking_feet(selfNode : NodeId) : array<float2> {
    ensure_enemy_frame_cache(enemyFrameStamp)
    var blockers : array<float2>
    for (p in cachedStaticBlockers) {
        push(blockers, p)
    }
    if (playerNode.isAlive && playerNode != selfNode) {
        push(blockers, playerWorldPosition)
    }
    fill_other_enemy_feet_from_cache(selfNode)
    for (p in otherFeetScratch) {
        push(blockers, p)
    }
    return <- blockers
}


def public cached_live_enemy_count() : int {
    return length(cachedLiveEnemyNodes)
}


def public cached_live_enemy_node(index : int) : NodeId {
    return cachedLiveEnemyNodes[index]
}


def public update_enemy_health_bar_positions() {
    if (!map_visibility_ready()) {
        return
    }
    let bounds = last_map_visibility_bounds()
    for (i in range(cached_live_enemy_count())) {
        get_component(cached_live_enemy_node(i)) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead) {
                let feet = ctrl.position
                let grid = world_to_grid(feet.x, feet.y)
                let gx = int(floor(grid.x + 0.5))
                let gy = int(floor(grid.y + 0.5))
                if (gx < bounds.minGx || gx > bounds.maxGx || gy < bounds.minGy || gy > bounds.maxGy) {
                    hide_enemy_health_bar(ctrl.healthBar)
                } else {
                    update_enemy_health_bar(ctrl.healthBar, feet, ctrl.hp, ctrl.maxHp)
                }
            }
        }
    }
}


def public apply_attack_hits(playerFeet : float2; row, col, attackGeneration : int) {
    if (!enemiesRootNode.isAlive) {
        return
    }
    if (!attack_slash_active(row, col)) {
        return
    }
    for (i in range(cached_live_enemy_count())) {
        get_component(cached_live_enemy_node(i)) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead && ctrl.lastHitByPlayerAttackGen != attackGeneration) {
                if (slash_hits_feet(playerFeet, ctrl.position, row, col, player_sword_range())) {
                    ctrl.lastHitByPlayerAttackGen = attackGeneration
                    let damage = resolve_weapon_damage(player_sword_damage(), player_sword_crit_chance())
                    ctrl.take_damage(facing_row_from_dir(playerFeet - ctrl.position), damage)
                    if (player_sword_knockback() > 0.0) {
                        ctrl.apply_knockback(playerFeet, player_sword_knockback())
                    }
                    apply_player_life_steal(damage, player_sword_life_steal())
                }
            }
        }
    }
}


def public apply_aoe_hits(center, playerFeet : float2) {
    apply_player_aoe_hits(
        center,
        playerFeet,
        player_special_damage(),
        player_special_aoe_hit_radius(),
        0.0,
        0.0,
        0.0
    )
}


def public apply_player_aoe_hits(
    center, playerFeet : float2;
    damage : int;
    hitRadius : float;
    critChance : float;
    knockback : float;
    lifeSteal : float
) {
    if (!enemiesRootNode.isAlive || damage <= 0) {
        return
    }
    let hitReach = hitRadius + ENTITY_FEET_RADIUS
    let hitReachSq = hitReach * hitReach
    var totalDamage = 0
    for (i in range(cached_live_enemy_count())) {
        get_component(cached_live_enemy_node(i)) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead) {
                if (length_sq(ctrl.position - center) <= hitReachSq) {
                    let hitDamage = resolve_weapon_damage(damage, critChance)
                    if (hitDamage > 0) {
                        ctrl.take_damage(facing_row_from_dir(playerFeet - ctrl.position), hitDamage)
                        totalDamage += hitDamage
                        if (knockback > 0.0) {
                            ctrl.apply_knockback(playerFeet, knockback)
                        }
                    }
                }
            }
        }
    }
    apply_player_life_steal(totalDamage, lifeSteal)
}


def count_living_enemies_of_kind(targetKind : int) : int {
    if (!enemiesRootNode.isAlive) {
        return 0
    }
    var alive = 0
    var inscope children = enemiesRootNode.get_children()
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead && ctrl.kind == targetKind) {
                alive += 1
            }
        }
    }
    return alive
}


def kind_spawn_allowed(livingTotal, kindCount : int; maxFraction : float) : bool {
    let nextTotal = livingTotal + 1
    let maxAllowed = int(floor(float(nextTotal) * maxFraction))
    return kindCount < maxAllowed
}


def pick_random_allowed_kind(allowed : array<int>) : int {
    if (length(allowed) == 0) {
        return 1
    }
    return allowed[random_range(0, length(allowed))]
}


def public random_enemy_kind() : int {
    let livingTotal = count_living_enemies()
    var allowed : array<int>
    push(allowed, 1)
    if (kind_spawn_allowed(livingTotal, count_living_enemies_of_kind(3), ENEMY3_MAX_FRACTION)) {
        push(allowed, 3)
    }
    if (kind_spawn_allowed(livingTotal, count_living_enemies_of_kind(2), ENEMY_MAGE_MAX_FRACTION)) {
        push(allowed, 2)
    }
    if (playerLevel >= ENEMY6_UNLOCK_LEVEL && kind_spawn_allowed(livingTotal, count_living_enemies_of_kind(6), ENEMY6_MAGE_MAX_FRACTION)) {
        push(allowed, 6)
    }
    return pick_random_allowed_kind(allowed)
}


def public count_living_enemies() : int {
    if (!enemiesRootNode.isAlive) {
        return 0
    }
    var alive = 0
    var inscope children = enemiesRootNode.get_children()
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead) {
                alive += 1
            }
        }
    }
    return alive
}
