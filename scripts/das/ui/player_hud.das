require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/ui/hud_bottom_bar public
require scripts/das/ui/hud_health public
require scripts/das/ui/hud_weapons public
require scripts/das/ui/hud_exp public
require scripts/das/ui/hud_character public
require scripts/das/ui/hud_wave public
require scripts/das/world/prefab_texture_hydrate

module player_hud public

def public load_player_hud_textures() {
    playerHealthTexture = request_texture_cached(PLAYER_HEALTH_SPRITE_PATH)
    playerSwordTexture = request_texture_cached(PLAYER_WEAPON_SWORD_PATH)
    playerBowTexture = request_texture_cached(PLAYER_WEAPON_BOW_PATH)
    playerUiBarTexture = request_texture_cached(PLAYER_UI_BAR_SPRITE_PATH)
    playerExpUiBarTexture = request_texture_cached(PLAYER_EXP_UI_BAR_SPRITE_PATH)
    waveTitleBoxTexture = request_texture_cached(WAVE_TITLE_BOX_PATH)
    playerCharacterPortraitTexture = request_texture_cached(PLAYER_CHARACTER_PORTRAIT_PATH)
    playerCharacterPortraitBoxTexture = request_texture_cached(PLAYER_CHARACTER_PORTRAIT_BOX_PATH)
    playerBottomBarTexture = request_texture_cached(PLAYER_BOTTOM_BAR_PATH)
}


def public queue_player_hud_texture_paths() {
    queue_texture_path(PLAYER_HEALTH_SPRITE_PATH)
    queue_texture_path(PLAYER_WEAPON_SWORD_PATH)
    queue_texture_path(PLAYER_WEAPON_BOW_PATH)
    queue_texture_path(PLAYER_UI_BAR_SPRITE_PATH)
    queue_texture_path(PLAYER_EXP_UI_BAR_SPRITE_PATH)
    queue_texture_path(WAVE_TITLE_BOX_PATH)
    queue_texture_path(PLAYER_CHARACTER_PORTRAIT_PATH)
    queue_texture_path(PLAYER_CHARACTER_PORTRAIT_BOX_PATH)
    queue_texture_path(PLAYER_BOTTOM_BAR_PATH)
}


def public init_player_hud() {
    init_player_hud_step(0)
    init_player_hud_step(1)
    init_player_hud_step(2)
}


def public init_player_hud_step(step : int) {
    if (step == 0) {
        init_player_bottom_bar_hud()
        init_player_health_hud()
    } elif (step == 1) {
        init_player_weapon_hud()
        init_player_character_hud()
    } elif (step == 2) {
        init_player_cooldown_hud()
        init_player_exp_hud()
        init_wave_title_hud()
        layout_player_bottom_huds()
    }
}


def public layout_player_bottom_huds() {
    apply_player_bottom_bar_hud_anchor()
    sync_player_character_hud_layout()
    sync_player_exp_bar_layout()
    sync_cooldown_bar_labels()
    sync_cooldown_bar_positions()
    apply_player_health_hud_anchor()
    sync_player_weapon_hud_layout()
}


def public init_player_character_hud() {
    if (!player_bottom_bar_hud_parent().isAlive) {
        return
    }
    let boxSize = player_character_box_hud_size()
    let portraitSize = player_character_portrait_hud_size()
    let portraitPos = player_character_portrait_pos()

    playerCharacterHudRoot = create_node(NodeData(name = "player_character_hud", parent = player_bottom_bar_hud_parent()))
    add_component(playerCharacterHudRoot, new UIAnchor(
        anchorMin = BOTTOM_LEFT_ANCHOR,
        anchorMax = BOTTOM_LEFT_ANCHOR,
        left = PLAYER_CHARACTER_PORTRAIT_HUD_LEFT_MARGIN,
        top = -PLAYER_CHARACTER_PORTRAIT_HUD_BOTTOM_MARGIN
    ))
    get_component(playerCharacterHudRoot) $(var hudFrame : UIFrame?) {
        if (hudFrame != null) {
            hudFrame.pivot = float2(0.0, 1.0)
        }
    }

    playerCharacterBoxNode = create_node(NodeData(name = "player_character_box", parent = playerCharacterHudRoot))
    add_component(playerCharacterBoxNode, new UIImage(
        textureId = playerCharacterPortraitBoxTexture,
        size = boxSize,
        pivot = float2(0.0, 1.0)
    ))

    playerCharacterPortraitNode = create_node(NodeData(name = "player_character_portrait", parent = playerCharacterHudRoot))
    add_component(playerCharacterPortraitNode, new UIImage(
        textureId = playerCharacterPortraitTexture,
        size = portraitSize,
        pivot = float2(0.0, 1.0),
        localPosition2D = portraitPos
    ))

    playerCharacterNameTextNode = create_node(NodeData(name = "player_character_name", parent = playerCharacterHudRoot))
    add_component(playerCharacterNameTextNode, new UIText(
        text = PLAYER_CHARACTER_NAME,
        fontSize = PLAYER_CHARACTER_NAME_FONT_SIZE,
        color = PLAYER_CHARACTER_NAME_COLOR,
        pivot = float2(0.0, 0.5),
        horAlignment = TextHorAlignment.Left,
        wordWrapping = false,
        localPosition2D = float2(player_character_text_x(), player_character_name_y())
    ))
    playerCharacterNameTextNode?.UIText.fontScaling = false
    playerCharacterNameTextNode?.UIText.autoResizeFrame = true

    playerCharacterLevelTextNode = create_node(NodeData(name = "player_character_level", parent = playerCharacterHudRoot))
    add_component(playerCharacterLevelTextNode, new UIText(
        text = player_character_level_label(),
        fontSize = PLAYER_CHARACTER_LEVEL_FONT_SIZE,
        color = PLAYER_CHARACTER_LEVEL_COLOR,
        pivot = float2(0.0, 0.5),
        horAlignment = TextHorAlignment.Left,
        wordWrapping = false,
        localPosition2D = float2(player_character_text_x(), player_character_level_y())
    ))
    playerCharacterLevelTextNode?.UIText.fontScaling = false
    playerCharacterLevelTextNode?.UIText.autoResizeFrame = true
    playerCharacterHudLastLevel = playerLevel
}


def public notify_player_health_damage() {
    playerHealthShakeT = 0.0
    playerHealthLastFrame = -1
    sync_player_health_sprite()
}


def tick_player_health_shake(dt : float) {
    if (!playerHealthHudImage.isAlive) {
        return
    }
    if (playerHealthShakeT < 0.0) {
        return
    }
    if (playerHealthShakeT >= PLAYER_HEALTH_SHAKE_DURATION) {
        playerHealthShakeT = -1.0
        playerHealthHudImage?.UIImage.localPosition2D = float2(0.0, 0.0)
        return
    }
    playerHealthShakeT += dt
    let decay = 1.0 - playerHealthShakeT / PLAYER_HEALTH_SHAKE_DURATION
    let amp = PLAYER_HEALTH_SHAKE_AMPLITUDE * decay
    let freq = 32.0
    let offsetX = sin(playerHealthShakeT * freq * PI * 2.0) * amp
    let offsetY = cos(playerHealthShakeT * freq * 1.4 * PI * 2.0) * amp * 0.5
    playerHealthHudImage?.UIImage.localPosition2D = float2(offsetX, offsetY)
}


def public update_player_health_hud() {
    sync_player_health_sprite()
    sync_player_cooldown_bars()
    sync_player_exp_bar()
    sync_player_exp_bar_label()
    sync_player_weapon_sprite()
    sync_player_character_level_text()
    sync_player_exp_bar_layout()
    tick_player_health_shake(get_delta_time())
}
