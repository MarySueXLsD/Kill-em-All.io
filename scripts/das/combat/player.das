require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/world/collision
require scripts/das/combat/enemies
require scripts/das/combat/aoe_effects
require scripts/das/combat/projectiles
require scripts/das/world/prefab_texture_hydrate
require scripts/das/core/game_state
require scripts/das/ui/player_hud
require scripts/das/world/world
require scripts/das/world/level
module player public

struct SpriteLayout {
    uv : float4
    scale : float2
    worldHeight : float
}

struct SpriteChoice {
    texture : TextureId
    row : int
}

var public idleTexture : TextureId
var public walkTexture : TextureId
var public runTexture : TextureId
var public attack1Texture : TextureId
var public attack2Texture : TextureId
var public attack3Texture : TextureId
var public takeDamageTexture : TextureId


def public load_spawn_player_textures() {
    idleTexture = texture_from_cache_only(PLAYER_IDLE_PATH)
    walkTexture = texture_from_cache_only(PLAYER_WALK_PATH)
    runTexture = texture_from_cache_only(PLAYER_RUN_PATH)
    attack1Texture = texture_from_cache_only(PLAYER_ATTACK1_PATH)
    if (!texture_id_is_valid(walkTexture)) {
        walkTexture = idleTexture
    }
    if (!texture_id_is_valid(runTexture)) {
        runTexture = idleTexture
    }
    if (!texture_id_is_valid(attack1Texture)) {
        attack1Texture = idleTexture
    }
    attack2Texture = texture_from_cache_only(PLAYER_ATTACK2_PATH)
    if (!texture_id_is_valid(attack2Texture)) {
        attack2Texture = idleTexture
    }
    attack3Texture = texture_from_cache_only(PLAYER_ATTACK3_PATH)
    if (!texture_id_is_valid(attack3Texture)) {
        attack3Texture = idleTexture
    }
    takeDamageTexture = texture_from_cache_only(PLAYER_TAKE_DAMAGE_PATH)
    if (!texture_id_is_valid(takeDamageTexture)) {
        takeDamageTexture = idleTexture
    }
}


def public refresh_spawn_player_textures_from_cache() {
    let idle = texture_from_cache_only(PLAYER_IDLE_PATH)
    if (texture_id_is_valid(idle)) {
        idleTexture = idle
    }
    let walk = texture_from_cache_only(PLAYER_WALK_PATH)
    if (texture_id_is_valid(walk)) {
        walkTexture = walk
    }
    let run = texture_from_cache_only(PLAYER_RUN_PATH)
    if (texture_id_is_valid(run)) {
        runTexture = run
    }
    let attack1 = texture_from_cache_only(PLAYER_ATTACK1_PATH)
    if (texture_id_is_valid(attack1)) {
        attack1Texture = attack1
    }
    let attack2 = texture_from_cache_only(PLAYER_ATTACK2_PATH)
    if (texture_id_is_valid(attack2)) {
        attack2Texture = attack2
    }
    let attack3 = texture_from_cache_only(PLAYER_ATTACK3_PATH)
    if (texture_id_is_valid(attack3)) {
        attack3Texture = attack3
    }
    let takeDamage = texture_from_cache_only(PLAYER_TAKE_DAMAGE_PATH)
    if (texture_id_is_valid(takeDamage)) {
        takeDamageTexture = takeDamage
    }
}


def public queue_spawn_player_texture_paths() {
    queue_texture_path(PLAYER_IDLE_PATH)
    queue_texture_path(PLAYER_WALK_PATH)
    queue_texture_path(PLAYER_RUN_PATH)
    queue_texture_path(PLAYER_ATTACK1_PATH)
}


def public load_background_player_textures() {
    attack2Texture = request_texture_cached(PLAYER_ATTACK2_PATH)
    attack3Texture = request_texture_cached(PLAYER_ATTACK3_PATH)
    takeDamageTexture = request_texture_cached(PLAYER_TAKE_DAMAGE_PATH)
    if (!texture_id_is_valid(attack2Texture)) {
        attack2Texture = idleTexture
    }
    if (!texture_id_is_valid(attack3Texture)) {
        attack3Texture = idleTexture
    }
    if (!texture_id_is_valid(takeDamageTexture)) {
        takeDamageTexture = idleTexture
    }
}


def public load_player_textures() {
    idleTexture = request_texture_cached(PLAYER_IDLE_PATH)
    walkTexture = request_texture_cached(PLAYER_WALK_PATH)
    runTexture = request_texture_cached(PLAYER_RUN_PATH)
    attack1Texture = request_texture_cached(PLAYER_ATTACK1_PATH)
    attack2Texture = request_texture_cached(PLAYER_ATTACK2_PATH)
    attack3Texture = request_texture_cached(PLAYER_ATTACK3_PATH)
    takeDamageTexture = request_texture_cached(PLAYER_TAKE_DAMAGE_PATH)
}


def public queue_player_texture_paths() {
    queue_spawn_player_texture_paths()
    queue_background_player_texture_paths()
}


def public queue_background_player_texture_paths() {
    queue_texture_path(PLAYER_ATTACK2_PATH)
    queue_texture_path(PLAYER_ATTACK3_PATH)
    queue_texture_path(PLAYER_TAKE_DAMAGE_PATH)
}


def sprite_layout(row, col : int) : SpriteLayout {
    let tileW = PLAYER_SHEET_WIDTH / float(PLAYER_SHEET_COLS)
    let tileH = PLAYER_SHEET_HEIGHT / float(PLAYER_SHEET_ROWS)
    let worldH = PLAYER_WORLD_HEIGHT
    let worldW = worldH * (tileW / tileH)
    return SpriteLayout(
        uv = uv_rect_from_tile(col, row, PLAYER_SHEET_COLS, PLAYER_SHEET_ROWS),
        scale = float2(worldW, worldH),
        worldHeight = worldH
    )
}


def player_anchor_offset(layout : SpriteLayout) : float2 {
    return entity_sprite_anchor_offset(
        layout.worldHeight,
        PLAYER_SHEET_HEIGHT,
        float(PLAYER_SHEET_ROWS),
        PLAYER_SHEET_WIDTH,
        float(PLAYER_SHEET_COLS)
    )
}


def public cursor_world_position() : float2 {
    if (!cameraNode.isAlive) {
        return float2(0.0)
    }
    let cam = cameraNode?.Camera
    let mousePos = get_action_vector2("cursor")
    return cam.screenToWorldDepth(mousePos, 0.1).xy
}


def player_facing_aim_origin(feet : float2) : float2 {
    let layout = sprite_layout(0, 0)
    let anchor = player_anchor_offset(layout)
    return feet + float2(0.0, anchor.y * PLAYER_ATTACK_FACING_AIM_HEIGHT_FRACTION)
}


def cursor_facing_row(playerFeet : float2) : int {
    if (!cameraNode.isAlive) {
        return 0
    }
    let cam = cameraNode?.Camera
    let cursorWorld = cursor_world_position()
    let aimOrigin = player_facing_aim_origin(playerFeet)
    let aimScreen = cam.worldToScreen(float3(aimOrigin.x, aimOrigin.y, 0.1)).xy
    let cursorScreen = cam.worldToScreen(float3(cursorWorld.x, cursorWorld.y, 0.1)).xy
    // Project both points through the camera so screen deltas match what you click.
    // Screen Y grows downward; flip so screen-down maps to bottom-facing rows.
    let screenDir = float2(cursorScreen.x - aimScreen.x, aimScreen.y - cursorScreen.y)
    return direction_to_facing_row(screenDir)
}


def cursor_aim_direction(playerFeet : float2) : float2 {
    let aimOrigin = player_facing_aim_origin(playerFeet)
    let toCursor = cursor_world_position() - aimOrigin
    if (length_sq(toCursor) < 0.0001) {
        return facing_dir_from_row(cursor_facing_row(playerFeet))
    }
    return normalize(toCursor)
}


def pick_sprite(playerPos, move : float2; moving, running : bool) : SpriteChoice {
    if (!moving) {
        return SpriteChoice(
            texture = idleTexture,
            row = cursor_facing_row(playerPos)
        )
    }

    let row = direction_to_facing_row(wasd_to_iso_direction(move))
    if (running) {
        return SpriteChoice(texture = runTexture, row = row)
    }
    return SpriteChoice(texture = walkTexture, row = row)
}


def anim_fps(move : float2; running : bool) : float {
    if (length_sq(move) < 0.01) {
        return PLAYER_IDLE_ANIM_FPS
    }
    if (running) {
        return PLAYER_RUN_ANIM_FPS
    }
    return PLAYER_WALK_ANIM_FPS
}


struct DashGhost {
    node : NodeId
    age : float
}


var private activeDashGhosts : array<DashGhost>


def spawn_dash_ghost(pos : float2; row, col : int) {
    let layout = sprite_layout(row, col)
    let anchor = player_anchor_offset(layout)
    let depth = depth_sort_entity_from_world(pos) - 1

    let ghostNode = create_node(NodeData(
        name = "dash_ghost",
        position = float3(pos.x + anchor.x, pos.y + anchor.y, SPRITE_DRAW_Z),
        scale = float3(layout.scale.x, layout.scale.y, 1.0),
        parent = mapRootNode
    ))
    add_component(ghostNode, new SpriteRenderer(
        textureId = runTexture,
        uvRect = layout.uv,
        color = float4(1.0, 1.0, 1.0, 0.85),
        useTextureSizeForScaling = false,
        renderOrder = depth
    ))
    push(activeDashGhosts, DashGhost(node = ghostNode, age = 0.0))
}


def public update_dash_ghosts() {
    if (length(activeDashGhosts) == 0) {
        return
    }
    let dt = get_delta_time()
    var i = 0
    while (i < length(activeDashGhosts)) {
        if (!activeDashGhosts[i].node.isAlive) {
            erase(activeDashGhosts, i)
            continue
        }
        activeDashGhosts[i].age += dt
        let t = activeDashGhosts[i].age / PLAYER_DASH_GHOST_FADE_DURATION
        if (t >= 1.0) {
            remove_node(activeDashGhosts[i].node)
            erase(activeDashGhosts, i)
            continue
        }
        let alpha = (1.0 - t) * 0.85
        activeDashGhosts[i].node?.SpriteRenderer.color = float4(1.0, 1.0, 1.0, alpha)
        i += 1
    }
}


[hot_reload_class]
class PlayerController : Component {
    @no_export
    position : float2
    @no_export
    facingRow : int = 0
    @no_export
    locomotionAnimTimer : float = 0.0
    @no_export
    actionActive : bool = false
    @no_export
    actionAllowMove : bool = false
    @no_export
    actionTrackCursor : bool = false
    @no_export
    actionTexture : TextureId
    @no_export
    actionRow : int = 0
    @no_export
    actionFps : float = PLAYER_ATTACK_ANIM_FPS
    @no_export
    actionAnimTimer : float = 0.0
    @no_export
    actionIsSpecial : bool = false
    @no_export
    actionIsBow : bool = false
    @no_export
    specialAoeSpawned : bool = false
    @no_export
    bowProjectileSpawned : bool = false
    @no_export
    specialTargetWorld : float2
    @no_export
    specialCooldownTimer : float = 0.0
    @no_export
    dashing : bool = false
    @no_export
    dashDirection : float2
    @no_export
    dashRow : int = 0
    @no_export
    dashTraveled : float = 0.0
    @no_export
    dashGhostTimer : float = 0.0
    @no_export
    dashAnimTimer : float = 0.0
    @no_export
    dashCooldownTimer : float = 0.0
    @no_export
    attackHitGeneration : int = 0
    @no_export
    takingDamage : bool = false
    @no_export
    damageRow : int = 0
    @no_export
    damageAnimTimer : float = 0.0
    @no_export
    depthSortKey : int = -99999999
    @no_export
    spawnInitialized : bool = false

    def apply_queued_damage() {
        if (length(playerDamageQueue) == 0) {
            return
        }
        for (event in playerDamageQueue) {
            take_damage(event.amount, event.fromFeet)
        }
        clear(playerDamageQueue)
    }

    def take_damage(amount : int; fromFeet : float2) {
        if (playerHp <= 0 || dashing) {
            return
        }
        playerHp = max(0, playerHp - amount)
        notify_player_health_damage()
        if (playerHp <= 0) {
            takingDamage = false
            actionActive = false
            dashing = false
            return
        }
        takingDamage = true
        actionActive = false
        damageRow = direction_to_facing_row(fromFeet - position)
        damageAnimTimer = 0.0
        dashing = false
    }

    def update_take_damage(move : float2; dt : float) {
        let speed = terrain_adjusted_speed(player_move_speed() * PLAYER_TAKE_DAMAGE_MOVE_SPEED_MULTIPLIER, position)
        let vel = wasd_to_iso_velocity(move, speed)
        apply_feet_move(position + vel * dt)

        damageAnimTimer += dt * PLAYER_TAKE_DAMAGE_ANIM_FPS
        let col = int(damageAnimTimer)
        if (col >= PLAYER_SHEET_COLS) {
            takingDamage = false
            damageAnimTimer = 0.0
            return
        }
        sync_sprite(takeDamageTexture, damageRow, col)
    }

    def apply_feet_move(desired : float2) {
        ensure_enemy_frame_cache(enemyFrameStamp)
        let blockers = gather_blocking_feet(nodeId)
        position = resolve_legs_feet_move(position, desired, PLAYER_WORLD_HEIGHT, blockers)
        playerWorldPosition = position
    }

    def feet_from_node() : float2 {
        let layout = sprite_layout(0, 0)
        let anchor = player_anchor_offset(layout)
        return nodeId.localPosition.xy - anchor
    }

    def spawn_feet_position() : float2 {
        if (playerNode.isAlive) {
            return feet_from_node()
        }
        if (playerSpawnFeetValid) {
            return playerSpawnFeet
        }
        return feet_from_node()
    }

    def public initialize_spawn_state() {
        position = spawn_feet_position()
        position = clamp_feet_to_grid(position)
        playerWorldPosition = position
        playerHp = player_max_hp()
        if (gameTexturesVerified) {
            sync_sprite(idleTexture, 0, 0)
        } else {
            sync_sprite_layout(0, 0)
        }
        spawnInitialized = true
    }

    def override on_initialize {
        // spawn_player() calls initialize_spawn_state() after textures are loaded.
    }

    def start_action(tex : TextureId; row : int; fps : float; allowMove, trackCursor, isSpecial, isBow : bool) {
        takingDamage = false
        actionActive = true
        actionAllowMove = allowMove
        actionTrackCursor = trackCursor
        actionIsSpecial = isSpecial
        actionIsBow = isBow
        actionTexture = tex
        actionRow = row
        actionFps = fps
        actionAnimTimer = 0.0
        specialAoeSpawned = false
        bowProjectileSpawned = false
        if (tex == attack1Texture) {
            attackHitGeneration += 1
        }
    }

    def start_special(row : int) {
        specialTargetWorld = cursor_world_position()
        start_action(attack3Texture, row, PLAYER_SPECIAL_ANIM_FPS, true, false, true, false)
    }

    def start_dash(move : float2) {
        let dir = wasd_to_iso_direction(move)
        if (length_sq(dir) < 0.01) {
            return
        }
        takingDamage = false
        dashing = true
        dashDirection = normalize(dir)
        dashRow = direction_to_facing_row(dashDirection)
        dashTraveled = 0.0
        dashGhostTimer = 0.0
        dashAnimTimer = locomotionAnimTimer
        actionActive = false
        playerDashing = true
        spawn_dash_ghost(position, dashRow, int(dashAnimTimer) % PLAYER_SHEET_COLS)
    }

    def update_dash(dt : float) {
        let dashSpeed = terrain_adjusted_speed(PLAYER_DASH_DISTANCE / PLAYER_DASH_DURATION, position)
        position = constrain_feet_move_for_terrain(position, position + dashDirection * dashSpeed * dt)
        playerWorldPosition = position
        dashTraveled += dashSpeed * dt

        dashAnimTimer += dt * PLAYER_DASH_ANIM_FPS
        let col = int(dashAnimTimer) % PLAYER_SHEET_COLS

        dashGhostTimer += dt
        if (dashGhostTimer >= PLAYER_DASH_GHOST_SPAWN_INTERVAL) {
            dashGhostTimer -= PLAYER_DASH_GHOST_SPAWN_INTERVAL
            spawn_dash_ghost(position, dashRow, col)
        }

        sync_sprite(runTexture, dashRow, col)

        if (dashTraveled >= PLAYER_DASH_DISTANCE) {
            let overshoot = dashTraveled - PLAYER_DASH_DISTANCE
            if (overshoot > 0.0) {
                position -= dashDirection * overshoot
            }
            dashing = false
            dashCooldownTimer = player_dash_cooldown()
        }
    }

    def sync_player_cooldown_hud_state() {
        playerDashCooldownRemaining = max(0.0, dashCooldownTimer)
        playerSpecialCooldownRemaining = max(0.0, specialCooldownTimer)
        playerDashing = dashing
        playerSpecialActive = actionActive && actionIsSpecial
    }

    def override on_update {
        if (!gameReady || !spawnInitialized) {
            return
        }
        let dt = get_delta_time()
        playerWorldPosition = position

        if (playerHp <= 0) {
            playerDashing = false
            playerSpecialActive = false
            playerDashCooldownRemaining = 0.0
            playerSpecialCooldownRemaining = 0.0
            return
        }

        if (upgradePickerActive) {
            sync_player_cooldown_hud_state()
            return
        }

        if (!dashing && dashCooldownTimer > 0.0) {
            dashCooldownTimer -= dt
        }

        if (specialCooldownTimer > 0.0) {
            specialCooldownTimer -= dt
        }

        if (dashing) {
            update_dash(dt)
            sync_player_cooldown_hud_state()
            return
        }

        let move = get_action_vector2("move")
        let running = is_action_pressed("run") && !takingDamage
        let cursorRow = cursor_facing_row(position)

        if (!actionActive && length_sq(move) >= 0.01 && dashCooldownTimer <= 0.0 && is_action_just_pressed("dash")) {
            start_dash(move)
            update_dash(dt)
            sync_player_cooldown_hud_state()
            return
        }

        apply_queued_damage()

        if (is_action_just_pressed("weaponSwitch") && !isBaseLevel) {
            if (playerWeapon == PlayerWeapon.Sword) {
                playerWeapon = PlayerWeapon.Bow
            } else {
                playerWeapon = PlayerWeapon.Sword
            }
        } else {
            let weaponScroll = get_action_axis("weaponScroll")
            if (!isBaseLevel && abs(weaponScroll) > 0.001) {
                if (playerWeapon == PlayerWeapon.Sword) {
                    playerWeapon = PlayerWeapon.Bow
                } else {
                    playerWeapon = PlayerWeapon.Sword
                }
            }
        }

        if (takingDamage && !isBaseLevel) {
            if (is_action_just_pressed("attack")) {
                if (playerWeapon == PlayerWeapon.Bow) {
                    start_action(attack2Texture, cursorRow, player_attack_anim_fps(), true, true, false, true)
                } else {
                    start_action(attack1Texture, cursorRow, player_attack_anim_fps(), true, true, false, false)
                }
            }
            if (!actionActive && is_action_just_pressed("special") && specialCooldownTimer <= 0.0 && is_world_on_grid(cursor_world_position())) {
                start_special(cursorRow)
            }
            if (!actionActive && length_sq(move) >= 0.01 && dashCooldownTimer <= 0.0) {
                if (is_action_just_pressed("dash")) {
                    start_dash(move)
                    update_dash(dt)
                    sync_player_cooldown_hud_state()
                    return
                }
            }
            if (takingDamage && !actionActive) {
                update_take_damage(move, dt)
                sync_player_cooldown_hud_state()
                return
            }
        }

        if (!actionActive && !isBaseLevel) {
            if (is_action_just_pressed("special") && specialCooldownTimer <= 0.0 && is_world_on_grid(cursor_world_position())) {
                start_special(cursorRow)
            }
            if (is_action_just_pressed("attack")) {
                if (playerWeapon == PlayerWeapon.Bow) {
                    start_action(attack2Texture, cursorRow, player_attack_anim_fps(), true, true, false, true)
                } else {
                    start_action(attack1Texture, cursorRow, player_attack_anim_fps(), true, true, false, false)
                }
            }
        }

        if (actionActive) {
            if (actionTrackCursor) {
                actionRow = cursorRow
            }

            if (actionAllowMove) {
                var moveMultiplier = PLAYER_ATTACK_MOVE_SPEED_MULTIPLIER
                if (actionIsSpecial) {
                    moveMultiplier = PLAYER_SPECIAL_MOVE_SPEED_MULTIPLIER
                }
                let actionSpeed = terrain_adjusted_speed(player_move_speed() * moveMultiplier, position)
                let vel = wasd_to_iso_velocity(move, actionSpeed)
                apply_feet_move(position + vel * dt)
            }

            actionAnimTimer += dt * actionFps
            let col = int(actionAnimTimer)
            if (col >= PLAYER_SHEET_COLS) {
                if (actionIsSpecial) {
                    specialCooldownTimer = player_special_cooldown()
                }
                actionActive = false
                actionIsSpecial = false
                actionIsBow = false
                actionAnimTimer = 0.0
            } else {
                if (actionIsSpecial && !specialAoeSpawned && col >= PLAYER_SPECIAL_AOE_COL) {
                    spawn_aoe(specialTargetWorld)
                    apply_aoe_hits(specialTargetWorld, position)
                    specialAoeSpawned = true
                } elif (!actionIsSpecial && !actionIsBow && actionTexture == attack1Texture) {
                    apply_attack_hits(position, actionRow, col, attackHitGeneration)
                    deflect_enemy_projectiles_in_slash(position, actionRow, col)
                } elif (actionIsBow && !bowProjectileSpawned && col >= PLAYER_BOW_PROJECTILE_COL) {
                    spawn_arrow_projectile(position, cursor_aim_direction(position))
                    bowProjectileSpawned = true
                }
                sync_sprite(actionTexture, actionRow, col)
                sync_player_cooldown_hud_state()
                return
            }
        }

        let baseSpeed = running ? player_run_speed() : player_move_speed()
        let speed = terrain_adjusted_speed(baseSpeed, position)
        let vel = wasd_to_iso_velocity(move, speed)
        let moving = length_sq(move) >= 0.01
        let choice = pick_sprite(position, move, moving, running)

        facingRow = choice.row

        apply_feet_move(position + vel * dt)
        locomotionAnimTimer += dt * anim_fps(move, running)
        let col = int(locomotionAnimTimer) % PLAYER_SHEET_COLS
        sync_sprite(choice.texture, choice.row, col)
        sync_player_cooldown_hud_state()
    }

    def sync_sprite(tex : TextureId; row, col : int) {
        let layout = sprite_layout(row, col)
        let anchor = player_anchor_offset(layout)

        nodeId.localPosition = float3(position.x + anchor.x, position.y + anchor.y, SPRITE_DRAW_Z)
        nodeId.localScale = float3(layout.scale.x, layout.scale.y, 1.0)
        nodeId?.SpriteRenderer.textureId = tex
        nodeId?.SpriteRenderer.uvRect = layout.uv
        nodeId?.SpriteRenderer.useTextureSizeForScaling = false
        let grid = world_to_grid(position.x, position.y)
        depthSortKey = int(grid.x + grid.y)
    }

    def sync_sprite_layout(row, col : int) {
        let layout = sprite_layout(row, col)
        let anchor = player_anchor_offset(layout)

        nodeId.localPosition = float3(position.x + anchor.x, position.y + anchor.y, SPRITE_DRAW_Z)
        nodeId.localScale = float3(layout.scale.x, layout.scale.y, 1.0)
        nodeId?.SpriteRenderer.uvRect = layout.uv
        nodeId?.SpriteRenderer.useTextureSizeForScaling = false
        let grid = world_to_grid(position.x, position.y)
        depthSortKey = int(grid.x + grid.y)
    }
}


def snap_camera_to_player() {
    if (!playerNode.isAlive || !cameraNode.isAlive) {
        return
    }
    let layout = sprite_layout(0, 0)
    let anchor = player_anchor_offset(layout)
    var feet = playerWorldPosition
    if (!playerSpawnFeetValid && length_sq(feet) < 0.0001) {
        feet = playerSpawnFeet
    }
    let spritePos = feet + anchor
    cameraNode.localPosition = float3(spritePos.x, spritePos.y, CAMERA_Z)
}


def create_runtime_player_fallback() {
    let spawnPos = grid_to_world(PLAYER_SPAWN_GRID_X, PLAYER_SPAWN_GRID_Y)
    let layout = sprite_layout(0, 0)
    let anchor = player_anchor_offset(layout)

    playerNode = create_node(NodeData(
        name = "player",
        position = float3(spawnPos.x + anchor.x, spawnPos.y + anchor.y, SPRITE_DRAW_Z),
        scale = float3(layout.scale.x, layout.scale.y, 1.0),
        parent = levelRootNode
    ))
    add_component(playerNode, new SpriteRenderer(
        textureId = idleTexture,
        uvRect = layout.uv,
        useTextureSizeForScaling = false,
        renderOrder = depth_sort_entity_from_world(spawnPos)
    ))
    add_component(playerNode, new PlayerController())
}


def public spawn_player() {
    playerNode = find_child(levelRootNode, "player")
    if (!playerNode.isAlive) {
        create_runtime_player_fallback()
        playerSpawnFeet = player_feet_from_scene_node()
        playerSpawnFeetValid = true
    } elif (!playerSpawnFeetValid) {
        playerSpawnFeet = player_feet_from_scene_node()
        playerSpawnFeetValid = true
    }
    get_component(playerNode) $(var ctrl : PlayerController?) {
        if (ctrl == null) {
            add_component(playerNode, new PlayerController())
            get_component(playerNode) $(var added : PlayerController?) {
                if (added != null) {
                    added.initialize_spawn_state()
                }
            }
        } else {
            ctrl.initialize_spawn_state()
        }
    }
    snap_camera_to_player()
}


def public sync_player_world_position() {
    if (!playerNode.isAlive) {
        return
    }
    get_component(playerNode) $(var ctrl : PlayerController?) {
        if (ctrl != null) {
            playerWorldPosition = ctrl.position
        }
    }
}
