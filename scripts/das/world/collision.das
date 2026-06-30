require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/world/props
require scripts/das/world/props_collision
require scripts/das/core/game_state
require scripts/das/world/world
require scripts/das/world/world_terrain
module collision public

var private gridWallBlockers : array<float2>


def append_grid_edge_wall_blockers(var blockers : array<float2>; gx0, gy0, gx1, gy1, ogx, ogy, spacing : float) {
    let start = grid_to_world(gx0 + ogx, gy0 + ogy)
    let end = grid_to_world(gx1 + ogx, gy1 + ogy)
    let edge = end - start
    let len = length(edge)
    if (len <= 0.0001) {
        push(blockers, start)
        return
    }
    let steps = max(1, int(ceil(len / spacing)))
    for (i in range(steps + 1)) {
        let t = float(i) / float(steps)
        push(blockers, start + edge * t)
    }
}


def grid_wall_outward() : float {
    let halfW = tile_half_width()
    let halfH = tile_half_height()
    let gridStep = sqrt(halfW * halfW + halfH * halfH)
    return grid_feet_margin() * 0.5 + entity_min_separation() * 0.35 / gridStep
}


def public build_grid_wall_blockers() {
    clear(gridWallBlockers)
    let minG = -0.5
    let maxG = float(activeMapWidth - 1) + 0.5
    let outward = grid_wall_outward()
    let spacing = entity_min_separation() * 0.8

    append_grid_edge_wall_blockers(gridWallBlockers, minG, minG, maxG, minG, 0.0, -outward, spacing)
    append_grid_edge_wall_blockers(gridWallBlockers, maxG, minG, maxG, maxG, outward, 0.0, spacing)
    append_grid_edge_wall_blockers(gridWallBlockers, maxG, maxG, minG, maxG, 0.0, outward, spacing)
    append_grid_edge_wall_blockers(gridWallBlockers, minG, maxG, minG, minG, -outward, 0.0, spacing)
}


def public append_grid_wall_blockers(var blockers : array<float2>) {
    for (p in gridWallBlockers) {
        push(blockers, p)
    }
}


def public entity_min_separation() : float {
    return ENTITY_FEET_RADIUS * 2.0
}


def ai_detour_step() : float {
    return entity_min_separation()
}


def waypoint_crowd_score(point : float2; blockers : array<float2>) : float {
    let minSep = entity_min_separation()
    var score = 0.0
    for (blocker in blockers) {
        score += min(length(point - blocker), minSep * 3.0)
    }
    return score
}


def detour_preferred_side(from, to : float2; dir : float2) : float {
    let cross = dir.x * (from.y - to.y) - dir.y * (from.x - to.x)
    if (cross >= 0.0) {
        return 1.0
    }
    return -1.0
}


def detour_score_waypoint(from, waypoint, goal : float2; blockers : array<float2>; preferredSign, sign : float) : float {
    let step = ai_detour_step()
    var score = 0.0
    if (!blocks_feet_path(waypoint, goal)) {
        score = AI_FLANK_CLEAR_PATH_BONUS - length(waypoint - goal)
    } else {
        score = length(waypoint - from) * 4.0
    }
    score += waypoint_crowd_score(waypoint, blockers) * AI_DETOUR_CROWD_WEIGHT
    if (sign == preferredSign) {
        score += step * AI_DETOUR_SIDE_BIAS
    }
    return score
}


struct DetourSearchState {
    bestPoint : float2
    bestScore : float = -1000000.0
    found : bool = false
}


def update_detour_search(
    var state : DetourSearchState;
    from, waypoint, goal : float2;
    blockers : array<float2>;
    preferredSign, sign : float
) {
    if (!is_feet_in_grid_bounds(waypoint)) {
        return
    }
    if (blocks_feet_path(from, waypoint)) {
        return
    }
    if (length_sq(waypoint - from) < 0.0001) {
        return
    }
    state.found = true
    let score = detour_score_waypoint(from, waypoint, goal, blockers, preferredSign, sign)
    if (score > state.bestScore) {
        state.bestScore = score
        state.bestPoint = waypoint
    }
}


def public pick_obstacle_route(from, to : float2; blockers : array<float2>; flankSign : float) : float2 {
    if (!blocks_feet_path(from, to)) {
        return to
    }
    let toTarget = to - from
    let dist = length(toTarget)
    if (dist < 0.0001) {
        return to
    }
    let dir = toTarget / dist
    let perp = float2(-dir.y, dir.x)
    let step = ai_detour_step()
    var preferredSign = flankSign
    if (preferredSign == 0.0) {
        preferredSign = detour_preferred_side(from, to, dir)
    }
    var state = DetourSearchState()
    for (sideOrder in range(2)) {
        let sign = sideOrder == 0 ? preferredSign : -preferredSign
        for (forward in range(0, AI_OBSTACLE_ROUTE_FORWARD_STEPS + 1)) {
            for (lat in range(1, AI_OBSTACLE_ROUTE_LATERAL_STEPS + 1)) {
                let waypoint = from + dir * step * float(forward) + perp * step * float(lat) * sign
                update_detour_search(state, from, waypoint, to, blockers, preferredSign, sign)
            }
        }
        for (back in range(1, AI_DETOUR_BACK_STEPS + 1)) {
            for (lat in range(1, AI_OBSTACLE_ROUTE_LATERAL_STEPS + 1)) {
                let waypoint = from - dir * step * float(back) + perp * step * float(lat) * sign
                update_detour_search(state, from, waypoint, to, blockers, preferredSign, sign)
            }
        }
    }
    if (state.found) {
        return state.bestPoint
    }
    for (lat in range(1, AI_OBSTACLE_ROUTE_LATERAL_STEPS + 1)) {
        let waypoint = from + perp * step * float(lat) * preferredSign
        if (is_feet_in_grid_bounds(waypoint) && !blocks_feet_path(from, waypoint)) {
            return waypoint
        }
    }
    return from + perp * step * preferredSign
}


def public resolve_approach_target(from, target : float2; blockers : array<float2>; flankSign : float) : float2 {
    return pick_obstacle_route(from, target, blockers, flankSign)
}


def public steer_direction(from, desiredDir : float2; blockers : array<float2>) : float2 {
    if (length_sq(desiredDir) < 0.0001) {
        return desiredDir
    }
    var dir = desiredDir
    let minSep = entity_min_separation()
    let steerRadius = minSep * 2.5
    let steerRadiusSq = steerRadius * steerRadius
    for (blocker in blockers) {
        let away = from - blocker
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


def public pick_least_crowded_ring_point(center, near : float2; radius : float; blockers : array<float2>) : float2 {
    var toward = near - center
    if (length_sq(toward) < 0.0001) {
        toward = float2(1.0, 0.0)
    } else {
        toward = normalize(toward)
    }
    var bestPoint = center + toward * radius
    var bestScore = -1000000.0
    let minSep = entity_min_separation()
    for (i in range(8)) {
        let angle = float(i) * (PI / 4.0)
        let point = center + float2(cos(angle), sin(angle)) * radius
        var score = 0.0
        for (blocker in blockers) {
            score += min(length(point - blocker), minSep * 2.0)
        }
        score -= length(point - near) * 0.25
        if (score > bestScore) {
            bestScore = score
            bestPoint = point
        }
    }
    return bestPoint
}


def public resolve_entity_separation(pos : float2; excludeFeet : float2; entityFeet : array<float2>) : float2 {
    var result = pos
    let minSep = entity_min_separation()
    let minSepSq = minSep * minSep

    for (_ in range(2)) {
        for (feet in entityFeet) {
            if (length_sq(feet - excludeFeet) < 0.0001) {
                continue
            }
            let delta = result - feet
            let distSq = length_sq(delta)
            if (distSq >= minSepSq) {
                continue
            }
            if (distSq > 0.000001) {
                let dist = sqrt(distSq)
                result = feet + delta / dist * minSep
            } else {
                result = excludeFeet + float2(minSep, 0.0)
            }
        }
        result = clamp_feet_to_grid(result)
    }
    return clamp_feet_to_grid(result)
}


def public resolve_entity_separation_for_nodes(pos : float2; selfNode : NodeId; entityFeet : array<float2>; entityNodes : array<NodeId>) : float2 {
    var result = pos
    let minSep = entity_min_separation()
    let minSepSq = minSep * minSep

    for (_ in range(2)) {
        for (i in range(length(entityFeet))) {
            if (entityNodes[i] == selfNode) {
                continue
            }
            let feet = entityFeet[i]
            let delta = result - feet
            let distSq = length_sq(delta)
            if (distSq >= minSepSq) {
                continue
            }
            if (distSq > 0.000001) {
                let dist = sqrt(distSq)
                result = feet + delta / dist * minSep
            } else {
                result = feet + float2(minSep, 0.0)
            }
        }
        result = clamp_feet_to_grid(result)
    }
    return clamp_feet_to_grid(result)
}


def public steer_direction_excluding(from, desiredDir, excludeFeet : float2; entityFeet : array<float2>) : float2 {
    if (length_sq(desiredDir) < 0.0001) {
        return desiredDir
    }
    var dir = desiredDir
    let minSep = entity_min_separation()
    let steerRadius = minSep * 2.5
    let steerRadiusSq = steerRadius * steerRadius
    for (feet in entityFeet) {
        if (length_sq(feet - excludeFeet) < 0.0001) {
            continue
        }
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


def public steer_direction_excluding_node(from, desiredDir : float2; selfNode : NodeId; entityFeet : array<float2>; entityNodes : array<NodeId>) : float2 {
    if (length_sq(desiredDir) < 0.0001) {
        return desiredDir
    }
    var dir = desiredDir
    let minSep = entity_min_separation()
    let steerRadius = minSep * 2.5
    let steerRadiusSq = steerRadius * steerRadius
    for (i in range(length(entityFeet))) {
        if (entityNodes[i] == selfNode) {
            continue
        }
        let feet = entityFeet[i]
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


def public resolve_feet_move(from, to : float2; blockers : array<float2>) : float2 {
    var pos = constrain_feet_move_for_terrain(from, to)
    let minSep = entity_min_separation()
    let minSepSq = minSep * minSep

    for (_ in range(4)) {
        for (blocker in blockers) {
            let delta = pos - blocker
            let distSq = length_sq(delta)
            if (distSq >= minSepSq) {
                continue
            }
            if (distSq > 0.000001) {
                let dist = sqrt(distSq)
                pos = blocker + delta / dist * minSep
            } else {
                let escape = from - blocker
                if (length_sq(escape) > 0.000001) {
                    pos = from
                } else {
                    pos = blocker + float2(minSep, 0.0)
                }
            }
        }
        pos = clamp_feet_to_grid(pos)
    }
    return clamp_feet_to_grid(pos)
}
