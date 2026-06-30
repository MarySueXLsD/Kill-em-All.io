require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/ui/hud_bottom_bar

module hud_character public

def public player_character_portrait_box_hud_size() : float {
    let barH = player_bottom_bar_visual_height()
    return max(0.0, barH - PLAYER_CHARACTER_PORTRAIT_HUD_TOP_MARGIN - PLAYER_CHARACTER_PORTRAIT_HUD_BOTTOM_MARGIN)
}


def public player_character_box_hud_size() : float2 {
    let size = player_character_portrait_box_hud_size()
    return float2(size, size)
}


def player_character_portrait_inset_hud() : float {
    return PLAYER_CHARACTER_PORTRAIT_BOX_INSET_PX * (player_character_portrait_box_hud_size() / PLAYER_CHARACTER_PORTRAIT_BOX_TEX_SIZE)
}


def public player_character_portrait_hud_size() : float2 {
    let innerTex = PLAYER_CHARACTER_PORTRAIT_BOX_TEX_SIZE - PLAYER_CHARACTER_PORTRAIT_BOX_INSET_PX * 2.0
    let scale = player_character_portrait_box_hud_size() / PLAYER_CHARACTER_PORTRAIT_BOX_TEX_SIZE
    let inner = innerTex * scale
    return float2(inner, inner)
}


def public player_character_portrait_pos() : float2 {
    let inset = player_character_portrait_inset_hud()
    return float2(inset, -inset)
}


def public player_character_level_label() : string {
    return "Level {playerLevel}"
}


def player_character_info_top_y() : float {
    let barH = player_bottom_bar_visual_height()
    let topInset = PLAYER_CHARACTER_PORTRAIT_HUD_BOTTOM_MARGIN + player_bottom_bar_top_band_height() + PLAYER_CHARACTER_TEXT_TOP_CLEARANCE + PLAYER_CHARACTER_NAME_FONT_SIZE * 0.5
    return -barH + topInset
}


def public player_character_name_y() : float {
    return player_character_info_top_y()
}


def public player_character_level_y() : float {
    return player_character_name_y() + PLAYER_CHARACTER_NAME_LEVEL_GAP
}


def public player_cooldown_special_row_y() : float {
    return player_character_level_y() + PLAYER_CHARACTER_LEVEL_FONT_SIZE * 0.5 + PLAYER_CHARACTER_LEVEL_ABILITY_GAP + PLAYER_UI_BAR_HUD_HEIGHT
}


def public player_cooldown_dash_row_y() : float {
    return player_cooldown_special_row_y() + PLAYER_COOLDOWN_HUD_BAR_SPACING + PLAYER_UI_BAR_HUD_HEIGHT
}


def public player_character_text_x() : float {
    return player_character_portrait_box_hud_size() + PLAYER_CHARACTER_PORTRAIT_TEXT_GAP
}


def public sync_player_character_level_text() {
    if (!playerCharacterLevelTextNode.isAlive) {
        return
    }
    if (playerLevel == playerCharacterHudLastLevel) {
        return
    }
    playerCharacterHudLastLevel = playerLevel
    playerCharacterLevelTextNode?.UIText.text = player_character_level_label()
}


def public sync_player_character_hud_layout() {
    if (!playerCharacterHudRoot.isAlive) {
        return
    }
    get_component(playerCharacterHudRoot) $(var anchor : UIAnchor?) {
        if (anchor != null) {
            anchor.left = PLAYER_CHARACTER_PORTRAIT_HUD_LEFT_MARGIN
            anchor.top = -PLAYER_CHARACTER_PORTRAIT_HUD_BOTTOM_MARGIN
        }
    }
    let boxSize = player_character_box_hud_size()
    let portraitSize = player_character_portrait_hud_size()
    let portraitPos = player_character_portrait_pos()
    if (playerCharacterBoxNode.isAlive) {
        playerCharacterBoxNode?.UIImage.size = boxSize
    }
    if (playerCharacterPortraitNode.isAlive) {
        playerCharacterPortraitNode?.UIImage.size = portraitSize
        playerCharacterPortraitNode?.UIImage.localPosition2D = portraitPos
    }
    if (playerCharacterNameTextNode.isAlive) {
        playerCharacterNameTextNode?.UIText.localPosition2D = float2(player_character_text_x(), player_character_name_y())
    }
    if (playerCharacterLevelTextNode.isAlive) {
        playerCharacterLevelTextNode?.UIText.localPosition2D = float2(player_character_text_x(), player_character_level_y())
    }
}

