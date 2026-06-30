require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
require scripts/das/ui/upgrade_defs
require scripts/das/world/prefab_texture_hydrate

module upgrade_picker public

def public load_upgrade_picker_textures() {
    upgradeBoxTexture = request_texture_cached(UPGRADE_BOX_PATH)
}


def public queue_upgrade_picker_texture_paths() {
    queue_texture_path(UPGRADE_BOX_PATH)
}


def upgrade_picker_canvas_size() : float2 {
    let res = get_resolution()
    return float2(float(res.x), float(res.y))
}



def upgrade_cards_row_width() : float {
    let cardW = UPGRADE_BOX_HUD_WIDTH
    let spacing = UPGRADE_PICKER_CARD_SPACING
    return float(UPGRADE_CHOICES_SHOWN) * cardW + float(UPGRADE_CHOICES_SHOWN - 1) * spacing
}


def upgrade_header_height() : float {
    return UPGRADE_PICKER_TITLE_FONT_SIZE + 8.0
}


def upgrade_cards_row_y() : float {
    return upgrade_header_height() + UPGRADE_PICKER_HEADER_GAP
}


def upgrade_picker_content_size() : float2 {
    return float2(upgrade_cards_row_width(), upgrade_cards_row_y() + UPGRADE_BOX_HUD_HEIGHT)
}


def upgrade_slide_top_hidden() : float {
    return UPGRADE_PICKER_SLIDE_HIDDEN_OFFSET
}


def upgrade_slide_top_shown() : float {
    return 0.0
}


def sync_upgrade_slide_group_frame() {
    if (!upgradeSlideGroupNode.isAlive) {
        return
    }
    get_component(upgradeSlideGroupNode) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.size = upgrade_picker_content_size()
            frame.pivot = float2(0.5, 0.5)
        }
    }
}


def sync_upgrade_slide_anchor() {
    if (!upgradeSlideGroupNode.isAlive) {
        return
    }
    sync_upgrade_slide_group_frame()
    get_component(upgradeSlideGroupNode) $(var anchor : UIAnchor?) {
        if (anchor != null) {
            anchor.top = upgradeSlideAnchorTop
            anchor.left = 0.0
        }
    }
}


def sync_upgrade_header_layout() {
    if (!upgradeHeaderNode.isAlive) {
        return
    }
    let contentW = upgrade_cards_row_width()
    upgradeHeaderNode?.UIText.localPosition2D = float2(contentW * 0.5, 0.0)
}


def clear_upgrade_card_nodes() {
    for (card in upgradeCardNodes) {
        if (card.isAlive) {
            remove_node(card)
        }
    }
    clear(upgradeCardNodes)
    clear(upgradeCardHoverOverlayNodes)
    clear(upgradeCardBasePos)
    clear(upgradeCardHoverT)
}


def is_upgrade_picker_input_locked() : bool {
    return upgradePickerInputLockT < UPGRADE_PICKER_INPUT_LOCK_DURATION
}


def move_toward_float(current, target : float; maxDelta : float) : float {
    if (current < target) {
        return min(current + maxDelta, target)
    }
    return max(current - maxDelta, target)
}


def set_upgrade_card_interactable(card : NodeId; interactable : bool) {
    if (!card.isAlive) {
        return
    }
    get_component(card) $(var button : UIButton?) {
        if (button != null) {
            button.interactable = interactable
        }
    }
}


def sync_upgrade_cards_interactable() {
    let interactable = !is_upgrade_picker_input_locked()
    for (card in upgradeCardNodes) {
        set_upgrade_card_interactable(card, interactable)
    }
}


def is_mouse_over_upgrade_card(card : NodeId) : bool {
    if (!card.isAlive || !card.isActive) {
        return false
    }
    return is_mouse_inside_frame(card?.UIFrame)
}


def apply_upgrade_card_hover_visual(cardIdx : int; hoverT : float) {
    if (cardIdx < 0 || cardIdx >= length(upgradeCardNodes)) {
        return
    }
    let card = upgradeCardNodes[cardIdx]
    if (!card.isAlive) {
        return
    }
    let base = upgradeCardBasePos[cardIdx]
    let liftY = base.y - UPGRADE_PICKER_CARD_HOVER_LIFT * hoverT
    card?.UIFrame.localPosition2D = float2(base.x, liftY)
    if (cardIdx < length(upgradeCardHoverOverlayNodes)) {
        let overlay = upgradeCardHoverOverlayNodes[cardIdx]
        if (overlay.isAlive) {
            var col = COLOR_UPGRADE_CARD_HOVER_OVERLAY
            col.w = COLOR_UPGRADE_CARD_HOVER_OVERLAY.w * hoverT
            overlay?.UIImage.color = col
        }
    }
}


def update_upgrade_card_hovers(dt : float) {
    let canHover = !is_upgrade_picker_input_locked()
    for (i in range(length(upgradeCardNodes))) {
        let hovered = canHover && is_mouse_over_upgrade_card(upgradeCardNodes[i])
        let target = hovered ? 1.0 : 0.0
        upgradeCardHoverT[i] = move_toward_float(upgradeCardHoverT[i], target, UPGRADE_PICKER_CARD_HOVER_LERP_SPEED * dt)
        apply_upgrade_card_hover_visual(i, upgradeCardHoverT[i])
    }
}


def create_upgrade_card_text(parent : NodeId; name : string; content : string; fontSize : float; color : float4; localX, localY : float; wrapWidth : float) : NodeId {
    let node = create_node(NodeData(name = name, parent = parent))
    add_component(node, new UIText(
        text = content,
        fontSize = fontSize,
        color = color,
        pivot = float2(0.5, 0.0),
        horAlignment = TextHorAlignment.Center,
        vertAlignment = TextVertAlignment.Top,
        wordWrapping = true,
        localPosition2D = float2(localX, localY)
    ))
    node?.UIText.fontScaling = false
    node?.UIText.autoResizeFrame = true
    if (wrapWidth > 0.0) {
        set_frame_size(node, float2(wrapWidth, 0.0))
    }
    return node
}


def bind_upgrade_card_click(card : NodeId; kind : int) {
    let pickedKind = kind
    get_component(card) $(var button : UIButton?) {
        if (button != null) {
            button.onClick = @() {
                if (is_upgrade_picker_input_locked()) {
                    return
                }
                confirm_upgrade_choice(pickedKind)
            }
            button.interactable = false
        }
    }
}


def create_upgrade_card(parent : NodeId; kind : int; localX, localY : float) : NodeId {
    let w = UPGRADE_BOX_HUD_WIDTH
    let h = UPGRADE_BOX_HUD_HEIGHT
    let card = create_node(NodeData(name = "upgrade_card_{kind}", parent = parent))
    add_component(card, new UIButton())
    set_frame_size(card, float2(w, h))
    set_frame_pivot(card, float2(0.5, 0.0))
    card?.UIFrame.localPosition2D = float2(localX, localY)

    let boxNode = create_node(NodeData(name = "upgrade_box_{kind}", parent = card))
    add_component(boxNode, new UIImage(
        textureId = upgradeBoxTexture,
        size = float2(w, h),
        pivot = float2(0.5, 0.0),
        localPosition2D = float2(w * 0.5, 0.0)
    ))

    let hoverOverlay = create_node(NodeData(name = "upgrade_hover_{kind}", parent = card))
    add_component(hoverOverlay, new UIImage(
        color = float4(0.0, 0.0, 0.0, 0.0),
        size = float2(w, h),
        pivot = float2(0.5, 0.0),
        localPosition2D = float2(w * 0.5, 0.0)
    ))

    let textWidth = w - UPGRADE_PICKER_CARD_TEXT_PAD_X * 2.0
    create_upgrade_card_text(card, "upgrade_title_{kind}", upgrade_kind_title(kind), UPGRADE_PICKER_CARD_TITLE_FONT_SIZE, COLOR_UPGRADE_TITLE, w * 0.5, UPGRADE_PICKER_CARD_TITLE_Y, textWidth)
    create_upgrade_card_text(card, "upgrade_desc_{kind}", upgrade_kind_description(kind), UPGRADE_PICKER_CARD_BODY_FONT_SIZE, COLOR_UPGRADE_BODY, w * 0.5, UPGRADE_PICKER_CARD_DESC_Y, textWidth)
    create_upgrade_card_text(card, "upgrade_stat_{kind}", upgrade_kind_stat_line(kind), UPGRADE_PICKER_CARD_STAT_FONT_SIZE, COLOR_UPGRADE_STAT, w * 0.5, UPGRADE_PICKER_CARD_STAT_Y, textWidth)
    bind_upgrade_card_click(card, kind)
    push(upgradeCardHoverOverlayNodes, hoverOverlay)
    push(upgradeCardBasePos, float2(localX, localY))
    push(upgradeCardHoverT, 0.0)
    return card
}


def rebuild_upgrade_cards() {
    clear_upgrade_card_nodes()
    if (!upgradeSlideGroupNode.isAlive) {
        return
    }
    sync_upgrade_header_layout()
    currentUpgradeChoices <- pick_random_upgrade_kinds(UPGRADE_CHOICES_SHOWN)
    let cardW = UPGRADE_BOX_HUD_WIDTH
    let spacing = UPGRADE_PICKER_CARD_SPACING
    let rowY = upgrade_cards_row_y()
    for (i in range(length(currentUpgradeChoices))) {
        let kind = currentUpgradeChoices[i]
        let localX = cardW * 0.5 + float(i) * (cardW + spacing)
        push(upgradeCardNodes, create_upgrade_card(upgradeSlideGroupNode, kind, localX, rowY))
    }
    sync_upgrade_slide_anchor()
}


def layout_upgrade_picker_nodes() {
    if (!upgradePickerCanvas.isAlive) {
        return
    }
    let canvasSize = upgrade_picker_canvas_size()
    upgradePickerCanvas?.UICanvas.size = canvasSize
    get_component(upgradePickerCanvas) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.size = canvasSize
        }
    }
    sync_upgrade_header_layout()
    sync_upgrade_slide_anchor()
}


def public init_upgrade_picker() {
    if (upgradePickerCanvas.isAlive) {
        remove_node(upgradePickerCanvas)
        upgradePickerCanvas = NodeId()
        upgradeSlideGroupNode = NodeId()
        upgradeOverlayNode = NodeId()
        upgradeHeaderNode = NodeId()
        clear_upgrade_card_nodes()
    }
    let canvasSize = upgrade_picker_canvas_size()
    upgradePickerCanvas = create_node(NodeData(name = "upgrade_picker_canvas"))
    add_component(upgradePickerCanvas, new UICanvas(
        screenMode = ScreenMode.FitExtend,
        size = canvasSize
    ))
    set_frame_size(upgradePickerCanvas, canvasSize)
    upgradePickerCanvas.isActive = false

    upgradeOverlayNode = create_node(NodeData(name = "upgrade_overlay", parent = upgradePickerCanvas))
    add_component(upgradeOverlayNode, new UIImage(color = float4(0.0, 0.0, 0.0, 0.0)))
    add_component(upgradeOverlayNode, new UIAnchor(
        anchorMin = TOP_LEFT_ANCHOR,
        anchorMax = BOTTOM_RIGHT_ANCHOR
    ))

    upgradeSlideGroupNode = create_node(NodeData(name = "upgrade_slide_group", parent = upgradePickerCanvas))
    add_component(upgradeSlideGroupNode, new UIAnchor(
        anchorMin = MIDDLE_CENTER_ANCHOR,
        anchorMax = MIDDLE_CENTER_ANCHOR,
        top = upgrade_slide_top_hidden(),
        left = 0.0
    ))

    upgradeHeaderNode = create_node(NodeData(name = "upgrade_header", parent = upgradeSlideGroupNode))
    add_component(upgradeHeaderNode, new UIText(
        text = "Level Up! Choose one upgrade",
        fontSize = UPGRADE_PICKER_TITLE_FONT_SIZE,
        color = COLOR_UPGRADE_HEADER,
        pivot = float2(0.5, 0.0),
        horAlignment = TextHorAlignment.Center,
        vertAlignment = TextVertAlignment.Top,
        wordWrapping = false,
        localPosition2D = float2(upgrade_cards_row_width() * 0.5, 0.0)
    ))
    upgradeHeaderNode?.UIText.fontScaling = false
    upgradeHeaderNode?.UIText.autoResizeFrame = true

    upgradeSlideAnchorTop = upgrade_slide_top_hidden()
    sync_upgrade_slide_group_frame()
}


def open_upgrade_picker() {
    if (!upgradePickerCanvas.isAlive) {
        init_upgrade_picker()
    }
    rebuild_upgrade_cards()
    upgradeSlideT = 0.0
    upgradePickerInputLockT = 0.0
    upgradeSlideAnchorTop = upgrade_slide_top_hidden()
    sync_upgrade_slide_anchor()
    sync_upgrade_cards_interactable()
    upgradeOverlayNode?.UIImage.color = float4(0.0, 0.0, 0.0, 0.0)
    savedDeltaTimeScale = get_delta_time_scale()
    set_delta_time_scale(0.0)
    upgradePickerActive = true
    upgradePickerCanvas.isActive = true
}


def close_upgrade_picker() {
    upgradePickerActive = false
    if (upgradePickerCanvas.isAlive) {
        upgradePickerCanvas.isActive = false
    }
    clear_upgrade_card_nodes()
    set_delta_time_scale(savedDeltaTimeScale)
}


def confirm_upgrade_choice(kind : int) {
    if (is_upgrade_picker_input_locked()) {
        return
    }
    apply_upgrade_kind(kind)
    close_upgrade_picker()
    try_open_upgrade_picker()
}


def public try_open_upgrade_picker() {
    if (upgradePickerActive || upgradePickerDelaying || pendingUpgradePicks <= 0 || !gameReady) {
        return
    }
    upgradePickerDelaying = true
    upgradePickerOpenDelayT = 0.0
}


def public queue_upgrade_pick() {
    pendingUpgradePicks += 1
    try_open_upgrade_picker()
}


def public is_upgrade_picker_active() : bool {
    return upgradePickerActive
}


def public is_upgrade_picker_delaying() : bool {
    return upgradePickerDelaying
}


def public update_upgrade_picker() {
    if (upgradePickerDelaying) {
        upgradePickerOpenDelayT += get_delta_time()
        if (upgradePickerOpenDelayT >= UPGRADE_PICKER_OPEN_DELAY) {
            upgradePickerDelaying = false
            upgradePickerOpenDelayT = 0.0
            if (pendingUpgradePicks > 0) {
                pendingUpgradePicks -= 1
                open_upgrade_picker()
            }
        }
        return
    }
    if (!upgradePickerActive) {
        return
    }
    let dt = get_unscaled_delta_time()
    upgradePickerInputLockT += dt
    sync_upgrade_cards_interactable()
    update_upgrade_card_hovers(dt)
    upgradeSlideT = min(1.0, upgradeSlideT + dt / UPGRADE_PICKER_SLIDE_DURATION)
    let inv = 1.0 - upgradeSlideT
    let ease = 1.0 - inv * inv
    upgradeSlideAnchorTop = lerp(upgrade_slide_top_hidden(), upgrade_slide_top_shown(), ease)
    sync_upgrade_slide_anchor()
    if (upgradeOverlayNode.isAlive) {
        let alpha = lerp(0.0, UPGRADE_OVERLAY_ALPHA, ease)
        upgradeOverlayNode?.UIImage.color = float4(0.0, 0.0, 0.0, alpha)
    }
}


def public resize_upgrade_picker() {
    layout_upgrade_picker_nodes()
}
