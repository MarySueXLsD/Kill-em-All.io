require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/ui/hud_bottom_bar
require scripts/das/ui/hud_character public

module hud_health public

var public playerHealthHudRoot : NodeId
var public playerHealthHudImage : NodeId
var public playerHealthLastFrame : int = -1
var public playerHealthShakeT : float = -1.0

def player_weapon_texture() : TextureId {
    if (playerWeapon == PlayerWeapon.Bow) {
        return playerBowTexture
    }
    return playerSwordTexture
}


def player_health_frame_index(hp : int) : int {
    if (hp <= 0) {
        return PLAYER_HEALTH_FRAME_COUNT - 1
    }
    let segments = min(
        PLAYER_HEALTH_SEGMENT_COUNT,
        int(ceil(float(hp) / float(player_max_hp()) * float(PLAYER_HEALTH_SEGMENT_COUNT)))
    )
    return PLAYER_HEALTH_SEGMENT_COUNT - segments
}


def player_health_uv(frameIndex : int) : float4 {
    return uv_rect_from_tile(frameIndex, 0, PLAYER_HEALTH_FRAME_COUNT, 1)
}


def public sync_player_health_sprite() {
    if (!playerHealthHudImage.isAlive) {
        return
    }
    let frame = player_health_frame_index(playerHp)
    if (frame == playerHealthLastFrame) {
        return
    }
    playerHealthLastFrame = frame
    playerHealthHudImage?.UIImage.uvRegion = player_health_uv(frame)
}


def player_health_hud_left_offset() : float {
    let res = get_resolution()
    let halfW = float(res.x) * 0.5
    let portraitRight = PLAYER_CHARACTER_PORTRAIT_HUD_LEFT_MARGIN + player_character_portrait_box_hud_size()
    let heartHalf = PLAYER_HEALTH_HUD_SIZE * 0.5
    return max(0.0, portraitRight + PLAYER_HEALTH_HUD_GAP_AFTER_PORTRAIT + heartHalf - halfW)
}


def public apply_player_health_hud_anchor() {
    if (!playerHealthHudRoot.isAlive) {
        return
    }
    get_component(playerHealthHudRoot) $(var anchor : UIAnchor?) {
        if (anchor != null) {
            anchor.left = player_health_hud_left_offset()
        }
    }
}


def public init_player_health_hud() {
    if (!enemyHealthCanvas.isAlive) {
        return
    }
    let displaySize = float2(PLAYER_HEALTH_HUD_SIZE, PLAYER_HEALTH_HUD_SIZE)

    playerHealthHudRoot = create_node(NodeData(name = "player_health_hud", parent = player_bottom_bar_hud_parent()))
    add_component(playerHealthHudRoot, new UIAnchor(
        anchorMin = BOTTOM_CENTER_ANCHOR,
        anchorMax = BOTTOM_CENTER_ANCHOR,
        top = -PLAYER_HEALTH_HUD_BOTTOM_MARGIN,
        left = player_health_hud_left_offset()
    ))

    playerHealthHudImage = create_node(NodeData(name = "player_health_icon", parent = playerHealthHudRoot))
    add_component(playerHealthHudImage, new UIImage(
        textureId = playerHealthTexture,
        size = displaySize,
        uvRegion = player_health_uv(0),
        pivot = float2(0.5, 1.0)
    ))

    playerHealthLastFrame = -1
    sync_player_health_sprite()
}

