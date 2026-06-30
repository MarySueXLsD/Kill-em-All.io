require engine.core

module disclaimer public

let private {
    COLOR_GOLD = float4(0.96, 0.82, 0.32, 1.0)
    COLOR_GOLD_SOFT = float4(0.86, 0.72, 0.38, 1.0)
    COLOR_BODY = float4(0.90, 0.92, 0.95, 1.0)
    COLOR_MUTED = float4(0.72, 0.76, 0.82, 1.0)
    COLOR_SUBTITLE = float4(0.62, 0.66, 0.72, 1.0)
    COLOR_BACKGROUND = float4(0.04, 0.05, 0.08, 1.0)
    SCREEN_MARGIN_X = 48.0
    SCREEN_MARGIN_TOP = 24.0
}


var private disclaimerRootNode : NodeId
var private disclaimerDismissed : bool = false
var private disclaimerTextWidth : float = 680.0


def disclaimer_text_width() : float {
    let res = get_resolution()
    return float(res.x) - SCREEN_MARGIN_X * 2.0
}


def styled_text(nodeName : string; content : string; fontSize : float; color : float4; wrap : bool; center : bool) : NodeId {
    let node = text(content)
    node.name = nodeName
    set_text_font_size(node, fontSize)
    set_text_color(node, color)
    node?.UIText.fontScaling = false
    node?.UIText.wordWrapping = wrap
    node?.UIText.autoResizeFrame = true
    if (center) {
        node?.UIText.horAlignment = TextHorAlignment.Center
    } else {
        node?.UIText.horAlignment = TextHorAlignment.Left
    }
    if (wrap) {
        set_frame_size(node, float2(disclaimerTextWidth, 0.0))
    }
    return node
}


def vertical_spacer(nodeName : string; heightPx : float) : NodeId {
    let node = create_node(NodeData(name = nodeName))
    add_component(node, new UIFrame(size = float2(disclaimerTextWidth, heightPx)))
    return node
}


def title_text(nodeName : string; content : string; fontSize : float; color : float4) : NodeId {
    return styled_text(nodeName, content, fontSize, color, false, true)
}


def section_heading(nodeName : string; content : string) : NodeId {
    return styled_text(nodeName, content, 24.0, COLOR_GOLD_SOFT, false, true)
}


def body_line(nodeName : string; content : string) : NodeId {
    return styled_text(nodeName, content, 18.0, COLOR_BODY, true, false)
}


def bullet_line(nodeName : string; content : string) : NodeId {
    return styled_text(nodeName, "  •  {content}", 17.0, COLOR_MUTED, true, false)
}


def build_disclaimer_content() : array<NodeId> {
    var nodes : array<NodeId>
    push(nodes, title_text("disclaimer_title", "Disclaimer", 52.0, COLOR_GOLD))
    push(nodes, title_text("disclaimer_subtitle", "Early Access Build", 20.0, COLOR_SUBTITLE))
    push(nodes, vertical_spacer("disclaimer_spacer_top", 8.0))

    push(nodes, section_heading("disclaimer_section_controls", "Controls"))
    push(nodes, bullet_line("disclaimer_ctrl_move", "WASD — Move"))
    push(nodes, bullet_line("disclaimer_ctrl_run", "Shift — Run"))
    push(nodes, bullet_line("disclaimer_ctrl_dash", "Space — Dash (needs movement direction)"))
    push(nodes, bullet_line("disclaimer_ctrl_attack", "Left click — Attack (aim with mouse)"))
    push(nodes, bullet_line("disclaimer_ctrl_special", "Right click — Special ground AOE (aim at a grid tile)"))
    push(nodes, bullet_line("disclaimer_ctrl_weapon_qe", "Q / E — Switch Sword and Bow"))
    push(nodes, bullet_line("disclaimer_ctrl_weapon_scroll", "Mouse wheel — Switch weapon (sword / bow)"))

    push(nodes, vertical_spacer("disclaimer_spacer_hud", 4.0))
    push(nodes, section_heading("disclaimer_section_hud", "HUD"))
    push(nodes, bullet_line("disclaimer_hud_health", "Bottom center — Health bar; shakes when you take damage"))
    push(nodes, bullet_line("disclaimer_hud_cooldowns", "Center bottom — Special and Dash cooldown bars with level labels"))
    push(nodes, bullet_line("disclaimer_hud_cooldown_refill", "Cooldown bars empty while the ability plays, then refill when ready"))
    push(nodes, bullet_line("disclaimer_hud_weapon", "Bottom right — Weapon icon plus weapon stats (range/crit/knockback/life steal or bow spread/pierce)"))
    push(nodes, bullet_line("disclaimer_hud_enemy_hearts", "Above enemies — Heart icons for remaining HP"))
    push(nodes, bullet_line("disclaimer_hud_exp_popup", "On kill — Floating +EXP text near the player"))
    push(nodes, bullet_line("disclaimer_hud_exp_bar", "Left center — Vertical EXP bar toward the next level"))
    push(nodes, bullet_line("disclaimer_hud_level", "Top left — Current level"))

    push(nodes, vertical_spacer("disclaimer_spacer_dev", 4.0))
    push(nodes, section_heading("disclaimer_section_dev", "In Active Development"))
    push(nodes, bullet_line("disclaimer_dev_progression", "Deeper level progression and ability upgrades"))
    push(nodes, bullet_line("disclaimer_dev_characters", "Multiple playable characters"))
    push(nodes, bullet_line("disclaimer_dev_enemies", "More enemy types and boss fights"))

    push(nodes, vertical_spacer("disclaimer_spacer_feedback", 4.0))
    push(nodes, section_heading("disclaimer_section_feedback", "Dev Feedback"))
    push(nodes, body_line("disclaimer_feedback_intro", "Every note helps while the game is in active development."))
    push(nodes, bullet_line("disclaimer_fb_death", "Death at 0 HP stops input but has no game-over or restart yet."))
    push(nodes, bullet_line("disclaimer_fb_levelup", "Level-ups increase spawn pressure but no level-up reward or fanfare yet."))
    push(nodes, bullet_line("disclaimer_fb_character", "Only one player character; Sword/Bow swap exists but no roster."))
    push(nodes, bullet_line("disclaimer_fb_enemies", "Three enemy kinds spawn off-screen; no bosses or elite variants yet."))
    push(nodes, bullet_line("disclaimer_fb_hurt_sprite", "Enemy type 2 may not show a proper hurt sprite (uses idle texture)."))
    push(nodes, bullet_line("disclaimer_fb_dev_keys", "Keys 1/2/3 and Up/Down are dev toggles still bound for playtests."))
    push(nodes, bullet_line("disclaimer_fb_special_tile", "Special must target a valid grid tile — easy to miss without feedback."))
    push(nodes, bullet_line("disclaimer_fb_no_pause", "No pause menu, settings, or save/load yet."))
    push(nodes, bullet_line("disclaimer_fb_suggestions", "Suggested next: game-over flow, level-up rewards, boss telegraphs, character select."))

    push(nodes, vertical_spacer("disclaimer_spacer_continue", 10.0))
    push(nodes, title_text("disclaimer_continue_prompt", "Press Enter, Space, or Click to continue", 20.0, COLOR_GOLD))
    return <- nodes
}


def create_fullscreen_background(parent : NodeId) {
    let bg = create_node(NodeData(name = "disclaimer_background", parent = parent))
    add_component(bg, new UIImage(color = COLOR_BACKGROUND))
    add_component(bg, new UIAnchor(
        anchorMin = TOP_LEFT_ANCHOR,
        anchorMax = BOTTOM_RIGHT_ANCHOR
    ))
}


def create_disclaimer_content(parent : NodeId) {
    disclaimerTextWidth = disclaimer_text_width()

    let wrapper = create_node(NodeData(name = "disclaimer_wrapper", parent = parent))
    add_component(wrapper, new UIAnchor(
        anchorMin = TOP_CENTER_ANCHOR,
        anchorMax = TOP_CENTER_ANCHOR,
        top = SCREEN_MARGIN_TOP
    ))
    set_frame_pivot(wrapper, float2(0.5, 0.0))

    let content = vbox(build_disclaimer_content())
    content.name = "disclaimer_content_vbox"
    content.set_parent(wrapper, AddChildStrategy.KeepLocalTransform)
    set_frame_size(content, float2(disclaimerTextWidth, 0.0))
    set_spacing(content, 3.0)
    set_alignment(content, LayoutAlignment.TopCenter)
    content?.UIVerticalLayout.childForceExpandWidth = true
}


def public init_disclaimer_screen() {
    disclaimerDismissed = false
    let res = get_resolution()
    let canvasSize = float2(float(res.x), float(res.y))

    disclaimerRootNode = create_node(NodeData(name = "disclaimer_canvas"))
    add_component(disclaimerRootNode, new UICanvas(
        screenMode = ScreenMode.FitExtend,
        size = canvasSize
    ))
    set_frame_size(disclaimerRootNode, canvasSize)

    create_fullscreen_background(disclaimerRootNode)
    create_disclaimer_content(disclaimerRootNode)
}


def hide_disclaimer_screen() {
    if (disclaimerRootNode.isAlive) {
        remove_node(disclaimerRootNode)
    }
}


def public is_disclaimer_active() : bool {
    return !disclaimerDismissed
}


def public update_disclaimer() : bool {
    if (disclaimerDismissed) {
        return true
    }
    if (is_action_just_pressed("skipDisclaimer") || is_action_just_pressed("attack")) {
        disclaimerDismissed = true
        hide_disclaimer_screen()
        return true
    }
    return false
}
