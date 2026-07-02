require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/combat/combat
require scripts/das/combat/player
require scripts/das/combat/enemies
require scripts/das/combat/aoe_effects
require scripts/das/combat/projectiles
require scripts/das/world/props
require scripts/das/world/collision
def draw_legs_box(feet : float2; worldHeight : float; color : float4) {
    let bounds = entity_legs_box_bounds(feet, worldHeight)
    draw_box(bounds.minPt, bounds.maxPt, color)
}


def draw_attack_hitboxes(playerFeet : float2; row, col : int) {
    draw_sphere(
        float3(playerFeet.x, playerFeet.y, DEBUG_DRAW_Z),
        player_sword_range(),
        float4(1.0, 0.55, 0.1, 0.85),
        1,
        24
    )

    let slash = query_attack_slash_debug(playerFeet, row, col)
    if (!slash.active) {
        return
    }
    draw_sphere(float3(slash.center.x, slash.center.y, DEBUG_DRAW_Z), slash.radius, float4(1.0, 0.15, 0.15, 1.0), 1, 24)
}


def draw_aoe_hitboxes() {
    if (!effectsRootNode.isAlive) {
        return
    }
    let hitReach = AOE_HIT_RADIUS + entity_legs_collision_half_width(PLAYER_WORLD_HEIGHT)
    var inscope children = effectsRootNode.get_children()
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var aoe : PlayerAoeEffect?) {
            if (aoe != null) {
                draw_sphere(
                    float3(aoe.center.x, aoe.center.y, DEBUG_DRAW_Z),
                    hitReach,
                    float4(1.0, 0.15, 0.15, 1.0),
                    1,
                    24
                )
            }
        }
    }
}


def draw_prop_obstacle_borders() {
    for (i in range(prop_wall_segment_count())) {
        let wallA = prop_wall_segment_a(i)
        let wallB = prop_wall_segment_b(i)
        draw_line(
            float3(wallA.x, wallA.y, DEBUG_DRAW_Z),
            float3(wallB.x, wallB.y, DEBUG_DRAW_Z),
            float4(0.95, 0.55, 0.15, 1.0),
            1
        )
    }
    for (i in range(prop_projectile_wall_segment_count())) {
        let wallA = prop_projectile_wall_segment_a(i)
        let wallB = prop_projectile_wall_segment_b(i)
        draw_line(
            float3(wallA.x, wallA.y, DEBUG_DRAW_Z + 0.01),
            float3(wallB.x, wallB.y, DEBUG_DRAW_Z + 0.01),
            float4(0.2, 0.65, 1.0, 1.0),
            1
        )
    }
}


def draw_prop_collision_sort_bounds() {
    for (i in range(length(propSpriteNodes))) {
        let node = propSpriteNodes[i]
        if (!node.isAlive || !node.isActive) {
            continue
        }
        let spriteBounds = sprite_node_collision_y_bounds(node)
        draw_box(
            float3(spriteBounds.xMin, spriteBounds.yMin, DEBUG_DRAW_Z),
            float3(spriteBounds.xMax, spriteBounds.yMax, DEBUG_DRAW_Z + 0.01),
            float4(0.25, 0.85, 1.0, 1.0)
        )
        let collisionBounds = prop_collision_bounds_at(i, node)
        if (collisionBounds.yMax > collisionBounds.yMin && collisionBounds.xMax > collisionBounds.xMin) {
            draw_box(
                float3(collisionBounds.xMin, collisionBounds.yMin, DEBUG_DRAW_Z + 0.02),
                float3(collisionBounds.xMax, collisionBounds.yMax, DEBUG_DRAW_Z + 0.03),
                float4(0.95, 0.55, 0.15, 1.0)
            )
        }
    }
}


def draw_border_wall_bottom_lines() {
    for (i in range(border_wall_bottom_count())) {
        let bottomA = border_wall_bottom_a(i)
        let bottomB = border_wall_bottom_b(i)
        draw_line(
            float3(bottomA.x, bottomA.y, DEBUG_DRAW_Z),
            float3(bottomB.x, bottomB.y, DEBUG_DRAW_Z),
            float4(0.25, 1.0, 0.45, 1.0),
            1
        )
    }
}


def draw_projectile_hitboxes() {
    if (!effectsRootNode.isAlive) {
        return
    }
    var inscope children = effectsRootNode.get_children()
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var arrow : ArrowProjectile?) {
            if (arrow != null && !arrow.consumed) {
                draw_sphere(
                    float3(arrow.position.x, arrow.position.y, DEBUG_DRAW_Z),
                    PLAYER_PROJECTILE_HIT_RADIUS,
                    float4(0.2, 0.65, 1.0, 1.0),
                    1,
                    20
                )
            }
        }
        get_component(child) $(var spell : EnemySpellProjectile?) {
            if (spell != null && !spell.consumed) {
                draw_sphere(
                    float3(spell.position.x, spell.position.y, DEBUG_DRAW_Z),
                    ENEMY_SPELL_PROJECTILE_HIT_RADIUS,
                    float4(0.85, 0.2, 1.0, 1.0),
                    1,
                    20
                )
            }
        }
    }
}


def draw_player_special_pending(ctrl : PlayerController?) {
    if (ctrl == null) {
        return
    }
    if (!ctrl.actionActive || !ctrl.actionIsSpecial) {
        return
    }
    let hitReach = AOE_HIT_RADIUS + entity_legs_collision_half_width(PLAYER_WORLD_HEIGHT)
    draw_sphere(
        float3(ctrl.specialTargetWorld.x, ctrl.specialTargetWorld.y, DEBUG_DRAW_Z),
        hitReach,
        float4(1.0, 0.4, 0.1, 0.85),
        1,
        24
    )
}


def public draw_character_debug_hitboxes() {
    if (!debugBordersEnabled) {
        return
    }
    if (playerNode.isAlive) {
        get_component(playerNode) $(var ctrl : PlayerController?) {
            if (ctrl != null) {
                draw_legs_box(ctrl.position, PLAYER_WORLD_HEIGHT, float4(0.2, 1.0, 0.35, 1.0))
                if (ctrl.actionActive && ctrl.actionTexture == attack1Texture) {
                    draw_attack_hitboxes(ctrl.position, ctrl.actionRow, int(ctrl.actionAnimTimer))
                }
                draw_player_special_pending(ctrl)
            }
        }
    }

    draw_aoe_hitboxes()
    draw_prop_obstacle_borders()
    draw_prop_collision_sort_bounds()
    draw_border_wall_bottom_lines()
    draw_projectile_hitboxes()

    if (!enemiesRootNode.isAlive) {
        return
    }
    var inscope children = enemiesRootNode.get_children()
    for (child in children) {
        if (!child.isAlive) {
            continue
        }
        get_component(child) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead) {
                var boxColor = float4(1.0, 0.9, 0.2, 1.0)
                if (ctrl.hitFlashTimer > 0.0) {
                    boxColor = float4(1.0, 0.15, 0.15, 1.0)
                }
                draw_legs_box(ctrl.position, ENEMY_WORLD_HEIGHT, boxColor)
                if (ctrl.attacking) {
                    draw_attack_hitboxes(ctrl.position, ctrl.attackRow, int(ctrl.attackAnimTimer))
                }
            }
        }
    }
}
