require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/combat/combat
require scripts/das/combat/enemies
require scripts/das/combat/aoe_effects
require scripts/das/world/props
require scripts/das/combat/weapon_combat
require scripts/das/world/prefab_texture_hydrate
module projectiles public

var public fireSpellTextures : array<TextureId>


def push_fire_spell_from_cache(texPath : string) {
    let tex = texture_from_cache_only(texPath)
    if (texture_id_is_valid(tex)) {
        push(fireSpellTextures, tex)
    }
}


def queue_fire_spell_texture_paths() {
    queue_texture_path("static/Projectiles/fire_spell/0003.png")
    queue_texture_path("static/Projectiles/fire_spell/0005.png")
    queue_texture_path("static/Projectiles/fire_spell/0007.png")
    queue_texture_path("static/Projectiles/fire_spell/0009.png")
    queue_texture_path("static/Projectiles/fire_spell/0011.png")
    queue_texture_path("static/Projectiles/fire_spell/0013.png")
    queue_texture_path("static/Projectiles/fire_spell/0015.png")
    queue_texture_path("static/Projectiles/fire_spell/0017.png")
    queue_texture_path("static/Projectiles/fire_spell/0019.png")
    queue_texture_path("static/Projectiles/fire_spell/0021.png")
    queue_texture_path("static/Projectiles/fire_spell/0023.png")
    queue_texture_path("static/Projectiles/fire_spell/0025.png")
    queue_texture_path("static/Projectiles/fire_spell/0027.png")
    queue_texture_path("static/Projectiles/fire_spell/0029.png")
}


def load_fire_spell_textures_from_cache() {
    clear(fireSpellTextures)
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0003.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0005.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0007.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0009.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0011.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0013.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0015.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0017.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0019.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0021.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0023.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0025.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0027.png")
    push_fire_spell_from_cache("static/Projectiles/fire_spell/0029.png")
}


def public load_spawn_projectile_textures() {
    load_fire_spell_textures_from_cache()
}


def public refresh_projectile_textures_from_cache() {
    load_fire_spell_textures_from_cache()
}


def public queue_spawn_projectile_texture_paths() {
    queue_fire_spell_texture_paths()
}


def public queue_background_projectile_texture_paths() {
}


def public load_projectile_textures() {
    clear(fireSpellTextures)
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0003.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0005.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0007.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0009.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0011.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0013.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0015.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0017.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0019.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0021.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0023.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0025.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0027.png"))
    push(fireSpellTextures, request_texture_cached("static/Projectiles/fire_spell/0029.png"))
}


def public queue_projectile_texture_paths() {
    queue_spawn_projectile_texture_paths()
    queue_background_projectile_texture_paths()
}


def projectile_spawn_position(feet : float2; aimDir : float2) : float2 {
    let forward = normalize(aimDir)
    let pixelToWorld = PLAYER_WORLD_HEIGHT / (PLAYER_SHEET_HEIGHT / float(PLAYER_SHEET_ROWS))
    return feet + forward * (28.0 * pixelToWorld) + float2(0.0, 18.0 * pixelToWorld)
}


def projectile_facing_angle(direction : float2) : float {
    return atan2(direction.y, direction.x)
}


def hit_effect_position(enemyFeet : float2) : float2 {
    let legsH = entity_legs_box_size_world(ENEMY_WORLD_HEIGHT).y
    return enemyFeet + float2(0.0, legsH * 0.45)
}


def projectile_circles_overlap(a, b : float2; radiusA, radiusB : float) : bool {
    let reach = radiusA + radiusB
    return length_sq(a - b) <= reach * reach
}


def public deflect_enemy_projectiles_in_slash(playerFeet : float2; row, col : int) {
    if (!effectsRootNode.isAlive || !attack_slash_active(row, col)) {
        return
    }
    var inscope children = effectsRootNode.get_children()
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var spell : EnemySpellProjectile?) {
            if (spell != null && !spell.consumed && !spell.deflected) {
                if (slash_hits_point(spell.position, playerFeet, row, col, ENEMY_SPELL_PROJECTILE_HIT_RADIUS, player_sword_range())) {
                    spell.deflect(playerFeet)
                }
            }
        }
    }
}


[hot_reload_class]
class ArrowProjectile : Component {
    position : float2
    direction : float2
    traveled : float = 0.0
    damage : int = PLAYER_BOW_DAMAGE
    pierceRemaining : int = 0
    critChance : float = 0.0
    knockback : float = 0.0
    lifeSteal : float = 0.0
    consumed : bool = false
    spawnHitImmunityTimer : float = PLAYER_PROJECTILE_SPAWN_HIT_IMMUNITY
    hitEnemyNodes : array<NodeId>
    animTimer : float = 0.0

    def spawn_impact_napalm(impactPos : float2) {
        spawn_napalm_aoe_visual(impactPos)
        apply_player_aoe_hits(
            impactPos,
            playerWorldPosition,
            damage,
            player_bow_napalm_aoe_hit_radius(),
            critChance,
            knockback,
            lifeSteal
        )
    }

    def enemy_already_hit(target : NodeId) : bool {
        for (n in hitEnemyNodes) {
            if (n == target) {
                return true
            }
        }
        return false
    }

    def sync_visual() {
        nodeId.localPosition = float3(position.x, position.y, 0.12)
        nodeId.localRotation = quat4(0.0, 0.0, projectile_facing_angle(direction))
        if (length(fireSpellTextures) > 0) {
            let frame = int(animTimer) % length(fireSpellTextures)
            nodeId?.SpriteRenderer.textureId = fireSpellTextures[frame]
        }
        nodeId?.SpriteRenderer.renderOrder = depth_sort_projectile_from_world(position, PLAYER_PROJECTILE_HIT_RADIUS)
    }

    def try_collide_with_enemy_spells() {
        if (consumed || !effectsRootNode.isAlive) {
            return
        }
        var inscope children = effectsRootNode.get_children()
        for (child in children) {
            if (consumed || !child.isAlive) {
                continue
            }
            get_component(child) $(var spell : EnemySpellProjectile?) {
                if (spell != null && !spell.consumed) {
                    if (projectile_circles_overlap(
                        position,
                        spell.position,
                        PLAYER_PROJECTILE_HIT_RADIUS,
                        ENEMY_SPELL_PROJECTILE_HIT_RADIUS
                    )) {
                        consumed = true
                        spell.consumed = true
                        let hitPos = (position + spell.position) * 0.5
                        spawn_impact_napalm(hitPos)
                        remove_node(spell.nodeId)
                        remove_node(nodeId)
                    }
                }
            }
            if (consumed) {
                return
            }
        }
    }

    def try_hit_obstacles(prevPos : float2) {
        if (consumed || spawnHitImmunityTimer > 0.0) {
            return
        }
        if (projectile_segment_hits_obstacle(prevPos, position, PLAYER_PROJECTILE_HIT_RADIUS)) {
            consumed = true
            spawn_impact_napalm(position)
            remove_node(nodeId)
        }
    }

    def try_hit_enemies() {
        if (consumed || !enemiesRootNode.isAlive) {
            return
        }
        let hitRadius = PLAYER_PROJECTILE_HIT_RADIUS
        for (i in range(cached_live_enemy_count())) {
            if (consumed) {
                return
            }
            let child = cached_live_enemy_node(i)
            if (!child.isAlive) {
                continue
            }
            get_component(child) $(var ctrl : EnemyController?) {
                if (ctrl != null && !ctrl.dead && !enemy_already_hit(child)) {
                    if (circle_intersects_legs_box(position, hitRadius, ctrl.position, ENEMY_WORLD_HEIGHT)) {
                        let hitPos = hit_effect_position(ctrl.position)
                        push(hitEnemyNodes, child)
                        spawn_impact_napalm(hitPos)
                        if (pierceRemaining <= 0) {
                            consumed = true
                            remove_node(nodeId)
                        } else {
                            pierceRemaining -= 1
                        }
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
        if (spawnHitImmunityTimer > 0.0) {
            spawnHitImmunityTimer = max(0.0, spawnHitImmunityTimer - dt)
        }
        let step = direction * PLAYER_PROJECTILE_SPEED * dt
        let prevPos = position
        position += step
        traveled += length(step)
        animTimer += dt * PLAYER_FIRE_SPELL_ANIM_FPS

        sync_visual()

        try_collide_with_enemy_spells()
        if (consumed) {
            return
        }

        try_hit_obstacles(prevPos)
        if (consumed) {
            return
        }

        try_hit_enemies()
        if (consumed) {
            return
        }

        if (!is_feet_in_grid_bounds(position) || traveled >= PLAYER_PROJECTILE_MAX_RANGE) {
            spawn_impact_napalm(position)
            remove_node(nodeId)
        }
    }
}


def spawn_single_arrow_projectile(fromFeet : float2; direction : float2) {
    if (!effectsRootNode.isAlive) {
        return
    }
    if (length(fireSpellTextures) == 0) {
        return
    }
    if (length_sq(direction) < 0.0001) {
        return
    }
    let aimDir = normalize(direction)
    let spawnPos = projectile_spawn_position(fromFeet, aimDir)
    let depth = depth_sort_projectile_from_world(spawnPos, PLAYER_PROJECTILE_HIT_RADIUS)
    let node = create_node(NodeData(
        name = "fire_spell",
        position = float3(spawnPos.x, spawnPos.y, 0.12),
        rotation = quat4(0.0, 0.0, projectile_facing_angle(aimDir)),
        scale = float3(PLAYER_PROJECTILE_WORLD_SIZE, PLAYER_PROJECTILE_WORLD_SIZE, 1.0),
        parent = effectsRootNode
    ))
    add_component(node, new SpriteRenderer(
        textureId = fireSpellTextures[0],
        uvRect = float4(0.0, 0.0, 1.0, 1.0),
        color = float4(1.0, 1.0, 1.0, 1.0),
        useTextureSizeForScaling = false,
        renderOrder = depth
    ))
    add_component(node, new ArrowProjectile(
        position = spawnPos,
        direction = aimDir,
        damage = player_bow_damage(),
        pierceRemaining = player_bow_pierce(),
        critChance = player_bow_crit_chance(),
        knockback = player_bow_knockback(),
        lifeSteal = player_bow_life_steal()
    ))
}


def public spawn_arrow_projectile(fromFeet : float2; aimDir : float2) {
    if (length_sq(aimDir) < 0.0001) {
        return
    }
    let baseDir = normalize(aimDir)
    spawn_single_arrow_projectile(fromFeet, baseDir)
    for (i in range(playerBonusBowExtraArrows)) {
        let spreadDir = spread_aim_direction(baseDir, PLAYER_BOW_VOLLEY_SPREAD_DEG)
        spawn_single_arrow_projectile(fromFeet, spreadDir)
    }
}
