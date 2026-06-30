require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/ui/hud_bottom_bar
require scripts/das/ui/hud_character public
require scripts/das/ui/hud_health

module hud_weapons public

def player_weapon_hud_text_y() : float {
    return player_character_name_y() + PLAYER_WEAPON_HUD_TEXT_Y_OFFSET
}


def player_weapon_hud_icon_y() : float {
    return player_weapon_hud_text_y() + PLAYER_WEAPON_HUD_ICON_DOWN_OFFSET
}


def public sync_player_weapon_hud_layout() {
    if (!playerWeaponHudRoot.isAlive) {
        return
    }
    get_component(playerWeaponHudRoot) $(var anchor : UIAnchor?) {
        if (anchor != null) {
            anchor.top = -PLAYER_WEAPON_HUD_BOTTOM_MARGIN
            anchor.left = -PLAYER_WEAPON_HUD_RIGHT_MARGIN
        }
    }
    let textY = player_weapon_hud_text_y()
    let iconY = player_weapon_hud_icon_y()
    if (playerWeaponHudImage.isAlive) {
        get_component(playerWeaponHudImage) $(var weaponImage : UIImage?) {
            if (weaponImage != null) {
                weaponImage.localPosition2D = float2(weapon_icon_canvas_x(), iconY)
            }
        }
    }
    if (playerWeaponStatsTextNode.isAlive) {
        get_component(playerWeaponStatsTextNode) $(var statsText : UIText?) {
            if (statsText != null) {
                statsText.localPosition2D = float2(weapon_stat_text_canvas_x(), textY)
            }
        }
    }
}


def public sync_player_weapon_sprite() {
    if (!playerWeaponHudImage.isAlive) {
        return
    }
    let weapon = int(playerWeapon)
    let weaponChanged = weapon != playerWeaponLastShown
    if (weaponChanged) {
        playerWeaponLastShown = weapon
        get_component(playerWeaponHudImage) $(var weaponImage : UIImage?) {
            if (weaponImage != null) {
                weaponImage.textureId = player_weapon_texture()
            }
        }
        if (playerWeaponStatsTextNode.isAlive) {
            playerWeaponStatsTextNode?.UIText.text = player_weapon_stats_hud_text()
        }
    }
    get_component(playerWeaponHudImage) $(var weaponImage : UIImage?) {
        if (weaponImage != null) {
            weaponImage.size = float2(PLAYER_WEAPON_HUD_SIZE, PLAYER_WEAPON_HUD_SIZE)
        }
    }
    sync_player_weapon_hud_layout()
}


def weapon_icon_canvas_x() : float {
    return -(PLAYER_WEAPON_HUD_TEXT_COLUMN_WIDTH + PLAYER_WEAPON_HUD_TEXT_GAP + PLAYER_WEAPON_HUD_LEFT_OFFSET)
}


def weapon_stat_text_canvas_x() : float {
    return -(PLAYER_WEAPON_HUD_TEXT_COLUMN_WIDTH + PLAYER_WEAPON_HUD_LEFT_OFFSET)
}


def ui_bar_fill_width_px() : float {
    return PLAYER_UI_BAR_FILL_MAX_X - PLAYER_UI_BAR_FILL_MIN_X + 1.0
}


def ui_bar_fill_height_px() : float {
    return PLAYER_UI_BAR_FILL_MAX_Y - PLAYER_UI_BAR_FILL_MIN_Y + 1.0
}


def ui_bar_hud_scale() : float2 {
    return float2(
        PLAYER_UI_BAR_HUD_WIDTH / PLAYER_UI_BAR_TEX_WIDTH,
        PLAYER_UI_BAR_HUD_HEIGHT / PLAYER_UI_BAR_TEX_HEIGHT
    )
}


def ui_bar_fill_display_size() : float2 {
    let scale = ui_bar_hud_scale()
    return float2(ui_bar_fill_width_px() * scale.x, ui_bar_fill_height_px() * scale.y)
}


def ui_bar_fill_top_left_offset() : float2 {
    let scale = ui_bar_hud_scale()
    let x = -PLAYER_UI_BAR_HUD_WIDTH * 0.5 + PLAYER_UI_BAR_FILL_MIN_X * scale.x
    let y = -PLAYER_UI_BAR_HUD_HEIGHT + PLAYER_UI_BAR_FILL_MIN_Y * scale.y
    return float2(x, y)
}


def apply_cooldown_fill_layout(fillNode : NodeId; barPos : float2) {
    if (!fillNode.isAlive) {
        return
    }
    let fillSize = ui_bar_fill_display_size()
    let fillPos = barPos + ui_bar_fill_top_left_offset()
    fillNode?.UIImage.size = fillSize
    fillNode?.UIImage.localPosition2D = fillPos
    get_component(fillNode) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.pivot = float2(0.0, 0.0)
            frame.size = fillSize
            frame.localPosition2D = fillPos
        }
    }
}


def player_ability_bar_center_x() : float {
    return player_character_text_x() + PLAYER_COOLDOWN_HUD_LABEL_WIDTH + PLAYER_COOLDOWN_HUD_LABEL_GAP + PLAYER_UI_BAR_HUD_WIDTH * 0.5
}


def cooldown_bar_row_pos(localY : float) : float2 {
    return float2(player_ability_bar_center_x(), localY)
}


def cooldown_bar_label_y(localY : float) : float {
    return localY - PLAYER_UI_BAR_HUD_HEIGHT * 0.5
}


def cooldown_level_label(level : int) : string {
    return "Lv. {level}"
}


def layout_cooldown_label_pair(prefixNode, levelNode : NodeId; localY : float) {
    if (!prefixNode.isAlive || !levelNode.isAlive) {
        return
    }
    let labelX = player_character_text_x()
    let labelY = cooldown_bar_label_y(localY)
    var prefixW = prefixNode?.UIFrame.size.x
    if (prefixW <= 0.0) {
        prefixW = 72.0
    }
    prefixNode?.UIText.localPosition2D = float2(labelX, labelY)
    levelNode?.UIText.localPosition2D = float2(labelX + prefixW + PLAYER_COOLDOWN_HUD_LABEL_LEVEL_GAP, labelY)
}


def create_cooldown_label_pair(parent : NodeId; name : string; prefixText : string; level : int; localY : float) : CooldownLabelPair {
    let labelX = player_character_text_x()
    let labelY = cooldown_bar_label_y(localY)

    let prefixNode = create_node(NodeData(name = "{name}_prefix", parent = parent))
    add_component(prefixNode, new UIText(
        text = prefixText,
        fontSize = PLAYER_COOLDOWN_HUD_LABEL_FONT_SIZE,
        color = PLAYER_COOLDOWN_HUD_LABEL_COLOR,
        pivot = float2(0.0, 0.5),
        horAlignment = TextHorAlignment.Left,
        wordWrapping = false,
        localPosition2D = float2(labelX, labelY)
    ))
    prefixNode?.UIText.fontScaling = false
    prefixNode?.UIText.autoResizeFrame = true

    let levelNode = create_node(NodeData(name = "{name}_level", parent = parent))
    add_component(levelNode, new UIText(
        text = cooldown_level_label(level),
        fontSize = PLAYER_COOLDOWN_HUD_LABEL_FONT_SIZE,
        color = PLAYER_COOLDOWN_HUD_LEVEL_COLOR,
        pivot = float2(0.0, 0.5),
        horAlignment = TextHorAlignment.Left,
        wordWrapping = false,
        localPosition2D = float2(labelX, labelY)
    ))
    levelNode?.UIText.fontScaling = false
    levelNode?.UIText.autoResizeFrame = true

    layout_cooldown_label_pair(prefixNode, levelNode, localY)
    return CooldownLabelPair(prefix = prefixNode, level = levelNode)
}


def public sync_cooldown_bar_labels() {
    if (playerSpecialLevel != playerSpecialCooldownLabelLastLevel) {
        playerSpecialCooldownLabelLastLevel = playerSpecialLevel
        if (playerSpecialCooldownLabelLevel.isAlive) {
            playerSpecialCooldownLabelLevel?.UIText.text = cooldown_level_label(playerSpecialLevel)
        }
    }
    if (playerDashLevel != playerDashCooldownLabelLastLevel) {
        playerDashCooldownLabelLastLevel = playerDashLevel
        if (playerDashCooldownLabelLevel.isAlive) {
            playerDashCooldownLabelLevel?.UIText.text = cooldown_level_label(playerDashLevel)
        }
    }
    layout_cooldown_label_pair(playerSpecialCooldownLabelPrefix, playerSpecialCooldownLabelLevel, player_cooldown_special_row_y())
    layout_cooldown_label_pair(playerDashCooldownLabelPrefix, playerDashCooldownLabelLevel, player_cooldown_dash_row_y())
}


def public sync_cooldown_bar_positions() {
    let specialPos = cooldown_bar_row_pos(player_cooldown_special_row_y())
    let dashPos = cooldown_bar_row_pos(player_cooldown_dash_row_y())
    if (playerAoeCooldownBarFrame.isAlive) {
        playerAoeCooldownBarFrame?.UIImage.localPosition2D = specialPos
    }
    if (playerDashCooldownBarFrame.isAlive) {
        playerDashCooldownBarFrame?.UIImage.localPosition2D = dashPos
    }
    apply_cooldown_fill_layout(playerAoeCooldownBarFill, specialPos)
    apply_cooldown_fill_layout(playerDashCooldownBarFill, dashPos)
}


def cooldown_bar_progress(remaining, maxCooldown : float; abilityActive : bool) : float {
    if (abilityActive) {
        return 0.0
    }
    if (remaining > 0.0 && maxCooldown > 0.0) {
        return clamp(1.0 - remaining / maxCooldown, 0.0, 1.0)
    }
    return 1.0
}


def sync_cooldown_bar_fill(fillNode : NodeId; remaining, maxCooldown : float; abilityActive : bool) {
    if (!fillNode.isAlive) {
        return
    }
    let progress = cooldown_bar_progress(remaining, maxCooldown, abilityActive)
    let maxSize = ui_bar_fill_display_size()
    let width = max(0.0, maxSize.x * progress)
    fillNode?.UIImage.size = float2(width, maxSize.y)
}


def create_cooldown_bar(parent : NodeId; name : string; barPos : float2; fillColor : float4) : CooldownBar {
    let barRoot = create_node(NodeData(name = name, parent = parent))

    let frameNode = create_node(NodeData(name = "{name}_frame", parent = barRoot))
    add_component(frameNode, new UIImage(
        textureId = playerUiBarTexture,
        size = float2(PLAYER_UI_BAR_HUD_WIDTH, PLAYER_UI_BAR_HUD_HEIGHT),
        pivot = float2(0.5, 1.0),
        localPosition2D = barPos
    ))

    let fillNode = create_node(NodeData(name = "{name}_fill", parent = barRoot))
    add_component(fillNode, new UIImage(
        color = fillColor,
        pivot = float2(0.0, 0.0)
    ))
    apply_cooldown_fill_layout(fillNode, barPos)
    return CooldownBar(frame = frameNode, fill = fillNode)
}


def public init_player_weapon_hud() {
    if (!enemyHealthCanvas.isAlive) {
        return
    }
    let displaySize = float2(PLAYER_WEAPON_HUD_SIZE, PLAYER_WEAPON_HUD_SIZE)
    let textY = player_weapon_hud_text_y()
    let iconY = player_weapon_hud_icon_y()

    playerWeaponHudRoot = create_node(NodeData(name = "player_weapon_hud", parent = enemyHealthCanvas))
    add_component(playerWeaponHudRoot, new UIAnchor(
        anchorMin = BOTTOM_RIGHT_ANCHOR,
        anchorMax = BOTTOM_RIGHT_ANCHOR,
        top = -PLAYER_WEAPON_HUD_BOTTOM_MARGIN,
        left = -PLAYER_WEAPON_HUD_RIGHT_MARGIN
    ))

    playerWeaponHudImage = create_node(NodeData(name = "player_weapon_icon", parent = playerWeaponHudRoot))
    add_component(playerWeaponHudImage, new UIImage(
        textureId = player_weapon_texture(),
        size = displaySize,
        pivot = float2(0.5, 1.0),
        localPosition2D = float2(weapon_icon_canvas_x(), iconY)
    ))

    playerWeaponStatsTextNode = create_node(NodeData(name = "player_weapon_stats", parent = playerWeaponHudRoot))
    add_component(playerWeaponStatsTextNode, new UIText(
        text = player_weapon_stats_hud_text(),
        fontSize = PLAYER_COOLDOWN_HUD_LABEL_FONT_SIZE,
        color = PLAYER_COOLDOWN_HUD_LABEL_COLOR,
        pivot = float2(1.0, 0.5),
        horAlignment = TextHorAlignment.Right,
        wordWrapping = false,
        localPosition2D = float2(weapon_stat_text_canvas_x(), textY)
    ))
    playerWeaponStatsTextNode?.UIText.fontScaling = false
    playerWeaponStatsTextNode?.UIText.autoResizeFrame = true

    playerWeaponLastShown = -1
    sync_player_weapon_sprite()
}


def public init_player_cooldown_hud() {
    if (!playerCharacterHudRoot.isAlive) {
        return
    }

    playerCooldownHudRoot = create_node(NodeData(name = "player_cooldown_hud", parent = playerCharacterHudRoot))

    let specialRowY = player_cooldown_special_row_y()
    let dashRowY = player_cooldown_dash_row_y()

    let specialLabels = create_cooldown_label_pair(
        playerCooldownHudRoot, "player_special_cooldown", "Special: ", playerSpecialLevel, specialRowY)
    playerSpecialCooldownLabelPrefix = specialLabels.prefix
    playerSpecialCooldownLabelLevel = specialLabels.level

    let dashLabels = create_cooldown_label_pair(
        playerCooldownHudRoot, "player_dash_cooldown", "Dash: ", playerDashLevel, dashRowY)
    playerDashCooldownLabelPrefix = dashLabels.prefix
    playerDashCooldownLabelLevel = dashLabels.level
    playerSpecialCooldownLabelLastLevel = playerSpecialLevel
    playerDashCooldownLabelLastLevel = playerDashLevel

    let dashBar = create_cooldown_bar(
        playerCooldownHudRoot,
        "player_dash_cooldown_bar",
        cooldown_bar_row_pos(dashRowY),
        PLAYER_COOLDOWN_HUD_DASH_FILL_COLOR
    )
    playerDashCooldownBarFrame = dashBar.frame
    playerDashCooldownBarFill = dashBar.fill

    let specialBar = create_cooldown_bar(
        playerCooldownHudRoot,
        "player_aoe_cooldown_bar",
        cooldown_bar_row_pos(specialRowY),
        PLAYER_COOLDOWN_HUD_AOE_FILL_COLOR
    )
    playerAoeCooldownBarFrame = specialBar.frame
    playerAoeCooldownBarFill = specialBar.fill

    sync_player_cooldown_bars()
}


def public sync_player_cooldown_bars() {
    sync_cooldown_bar_labels()
    sync_cooldown_bar_positions()
    sync_cooldown_bar_fill(playerDashCooldownBarFill, playerDashCooldownRemaining, player_dash_cooldown(), playerDashing)
    sync_cooldown_bar_fill(playerAoeCooldownBarFill, playerSpecialCooldownRemaining, player_special_cooldown(), playerSpecialActive)
}

