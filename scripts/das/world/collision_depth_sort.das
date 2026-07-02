require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/props_collision
require scripts/das/world/props_walls
require scripts/das/combat/player
require scripts/das/combat/enemies

module collision_depth_sort public

struct DepthSortEntry {
    node : NodeId
    spriteBounds : CollisionYBounds
    collisionBounds : CollisionYBounds
    groundY : float
    order : int
    isEntity : bool
}


def boost_order_in_front(frontOrder, backOrder : int) : int {
    return max(frontOrder, backOrder + DEPTH_COLLISION_SORT_BIAS)
}


def resolve_entity_entity_pair(ai, aj : int; entryA, entryB : DepthSortEntry; eps : float) : int2 {
    let aColl = entryA.collisionBounds
    let bColl = entryB.collisionBounds
    if (aColl.yMin > bColl.yMax + eps) {
        return int2(ai, boost_order_in_front(aj, ai))
    }
    if (bColl.yMin > aColl.yMax + eps) {
        return int2(boost_order_in_front(ai, aj), aj)
    }
    let ay = entryA.groundY
    let by = entryB.groundY
    if (ay < by - eps) {
        return int2(boost_order_in_front(ai, aj), aj)
    }
    if (by < ay - eps) {
        return int2(ai, boost_order_in_front(aj, ai))
    }
    return int2(ai, aj)
}


def run_y_overlap_depth_pass(var entries : array<DepthSortEntry>) {
    let count = length(entries)
    if (count <= 1) {
        return
    }
    let eps = COLLISION_DEPTH_Y_EPSILON
    for (i in range(count)) {
        for (j in range(i + 1, count)) {
            var ai = entries[i].order
            var aj = entries[j].order
            let iEntity = entries[i].isEntity
            let jEntity = entries[j].isEntity
            if ((iEntity && !jEntity) || (jEntity && !iEntity)) {
                // Entity-vs-prop is fully defined by base order:
                // entity uses legs collision yMin, prop uses collision yMax.
                // No pairwise boost here to avoid edge artifacts from nearby props.
                continue
            } elif (iEntity && jEntity) {
                if (!collision_y_ranges_overlap(entries[i].spriteBounds, entries[j].spriteBounds)) {
                    continue
                }
                let resolved = resolve_entity_entity_pair(ai, aj, entries[i], entries[j], eps)
                ai = resolved.x
                aj = resolved.y
            } else {
                if (!collision_y_ranges_overlap(entries[i].spriteBounds, entries[j].spriteBounds)) {
                    continue
                }
                let yi = entries[i].groundY
                let yj = entries[j].groundY
                if (yi < yj - eps) {
                    ai = boost_order_in_front(ai, aj)
                } elif (yj < yi - eps) {
                    aj = boost_order_in_front(aj, ai)
                }
            }
            entries[i].order = ai
            entries[j].order = aj
        }
    }
}


def append_entity_depth_entry(var entries : array<DepthSortEntry>; node : NodeId; feet : float2; worldHeight : float) {
    if (!node.isAlive || node?.SpriteRenderer == null) {
        return
    }
    let spriteBounds = sprite_node_collision_y_bounds(node)
    let collisionBounds = legs_collision_y_bounds(feet, worldHeight)
    let baseOrder = depth_sort_from_sprite_bottom(collisionBounds.yMin)
    push(entries, DepthSortEntry(
        node = node,
        spriteBounds = spriteBounds,
        collisionBounds = collisionBounds,
        groundY = feet.y,
        order = baseOrder,
        isEntity = true
    ))
}


def append_prop_depth_entry(var entries : array<DepthSortEntry>; propIndex : int; node : NodeId) {
    if (!node.isAlive || !node.isActive || node?.SpriteRenderer == null) {
        return
    }
    let spriteBounds = sprite_node_collision_y_bounds(node)
    let collisionBounds = prop_collision_bounds_at(propIndex, node)
    let groundPos = prop_collision_sort_pos(propIndex, node)
    let groundY = groundPos.y
    var baseOrder = depth_sort_from_sprite_bottom(collisionBounds.yMax)
    if (is_decor_border_wall_name(node.name)) {
        baseOrder = border_wall_render_order_for_name(node.name, groundPos)
    }
    push(entries, DepthSortEntry(
        node = node,
        spriteBounds = spriteBounds,
        collisionBounds = collisionBounds,
        groundY = groundY,
        order = baseOrder,
        isEntity = false
    ))
}


def apply_depth_sort_entries(entries : array<DepthSortEntry>) {
    for (entry in entries) {
        if (!entry.node.isAlive || entry.node?.SpriteRenderer == null) {
            continue
        }
        entry.node?.SpriteRenderer.renderOrder = entry.order
    }
}


def public update_collision_depth_sorting() {
    if (!gameReady || playerDashing) {
        return
    }

    var entries : array<DepthSortEntry>

    if (playerNode.isAlive) {
        append_entity_depth_entry(entries, playerNode, playerWorldPosition, PLAYER_WORLD_HEIGHT)
    }

    for (i in range(cached_live_enemy_count())) {
        let enemyNode = cached_live_enemy_node(i)
        if (!enemyNode.isAlive) {
            continue
        }
        get_component(enemyNode) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead) {
                append_entity_depth_entry(entries, enemyNode, ctrl.position, ENEMY_WORLD_HEIGHT)
            }
        }
    }

    for (i in range(length(propSpriteNodes))) {
        append_prop_depth_entry(entries, i, propSpriteNodes[i])
    }

    run_y_overlap_depth_pass(entries)
    apply_depth_sort_entries(entries)
}
