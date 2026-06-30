require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state

module upgrade_defs public

let public {
    UPGRADE_KIND_COUNT = 15
    UPGRADE_CHOICES_SHOWN = 3
    COLOR_UPGRADE_TITLE = float4(0.96, 0.82, 0.32, 1.0)
    COLOR_UPGRADE_BODY = float4(0.90, 0.92, 0.95, 1.0)
    COLOR_UPGRADE_STAT = float4(0.55, 0.88, 1.0, 1.0)
    COLOR_UPGRADE_HEADER = float4(1.0, 1.0, 1.0, 1.0)
    COLOR_UPGRADE_CARD_HOVER_OVERLAY = float4(0.95, 0.82, 0.35, 0.32)
}

enum UpgradeKind {
    Vitality = 0,
    MoveSpeed = 1,
    SwordDamage = 2,
    BowDamage = 3,
    SpecialDamage = 4,
    SpecialCooldown = 5,
    AoeRadius = 6,
    FleetDash = 7,
    CameraZoom = 8,
    Crit = 9,
    Knockback = 10,
    LifeSteal = 11,
    BowVolley = 12,
    Pierce = 13,
    AttackSpeed = 14,
}


var public upgradeBoxTexture : TextureId
var public upgradePickerCanvas : NodeId
var public upgradeOverlayNode : NodeId
var public upgradeHeaderNode : NodeId
var public upgradeSlideGroupNode : NodeId
var public upgradeCardNodes : array<NodeId>
var public upgradeCardHoverOverlayNodes : array<NodeId>
var public upgradeCardBasePos : array<float2>
var public upgradeCardHoverT : array<float>
var public upgradeSlideT : float = 0.0
var public upgradeSlideAnchorTop : float = 0.0
var public upgradePickerInputLockT : float = 0.0
var public upgradePickerOpenDelayT : float = 0.0
var public upgradePickerDelaying : bool = false
var public savedDeltaTimeScale : float = 1.0
var public currentUpgradeChoices : array<int>



def upgrade_kind_title(kind : int) : string {
    if (kind == int(UpgradeKind.MoveSpeed)) {
        return "Swift Feet"
    }
    if (kind == int(UpgradeKind.SwordDamage)) {
        return "Sharpened Steel"
    }
    if (kind == int(UpgradeKind.BowDamage)) {
        return "True Aim"
    }
    if (kind == int(UpgradeKind.SpecialDamage)) {
        return "Blazing Burst"
    }
    if (kind == int(UpgradeKind.SpecialCooldown)) {
        return "Focused Recovery"
    }
    if (kind == int(UpgradeKind.AoeRadius)) {
        return "Wide Blast"
    }
    if (kind == int(UpgradeKind.FleetDash)) {
        return "Fleet Dash"
    }
    if (kind == int(UpgradeKind.CameraZoom)) {
        return "Eagle Eye"
    }
    if (kind == int(UpgradeKind.Crit)) {
        return "Deadly Precision"
    }
    if (kind == int(UpgradeKind.Knockback)) {
        return "Forceful Blow"
    }
    if (kind == int(UpgradeKind.LifeSteal)) {
        return "Vampiric Touch"
    }
    if (kind == int(UpgradeKind.BowVolley)) {
        return "Arrow Storm"
    }
    if (kind == int(UpgradeKind.Pierce)) {
        return "Piercing Shot"
    }
    if (kind == int(UpgradeKind.AttackSpeed)) {
        return "Quick Hands"
    }
    return "Iron Will"
}


def upgrade_kind_description(kind : int) : string {
    if (kind == int(UpgradeKind.MoveSpeed)) {
        return "+{format_weapon_one_decimal(UPGRADE_MOVE_SPEED_BONUS)} walk and sprint speed."
    }
    if (kind == int(UpgradeKind.SwordDamage)) {
        return "+{UPGRADE_SWORD_DAMAGE_BONUS} sword damage."
    }
    if (kind == int(UpgradeKind.BowDamage)) {
        return "+{UPGRADE_BOW_DAMAGE_BONUS} bow damage."
    }
    if (kind == int(UpgradeKind.SpecialDamage)) {
        return "+{UPGRADE_SPECIAL_DAMAGE_BONUS} damage on your right-click explosion."
    }
    if (kind == int(UpgradeKind.SpecialCooldown)) {
        return "Right-click special recharges {format_weapon_one_decimal(UPGRADE_SPECIAL_COOLDOWN_REDUCTION)}s faster."
    }
    if (kind == int(UpgradeKind.AoeRadius)) {
        return "Right-click explosion covers 15% more area."
    }
    if (kind == int(UpgradeKind.FleetDash)) {
        return "Space dash recharges {format_weapon_one_decimal(UPGRADE_FLEET_DASH_COOLDOWN_REDUCTION)}s faster."
    }
    if (kind == int(UpgradeKind.CameraZoom)) {
        return "Pull the camera back to see more of the map."
    }
    if (kind == int(UpgradeKind.Crit)) {
        return "+1% crit chance with sword and bow."
    }
    if (kind == int(UpgradeKind.Knockback)) {
        return "+5% knockback on sword, bow, and hits."
    }
    if (kind == int(UpgradeKind.LifeSteal)) {
        return "+1% of damage dealt returned as healing."
    }
    if (kind == int(UpgradeKind.BowVolley)) {
        return "+1 arrow per shot (extra arrows fly at a random angle)."
    }
    if (kind == int(UpgradeKind.Pierce)) {
        return "Arrows pass through +1 more enemy before breaking."
    }
    if (kind == int(UpgradeKind.AttackSpeed)) {
        return "+10% sword and bow attack animation speed."
    }
    return "+{UPGRADE_VITALITY_HP_BONUS} max HP and heal the same amount."
}


def upgrade_kind_stat_line(kind : int) : string {
    if (kind == int(UpgradeKind.MoveSpeed)) {
        let walkBefore = player_move_speed()
        let walkAfter = walkBefore + UPGRADE_MOVE_SPEED_BONUS
        let runBefore = player_run_speed()
        let runAfter = runBefore + UPGRADE_MOVE_SPEED_BONUS
        return "Walk: {format_weapon_one_decimal(walkBefore)} → {format_weapon_one_decimal(walkAfter)}\nSprint: {format_weapon_one_decimal(runBefore)} → {format_weapon_one_decimal(runAfter)}"
    }
    if (kind == int(UpgradeKind.SwordDamage)) {
        let before = player_sword_damage()
        let after = before + UPGRADE_SWORD_DAMAGE_BONUS
        return "Sword DMG: {before} → {after}"
    }
    if (kind == int(UpgradeKind.BowDamage)) {
        let before = player_bow_damage()
        let after = before + UPGRADE_BOW_DAMAGE_BONUS
        return "Bow DMG: {before} → {after}"
    }
    if (kind == int(UpgradeKind.SpecialDamage)) {
        let before = player_special_damage()
        let after = before + UPGRADE_SPECIAL_DAMAGE_BONUS
        return "Special DMG: {before} → {after}"
    }
    if (kind == int(UpgradeKind.SpecialCooldown)) {
        let before = player_special_cooldown()
        let after = max(UPGRADE_MIN_ABILITY_COOLDOWN, before - UPGRADE_SPECIAL_COOLDOWN_REDUCTION)
        return "Special CD: {format_weapon_one_decimal(before)}s → {format_weapon_one_decimal(after)}s"
    }
    if (kind == int(UpgradeKind.AoeRadius)) {
        let before = player_aoe_hit_radius()
        let after = before * UPGRADE_AOE_RADIUS_SCALE
        return "AOE Radius: {format_weapon_one_decimal(before)} → {format_weapon_one_decimal(after)}"
    }
    if (kind == int(UpgradeKind.FleetDash)) {
        let before = player_dash_cooldown()
        let after = max(UPGRADE_MIN_ABILITY_COOLDOWN, before - UPGRADE_FLEET_DASH_COOLDOWN_REDUCTION)
        return "Dash CD: {format_weapon_one_decimal(before)}s → {format_weapon_one_decimal(after)}s"
    }
    if (kind == int(UpgradeKind.CameraZoom)) {
        let before = player_camera_ortho_size()
        let after = clamp(before + UPGRADE_CAMERA_ZOOM_OUT, CAMERA_ORTHO_SIZE_MIN, CAMERA_ORTHO_SIZE_MAX)
        return "View range: {format_weapon_one_decimal(before)} → {format_weapon_one_decimal(after)}"
    }
    if (kind == int(UpgradeKind.Crit)) {
        let before = player_sword_crit_chance()
        let after = before + UPGRADE_CRIT_BONUS
        return "Crit: {format_weapon_percent(before)} → {format_weapon_percent(after)}"
    }
    if (kind == int(UpgradeKind.Knockback)) {
        let before = playerBonusKnockbackScale
        let after = before + UPGRADE_KNOCKBACK_BONUS
        return "Knockback: +{format_weapon_percent(before)} → +{format_weapon_percent(after)}"
    }
    if (kind == int(UpgradeKind.LifeSteal)) {
        let before = player_sword_life_steal()
        let after = before + UPGRADE_LIFE_STEAL_BONUS
        return "Life Steal: {format_weapon_percent(before)} → {format_weapon_percent(after)}"
    }
    if (kind == int(UpgradeKind.BowVolley)) {
        let before = player_bow_arrow_count()
        let after = before + 1
        return "Arrows/shot: {before} → {after}"
    }
    if (kind == int(UpgradeKind.Pierce)) {
        let before = player_bow_pierce()
        let after = before + 1
        return "Pierce: {before} → {after}"
    }
    if (kind == int(UpgradeKind.AttackSpeed)) {
        let before = player_attack_anim_fps()
        let after = PLAYER_ATTACK_ANIM_FPS * (1.0 + playerBonusAttackSpeed + UPGRADE_ATTACK_SPEED_BONUS)
        return "Attack SPD: {format_weapon_one_decimal(before)} → {format_weapon_one_decimal(after)}"
    }
    let before = player_max_hp()
    let after = before + UPGRADE_VITALITY_HP_BONUS
    return "Max HP: {before} → {after}"
}


def pick_random_upgrade_kinds(count : int) : array<int> {
    var pool : array<int>
    for (i in range(UPGRADE_KIND_COUNT)) {
        push(pool, i)
    }
    for (i in range(count)) {
        let pick = i + random_range(0, length(pool) - i)
        let swap = pool[i]
        pool[i] = pool[pick]
        pool[pick] = swap
    }
    var result : array<int>
    for (i in range(count)) {
        push(result, pool[i])
    }
    return <- result
}


def apply_upgrade_kind(kind : int) {
    if (kind == int(UpgradeKind.MoveSpeed)) {
        playerBonusWalkSpeed += UPGRADE_MOVE_SPEED_BONUS
        playerBonusRunSpeed += UPGRADE_MOVE_SPEED_BONUS
        return
    }
    if (kind == int(UpgradeKind.SwordDamage)) {
        playerBonusSwordDamage += UPGRADE_SWORD_DAMAGE_BONUS
        return
    }
    if (kind == int(UpgradeKind.BowDamage)) {
        playerBonusBowDamage += UPGRADE_BOW_DAMAGE_BONUS
        return
    }
    if (kind == int(UpgradeKind.SpecialDamage)) {
        playerBonusSpecialDamage += UPGRADE_SPECIAL_DAMAGE_BONUS
        return
    }
    if (kind == int(UpgradeKind.SpecialCooldown)) {
        playerBonusSpecialCooldown += UPGRADE_SPECIAL_COOLDOWN_REDUCTION
        playerSpecialLevel += 1
        return
    }
    if (kind == int(UpgradeKind.AoeRadius)) {
        playerBonusAoeRadiusScale *= UPGRADE_AOE_RADIUS_SCALE
        playerSpecialLevel += 1
        return
    }
    if (kind == int(UpgradeKind.FleetDash)) {
        playerBonusDashCooldown += UPGRADE_FLEET_DASH_COOLDOWN_REDUCTION
        playerDashLevel += 1
        return
    }
    if (kind == int(UpgradeKind.CameraZoom)) {
        playerBonusCameraZoom += UPGRADE_CAMERA_ZOOM_OUT
        cameraOrthoSize = player_camera_ortho_size()
        cameraOrthoSizeTarget = cameraOrthoSize
        if (cameraNode.isAlive) {
            cameraNode?.Camera.orthographicSize = cameraOrthoSize
        }
        return
    }
    if (kind == int(UpgradeKind.Crit)) {
        playerBonusCrit += UPGRADE_CRIT_BONUS
        return
    }
    if (kind == int(UpgradeKind.Knockback)) {
        playerBonusKnockbackScale += UPGRADE_KNOCKBACK_BONUS
        return
    }
    if (kind == int(UpgradeKind.LifeSteal)) {
        playerBonusLifeSteal += UPGRADE_LIFE_STEAL_BONUS
        return
    }
    if (kind == int(UpgradeKind.BowVolley)) {
        playerBonusBowExtraArrows += 1
        return
    }
    if (kind == int(UpgradeKind.Pierce)) {
        playerBonusBowPierce += 1
        return
    }
    if (kind == int(UpgradeKind.AttackSpeed)) {
        playerBonusAttackSpeed += UPGRADE_ATTACK_SPEED_BONUS
        return
    }
    playerBonusMaxHp += UPGRADE_VITALITY_HP_BONUS
    playerHp = min(player_max_hp(), playerHp + UPGRADE_VITALITY_HP_BONUS)
}

