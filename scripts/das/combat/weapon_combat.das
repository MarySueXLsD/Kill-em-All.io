require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
module weapon_combat public


def combat_random_unit() : float {
    return float(random_range(0, 9999)) / 9999.0
}


def public roll_weapon_crit(critChance : float) : bool {
    if (critChance <= 0.0) {
        return false
    }
    return combat_random_unit() < critChance
}


def public resolve_weapon_damage(baseDamage : int; critChance : float) : int {
    if (baseDamage <= 0) {
        return 0
    }
    if (roll_weapon_crit(critChance)) {
        return max(1, int(float(baseDamage) * PLAYER_CRIT_DAMAGE_MULTIPLIER))
    }
    return baseDamage
}


def public apply_player_life_steal(damageDealt : int; lifeStealFraction : float) {
    if (damageDealt <= 0 || lifeStealFraction <= 0.0 || playerHp <= 0) {
        return
    }
    let heal = int(ceil(float(damageDealt) * lifeStealFraction))
    if (heal <= 0) {
        return
    }
    playerHp = min(player_max_hp(), playerHp + heal)
}


def public spread_aim_direction(baseDir : float2; spreadDeg : float) : float2 {
    if (length_sq(baseDir) < 0.0001) {
        return float2(1.0, 0.0)
    }
    let direction = normalize(baseDir)
    if (spreadDeg <= 0.0) {
        return direction
    }
    let halfRad = spreadDeg * 0.5 * (PI / 180.0)
    let offset = (combat_random_unit() * 2.0 - 1.0) * halfRad
    let ca = cos(offset)
    let sa = sin(offset)
    return normalize(float2(
        direction.x * ca - direction.y * sa,
        direction.x * sa + direction.y * ca
    ))
}
