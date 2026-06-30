require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/ui/hud_bottom_bar

module hud_wave public

def wave_title_hud_display_size() : float2 {
    return float2(WAVE_TITLE_HUD_WIDTH, WAVE_TITLE_HUD_HEIGHT)
}


def public init_wave_title_hud() {
    if (!enemyHealthCanvas.isAlive) {
        return
    }
    let displaySize = wave_title_hud_display_size()

    waveTitleHudRoot = create_node(NodeData(name = "wave_title_hud", parent = enemyHealthCanvas))
    add_component(waveTitleHudRoot, new UIAnchor(
        anchorMin = TOP_CENTER_ANCHOR,
        anchorMax = TOP_CENTER_ANCHOR,
        top = WAVE_TITLE_HUD_TOP_MARGIN
    ))

    waveTitleBoxImage = create_node(NodeData(name = "wave_title_box", parent = waveTitleHudRoot))
    add_component(waveTitleBoxImage, new UIImage(
        textureId = waveTitleBoxTexture,
        size = displaySize,
        pivot = float2(0.5, 0.0)
    ))

    waveTitleTextNode = create_node(NodeData(name = "wave_title_text", parent = waveTitleHudRoot))
    add_component(waveTitleTextNode, new UIText(
        text = wave_title_hud_label(),
        fontSize = WAVE_TITLE_HUD_FONT_SIZE,
        color = WAVE_TITLE_HUD_TEXT_COLOR,
        pivot = float2(0.5, 0.5),
        horAlignment = TextHorAlignment.Center,
        vertAlignment = TextVertAlignment.Middle,
        wordWrapping = false,
        localPosition2D = float2(0.0, displaySize.y * 0.5)
    ))
    waveTitleTextNode?.UIText.fontScaling = false
    waveTitleTextNode?.UIText.autoResizeFrame = true
    waveTitleTextNode?.UIText.size = float2(0.0, 0.0)
}

