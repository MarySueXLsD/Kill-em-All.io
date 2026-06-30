require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state

module hud_bottom_bar public


struct CooldownLabelPair {
    prefix : NodeId
    level : NodeId
}


struct CooldownBar {
    frame : NodeId
    fill : NodeId
}


var public playerHealthTexture : TextureId
var public playerSwordTexture : TextureId
var public playerBowTexture : TextureId
var public playerUiBarTexture : TextureId
var public playerExpUiBarTexture : TextureId
var public waveTitleBoxTexture : TextureId
var public playerCharacterPortraitTexture : TextureId
var public playerCharacterPortraitBoxTexture : TextureId
var public playerBottomBarTexture : TextureId
var public playerBottomBarHudRoot : NodeId
var private playerBottomBarBackgroundRoot : NodeId
var private playerBottomBarTileSeq : int = 0
var public playerCharacterHudRoot : NodeId
var public playerCharacterBoxNode : NodeId
var public playerCharacterPortraitNode : NodeId
var public playerCharacterNameTextNode : NodeId
var public playerCharacterLevelTextNode : NodeId
var public playerCharacterHudLastLevel : int = -1
var public playerCooldownHudRoot : NodeId
var public playerAoeCooldownBarFill : NodeId
var public playerAoeCooldownBarFrame : NodeId
var public playerDashCooldownBarFill : NodeId
var public playerDashCooldownBarFrame : NodeId
var public playerSpecialCooldownLabelPrefix : NodeId
var public playerSpecialCooldownLabelLevel : NodeId
var public playerDashCooldownLabelPrefix : NodeId
var public playerDashCooldownLabelLevel : NodeId
var public playerSpecialCooldownLabelLastLevel : int = -1
var public playerDashCooldownLabelLastLevel : int = -1
var public playerExpHudRoot : NodeId
var public playerExpBarFill : NodeId
var public playerExpBarFrame : NodeId
var public playerExpBarLabelNode : NodeId
var public playerExpBarLastProgress : float = -1.0
var public playerExpBarLastLevel : int = -1
var public playerExpBarLastLabel : string = ""
var public playerWeaponHudRoot : NodeId
var public playerWeaponHudImage : NodeId
var public playerWeaponStatsTextNode : NodeId
var public waveTitleHudRoot : NodeId
var public waveTitleBoxImage : NodeId
var public waveTitleTextNode : NodeId
var public playerWeaponLastShown : int = -1



def player_bottom_bar_hud_parent() : NodeId {
    if (playerBottomBarHudRoot.isAlive) {
        return playerBottomBarHudRoot
    }
    return enemyHealthCanvas
}


def player_bottom_bar_tile_scale() : float {
    return PLAYER_BOTTOM_BAR_TILE_SCALE
}


def player_bottom_bar_slice_uv(minX, minY, maxX, maxY : float) : float4 {
    let tex = PLAYER_BOTTOM_BAR_TEX_SIZE
    return float4(
        minX / tex,
        (tex - maxY) / tex,
        (maxX - minX) / tex,
        (maxY - minY) / tex
    )
}


def player_bottom_bar_top_band_height() : float {
    return PLAYER_BOTTOM_BAR_SLICE_TOP * player_bottom_bar_tile_scale()
}


def player_bottom_bar_bottom_band_height() : float {
    return (PLAYER_BOTTOM_BAR_TEX_SIZE - PLAYER_BOTTOM_BAR_SLICE_BOTTOM) * player_bottom_bar_tile_scale()
}


def player_bottom_bar_middle_band_height() : float {
    return (PLAYER_BOTTOM_BAR_SLICE_BOTTOM - PLAYER_BOTTOM_BAR_SLICE_TOP) * player_bottom_bar_tile_scale()
}


def player_bottom_bar_tiled_visual_height(desiredHeight : float) : float {
    let topH = player_bottom_bar_top_band_height()
    let bottomH = player_bottom_bar_bottom_band_height()
    let midH = player_bottom_bar_middle_band_height()
    if (midH <= 0.0) {
        return topH + bottomH
    }
    let inner = max(0.0, desiredHeight - topH - bottomH)
    let rows = max(1, int(ceil(inner / midH)))
    return topH + bottomH + float(rows) * midH
}


def player_bottom_bar_visual_height() : float {
    return player_bottom_bar_tiled_visual_height(PLAYER_BOTTOM_BAR_HUD_TARGET_HEIGHT)
}


def player_bottom_bar_hud_height() : float {
    return max(PLAYER_BOTTOM_BAR_HUD_TARGET_HEIGHT, player_bottom_bar_visual_height())
}


def player_bottom_bar_left_cap_width() : float {
    return PLAYER_BOTTOM_BAR_SLICE_LEFT * player_bottom_bar_tile_scale()
}


def player_bottom_bar_right_cap_width() : float {
    return (PLAYER_BOTTOM_BAR_TEX_SIZE - PLAYER_BOTTOM_BAR_SLICE_RIGHT) * player_bottom_bar_tile_scale()
}


def player_bottom_bar_middle_tile_width() : float {
    return (PLAYER_BOTTOM_BAR_SLICE_RIGHT - PLAYER_BOTTOM_BAR_SLICE_LEFT) * player_bottom_bar_tile_scale()
}


def player_bottom_bar_middle_end_x(displayW : float) : float {
    return displayW - player_bottom_bar_right_cap_width()
}


def apply_player_bottom_bar_background_layout(displayW : float) {
    if (!playerBottomBarBackgroundRoot.isAlive) {
        return
    }
    let visualH = player_bottom_bar_visual_height()
    get_component(playerBottomBarBackgroundRoot) $(var anchor : UIAnchor?) {
        if (anchor != null) {
            anchor.left = 0.0
            anchor.top = 0.0
        }
    }
    get_component(playerBottomBarBackgroundRoot) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.pivot = float2(0.0, 1.0)
            frame.size = float2(displayW, visualH)
        }
    }
}


def add_player_bottom_bar_tile(parent : NodeId; uv : float4; pos, tileSize : float2) {
    playerBottomBarTileSeq++
    let node = create_node(NodeData(name = "player_bottom_bar_tile_{playerBottomBarTileSeq}", parent = parent))
    add_component(node, new UIImage(
        textureId = playerBottomBarTexture,
        size = tileSize,
        uvRegion = uv,
        pivot = float2(0.0, 0.0),
        localPosition2D = pos
    ))
}


def clear_player_bottom_bar_tiles() {
    if (!playerBottomBarBackgroundRoot.isAlive) {
        return
    }
    playerBottomBarTileSeq = 0
    var inscope children = playerBottomBarBackgroundRoot.get_children()
    for (child in children) {
        remove_node(child)
    }
}


def player_bottom_bar_fill_horizontal_tiles(
    parent : NodeId;
    y, bandH : float;
    uvMinY, uvMaxY : float;
    startX, endX : float;
    uvMinX, uvMaxX : float
) {
    let midW = player_bottom_bar_middle_tile_width()
    var x = startX
    while (x < endX - 0.001) {
        let w = min(midW, endX - x)
        add_player_bottom_bar_tile(
            parent,
            player_bottom_bar_slice_uv(uvMinX, uvMinY, uvMaxX, uvMaxY),
            float2(x, y),
            float2(w, bandH)
        )
        x += w
    }
}


def build_player_bottom_bar_tiles(displayW : float) {
    if (!playerBottomBarBackgroundRoot.isAlive) {
        return
    }
    clear_player_bottom_bar_tiles()

    let tex = PLAYER_BOTTOM_BAR_TEX_SIZE
    let visualH = player_bottom_bar_visual_height()
    apply_player_bottom_bar_background_layout(displayW)

    let topH = player_bottom_bar_top_band_height()
    let bottomH = player_bottom_bar_bottom_band_height()
    let midH = player_bottom_bar_middle_band_height()
    let leftW = player_bottom_bar_left_cap_width()
    let rightW = player_bottom_bar_right_cap_width()
    let midEndX = player_bottom_bar_middle_end_x(displayW)
    let bottomY = visualH - bottomH

    let innerH = max(0.0, visualH - topH - bottomH)
    let centerRows = max(1, int(ceil(innerH / midH)))

    add_player_bottom_bar_tile(
        playerBottomBarBackgroundRoot,
        player_bottom_bar_slice_uv(0.0, 0.0, PLAYER_BOTTOM_BAR_SLICE_LEFT, PLAYER_BOTTOM_BAR_SLICE_TOP),
        float2(0.0, 0.0),
        float2(leftW, topH)
    )
    player_bottom_bar_fill_horizontal_tiles(
        playerBottomBarBackgroundRoot,
        0.0, topH,
        0.0, PLAYER_BOTTOM_BAR_SLICE_TOP,
        leftW, midEndX,
        PLAYER_BOTTOM_BAR_SLICE_LEFT, PLAYER_BOTTOM_BAR_SLICE_RIGHT
    )
    add_player_bottom_bar_tile(
        playerBottomBarBackgroundRoot,
        player_bottom_bar_slice_uv(PLAYER_BOTTOM_BAR_SLICE_RIGHT, 0.0, tex, PLAYER_BOTTOM_BAR_SLICE_TOP),
        float2(midEndX, 0.0),
        float2(rightW, topH)
    )

    for (row in range(centerRows)) {
        let y = topH + float(row) * midH
        add_player_bottom_bar_tile(
            playerBottomBarBackgroundRoot,
            player_bottom_bar_slice_uv(0.0, PLAYER_BOTTOM_BAR_SLICE_TOP, PLAYER_BOTTOM_BAR_SLICE_LEFT, PLAYER_BOTTOM_BAR_SLICE_BOTTOM),
            float2(0.0, y),
            float2(leftW, midH)
        )
        player_bottom_bar_fill_horizontal_tiles(
            playerBottomBarBackgroundRoot,
            y, midH,
            PLAYER_BOTTOM_BAR_SLICE_TOP, PLAYER_BOTTOM_BAR_SLICE_BOTTOM,
            leftW, midEndX,
            PLAYER_BOTTOM_BAR_SLICE_LEFT, PLAYER_BOTTOM_BAR_SLICE_RIGHT
        )
        add_player_bottom_bar_tile(
            playerBottomBarBackgroundRoot,
            player_bottom_bar_slice_uv(PLAYER_BOTTOM_BAR_SLICE_RIGHT, PLAYER_BOTTOM_BAR_SLICE_TOP, tex, PLAYER_BOTTOM_BAR_SLICE_BOTTOM),
            float2(midEndX, y),
            float2(rightW, midH)
        )
    }

    add_player_bottom_bar_tile(
        playerBottomBarBackgroundRoot,
        player_bottom_bar_slice_uv(0.0, PLAYER_BOTTOM_BAR_SLICE_BOTTOM, PLAYER_BOTTOM_BAR_SLICE_LEFT, tex),
        float2(0.0, bottomY),
        float2(leftW, bottomH)
    )
    player_bottom_bar_fill_horizontal_tiles(
        playerBottomBarBackgroundRoot,
        bottomY, bottomH,
        PLAYER_BOTTOM_BAR_SLICE_BOTTOM, tex,
        leftW, midEndX,
        PLAYER_BOTTOM_BAR_SLICE_LEFT, PLAYER_BOTTOM_BAR_SLICE_RIGHT
    )
    add_player_bottom_bar_tile(
        playerBottomBarBackgroundRoot,
        player_bottom_bar_slice_uv(PLAYER_BOTTOM_BAR_SLICE_RIGHT, PLAYER_BOTTOM_BAR_SLICE_BOTTOM, tex, tex),
        float2(midEndX, bottomY),
        float2(rightW, bottomH)
    )
}


def public apply_player_bottom_bar_hud_anchor() {
    if (!playerBottomBarHudRoot.isAlive) {
        return
    }
    let res = get_resolution()
    let barSize = float2(float(res.x), player_bottom_bar_hud_height())
    get_component(playerBottomBarHudRoot) $(var anchor : UIAnchor?) {
        if (anchor != null) {
            anchor.left = 0.0
            anchor.top = 0.0
        }
    }
    get_component(playerBottomBarHudRoot) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.size = barSize
        }
    }
    build_player_bottom_bar_tiles(barSize.x)
}


def public init_player_bottom_bar_hud() {
    if (!enemyHealthCanvas.isAlive) {
        return
    }
    let res = get_resolution()
    let barSize = float2(float(res.x), player_bottom_bar_hud_height())

    playerBottomBarHudRoot = create_node(NodeData(name = "player_bottom_bar_hud", parent = enemyHealthCanvas))
    add_component(playerBottomBarHudRoot, new UIAnchor(
        anchorMin = BOTTOM_LEFT_ANCHOR,
        anchorMax = BOTTOM_LEFT_ANCHOR,
        left = 0.0,
        top = 0.0
    ))
    get_component(playerBottomBarHudRoot) $(var hudFrame : UIFrame?) {
        if (hudFrame != null) {
            hudFrame.pivot = float2(0.0, 1.0)
            hudFrame.size = barSize
        }
    }

    playerBottomBarBackgroundRoot = create_node(NodeData(name = "player_bottom_bar_background", parent = playerBottomBarHudRoot))
    add_component(playerBottomBarBackgroundRoot, new UIAnchor(
        anchorMin = BOTTOM_LEFT_ANCHOR,
        anchorMax = BOTTOM_LEFT_ANCHOR,
        left = 0.0,
        top = 0.0
    ))
    get_component(playerBottomBarBackgroundRoot) $(var bgFrame : UIFrame?) {
        if (bgFrame != null) {
            bgFrame.pivot = float2(0.0, 1.0)
        }
    }
    build_player_bottom_bar_tiles(barSize.x)
}

