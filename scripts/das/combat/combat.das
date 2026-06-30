require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
struct AttackSlashHitbox {
    row : int
    col : int
    tileOffset : float2
    radius : float
}


struct AttackSlashDebugInfo {
    active : bool
    center : float2
    radius : float
}


// Slash white pixels in Attack1.png tile space (feet anchor at tile center-x, y=89 from top).
// Row 0 = right on the sheet. Tile offsets are in character-local space (+x = right, -y = forward).
var private attack_slash_frames : array<AttackSlashHitbox> <- [
    AttackSlashHitbox(row = 0, col = 7, tileOffset = float2(14.0, -20.0), radius = 1.3906),
    AttackSlashHitbox(row = 0, col = 8, tileOffset = float2(15.0, -21.5), radius = 1.3594),
    AttackSlashHitbox(row = 0, col = 9, tileOffset = float2(17.5, -22.5), radius = 1.2812),
    AttackSlashHitbox(row = 0, col = 10, tileOffset = float2(22.5, -23.5), radius = 1.1875),
    AttackSlashHitbox(row = 0, col = 11, tileOffset = float2(25.0, -23.5), radius = 1.2188),
    AttackSlashHitbox(row = 0, col = 12, tileOffset = float2(25.5, -22.5), radius = 1.1562),
    AttackSlashHitbox(row = 1, col = 7, tileOffset = float2(-1.5, -13.0), radius = 1.6875),
    AttackSlashHitbox(row = 1, col = 8, tileOffset = float2(0.0, -15.5), radius = 1.7344),
    AttackSlashHitbox(row = 1, col = 9, tileOffset = float2(2.0, -17.5), radius = 1.7344),
    AttackSlashHitbox(row = 1, col = 10, tileOffset = float2(6.5, -18.0), radius = 1.5938),
    AttackSlashHitbox(row = 1, col = 11, tileOffset = float2(7.5, -18.5), radius = 1.5625),
    AttackSlashHitbox(row = 2, col = 7, tileOffset = float2(-10.0, -17.0), radius = 1.4844),
    AttackSlashHitbox(row = 2, col = 8, tileOffset = float2(-7.5, -17.0), radius = 1.5625),
    AttackSlashHitbox(row = 2, col = 9, tileOffset = float2(-5.5, -15.5), radius = 1.6250),
    AttackSlashHitbox(row = 2, col = 10, tileOffset = float2(-4.5, -10.5), radius = 1.6562),
    AttackSlashHitbox(row = 2, col = 11, tileOffset = float2(-4.5, -10.5), radius = 1.6562),
    AttackSlashHitbox(row = 3, col = 7, tileOffset = float2(-19.5, -29.0), radius = 1.2344),
    AttackSlashHitbox(row = 3, col = 8, tileOffset = float2(-16.0, -27.5), radius = 1.2969),
    AttackSlashHitbox(row = 3, col = 9, tileOffset = float2(-13.5, -26.5), radius = 1.3750),
    AttackSlashHitbox(row = 3, col = 10, tileOffset = float2(-12.5, -24.5), radius = 1.4062),
    AttackSlashHitbox(row = 3, col = 11, tileOffset = float2(-12.0, -22.5), radius = 1.3906),
    AttackSlashHitbox(row = 4, col = 7, tileOffset = float2(-13.0, -35.0), radius = 1.3906),
    AttackSlashHitbox(row = 4, col = 8, tileOffset = float2(-14.0, -33.0), radius = 1.3594),
    AttackSlashHitbox(row = 4, col = 9, tileOffset = float2(-16.0, -31.5), radius = 1.2969),
    AttackSlashHitbox(row = 4, col = 10, tileOffset = float2(-23.0, -31.0), radius = 1.2031),
    AttackSlashHitbox(row = 4, col = 11, tileOffset = float2(-23.0, -31.0), radius = 1.2031),
    AttackSlashHitbox(row = 5, col = 7, tileOffset = float2(3.0, -41.0), radius = 1.7031),
    AttackSlashHitbox(row = 5, col = 8, tileOffset = float2(1.0, -39.5), radius = 1.7344),
    AttackSlashHitbox(row = 5, col = 9, tileOffset = float2(-1.0, -37.5), radius = 1.7344),
    AttackSlashHitbox(row = 5, col = 10, tileOffset = float2(-4.5, -36.5), radius = 1.6250),
    AttackSlashHitbox(row = 5, col = 11, tileOffset = float2(-4.5, -35.5), radius = 1.6250),
    AttackSlashHitbox(row = 6, col = 7, tileOffset = float2(11.0, -37.0), radius = 1.4844),
    AttackSlashHitbox(row = 6, col = 8, tileOffset = float2(9.0, -37.5), radius = 1.5469),
    AttackSlashHitbox(row = 6, col = 9, tileOffset = float2(6.5, -39.0), radius = 1.6250),
    AttackSlashHitbox(row = 6, col = 10, tileOffset = float2(6.0, -43.5), radius = 1.6406),
    AttackSlashHitbox(row = 6, col = 11, tileOffset = float2(6.0, -45.0), radius = 1.6406),
    AttackSlashHitbox(row = 7, col = 7, tileOffset = float2(20.5, -25.5), radius = 1.2188),
    AttackSlashHitbox(row = 7, col = 8, tileOffset = float2(17.5, -27.0), radius = 1.2812),
    AttackSlashHitbox(row = 7, col = 9, tileOffset = float2(14.5, -28.0), radius = 1.3750),
    AttackSlashHitbox(row = 7, col = 10, tileOffset = float2(13.5, -31.0), radius = 1.4062),
    AttackSlashHitbox(row = 7, col = 11, tileOffset = float2(13.5, -31.5), radius = 1.4062),
    AttackSlashHitbox(row = 7, col = 12, tileOffset = float2(14.0, -30.5), radius = 1.3906),
]


def attack_tile_pixel_to_world() : float {
    return PLAYER_WORLD_HEIGHT / (PLAYER_SHEET_HEIGHT / float(PLAYER_SHEET_ROWS))
}


def attack_slash_anchor(feet : float2) : float2 {
    let pixelToWorld = attack_tile_pixel_to_world()
    return feet + float2(0.0, PLAYER_ATTACK_SLASH_CENTER_Y_OFFSET_PX * pixelToWorld)
}


def slash_offset_world(tileOffset : float2; row : int) : float2 {
    let pixelToWorld = attack_tile_pixel_to_world()
    let forward = facing_dir_from_row(row)
    let right = float2(forward.y, -forward.x)
    let localRight = tileOffset.x * pixelToWorld
    let localForward = -tileOffset.y * pixelToWorld
    return right * localRight + forward * localForward
}


def attack_facing_dir(row : int) : float2 {
    return facing_dir_from_row(row)
}


def public attack_slash_hit_radius(frameRadius : float) : float {
    return frameRadius * PLAYER_ATTACK_SLASH_RADIUS_SCALE + ENTITY_FEET_RADIUS + PLAYER_ATTACK_HIT_FEET_PAD
}


def public query_attack_slash_debug(playerFeet : float2; row, col : int) : AttackSlashDebugInfo {
    if (!attack_slash_active(row, col)) {
        return AttackSlashDebugInfo(active = false, center = float2(0.0), radius = 0.0)
    }
    for (frame in attack_slash_frames) {
        if (frame.row != row || frame.col != col) {
            continue
        }
        let center = attack_slash_anchor(playerFeet) + slash_offset_world(frame.tileOffset, row)
        let radius = attack_slash_hit_radius(frame.radius)
        return AttackSlashDebugInfo(active = true, center = center, radius = radius)
    }
    return AttackSlashDebugInfo(active = false, center = float2(0.0), radius = 0.0)
}


def public attack_slash_active(row, col : int) : bool {
    for (frame in attack_slash_frames) {
        if (frame.row == row && frame.col == col) {
            return true
        }
    }
    return false
}


def public slash_hits_feet(playerFeet, enemyFeet : float2; row, col : int; maxReach : float) : bool {
    if (!attack_slash_active(row, col)) {
        return false
    }

    let toEnemy = enemyFeet - playerFeet
    let distSq = length_sq(toEnemy)
    if (distSq > maxReach * maxReach) {
        return false
    }

    let facing = attack_facing_dir(row)
    if (dot(toEnemy, facing) <= 0.0) {
        return false
    }

    for (frame in attack_slash_frames) {
        if (frame.row != row || frame.col != col) {
            continue
        }
        let center = attack_slash_anchor(playerFeet) + slash_offset_world(frame.tileOffset, row)
        let slashRadius = attack_slash_hit_radius(frame.radius)
        return length_sq(enemyFeet - center) <= slashRadius * slashRadius
    }
    return false
}


def public slash_hits_point(point : float2; attackerFeet : float2; row, col : int; pointRadius, maxReach : float) : bool {
    if (!attack_slash_active(row, col)) {
        return false
    }

    let toPoint = point - attackerFeet
    if (length_sq(toPoint) > maxReach * maxReach) {
        return false
    }

    for (frame in attack_slash_frames) {
        if (frame.row != row || frame.col != col) {
            continue
        }
        let center = attack_slash_anchor(attackerFeet) + slash_offset_world(frame.tileOffset, row)
        let slashRadius = attack_slash_hit_radius(frame.radius) + pointRadius
        return length_sq(point - center) <= slashRadius * slashRadius
    }
    return false
}
