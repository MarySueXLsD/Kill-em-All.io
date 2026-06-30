require engine.core
require scripts/das/core/constants
module game_state public

enum PlayerWeapon {
    Sword = 0,
    Bow = 1,
}


struct PlayerDamageEvent {
    amount : int
    fromFeet : float2
}


var public cameraNode : NodeId
var public playerNode : NodeId
// Feet world position captured from level.prefab player node transform at bind (before runtime overwrites).
var public playerSpawnFeet : float2
var public playerSpawnFeetValid : bool = false
var public mapRootNode : NodeId
var public wallsRootNode : NodeId
var public propsRootNode : NodeId
var public enemiesRootNode : NodeId
var public effectsRootNode : NodeId
var public cameraOrthoSize : float = CAMERA_ORTHO_SIZE
var public cameraOrthoSizeTarget : float = CAMERA_ORTHO_SIZE
var public playerWorldPosition : float2
var public playerHp : int = PLAYER_MAX_HP
var public playerLevel : int = 1
var public playerDashLevel : int = 1
var public playerSpecialLevel : int = 1
var public playerExp : int = 0
var public playerDashing : bool = false
var public playerSpecialActive : bool = false
var public playerDashCooldownRemaining : float = 0.0
var public playerSpecialCooldownRemaining : float = 0.0
var public playerDamageQueue : array<PlayerDamageEvent>
var public enemyHealthCanvas : NodeId
var public enemyHeartsHudRoot : NodeId
var public tileEdgeAngleDeg : float = GROUND_TILE_EDGE_ANGLE_DEG
var public tileAngleHudNode : NodeId
var public debugBordersEnabled : bool = false
var public enemiesActive : bool = true
var public debugHudVisible : bool = false
var public gameReady : bool = false
var public gameTexturesVerified : bool = false
var public isBaseLevel : bool = false
var public activeGridWidth : int = GRID_WIDTH
var public activeGridHeight : int = GRID_HEIGHT
var public activeMapWidth : int = MAP_WIDTH
var public activeMapHeight : int = MAP_HEIGHT
var public activeGridMinX : int = GRID_MIN_X
var public activeGridMinY : int = GRID_MIN_Y
var public enemyFrameStamp : int = 0
var public deathKnightBossTierSpawned : int = 0
var public playerWeapon : PlayerWeapon = PlayerWeapon.Sword
var public currentWave : int = 1
var public upgradePickerActive : bool = false
var public pendingUpgradePicks : int = 0
var public playerBonusMaxHp : int = 0
var public playerBonusWalkSpeed : float = 0.0
var public playerBonusRunSpeed : float = 0.0
var public playerBonusSwordDamage : int = 0
var public playerBonusBowDamage : int = 0
var public playerBonusSpecialDamage : int = 0
var public playerBonusDashCooldown : float = 0.0
var public playerBonusSpecialCooldown : float = 0.0
var public playerBonusAoeRadiusScale : float = 1.0
var public playerBonusCameraZoom : float = 0.0
var public playerBonusCrit : float = 0.0
var public playerBonusKnockbackScale : float = 0.0
var public playerBonusLifeSteal : float = 0.0
var public playerBonusBowExtraArrows : int = 0
var public playerBonusBowPierce : int = 0
var public playerBonusAttackSpeed : float = 0.0


def public configure_level_1_profile() {
    isBaseLevel = false
    activeGridWidth = GRID_WIDTH
    activeGridHeight = GRID_HEIGHT
    activeMapWidth = MAP_WIDTH
    activeMapHeight = MAP_HEIGHT
    activeGridMinX = GRID_MIN_X
    activeGridMinY = GRID_MIN_Y
    enemiesActive = true
}


def public configure_base_level_profile() {
    isBaseLevel = true
    activeGridWidth = BASE_GRID_WIDTH
    activeGridHeight = BASE_GRID_HEIGHT
    activeMapWidth = BASE_MAP_WIDTH
    activeMapHeight = BASE_MAP_HEIGHT
    activeGridMinX = BASE_GRID_MIN_X
    activeGridMinY = BASE_GRID_MIN_Y
    enemiesActive = false
}


def public player_weapon_label() : string {
    if (playerWeapon == PlayerWeapon.Bow) {
        return "Bow"
    }
    return "Sword"
}


def public player_max_hp() : int {
    return PLAYER_MAX_HP + playerBonusMaxHp
}


def public player_move_speed() : float {
    return PLAYER_SPEED + playerBonusWalkSpeed
}


def public player_run_speed() : float {
    return PLAYER_SPEED * PLAYER_RUN_SPEED_MULTIPLIER + playerBonusRunSpeed
}


def public player_camera_ortho_size() : float {
    return clamp(CAMERA_ORTHO_SIZE + playerBonusCameraZoom, CAMERA_ORTHO_SIZE_MIN, CAMERA_ORTHO_SIZE_MAX)
}


def public player_attack_anim_fps() : float {
    return PLAYER_ATTACK_ANIM_FPS * (1.0 + playerBonusAttackSpeed)
}


def public player_dash_cooldown() : float {
    return max(UPGRADE_MIN_ABILITY_COOLDOWN, PLAYER_DASH_COOLDOWN - playerBonusDashCooldown)
}


def public player_special_cooldown() : float {
    return max(UPGRADE_MIN_ABILITY_COOLDOWN, PLAYER_SPECIAL_COOLDOWN - playerBonusSpecialCooldown)
}


def public player_aoe_hit_radius() : float {
    return AOE_HIT_RADIUS * playerBonusAoeRadiusScale
}


def public player_special_aoe_hit_radius() : float {
    return player_aoe_hit_radius() * PLAYER_SPECIAL_AOE_HIT_RADIUS_SCALE
}


def public player_bow_napalm_aoe_hit_radius() : float {
    return player_aoe_hit_radius() * PLAYER_BOW_NAPALM_AOE_HIT_RADIUS_SCALE
}


def public player_sword_damage() : int {
    return PLAYER_SWORD_DAMAGE + playerBonusSwordDamage
}


def public player_bow_damage() : int {
    return PLAYER_BOW_DAMAGE + playerBonusBowDamage
}


def public player_special_damage() : int {
    return PLAYER_SPECIAL_DAMAGE + playerBonusSpecialDamage
}


def public player_weapon_damage() : int {
    if (playerWeapon == PlayerWeapon.Bow) {
        return player_bow_damage()
    }
    return player_sword_damage()
}


def format_weapon_one_decimal(value : float) : string {
    let scaled = int(value * 10.0 + 0.5)
    let whole = scaled / 10
    let frac = scaled % 10
    let fracPart = (frac < 0 ? -frac : frac)
    return "{whole}.{fracPart}"
}


def format_weapon_percent(fraction : float) : string {
    return "{int(round(fraction * 100.0))}%"
}


def format_weapon_range(value : float) : string {
    return format_weapon_one_decimal(value)
}


def format_weapon_knockback(value : float) : string {
    return format_weapon_one_decimal(value)
}


def public player_sword_range() : float {
    return PLAYER_SWORD_RANGE
}


def public player_sword_crit_chance() : float {
    return PLAYER_SWORD_CRIT_CHANCE + playerBonusCrit
}


def public player_sword_knockback() : float {
    return PLAYER_SWORD_KNOCKBACK * (1.0 + playerBonusKnockbackScale)
}


def public player_sword_life_steal() : float {
    return PLAYER_SWORD_LIFE_STEAL + playerBonusLifeSteal
}


def public player_bow_arrow_count() : int {
    return 1 + playerBonusBowExtraArrows
}


def public player_bow_crit_chance() : float {
    return PLAYER_BOW_CRIT_CHANCE + playerBonusCrit
}


def public player_bow_knockback() : float {
    return PLAYER_BOW_KNOCKBACK * (1.0 + playerBonusKnockbackScale)
}


def public player_bow_pierce() : int {
    return PLAYER_BOW_PIERCE + playerBonusBowPierce
}


def public player_bow_life_steal() : float {
    return PLAYER_BOW_LIFE_STEAL + playerBonusLifeSteal
}


def public player_weapon_stats_hud_text() : string {
    if (playerWeapon == PlayerWeapon.Bow) {
        return "ARROWS: {player_bow_arrow_count()}\nCRIT: {format_weapon_percent(player_bow_crit_chance())}\nKNOCK: {format_weapon_knockback(player_bow_knockback())}\nPIERCE: {player_bow_pierce()}\nLIFE STEAL: {format_weapon_percent(player_bow_life_steal())}"
    }
    return "RANGE: {format_weapon_range(player_sword_range())}\nCRIT: {format_weapon_percent(player_sword_crit_chance())}\nKNOCK: {format_weapon_knockback(player_sword_knockback())}\nLIFE STEAL: {format_weapon_percent(player_sword_life_steal())}\nATK SPD: {format_weapon_percent(playerBonusAttackSpeed)}"
}


def public player_weapon_hud_line() : string {
    return "Weapon: {player_weapon_label()} ({player_weapon_damage()})"
}


def public wave_title_hud_label() : string {
    return "Wave {currentWave}"
}


def public exp_required_for_level(level : int) : int {
    if (level == 1) {
        return 15
    }
    if (level == 2) {
        return 25
    }
    if (level == 3) {
        return 35
    }
    if (level == 4) {
        return 50
    }
    if (level == 5) {
        return 75
    }
    if (level == 6) {
        return 90
    }
    if (level == 7) {
        return 110
    }
    if (level == 8) {
        return 130
    }
    if (level == 9) {
        return 160
    }
    if (level == 10) {
        return 210
    }
    if (level == 11) {
        return 260
    }
    if (level == 12) {
        return 310
    }
    if (level == 13) {
        return 360
    }
    if (level == 14) {
        return 410
    }
    return 410 + (level - 14) * 50
}


def public player_level_hud_label() : string {
    return "Level: {playerLevel}"
}


def public player_exp_hud_label() : string {
    let needed = exp_required_for_level(playerLevel)
    return "Current EXP: {playerExp}/{needed}"
}


def public queue_player_damage(amount : int; fromFeet : float2) {
    if (amount <= 0 || playerHp <= 0 || playerDashing) {
        return
    }
    push(playerDamageQueue, PlayerDamageEvent(amount = amount, fromFeet = fromFeet))
}
