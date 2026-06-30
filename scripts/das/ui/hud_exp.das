require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/ui/hud_bottom_bar
require scripts/das/ui/hud_character public

module hud_exp public

def exp_ui_bar_fill_width_px() : float {
    return PLAYER_EXP_UI_BAR_FILL_MAX_X - PLAYER_EXP_UI_BAR_FILL_MIN_X + 1.0
}


def exp_ui_bar_fill_height_px() : float {
    return PLAYER_EXP_UI_BAR_FILL_MAX_Y - PLAYER_EXP_UI_BAR_FILL_MIN_Y + 1.0
}


def exp_ui_bar_hud_scale() : float2 {
    return float2(
        PLAYER_EXP_UI_BAR_HUD_WIDTH / PLAYER_EXP_UI_BAR_TEX_WIDTH,
        PLAYER_EXP_UI_BAR_HUD_HEIGHT / PLAYER_EXP_UI_BAR_TEX_HEIGHT
    )
}


def exp_ui_bar_fill_display_size() : float2 {
    let scale = exp_ui_bar_hud_scale()
    return float2(exp_ui_bar_fill_width_px() * scale.x, exp_ui_bar_fill_height_px() * scale.y)
}


def exp_ui_bar_fill_top_left_offset() : float2 {
    let scale = exp_ui_bar_hud_scale()
    let x = -PLAYER_EXP_UI_BAR_HUD_WIDTH * 0.5 + PLAYER_EXP_UI_BAR_FILL_MIN_X * scale.x
    let y = -PLAYER_EXP_UI_BAR_HUD_HEIGHT * 0.5 + PLAYER_EXP_UI_BAR_FILL_MIN_Y * scale.y
    return float2(x, y)
}


def apply_exp_bar_fill_layout(fillNode : NodeId; barPos : float2) {
    if (!fillNode.isAlive) {
        return
    }
    let fillPos = barPos + exp_ui_bar_fill_top_left_offset()
    fillNode?.UIImage.localPosition2D = fillPos
    get_component(fillNode) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.pivot = float2(0.0, 0.0)
            frame.localPosition2D = fillPos
        }
    }
}


def player_exp_bar_center_x() : float {
    var levelTextW = PLAYER_CHARACTER_LEVEL_FONT_SIZE * 4.0
    if (playerCharacterLevelTextNode.isAlive) {
        let w = playerCharacterLevelTextNode?.UIFrame.size.x
        if (w > 0.0) {
            levelTextW = w
        }
    }
    return player_character_text_x() + levelTextW + PLAYER_EXP_UI_BAR_HUD_LEVEL_GAP + PLAYER_EXP_UI_BAR_HUD_WIDTH * 0.5
}


def player_exp_bar_pos() : float2 {
    return float2(player_exp_bar_center_x(), player_character_level_y())
}


def player_exp_bar_label() : string {
    let needed = exp_required_for_level(playerLevel)
    return "Experience {playerExp}/{needed} XP"
}


def player_exp_bar_label_pos() : float2 {
    let barPos = player_exp_bar_pos()
    let labelY = barPos.y - PLAYER_EXP_UI_BAR_HUD_HEIGHT * 0.5 - PLAYER_EXP_UI_BAR_LABEL_GAP - PLAYER_EXP_UI_BAR_LABEL_FONT_SIZE * 0.5 + PLAYER_EXP_UI_BAR_LABEL_DOWN_OFFSET
    return float2(barPos.x, labelY)
}


def public sync_player_exp_bar_layout() {
    if (!playerExpBarFrame.isAlive) {
        return
    }
    let barPos = player_exp_bar_pos()
    playerExpBarFrame?.UIImage.localPosition2D = barPos
    apply_exp_bar_fill_layout(playerExpBarFill, barPos)
    sync_player_exp_bar_label_layout()
    sync_player_exp_bar()
}


def sync_player_exp_bar_label_layout() {
    if (!playerExpBarLabelNode.isAlive) {
        return
    }
    playerExpBarLabelNode?.UIText.localPosition2D = player_exp_bar_label_pos()
}


def public sync_player_exp_bar_label() {
    if (!playerExpBarLabelNode.isAlive) {
        return
    }
    let labelText = player_exp_bar_label()
    if (labelText != playerExpBarLastLabel) {
        playerExpBarLastLabel = labelText
        playerExpBarLabelNode?.UIText.text = labelText
    }
}


def exp_bar_progress() : float {
    let needed = exp_required_for_level(playerLevel)
    if (needed <= 0) {
        return 1.0
    }
    return clamp(float(playerExp) / float(needed), 0.0, 1.0)
}


def public sync_player_exp_bar() {
    if (!playerExpBarFill.isAlive) {
        return
    }
    if (playerLevel != playerExpBarLastLevel) {
        playerExpBarLastLevel = playerLevel
        playerExpBarLastProgress = -1.0
    }
    let progress = exp_bar_progress()
    if (progress == playerExpBarLastProgress) {
        return
    }
    playerExpBarLastProgress = progress
    let maxSize = exp_ui_bar_fill_display_size()
    let width = max(0.0, maxSize.x * progress)
    let fillSize = float2(width, maxSize.y)
    playerExpBarFill?.UIImage.size = fillSize
    get_component(playerExpBarFill) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.size = fillSize
        }
    }
}


def create_exp_bar(parent : NodeId; name : string; barPos : float2) : NodeId {
    let barRoot = create_node(NodeData(name = name, parent = parent))

    let frameNode = create_node(NodeData(name = "{name}_frame", parent = barRoot))
    playerExpBarFrame = frameNode
    add_component(frameNode, new UIImage(
        textureId = playerExpUiBarTexture,
        size = float2(PLAYER_EXP_UI_BAR_HUD_WIDTH, PLAYER_EXP_UI_BAR_HUD_HEIGHT),
        pivot = float2(0.5, 0.5),
        localPosition2D = barPos
    ))

    let fillNode = create_node(NodeData(name = "{name}_fill", parent = barRoot))
    add_component(fillNode, new UIImage(
        color = PLAYER_EXP_UI_BAR_FILL_COLOR,
        pivot = float2(0.0, 0.0)
    ))
    apply_exp_bar_fill_layout(fillNode, barPos)
    return fillNode
}


def public init_player_exp_hud() {
    if (!playerCharacterHudRoot.isAlive) {
        return
    }

    playerExpHudRoot = create_node(NodeData(name = "player_exp_hud", parent = playerCharacterHudRoot))

    playerExpBarLabelNode = create_node(NodeData(name = "player_exp_bar_label", parent = playerExpHudRoot))
    add_component(playerExpBarLabelNode, new UIText(
        text = player_exp_bar_label(),
        fontSize = PLAYER_EXP_UI_BAR_LABEL_FONT_SIZE,
        color = PLAYER_EXP_UI_BAR_LABEL_COLOR,
        pivot = float2(0.5, 0.5),
        horAlignment = TextHorAlignment.Center,
        wordWrapping = false,
        localPosition2D = player_exp_bar_label_pos()
    ))
    playerExpBarLabelNode?.UIText.fontScaling = false
    playerExpBarLabelNode?.UIText.autoResizeFrame = true
    playerExpBarLastLabel = player_exp_bar_label()

    playerExpBarFill = create_exp_bar(playerExpHudRoot, "player_exp_bar", player_exp_bar_pos())
    playerExpBarLastProgress = -1.0
    playerExpBarLastLevel = playerLevel
    sync_player_exp_bar()
}

