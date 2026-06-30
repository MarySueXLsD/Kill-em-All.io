require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/props_collision
require scripts/das/combat/player
require scripts/das/combat/enemies

module collision_depth_sort public

struct DepthSortEntry {
    node : NodeId
    bounds : CollisionYBounds
    order : int
}


def run_collision_depth_pass(var entries : array<DepthSortEntry>) {
    let count = length(entries)
    if (count <= 1) {
        return
    }
    let eps = COLLISION_DEPTH_Y_EPSILON
    for (i in range(count)) {
        for (j in range(i + 1, count)) {
            if (!collision_y_bounds_overlap(entries[i].bounds, entries[j].bounds)) {
                continue
            }
            var ao = entries[i].order
            var bo = entries[j].order
            if (entries[i].bounds.yMin < entries[j].bounds.yMin - eps) {
                ao = max(ao, bo + DEPTH_COLLISION_SORT_BIAS)
            }
            if (entries[i].bounds.yMax > entries[j].bounds.yMax + eps) {
                bo = max(bo, ao + DEPTH_COLLISION_SORT_BIAS)
            }
            entries[i].order = ao
            entries[j].order = bo
        }
    }
}


def entity_bounds_near_prop(entityBounds : CollisionYBounds; propBounds : CollisionYBounds) : bool {
    return collision_y_bounds_overlap(
        collision_y_bounds_expand(entityBounds, COLLISION_DEPTH_PROP_NEAR_MARGIN),
        propBounds
    )
}


def append_entity_depth_entry(
    var entries : array<DepthSortEntry>;
    node : NodeId;
    feet : float2;
    worldHeight : float
) {
    if (!node.isAlive || node?.SpriteRenderer == null) {
        return
    }
    let bounds = legs_collision_y_bounds(feet, worldHeight)
    let baseOrder = depth_sort_entity_from_world(feet)
    push(entries, DepthSortEntry(node = node, bounds = bounds, order = baseOrder))
}


def append_nearby_prop_depth_entries(var entries : array<DepthSortEntry>; entityBounds : array<CollisionYBounds>) {
    for (i in range(length(propSpriteNodes))) {
        if (i >= length(propCollisionBounds)) {
            continue
        }
        let node = propSpriteNodes[i]
        if (!node.isAlive || !node.isActive || node?.SpriteRenderer == null) {
            continue
        }
        let propBounds = propCollisionBounds[i]
        var nearEntity = false
        for (eb in entityBounds) {
            if (entity_bounds_near_prop(eb, propBounds)) {
                nearEntity = true
                break
            }
        }
        if (!nearEntity) {
            continue
        }
        let baseOrder = node?.SpriteRenderer.renderOrder
        push(entries, DepthSortEntry(node = node, bounds = propBounds, order = baseOrder))
    }
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
    var entityBounds : array<CollisionYBounds>

    if (playerNode.isAlive) {
        let playerBounds = legs_collision_y_bounds(playerWorldPosition, PLAYER_WORLD_HEIGHT)
        push(entityBounds, playerBounds)
        append_entity_depth_entry(entries, playerNode, playerWorldPosition, PLAYER_WORLD_HEIGHT)
    }

    for (i in range(cached_live_enemy_count())) {
        let enemyNode = cached_live_enemy_node(i)
        if (!enemyNode.isAlive) {
            continue
        }
        get_component(enemyNode) $(var ctrl : EnemyController?) {
            if (ctrl != null && !ctrl.dead) {
                let enemyBounds = legs_collision_y_bounds(ctrl.position, ENEMY_WORLD_HEIGHT)
                push(entityBounds, enemyBounds)
                append_entity_depth_entry(entries, enemyNode, ctrl.position, ENEMY_WORLD_HEIGHT)
            }
        }
    }

    append_nearby_prop_depth_entries(entries, entityBounds)

    for (passIdx in range(COLLISION_DEPTH_SORT_PASSES)) {
        run_collision_depth_pass(entries)
    }
    apply_depth_sort_entries(entries)
}
