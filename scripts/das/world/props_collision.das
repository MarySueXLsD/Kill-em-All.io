require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/prop_footprint
require strings

module props_collision public

var private propEditCounter : int = 0

var public miscB12Texture : TextureId
var public miscB5Texture : TextureId
var public miscB10Texture : TextureId
var public miscB8Texture : TextureId
var public miscB25Texture : TextureId
var public miscB3Texture : TextureId
var public miscB14Texture : TextureId
var public miscB11Texture : TextureId
var public miscB2Texture : TextureId
var public miscB7Texture : TextureId
var public miscB9Texture : TextureId
var public miscB40Texture : TextureId
var public miscB20Texture : TextureId
var public miscB1Texture : TextureId
var public wallB1ETexture : TextureId
var public wallB1WTexture : TextureId
var public wallB1NTexture : TextureId
var public wallB1STexture : TextureId
var public wallB2ETexture : TextureId
var public wallB2WTexture : TextureId
var public wallB2NTexture : TextureId
var public wallB2STexture : TextureId
var public propBlockers : array<float2>
var public propWallSegmentsA : array<float2>
var public propWallSegmentsB : array<float2>
var public propProjectileWallSegmentsA : array<float2>
var public propProjectileWallSegmentsB : array<float2>
var public borderWallBottomA : array<float2>
var public borderWallBottomB : array<float2>
var public propSpriteNodes : array<NodeId>
var public propSpriteFeet : array<float2>
var public propSpriteProjectilePassable : array<bool>
var public propCollisionBounds : array<CollisionYBounds>
var public propTexturesLoaded : bool = false


def point_inside_sprite_node_bounds(point : float2; node : NodeId; padding : float) : bool {
    if (!node.isAlive || node?.SpriteRenderer == null) {
        return false
    }
    let center = node.worldPosition.xy
    let half = float2(abs(node.worldScale.x), abs(node.worldScale.y)) * 0.5 + float2(padding)
    return abs(point.x - center.x) <= half.x && abs(point.y - center.y) <= half.y
}


def public sprite_node_collision_y_bounds(node : NodeId) : CollisionYBounds {
    if (!node.isAlive) {
        return CollisionYBounds(yMin = 0.0, yMax = 0.0, xMin = 0.0, xMax = 0.0)
    }
    let center = node.worldPosition.xy
    let half = float2(abs(node.worldScale.x), abs(node.worldScale.y)) * 0.5
    return CollisionYBounds(
        yMin = center.y - half.y,
        yMax = center.y + half.y,
        xMin = center.x - half.x,
        xMax = center.x + half.x
    )
}


// Ground contact for Y-sort: bottom-center of the sprite quad (screen-bottom edge).
def public prop_sort_world_pos(node : NodeId) : float2 {
    let bounds = sprite_node_collision_y_bounds(node)
    return float2((bounds.xMin + bounds.xMax) * 0.5, bounds.yMin)
}


// Collision-volume ground point for Y-sort (preferred over sprite bounds when available).
def public prop_collision_sort_pos(propIndex : int; node : NodeId) : float2 {
    if (propIndex >= 0 && propIndex < length(propCollisionBounds)) {
        let bounds = propCollisionBounds[propIndex]
        if (bounds.yMax >= bounds.yMin && bounds.xMax >= bounds.xMin) {
            return float2((bounds.xMin + bounds.xMax) * 0.5, bounds.yMin)
        }
    }
    return prop_sort_world_pos(node)
}


def public prop_collision_bounds_at(propIndex : int; node : NodeId) : CollisionYBounds {
    if (propIndex >= 0 && propIndex < length(propCollisionBounds)) {
        let bounds = propCollisionBounds[propIndex]
        if (bounds.yMax >= bounds.yMin && bounds.xMax >= bounds.xMin) {
            return bounds
        }
    }
    return sprite_node_collision_y_bounds(node)
}


def register_prop_sprite_track(node : NodeId; feet : float2; projectilePassable : bool; collisionBounds : CollisionYBounds) {
    push(propSpriteNodes, node)
    push(propSpriteFeet, feet)
    push(propSpriteProjectilePassable, projectilePassable)
    push(propCollisionBounds, collisionBounds)
}


def public depth_sort_projectile_from_world(pos : float2; boundsPadding : float) : int {
    var depth = depth_sort_entity_from_world(pos) + DEPTH_PROJECTILE_ABOVE_PASSABLE
    for (i in range(length(propSpriteNodes))) {
        if (i >= length(propSpriteProjectilePassable) || !propSpriteProjectilePassable[i]) {
            continue
        }
        let node = propSpriteNodes[i]
        if (!node.isAlive || !node.isActive) {
            continue
        }
        if (!point_inside_sprite_node_bounds(pos, node, boundsPadding)) {
            continue
        }
        let propDepth = node?.SpriteRenderer.renderOrder
        if (propDepth >= depth) {
            depth = propDepth + DEPTH_PROJECTILE_ABOVE_PASSABLE
        }
    }
    return depth
}


def segment_point_param_on_segment(a, b, p : float2) : float {
    let ab = b - a
    let lenSq = length_sq(ab)
    if (lenSq < 0.000001) {
        return 0.0
    }
    return clamp(dot(p - a, ab) / lenSq, 0.0, 1.0)
}


def distance_to_segment(p, a, b : float2) : float {
    let t = segment_point_param_on_segment(a, b, p)
    let closest = a + (b - a) * t
    return length(p - closest)
}


def append_wall_blocker_points(var blockers : array<float2>; a, b : float2) {
    let edge = b - a
    let len = length(edge)
    if (len <= 0.0001) {
        push(blockers, a)
        return
    }
    let steps = max(1, int(ceil(len / PROP_WALL_BLOCKER_SPACING)))
    for (i in range(steps + 1)) {
        let t = float(i) / float(steps)
        push(blockers, a + edge * t)
    }
}


def record_prop_wall_segment(a, b : float2; blocksProjectiles : bool = true) {
    push(propWallSegmentsA, a)
    push(propWallSegmentsB, b)
    append_wall_blocker_points(propBlockers, a, b)
    if (blocksProjectiles) {
        push(propProjectileWallSegmentsA, a)
        push(propProjectileWallSegmentsB, b)
    }
}


def point_hits_wall_segments(
    point : float2;
    extraRadius : float;
    segA, segB : array<float2>
) : bool {
    let thickness = PROP_WALL_LINE_HALF_THICKNESS + extraRadius
    for (i in range(length(segA))) {
        let wallA = segA[i]
        let wallB = segB[i]
        let wallMinX = min(wallA.x, wallB.x) - thickness
        let wallMaxX = max(wallA.x, wallB.x) + thickness
        let wallMinY = min(wallA.y, wallB.y) - thickness
        let wallMaxY = max(wallA.y, wallB.y) + thickness
        if (point.x < wallMinX || point.x > wallMaxX || point.y < wallMinY || point.y > wallMaxY) {
            continue
        }
        if (distance_to_segment(point, wallA, wallB) <= thickness) {
            return true
        }
    }
    return false
}


def segment_hits_wall_segments(
    pathA, pathB : float2;
    extraRadius : float;
    wallSegA, wallSegB : array<float2>
) : bool {
    let thickness = PROP_WALL_LINE_HALF_THICKNESS + extraRadius
    let pathMinX = min(pathA.x, pathB.x) - thickness
    let pathMaxX = max(pathA.x, pathB.x) + thickness
    let pathMinY = min(pathA.y, pathB.y) - thickness
    let pathMaxY = max(pathA.y, pathB.y) + thickness
    for (i in range(length(wallSegA))) {
        let wallA = wallSegA[i]
        let wallB = wallSegB[i]
        let wallMinX = min(wallA.x, wallB.x) - thickness
        let wallMaxX = max(wallA.x, wallB.x) + thickness
        let wallMinY = min(wallA.y, wallB.y) - thickness
        let wallMaxY = max(wallA.y, wallB.y) + thickness
        if (wallMaxX < pathMinX || wallMinX > pathMaxX || wallMaxY < pathMinY || wallMinY > pathMaxY) {
            continue
        }
        if (distance_to_segment(pathA, wallA, wallB) <= thickness) {
            return true
        }
        if (distance_to_segment(pathB, wallA, wallB) <= thickness) {
            return true
        }
        if (distance_to_segment(wallA, pathA, pathB) <= thickness) {
            return true
        }
        if (distance_to_segment(wallB, pathA, pathB) <= thickness) {
            return true
        }
        let midPath = (pathA + pathB) * 0.5
        if (distance_to_segment(midPath, wallA, wallB) <= thickness) {
            return true
        }
    }
    return false
}


def point_hits_prop_walls(point : float2; extraRadius : float) : bool {
    return point_hits_wall_segments(point, extraRadius, propWallSegmentsA, propWallSegmentsB)
}


def point_hits_projectile_walls(point : float2; extraRadius : float) : bool {
    return point_hits_wall_segments(point, extraRadius, propProjectileWallSegmentsA, propProjectileWallSegmentsB)
}


def segment_hits_prop_walls(segA, segB : float2; extraRadius : float) : bool {
    return segment_hits_wall_segments(segA, segB, extraRadius, propWallSegmentsA, propWallSegmentsB)
}


def segment_hits_projectile_walls(segA, segB : float2; extraRadius : float) : bool {
    return segment_hits_wall_segments(
        segA, segB, extraRadius, propProjectileWallSegmentsA, propProjectileWallSegmentsB
    )
}


def public blocks_feet_path(from, to : float2; worldHeight : float) : bool {
    return legs_path_blocked(from, to, worldHeight)
}


def legs_hits_prop_walls_at(feet : float2; worldHeight : float) : bool {
    let bounds = legs_collision_y_bounds(feet, worldHeight)
    for (i in range(length(propWallSegmentsA))) {
        let wallA = propWallSegmentsA[i]
        let wallB = propWallSegmentsB[i]
        let segMinY = min(wallA.y, wallB.y)
        let segMaxY = max(wallA.y, wallB.y)
        if (segMaxY < bounds.yMin || segMinY > bounds.yMax) {
            continue
        }
        if (segment_intersects_collision_y_bounds(wallA, wallB, bounds)) {
            return true
        }
    }
    return false
}


def public legs_path_blocked(from, to : float2; worldHeight : float) : bool {
    if (legs_hits_prop_walls_at(to, worldHeight)) {
        return true
    }
    if (legs_hits_prop_walls_at(from, worldHeight)) {
        return false
    }
    let mid = (from + to) * 0.5
    return legs_hits_prop_walls_at(mid, worldHeight)
}


def public blocks_projectile_path(from, to : float2; projectileRadius : float) : bool {
    if (point_hits_projectile_walls(from, projectileRadius) || point_hits_projectile_walls(to, projectileRadius)) {
        return true
    }
    return segment_hits_projectile_walls(from, to, projectileRadius)
}


def public projectile_segment_hits_obstacle(from, to : float2; projectileRadius : float) : bool {
    return segment_hits_projectile_walls(from, to, projectileRadius)
}


def public prop_projectile_wall_segment_count() : int {
    return length(propProjectileWallSegmentsA)
}


def public prop_projectile_wall_segment_a(index : int) : float2 {
    return propProjectileWallSegmentsA[index]
}


def public prop_projectile_wall_segment_b(index : int) : float2 {
    return propProjectileWallSegmentsB[index]
}
