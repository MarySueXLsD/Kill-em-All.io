require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/prefab_texture_hydrate
module enemy_hud public


var public enemyHeartTexture : TextureId
var private enemyHealthBarSeq : int = 0


[safe_when_uninitialized]
struct EnemyHealthBarNodes {
    root : NodeId
    heart0 : NodeId
    heart1 : NodeId
    heartCount : int = 1
    visualSegments : int = 4
    shakeT : float = -1.0
    lastSyncedHp : int = -1
}


def enemy_health_heart_node(bar : EnemyHealthBarNodes; index : int) : NodeId {
    if (!bar.root.isAlive || index < 0 || index >= bar.heartCount) {
        return NodeId()
    }
    return get_child(bar.root, index)
}


def public load_enemy_hud_textures() {
    enemyHeartTexture = request_texture_cached(ENEMY_HEART_SPRITE_PATH)
}


def public queue_enemy_hud_texture_paths() {
    queue_texture_path(ENEMY_HEART_SPRITE_PATH)
}


def enemy_heart_hud_world_y(feetY : float) : float {
    let tileH = PLAYER_SHEET_HEIGHT / float(PLAYER_SHEET_ROWS)
    let pxToWorld = ENEMY_WORLD_HEIGHT / tileH
    return feetY + (PLAYER_SHEET_FEET_Y_PX - ENEMY_TOP_OPAQUE_Y_PX) * pxToWorld + ENEMY_HEART_HUD_OFFSET_ABOVE_TOP_PX * pxToWorld
}


def enemy_heart_raw_canvas_pos(feet : float2) : float2 {
    return world_point_to_canvas_pos(float2(feet.x, enemy_heart_hud_world_y(feet.y)))
}


def enemy_heart_canvas_y_max() : float {
    let res = get_resolution()
    let halfH = float(res.y) * 0.5
    let heartHalf = ENEMY_HEART_HUD_SIZE * 0.5
    return halfH - WAVE_TITLE_HUD_TOP_MARGIN - WAVE_TITLE_HUD_HEIGHT - ENEMY_HEART_HUD_WAVE_CLEARANCE - heartHalf
}


def enemy_heart_canvas_pos_on_screen(pos : float2) : bool {
    let res = get_resolution()
    let halfW = float(res.x) * 0.5
    let halfH = float(res.y) * 0.5
    let pad = ENEMY_HEART_HUD_SIZE * 0.5
    let inX = pos.x >= -halfW + pad && pos.x <= halfW - pad
    let inY = pos.y >= -halfH + pad && pos.y <= halfH - pad
    return inX && inY
}


def enemy_heart_display_canvas_pos(raw : float2) : float2 {
    let maxY = enemy_heart_canvas_y_max()
    if (raw.y > maxY) {
        return float2(raw.x, maxY)
    }
    return raw
}


def public init_enemy_health_canvas() {
    let res = get_resolution()
    let canvasSize = float2(float(res.x), float(res.y))
    enemyHealthCanvas = create_node(NodeData(name = "enemy_health_canvas"))
    add_component(enemyHealthCanvas, new UICanvas(
        screenMode = ScreenMode.FitExtend,
        size = canvasSize
    ))
    get_component(enemyHealthCanvas) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.size = canvasSize
        }
    }

    enemyHeartsHudRoot = create_node(NodeData(name = "enemy_hearts_hud"))
    add_child(enemyHealthCanvas, enemyHeartsHudRoot, 0, AddChildStrategy.KeepLocalTransform)
}


def public resize_enemy_health_canvas() {
    if (!enemyHealthCanvas.isAlive) {
        return
    }
    let res = get_resolution()
    let canvasSize = float2(float(res.x), float(res.y))
    enemyHealthCanvas?.UICanvas.size = canvasSize
    get_component(enemyHealthCanvas) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.size = canvasSize
        }
    }
}


def enemy_heart_count(kind : int) : int {
    if (kind == 2 || kind == 6) {
        return 1
    }
    if (kind == 7) {
        return 8
    }
    if (kind == 3) {
        return 4
    }
    return 2
}


def enemy_visual_segments(kind : int) : int {
    return enemy_heart_count(kind) * ENEMY_HEART_SEGMENT_COUNT
}


def enemy_total_segments_from_hp(hp, maxHp, visualSegments : int) : int {
    if (hp <= 0 || maxHp <= 0) {
        return 0
    }
    return min(
        visualSegments,
        int(ceil(float(hp) / float(maxHp) * float(visualSegments)))
    )
}


def enemy_heart_segments(heartIndex, heartCount, totalSegments : int) : int {
    if (heartCount <= 1) {
        return totalSegments
    }
    let start = heartIndex * ENEMY_HEART_SEGMENT_COUNT
    let remaining = max(0, totalSegments - start)
    return min(ENEMY_HEART_SEGMENT_COUNT, remaining)
}


def enemy_heart_frame(segments : int) : int {
    if (segments <= 0) {
        return ENEMY_HEART_FRAME_COUNT - 1
    }
    let filled = min(ENEMY_HEART_SEGMENT_COUNT, segments)
    return ENEMY_HEART_SEGMENT_COUNT - filled
}


def enemy_heart_uv(frameIndex : int) : float4 {
    return uv_rect_from_tile(frameIndex, 0, ENEMY_HEART_FRAME_COUNT, 1)
}


def enemy_health_shake_offset(shakeT : float) : float2 {
    if (shakeT < 0.0) {
        return float2(0.0, 0.0)
    }
    if (shakeT >= PLAYER_HEALTH_SHAKE_DURATION) {
        return float2(0.0, 0.0)
    }
    let decay = 1.0 - shakeT / PLAYER_HEALTH_SHAKE_DURATION
    let amp = ENEMY_HEART_SHAKE_AMPLITUDE * decay
    let freq = 32.0
    let offsetX = sin(shakeT * freq * PI * 2.0) * amp
    let offsetY = cos(shakeT * freq * 1.4 * PI * 2.0) * amp * 0.5
    return float2(offsetX, offsetY)
}


def sync_enemy_health_hearts(var bar : EnemyHealthBarNodes; hp, maxHp : int) {
    let total = enemy_total_segments_from_hp(hp, maxHp, bar.visualSegments)
    for (i in range(bar.heartCount)) {
        let heartNode = enemy_health_heart_node(bar, i)
        if (!heartNode.isAlive) {
            continue
        }
        let segments = enemy_heart_segments(i, bar.heartCount, total)
        let frame = enemy_heart_frame(segments)
        heartNode?.UIImage.uvRegion = enemy_heart_uv(frame)
    }
}


def public world_point_to_canvas_pos(world : float2) : float2 {
    if (!cameraNode.isAlive) {
        return float2(0.0)
    }
    let cam = cameraNode?.Camera
    let screen = cam.worldToScreen(float3(world.x, world.y, 0.1)).xy
    let res = get_resolution()
    return float2(screen.x - float(res.x) * 0.5, float(res.y) * 0.5 - screen.y)
}


struct ActiveExpPopup {
    root : NodeId
    textNode : NodeId
    canvasPos : float2
    age : float
}


var private nextExpPopupId : int = 0
var private activeExpPopups : array<ActiveExpPopup>


def exp_popup_unit_from_seed(seed : int) : float {
    return float((seed * 92837111 + 689287499) % 10000) / 10000.0
}


def exp_popup_side_sign(seed : int) : float {
    if (exp_popup_unit_from_seed(seed * 2 + 1) >= 0.5) {
        return 1.0
    }
    return -1.0
}


def exp_popup_canvas_pos_for_player(playerFeet : float2; seed, stackIndex : int) : float2 {
    let base = world_point_to_canvas_pos(playerFeet)
    let side = exp_popup_side_sign(seed)
    let stackShift = float(stackIndex) * EXP_POPUP_STACK_OFFSET_CANVAS
    return float2(
        base.x + side * EXP_POPUP_SIDE_OFFSET_CANVAS,
        base.y - EXP_POPUP_VERTICAL_OFFSET_CANVAS + stackShift
    )
}


def create_exp_popup_node(playerFeet : float2; amount : int; seed, stackIndex : int) {
    if (!enemyHealthCanvas.isAlive) {
        return
    }
    let canvasPos = exp_popup_canvas_pos_for_player(playerFeet, seed, stackIndex)
    let expLine = "+{amount}xp"

    let root = create_node(NodeData(name = "exp_popup_{seed}", parent = enemyHealthCanvas))
    root.localPosition = float3(canvasPos.x, canvasPos.y, 0.0)

    let textNode = create_node(NodeData(name = "exp_popup_text_{seed}", parent = root))
    add_component(textNode, new UIText(
        text = expLine,
        fontSize = EXP_POPUP_FONT_SIZE,
        color = float4(1.0, 0.92, 0.25, 1.0),
        pivot = float2(0.5, 0.5)
    ))
    textNode?.UIText.fontScaling = false
    textNode?.UIText.autoResizeFrame = true

    push(activeExpPopups, ActiveExpPopup(
        root = root,
        textNode = textNode,
        canvasPos = canvasPos,
        age = 0.0
    ))
}


def public spawn_exp_popup(playerFeet : float2; amount : int) {
    if (amount <= 0) {
        return
    }
    nextExpPopupId += 1
    let stackIndex = length(activeExpPopups)
    create_exp_popup_node(playerFeet, amount, nextExpPopupId, stackIndex)
}


def public flush_exp_popup_spawns() {
    pass
}


def public update_exp_popups() {
    let dt = get_delta_time()
    var i = 0
    while (i < length(activeExpPopups)) {
        if (!activeExpPopups[i].root.isAlive) {
            erase(activeExpPopups, i)
            continue
        }
        activeExpPopups[i].age += dt
        let t = activeExpPopups[i].age / EXP_POPUP_DURATION
        if (t >= 1.0) {
            remove_node(activeExpPopups[i].root)
            erase(activeExpPopups, i)
            continue
        }
        let rise = activeExpPopups[i].age * EXP_POPUP_RISE_PX_PER_SEC
        let alpha = 1.0 - t
        activeExpPopups[i].root.localPosition = float3(
            activeExpPopups[i].canvasPos.x,
            activeExpPopups[i].canvasPos.y + rise,
            0.0
        )
        if (activeExpPopups[i].textNode.isAlive) {
            activeExpPopups[i].textNode?.UIText.color = float4(1.0, 0.92, 0.25, alpha)
        }
        i += 1
    }
}


def public create_enemy_health_bar(kind : int) : EnemyHealthBarNodes {
    let heartCount = enemy_heart_count(kind)
    let visualSegments = enemy_visual_segments(kind)
    let heartSize = float2(ENEMY_HEART_HUD_SIZE, ENEMY_HEART_HUD_SIZE)
    let totalWidth = float(heartCount) * ENEMY_HEART_HUD_SIZE + float(heartCount - 1) * ENEMY_HEART_HUD_SPACING

    let heartsParent = enemyHeartsHudRoot.isAlive ? enemyHeartsHudRoot : enemyHealthCanvas
    enemyHealthBarSeq++
    let barId = enemyHealthBarSeq
    let root = create_node(NodeData(name = "enemy_hp_hearts_{barId}", parent = heartsParent))

    var heart0 : NodeId
    var heart1 : NodeId
    for (i in range(heartCount)) {
        let x = -totalWidth * 0.5 + ENEMY_HEART_HUD_SIZE * 0.5 + float(i) * (ENEMY_HEART_HUD_SIZE + ENEMY_HEART_HUD_SPACING)
        let heartNode = create_node(NodeData(name = "enemy_hp_heart_{barId}_{i}", parent = root))
        add_component(heartNode, new UIImage(
            textureId = enemyHeartTexture,
            size = heartSize,
            uvRegion = enemy_heart_uv(0),
            pivot = float2(0.5, 0.5),
            localPosition2D = float2(x, 0.0)
        ))
        if (i == 0) {
            heart0 = heartNode
        } else {
            heart1 = heartNode
        }
    }

    return EnemyHealthBarNodes(
        root = root,
        heart0 = heart0,
        heart1 = heart1,
        heartCount = heartCount,
        visualSegments = visualSegments,
        shakeT = -1.0
    )
}


def public notify_enemy_health_damage(var bar : EnemyHealthBarNodes) {
    bar.shakeT = 0.0
}


def public update_enemy_health_bar(var bar : EnemyHealthBarNodes; feet : float2; hp, maxHp : int) {
    if (!bar.root.isAlive) {
        return
    }
    let dt = get_delta_time()
    if (bar.shakeT >= 0.0) {
        bar.shakeT += dt
        if (bar.shakeT >= PLAYER_HEALTH_SHAKE_DURATION) {
            bar.shakeT = -1.0
        }
    }
    let shake = enemy_health_shake_offset(bar.shakeT)
    let rawPos = enemy_heart_raw_canvas_pos(feet)
    if (!enemy_heart_canvas_pos_on_screen(rawPos)) {
        hide_enemy_health_bar(bar)
        return
    }
    let uiPos = enemy_heart_display_canvas_pos(rawPos)
    let root = bar.root
    root.localPosition = float3(uiPos.x + shake.x, uiPos.y + shake.y, 0.0)
    if (!root.isActive) {
        root.isActive = true
    }
    if (bar.lastSyncedHp != hp) {
        sync_enemy_health_hearts(bar, hp, maxHp)
        bar.lastSyncedHp = hp
    }
}


def public hide_enemy_health_bar(bar : EnemyHealthBarNodes) {
    if (bar.root.isAlive) {
        bar.root.isActive = false
    }
}


def public destroy_enemy_health_bar(bar : EnemyHealthBarNodes) {
    if (bar.root.isAlive) {
        remove_node(bar.root)
    }
}
