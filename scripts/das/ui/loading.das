require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
require scripts/das/world/world
require scripts/das/combat/player
require scripts/das/combat/enemies
require scripts/das/combat/aoe_effects
require scripts/das/combat/projectiles
require scripts/das/world/collision
require scripts/das/world/collision_library
require scripts/das/world/props
require scripts/das/world/prefab_texture_hydrate
require scripts/das/ui/enemy_hud
require scripts/das/ui/player_hud public
require scripts/das/ui/upgrade_picker
module loading public

let private TEXTURE_PROBE_PATH = "static/UI/Boxes/title_box.png"

let private LOADING_PHASE_HYDRATE = 0
let private LOADING_PHASE_WORLD = 1
let private LOADING_PHASE_UI_TEXTURES = 2
let private LOADING_PHASE_COLLISION = 3
let private LOADING_PHASE_STREAM = 4
let private LOADING_PHASE_COMBAT_ASSIGN = 5
let private LOADING_PHASE_WAIT_CONTINUE = 6
let private LOADING_PHASE_SPAWN = 7
let private LOADING_PHASE_READY = 8

let private {
    LOADING_BOOK_FRAME_COUNT = 100
    LOADING_TEXT_FRAME_COUNT = 4
    LOADING_BOOK_PIN_PER_TICK = 1
    LOADING_BOOK_MAX_TEX_DIM = 440
    LOADING_BOOK_SOURCE_DECODE_BYTES = 1484800
    LOADING_TEXT_MAX_TEX_DIM = 480
    LOADING_BOOK_ANIM_FPS = 12.0
    LOADING_TEXT_ANIM_FPS = 4.0
    LOADING_CIRCLE_COUNT = 32
    LOADING_CIRCLE_MARGIN = 36.0
    LOADING_BOOK_DISPLAY_W = 440.0
    LOADING_TEXT_DISPLAY_W = 300.0
    LOADING_STACK_SPACING = 20.0
    LOADING_STATUS_FONT_SIZE = 16.0
    LOADING_STATUS_MARGIN_X = 48.0
    LOADING_CONTINUE_TEXT = "Press any button to continue..."
    LOADING_CONTINUE_FONT_BASE = 40.0
    LOADING_CONTINUE_SCALE_PULSE = 0.045
    LOADING_CONTINUE_PULSE_SPEED = 1.4
    COLOR_LOADING_STATUS = float4(0.72, 0.76, 0.82, 1.0)
    COLOR_LOADING_CONTINUE = float4(0.94, 0.90, 0.84, 1.0)
    COLOR_FUR_BASE = float3(0.18, 0.04, 0.06)
    COLOR_FUR_HI = float3(0.32, 0.08, 0.10)
    COLOR_FUR_LO = float3(0.10, 0.02, 0.04)
}

var private loadingCanvasNode : NodeId
var private loadingBookImageNode : NodeId
var private loadingTextImageNode : NodeId
var private loadingStatusNode : NodeId
var private loadingContinueNode : NodeId
var private loadingAwaitingContinue : bool = false
var private loadingContinuePulseTimer : float = 0.0
var private loadingBookFramePaths : array<string>
var private loadingTextFramePaths : array<string>
var private loadingBookPinnedTextures : array<TextureId>
var private loadingBookPinCursor : int = 0
var private loadingTextTextures : array<TextureId>
var private loadingCenterStackNode : NodeId
var private loadingBookAnimTimer : float = 0.0
var private loadingTextAnimTimer : float = 0.0
var private loadingBookFrameIndex : int = -1
var private loadingTextFrameIndex : int = -1
var private loadingFurTexture : TextureId
var private loadingGradientTexture : TextureId
var private loadingCircleTexture : TextureId
var private loadingCircleNodes : array<NodeId>
var private loadingCirclePhases : array<float>
var private loadingCircleSpeeds : array<float>
var private loadingCircleBasePositions : array<float2>
var private loadingCircleDriftAmplitudes : array<float2>
var private loadingPhase : int = 0
var private hydrateBegun : bool = false
var private uiPathsQueued : bool = false
var private streamPathsQueued : bool = false
var private worldPathsQueued : bool = false
var private mapBuildBegun : bool = false
var private spawnTexturesReady : bool = false
var private readyHudStep : int = 0
var public backgroundTexturesReady : bool = false
var public extendedTexturesReady : bool = false
var public textureProbeId : TextureId


def pack_pixel_rgba(r, g, b, a : int) : uint {
    return (uint(a) << 24u) | (uint(r) << 16u) | (uint(g) << 8u) | uint(b)
}


def loading_four_digit_suffix(frameIndex : int) : string {
    if (frameIndex >= 1000) {
        return "{frameIndex}"
    }
    if (frameIndex >= 100) {
        return "0{frameIndex}"
    }
    if (frameIndex >= 10) {
        return "00{frameIndex}"
    }
    return "000{frameIndex}"
}


def build_loading_frame_path_lists() {
    clear(loadingBookFramePaths)
    clear(loadingTextFramePaths)
    for (i in range(LOADING_BOOK_FRAME_COUNT)) {
        push(loadingBookFramePaths, "static/UI/loading_book/Book_White{loading_four_digit_suffix(i)}.png")
    }
    for (i in range(LOADING_TEXT_FRAME_COUNT)) {
        push(loadingTextFramePaths, "static/UI/loading_text/Loading Text{loading_four_digit_suffix(i)}.png")
    }
    resize(loadingTextTextures, LOADING_TEXT_FRAME_COUNT)
    for (i in range(LOADING_TEXT_FRAME_COUNT)) {
        loadingTextTextures[i] = TextureId()
    }
    resize(loadingBookPinnedTextures, LOADING_BOOK_FRAME_COUNT)
    for (i in range(LOADING_BOOK_FRAME_COUNT)) {
        loadingBookPinnedTextures[i] = TextureId()
    }
    loadingBookPinCursor = 0
}


def loading_book_pin_complete() : bool {
    return loadingBookPinCursor >= LOADING_BOOK_FRAME_COUNT
}


def loading_book_pinned_frame_count() : int {
    return max(loadingBookPinCursor, 1)
}


def loading_book_texture_for_frame(frameIndex : int) : TextureId {
    if (frameIndex < 0 || frameIndex >= LOADING_BOOK_FRAME_COUNT) {
        return TextureId()
    }
    if (frameIndex >= loadingBookPinCursor) {
        return TextureId()
    }
    return loadingBookPinnedTextures[frameIndex]
}


def public refresh_loading_book_game_load_gate() {
    loadingBookBlocksGameLoads = !gameReady && !loading_book_pin_complete()
}


def set_loading_book_visible(visible : bool) {
    if (!loadingBookImageNode.isAlive) {
        return
    }
    let alpha = visible ? 1.0 : 0.0
    loadingBookImageNode?.UIImage.color = float4(1.0, 1.0, 1.0, alpha)
}


def loading_status_line_width() : float {
    let res = get_resolution()
    return float(res.x) - LOADING_STATUS_MARGIN_X * 2.0
}


def sync_loading_status_layout() {
    if (!loadingStatusNode.isAlive) {
        return
    }
    let lineW = loading_status_line_width()
    set_frame_size(loadingStatusNode, float2(lineW, 0.0))
    if (!loadingContinueNode.isAlive) {
        return
    }
    set_frame_size(loadingContinueNode, float2(lineW, 0.0))
}


def set_loading_continue_visible(visible : bool) {
    loadingAwaitingContinue = visible
    if (loadingStatusNode.isAlive) {
        let statusAlpha = visible ? 0.0 : 1.0
        loadingStatusNode?.UIText.color = float4(
            COLOR_LOADING_STATUS.x,
            COLOR_LOADING_STATUS.y,
            COLOR_LOADING_STATUS.z,
            statusAlpha
        )
        if (visible) {
            loadingStatusNode?.UIText.text = ""
        }
    }
    if (!loadingContinueNode.isAlive) {
        return
    }
    let alpha = visible ? 1.0 : 0.0
    loadingContinueNode?.UIText.color = float4(COLOR_LOADING_CONTINUE.x, COLOR_LOADING_CONTINUE.y, COLOR_LOADING_CONTINUE.z, alpha)
    if (!visible) {
        loadingContinueNode.localScale = float3(1.0, 1.0, 1.0)
    }
}


def sync_loading_continue_pulse() {
    if (!loadingAwaitingContinue || !loadingContinueNode.isAlive) {
        return
    }
    let pulse = sin(loadingContinuePulseTimer * LOADING_CONTINUE_PULSE_SPEED)
    let scale = 1.0 + pulse * LOADING_CONTINUE_SCALE_PULSE
    loadingContinueNode.localScale = float3(scale, scale, 1.0)
}


def loading_continue_input_pressed() : bool {
    return is_action_just_pressed("skipDisclaimer") || is_action_just_pressed("attack") || is_action_just_pressed("special") || is_action_just_pressed("dash") || is_action_just_pressed("weaponSwitch") || is_action_just_pressed("run")
}


def loading_memory_can_decode(maxDim : int) : bool {
    let need = maxDim * maxDim * 4
    let used = heap_bytes_used()
    return used + need < loading_animation_heap_cap()
}


def loading_memory_can_decode_book(maxDim : int) : bool {
    let destBytes = maxDim * maxDim * 4
    let need = LOADING_BOOK_SOURCE_DECODE_BYTES + destBytes
    let used = heap_bytes_used()
    return used + need < loading_animation_heap_cap()
}


def unpack_pixel_r(pixel : uint) : int {
    return int((pixel >> 16u) & 255u)
}


def unpack_pixel_g(pixel : uint) : int {
    return int((pixel >> 8u) & 255u)
}


def unpack_pixel_b(pixel : uint) : int {
    return int(pixel & 255u)
}


def apply_book_bitmap_transparency(var bmp : Bitmap) {
    let pixelCount = bmp.w * bmp.h
    for (i in range(pixelCount)) {
        let pixel = bmp.pixels[i]
        let r = unpack_pixel_r(pixel)
        let g = unpack_pixel_g(pixel)
        let b = unpack_pixel_b(pixel)
        if (r <= 24 && g <= 24 && b <= 24) {
            bmp.pixels[i] = pack_pixel_rgba(0, 0, 0, 0)
        }
    }
}


def load_loading_ui_texture_from_path(texPath : string; maxDim : int; isBookFrame : bool = false) : TextureId {
    if (length(texPath) == 0) {
        return TextureId()
    }
    if (isBookFrame) {
        if (!loading_memory_can_decode_book(maxDim)) {
            return TextureId()
        }
    } elif (!loading_memory_can_decode(maxDim)) {
        return TextureId()
    }
    var created : TextureId
    var loaded = false
    get_image_content(texPath) $(var bitmap : Bitmap) {
        let srcW = bitmap.w
        let srcH = bitmap.h
        let maxSide = max(srcW, srcH)
        if (maxSide > maxDim) {
            let dstW = max(1, int(float(srcW) * float(maxDim) / float(maxSide)))
            let dstH = max(1, int(float(srcH) * float(maxDim) / float(maxSide)))
            var dst <- Bitmap(dstW, dstH)
            dst.pixels |> resize(dstW * dstH)
            for (y in range(dstH)) {
                let sy = y * srcH / dstH
                let rowStart = y * dstW
                let srcRowStart = sy * srcW
                for (x in range(dstW)) {
                    let sx = x * srcW / dstW
                    dst.pixels[rowStart + x] = bitmap.pixels[srcRowStart + sx]
                }
            }
            if (isBookFrame) {
                apply_book_bitmap_transparency(dst)
            }
            created = create_texture(dst, loading_ui_texture_declaration())
        } else {
            if (isBookFrame) {
                apply_book_bitmap_transparency(bitmap)
            }
            created = create_texture(bitmap, loading_ui_texture_declaration())
        }
        loaded = true
    }
    if (loaded && texture_id_is_valid(created)) {
        return created
    }
    return TextureId()
}


def step_loading_book_pin(maxLoads : int) : int {
    var loaded = 0
    while (loadingBookPinCursor < LOADING_BOOK_FRAME_COUNT && loaded < maxLoads) {
        let frameIndex = loadingBookPinCursor
        if (texture_id_is_valid(loadingBookPinnedTextures[frameIndex])) {
            loadingBookPinCursor++
            loaded++
            continue
        }
        let created = load_loading_ui_texture_from_path(
            loadingBookFramePaths[frameIndex],
            LOADING_BOOK_MAX_TEX_DIM,
            true
        )
        if (!texture_id_is_valid(created)) {
            break
        }
        loadingBookPinnedTextures[frameIndex] = created
        loadingBookPinCursor++
        loaded++
    }
    return loaded
}


def loading_ui_texture_declaration() : TextureDeclaration {
    return TextureDeclaration(
        filter = TextureFilter.Point,
        sRGB = true,
        addressing = TextureAddress.Clamp,
        generateMipLevels = false
    )
}


def fur_hash_noise(x, y : float) : float {
    let v = sin(x * 12.9898 + y * 78.233) * 43758.5453
    return v - floor(v)
}


def create_loading_fur_texture() : TextureId {
    let w = 256
    let h = 256
    var bmp <- Bitmap(w, h)
    bmp.pixels |> resize(w * h)
    for (y in range(h)) {
        let fy = float(y)
        for (x in range(w)) {
            let fx = float(x)
            let n1 = sin(fx * 0.09) * sin(fy * 0.11) * 0.5 + 0.5
            let n2 = fur_hash_noise(fx * 0.17, fy * 0.23)
            let n3 = sin(fx * 0.31 + fy * 0.27) * 0.5 + 0.5
            let blend = saturate(n1 * 0.45 + n2 * 0.35 + n3 * 0.20)
            let rgb = lerp(COLOR_FUR_LO, COLOR_FUR_HI, blend)
            let shade = lerp(COLOR_FUR_BASE, rgb, 0.55 + blend * 0.45)
            let r = int(clamp(shade.x * 255.0, 0.0, 255.0))
            let g = int(clamp(shade.y * 255.0, 0.0, 255.0))
            let b = int(clamp(shade.z * 255.0, 0.0, 255.0))
            bmp.pixels[y * w + x] = pack_pixel_rgba(r, g, b, 255)
        }
    }
    return create_texture(bmp, loading_ui_texture_declaration())
}


def create_loading_gradient_texture() : TextureId {
    let w = 1
    let h = 64
    var bmp <- Bitmap(w, h)
    bmp.pixels |> resize(w * h)
    for (y in range(h)) {
        let t = float(y) / float(h - 1)
        let edge = abs(t - 0.5) * 2.0
        let alpha = int(clamp((1.0 - edge * 0.65) * 102.0, 0.0, 255.0))
        bmp.pixels[y] = pack_pixel_rgba(8, 2, 4, alpha)
    }
    return create_texture(bmp, loading_ui_texture_declaration())
}


def create_loading_circle_texture() : TextureId {
    let size = 32
    var bmp <- Bitmap(size, size)
    bmp.pixels |> resize(size * size)
    let center = float(size - 1) * 0.5
    let radius = center
    for (y in range(size)) {
        for (x in range(size)) {
            let dx = float(x) - center
            let dy = float(y) - center
            let dist = sqrt(dx * dx + dy * dy) / radius
            let falloff = saturate(1.0 - dist)
            let alpha = int(clamp(falloff * falloff * 255.0, 0.0, 255.0))
            bmp.pixels[y * size + x] = pack_pixel_rgba(255, 220, 200, alpha)
        }
    }
    return create_texture(bmp, loading_ui_texture_declaration())
}


def sync_loading_book_frame(frameIndex : int) {
    if (!loadingBookImageNode.isAlive) {
        return
    }
    let tex = loading_book_texture_for_frame(frameIndex)
    if (!texture_id_is_valid(tex)) {
        set_loading_book_visible(false)
        return
    }
    set_loading_book_visible(true)
    loadingBookImageNode?.UIImage.textureId = tex
}


def ensure_loading_text_texture(frameIndex : int) : TextureId {
    if (frameIndex < 0 || frameIndex >= LOADING_TEXT_FRAME_COUNT) {
        return TextureId()
    }
    if (texture_id_is_valid(loadingTextTextures[frameIndex])) {
        return loadingTextTextures[frameIndex]
    }
    let created = load_loading_ui_texture_from_path(loadingTextFramePaths[frameIndex], LOADING_TEXT_MAX_TEX_DIM)
    if (texture_id_is_valid(created)) {
        loadingTextTextures[frameIndex] = created
        return created
    }
    return TextureId()
}


def sync_loading_text_frame(frameIndex : int) {
    if (!loadingTextImageNode.isAlive) {
        return
    }
    let tex = ensure_loading_text_texture(frameIndex)
    if (texture_id_is_valid(tex)) {
        loadingTextImageNode?.UIImage.textureId = tex
    }
}


def preload_loading_startup_textures() {
    for (i in range(LOADING_TEXT_FRAME_COUNT)) {
        ensure_loading_text_texture(i)
    }
    sync_loading_text_frame(0)
    loadingBookFrameIndex = -1
    loadingTextFrameIndex = 0
}


def create_loading_fullscreen_image(parent : NodeId; name : string; tex : TextureId; tint : float4) : NodeId {
    let node = create_node(NodeData(name = name, parent = parent))
    add_component(node, new UIImage(
        textureId = tex,
        color = tint
    ))
    add_component(node, new UIAnchor(
        anchorMin = TOP_LEFT_ANCHOR,
        anchorMax = BOTTOM_RIGHT_ANCHOR
    ))
    return node
}


def loading_circle_hash01(seed : int) : float {
    let v = sin(float(seed) * 12.9898 + 78.233) * 43758.5453
    return v - floor(v)
}


def loading_circle_canvas_size() : float2 {
    let res = get_resolution()
    return float2(float(res.x), float(res.y))
}


def sync_loading_circle_layout() {
    let canvasSize = loading_circle_canvas_size()
    let usableW = max(1.0, canvasSize.x - LOADING_CIRCLE_MARGIN * 2.0)
    let usableH = max(1.0, canvasSize.y - LOADING_CIRCLE_MARGIN * 2.0)
    resize(loadingCircleBasePositions, LOADING_CIRCLE_COUNT)
    resize(loadingCircleDriftAmplitudes, LOADING_CIRCLE_COUNT)
    for (i in range(LOADING_CIRCLE_COUNT)) {
        let hx = loading_circle_hash01(i * 5 + 1)
        let hy = loading_circle_hash01(i * 5 + 2)
        let driftX = 24.0 + loading_circle_hash01(i * 5 + 3) * 56.0
        let driftY = 18.0 + loading_circle_hash01(i * 5 + 4) * 44.0
        loadingCircleBasePositions[i] = float2(
            LOADING_CIRCLE_MARGIN + hx * usableW,
            LOADING_CIRCLE_MARGIN + hy * usableH
        )
        loadingCircleDriftAmplitudes[i] = float2(driftX, driftY)
        if (i < length(loadingCircleNodes) && loadingCircleNodes[i].isAlive) {
            set_frame_pos(loadingCircleNodes[i], loadingCircleBasePositions[i])
        }
    }
}


def create_loading_circles_layer(parent : NodeId) {
    clear(loadingCircleNodes)
    clear(loadingCirclePhases)
    clear(loadingCircleSpeeds)
    clear(loadingCircleBasePositions)
    clear(loadingCircleDriftAmplitudes)

    let canvasSize = loading_circle_canvas_size()

    let layer = create_node(NodeData(name = "loading_circles_layer", parent = parent))
    add_component(layer, new UIAnchor(
        anchorMin = TOP_LEFT_ANCHOR,
        anchorMax = BOTTOM_RIGHT_ANCHOR
    ))
    set_frame_size(layer, canvasSize)

    sync_loading_circle_layout()

    for (i in range(LOADING_CIRCLE_COUNT)) {
        let circle = create_node(NodeData(name = "loading_circle_{i}", parent = layer))
        let sizeRoll = loading_circle_hash01(i * 7 + 11)
        let circleSize = 28.0 + sizeRoll * 52.0
        let alphaRoll = loading_circle_hash01(i * 7 + 13)
        add_component(circle, new UIImage(
            textureId = loadingCircleTexture,
            size = float2(circleSize, circleSize),
            color = float4(0.55, 0.12, 0.14, 0.05 + alphaRoll * 0.09),
            pivot = float2(0.5, 0.5)
        ))
        set_frame_pivot(circle, float2(0.5, 0.5))
        set_frame_pos(circle, loadingCircleBasePositions[i])
        push(loadingCircleNodes, circle)
        push(loadingCirclePhases, float(i) * 0.63)
        push(loadingCircleSpeeds, 0.35 + loading_circle_hash01(i * 7 + 17) * 0.55)
    }
}


def create_loading_center_stack(parent : NodeId) {
    let bookH = LOADING_BOOK_DISPLAY_W * 0.75
    let textH = LOADING_TEXT_DISPLAY_W * 0.18
    let statusW = loading_status_line_width()

    let wrapper = create_node(NodeData(name = "loading_center_stack", parent = parent))
    add_component(wrapper, new UIAnchor(
        anchorMin = MIDDLE_CENTER_ANCHOR,
        anchorMax = MIDDLE_CENTER_ANCHOR
    ))
    set_frame_pivot(wrapper, float2(0.5, 0.5))
    loadingCenterStackNode = wrapper

    loadingBookImageNode = create_node(NodeData(name = "loading_book_image", parent = wrapper))
    add_component(loadingBookImageNode, new UIImage(
        size = float2(LOADING_BOOK_DISPLAY_W, bookH),
        pivot = float2(0.5, 0.5),
        color = float4(1.0, 1.0, 1.0, 0.0)
    ))
    set_frame_pivot(loadingBookImageNode, float2(0.5, 0.5))
    set_frame_size(loadingBookImageNode, float2(LOADING_BOOK_DISPLAY_W, bookH))
    set_frame_pos(loadingBookImageNode, float2(0.0, -(textH + LOADING_STACK_SPACING * 2.0 + 24.0) * 0.5))

    loadingTextImageNode = create_node(NodeData(name = "loading_text_image", parent = wrapper))
    add_component(loadingTextImageNode, new UIImage(
        size = float2(LOADING_TEXT_DISPLAY_W, textH),
        pivot = float2(0.5, 0.5)
    ))
    set_frame_pivot(loadingTextImageNode, float2(0.5, 0.5))
    set_frame_size(loadingTextImageNode, float2(LOADING_TEXT_DISPLAY_W, textH))
    set_frame_pos(loadingTextImageNode, float2(0.0, bookH * 0.5 + LOADING_STACK_SPACING - textH * 0.5))

    loadingStatusNode = text("Starting...")
    loadingStatusNode.name = "loading_status"
    loadingStatusNode.set_parent(wrapper, AddChildStrategy.KeepLocalTransform)
    set_text_font_size(loadingStatusNode, LOADING_STATUS_FONT_SIZE)
    set_text_color(loadingStatusNode, COLOR_LOADING_STATUS)
    loadingStatusNode?.UIText.fontScaling = false
    loadingStatusNode?.UIText.autoResizeFrame = true
    loadingStatusNode?.UIText.wordWrapping = false
    loadingStatusNode?.UIText.horAlignment = TextHorAlignment.Center
    set_frame_pivot(loadingStatusNode, float2(0.5, 0.5))
    set_frame_size(loadingStatusNode, float2(statusW, 0.0))
    set_frame_pos(loadingStatusNode, float2(0.0, bookH * 0.5 + LOADING_STACK_SPACING + textH + LOADING_STACK_SPACING))

    let statusBottomY = bookH * 0.5 + LOADING_STACK_SPACING + textH + LOADING_STACK_SPACING + 20.0
    loadingContinueNode = text(LOADING_CONTINUE_TEXT)
    loadingContinueNode.name = "loading_continue"
    loadingContinueNode.set_parent(wrapper, AddChildStrategy.KeepLocalTransform)
    set_text_font_size(loadingContinueNode, LOADING_CONTINUE_FONT_BASE)
    set_text_color(loadingContinueNode, COLOR_LOADING_CONTINUE)
    loadingContinueNode?.UIText.fontScaling = false
    loadingContinueNode?.UIText.autoResizeFrame = true
    loadingContinueNode?.UIText.wordWrapping = false
    loadingContinueNode?.UIText.horAlignment = TextHorAlignment.Center
    set_frame_pivot(loadingContinueNode, float2(0.5, 0.5))
    set_frame_size(loadingContinueNode, float2(statusW, 0.0))
    set_frame_pos(loadingContinueNode, float2(0.0, statusBottomY + LOADING_STACK_SPACING))
    set_loading_continue_visible(false)
}


def build_loading_screen_ui() {
    if (loadingCanvasNode.isAlive) {
        remove_node(loadingCanvasNode)
    }

    build_loading_frame_path_lists()
    loadingFurTexture = create_loading_fur_texture()
    loadingGradientTexture = create_loading_gradient_texture()
    loadingCircleTexture = create_loading_circle_texture()

    let res = get_resolution()
    let canvasSize = float2(float(res.x), float(res.y))

    loadingCanvasNode = create_node(NodeData(name = "loading_canvas"))
    add_component(loadingCanvasNode, new UICanvas(
        screenMode = ScreenMode.FitExtend,
        size = canvasSize
    ))
    set_frame_size(loadingCanvasNode, canvasSize)

    create_loading_fullscreen_image(
        loadingCanvasNode,
        "loading_fur_bg",
        loadingFurTexture,
        float4(1.0, 1.0, 1.0, 1.0)
    )
    create_loading_fullscreen_image(
        loadingCanvasNode,
        "loading_gradient_overlay",
        loadingGradientTexture,
        float4(0.45, 0.08, 0.10, 0.55)
    )
    create_loading_circles_layer(loadingCanvasNode)
    create_loading_center_stack(loadingCanvasNode)

    loadingBookAnimTimer = 0.0
    loadingTextAnimTimer = 0.0
    loadingBookFrameIndex = -1
    loadingTextFrameIndex = -1
    preload_loading_startup_textures()
}


def clear_loading_screen_textures() {
    clear(loadingBookFramePaths)
    clear(loadingTextFramePaths)
    clear(loadingBookPinnedTextures)
    clear(loadingTextTextures)
    loadingBookPinCursor = 0
    clear(loadingCircleNodes)
    clear(loadingCirclePhases)
    clear(loadingCircleSpeeds)
    clear(loadingCircleBasePositions)
    clear(loadingCircleDriftAmplitudes)
    loadingFurTexture = TextureId()
    loadingGradientTexture = TextureId()
    loadingCircleTexture = TextureId()
    loadingCenterStackNode = NodeId()
    loadingBookImageNode = NodeId()
    loadingTextImageNode = NodeId()
    loadingStatusNode = NodeId()
    loadingContinueNode = NodeId()
    loadingAwaitingContinue = false
    loadingContinuePulseTimer = 0.0
}


def public update_loading_screen() {
    if (!loadingCanvasNode.isAlive) {
        return
    }
    let dt = get_delta_time()

    if (!loading_book_pin_complete()) {
        step_loading_book_pin(LOADING_BOOK_PIN_PER_TICK)
    }

    loadingBookAnimTimer += dt
    refresh_loading_book_game_load_gate()
    let animFrameCount = loading_book_pin_complete() ? LOADING_BOOK_FRAME_COUNT : loadingBookPinCursor
    if (animFrameCount > 0) {
        let bookFrame = int(loadingBookAnimTimer * LOADING_BOOK_ANIM_FPS) % animFrameCount
        if (bookFrame != loadingBookFrameIndex) {
            loadingBookFrameIndex = bookFrame
            sync_loading_book_frame(bookFrame)
        }
    }

    loadingTextAnimTimer += dt
    let textFrame = int(loadingTextAnimTimer * LOADING_TEXT_ANIM_FPS) % LOADING_TEXT_FRAME_COUNT
    if (textFrame != loadingTextFrameIndex) {
        loadingTextFrameIndex = textFrame
        sync_loading_text_frame(textFrame)
    }

    for (i in range(length(loadingCircleNodes))) {
        if (!loadingCircleNodes[i].isAlive) {
            continue
        }
        loadingCirclePhases[i] += loadingCircleSpeeds[i] * dt
        let angle = loadingCirclePhases[i]
        let basePos = loadingCircleBasePositions[i]
        let drift = loadingCircleDriftAmplitudes[i]
        let posX = basePos.x + cos(angle) * drift.x
        let posY = basePos.y + sin(angle * 0.73) * drift.y
        set_frame_pos(loadingCircleNodes[i], float2(posX, posY))
    }

    if (loadingAwaitingContinue) {
        loadingContinuePulseTimer += dt
        sync_loading_continue_pulse()
    }
}


def public resize_loading_screen() {
    if (!loadingCanvasNode.isAlive) {
        return
    }
    let res = get_resolution()
    let canvasSize = float2(float(res.x), float(res.y))
    get_component(loadingCanvasNode) $(var frame : UIFrame?) {
        if (frame != null) {
            frame.size = canvasSize
        }
    }
    loadingCanvasNode?.UICanvas.size = canvasSize
    sync_loading_status_layout()
    sync_loading_circle_layout()
}


def set_loading_message(msg : string) {
    if (loadingStatusNode.isAlive) {
        loadingStatusNode?.UIText.text = msg
    }
}


def queue_ui_texture_paths() {
    queue_player_hud_texture_paths()
    queue_upgrade_picker_texture_paths()
    queue_enemy_hud_texture_paths()
    queue_texture_path(TEXTURE_PROBE_PATH)
}


def queue_spawn_combat_texture_paths() {
    queue_spawn_projectile_texture_paths()
}


def queue_stream_texture_paths() {
    queue_spawn_projectile_texture_paths()
    queue_texture_path(ENEMY1_IDLE_PATH)
    queue_texture_path(ENEMY2_IDLE_PATH)
    queue_texture_path(ENEMY3_IDLE_PATH)
    queue_spawn_player_texture_paths()
    queue_pump_enemy_texture_paths()
    queue_background_combat_texture_paths()
    queue_background_player_texture_paths()
    queue_remaining_hydrate_paths()
    queue_texture_path(ENEMY2_SPECIAL1_PATH)
    queue_texture_path(ENEMY6_IDLE_PATH)
    queue_texture_path(ENEMY6_WALK_PATH)
    queue_texture_path(ENEMY6_ATTACK1_PATH)
    queue_texture_path(ENEMY6_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY6_DIE_PATH)
    queue_texture_path(ENEMY6_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_IDLE_PATH)
    queue_texture_path(ENEMY7_WALK_PATH)
    queue_texture_path(ENEMY7_RUN_PATH)
    queue_texture_path(ENEMY7_ATTACK1_PATH)
    queue_texture_path(ENEMY7_CAST_SPELL_PATH)
    queue_texture_path(ENEMY7_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY7_DIE_PATH)
    queue_texture_path(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
    queue_background_projectile_texture_paths()
    queue_background_aoe_texture_paths()
}


def queue_background_combat_texture_paths() {
    queue_texture_path(ENEMY1_ATTACK1_PATH)
    queue_texture_path(ENEMY2_ATTACK1_PATH)
    queue_texture_path(ENEMY3_ATTACK1_PATH)
    queue_texture_path(ENEMY1_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY3_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY1_DIE_PATH)
    queue_texture_path(ENEMY2_DIE_PATH)
    queue_texture_path(ENEMY3_DIE_PATH)
}


def queue_extended_background_texture_paths() {
    queue_background_player_texture_paths()
    queue_texture_path(ENEMY6_IDLE_PATH)
    queue_texture_path(ENEMY6_WALK_PATH)
    queue_texture_path(ENEMY6_ATTACK1_PATH)
    queue_texture_path(ENEMY6_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY6_DIE_PATH)
    queue_texture_path(ENEMY7_IDLE_PATH)
    queue_texture_path(ENEMY7_WALK_PATH)
    queue_texture_path(ENEMY7_ATTACK1_PATH)
    queue_texture_path(ENEMY7_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY7_DIE_PATH)
    queue_texture_path(ENEMY2_SPECIAL1_PATH)
    queue_texture_path(ENEMY6_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_CAST_SPELL_PATH)
    queue_texture_path(ENEMY7_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_RUN_PATH)
    queue_texture_path(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
    queue_background_projectile_texture_paths()
    queue_background_aoe_texture_paths()
}


def queue_pump_combat_texture_paths() {
    queue_spawn_player_texture_paths()
    queue_pump_enemy_texture_paths()
    queue_background_combat_texture_paths()
    queue_extended_background_texture_paths()
}


def queue_combat_texture_paths() {
    queue_spawn_combat_texture_paths()
    queue_stream_texture_paths()
}


def assign_ui_texture_modules() {
    load_player_hud_textures()
    load_upgrade_picker_textures()
    load_enemy_hud_textures()
    textureProbeId = request_texture_cached(TEXTURE_PROBE_PATH)
}


def assign_spawn_combat_texture_modules() {
    load_spawn_player_textures()
    load_spawn_enemy_textures()
    load_spawn_projectile_textures()
}


def refresh_pump_combat_texture_bindings() {
    refresh_spawn_player_textures_from_cache()
    refresh_spawn_enemy_textures_from_cache()
    refresh_extended_enemy_textures_from_cache()
    refresh_projectile_textures_from_cache()
    refresh_aoe_textures_from_cache()
}


def assign_combat_texture_modules() {
    assign_spawn_combat_texture_modules()
    refresh_pump_combat_texture_bindings()
    assign_level_sprite_textures()
}


def public verify_game_textures_loaded() : bool {
    let ok = prefabTexturesHydrated && texture_id_is_valid(playerBottomBarTexture)
    gameTexturesVerified = ok
    if (!ok) {
        print("loading: texture verification (hydrated={prefabTexturesHydrated}, hud={texture_id_is_valid(playerBottomBarTexture)})")
    }
    return ok
}


def public load_all_game_textures() {
    assign_ui_texture_modules()
    assign_combat_texture_modules()
    load_world_textures()
    load_prop_textures()
}


def public reload_game_textures_for_runtime() {
    gameTexturesVerified = false
    reset_texture_loading_state()
    queue_ui_texture_paths()
    queue_combat_texture_paths()
}


def public ensure_game_textures_loaded() {
    if (gameTexturesVerified) {
        return
    }
}


def public apply_procedural_visuals_if_ready() {
    if (!gameTexturesVerified) {
        return
    }
    if (!world_textures_ready() || !propTexturesLoaded) {
        return
    }
    apply_map_prefab_textures()
    refresh_level_prop_visuals()
}


def public pump_background_texture_loads() : bool {
    return extendedTexturesReady
}


def public init_loading_screen() {
    loadingPhase = LOADING_PHASE_HYDRATE
    hydrateBegun = false
    uiPathsQueued = false
    worldPathsQueued = false
    mapBuildBegun = false
    spawnTexturesReady = false
    readyHudStep = 0
    streamPathsQueued = false
    backgroundTexturesReady = false
    extendedTexturesReady = false
    gameReady = false
    loadingBookAnimationReady = false
    loadingBookBlocksGameLoads = true
    loadingBookPinCursor = 0
    loadingAwaitingContinue = false
    loadingContinuePulseTimer = 0.0
    gameTexturesVerified = false
    reset_prefab_textures_hydrated()
    reset_texture_loading_state()
    build_loading_screen_ui()
    set_loading_message("Starting...")
}


def public hide_loading_screen() {
    if (loadingCanvasNode.isAlive) {
        remove_node(loadingCanvasNode)
    }
    loadingCanvasNode = NodeId()
    clear_loading_screen_textures()
}


def public advance_loading() : bool {
    if (gameReady) {
        return true
    }

    begin_texture_load_frame()

    if (!loading_book_pin_complete()) {
        step_loading_book_pin(LOADING_BOOK_PIN_PER_TICK)
        let pct = int(float(loadingBookPinCursor) / float(LOADING_BOOK_FRAME_COUNT) * 100.0)
        set_loading_message("Loading animation... {pct}%")
        refresh_loading_book_game_load_gate()
        if (loadingBookPinCursor > 0 && loadingBookFrameIndex < 0) {
            sync_loading_book_frame(0)
            loadingBookFrameIndex = 0
        }
        return false
    }

    if (!loadingBookAnimationReady) {
        loadingBookAnimationReady = true
        loadingBookBlocksGameLoads = false
        sync_loading_book_frame(0)
        loadingBookFrameIndex = 0
        set_loading_message("Starting...")
    }

    if (loadingPhase == LOADING_PHASE_HYDRATE) {
        if (!hydrateBegun) {
            begin_level_texture_hydrate()
            hydrateBegun = true
        }
        if (!advance_level_texture_hydrate(HYDRATE_WALK_NODES_PER_FRAME)) {
            let pct = int(hydrate_level_progress() * 100.0)
            set_loading_message("Binding world... {pct}%")
            return false
        }
        release_hydrate_loading_scratch()
        begin_deferred_texture_batch()
        set_loading_message("Loading terrain...")
        loadingPhase = LOADING_PHASE_WORLD
        return false
    }

    if (loadingPhase == LOADING_PHASE_WORLD) {
        if (!worldPathsQueued) {
            queue_world_texture_paths()
            worldPathsQueued = true
        }
        if (!advance_deferred_texture_loads(MAX_TEXTURE_LOADS_PER_FRAME)) {
            let left = deferred_textures_remaining()
            set_loading_message("Loading terrain... ({left} left)")
            return false
        }
        release_deferred_texture_scratch()
        load_world_textures()
        if (!mapBuildBegun) {
            begin_batched_map_build()
            mapBuildBegun = true
        }
        if (!advance_batched_map_build(MAP_CELLS_PER_FRAME)) {
            let pct = int(batched_map_build_progress() * 100.0)
            set_loading_message("Building map... {pct}%")
            return false
        }
        init_world_from_prefab()
        apply_map_prefab_textures()
        release_map_build_scratch()
        begin_deferred_texture_batch()
        loadingPhase = LOADING_PHASE_UI_TEXTURES
        return false
    }

    if (loadingPhase == LOADING_PHASE_UI_TEXTURES) {
        if (!uiPathsQueued) {
            queue_ui_texture_paths()
            uiPathsQueued = true
            set_loading_message("Loading UI...")
        }
        if (!advance_deferred_texture_loads(MAX_TEXTURE_LOADS_PER_FRAME)) {
            let left = deferred_textures_remaining()
            set_loading_message("Loading UI... ({left} left)")
            return false
        }
        release_deferred_texture_scratch()
        assign_ui_texture_modules()
        verify_game_textures_loaded()
        begin_deferred_texture_batch()
        loadingPhase = LOADING_PHASE_COLLISION
        return false
    }

    if (loadingPhase == LOADING_PHASE_COLLISION) {
        set_loading_message("Preparing collision...")
        build_grid_wall_blockers()
        print(
            "collision library: {collision_library_asset_count()} assets (baked {collision_library_baked_at()})"
        )
        init_effects_root()
        begin_deferred_texture_batch()
        loadingPhase = LOADING_PHASE_STREAM
        return false
    }

    if (loadingPhase == LOADING_PHASE_STREAM) {
        if (!streamPathsQueued) {
            queue_stream_texture_paths()
            streamPathsQueued = true
            set_loading_message("Loading assets...")
        }
        if (!advance_deferred_texture_loads(MAX_TEXTURE_LOADS_PER_FRAME)) {
            let left = deferred_textures_remaining()
            let heapPct = heap_usage_percent()
            set_loading_message("Loading assets... ({left} left, {heapPct}% heap)")
            if (should_refresh_texture_bindings()) {
                refresh_pump_combat_texture_bindings()
                load_spawn_player_textures()
                load_spawn_enemy_textures()
                load_spawn_projectile_textures()
            }
            return false
        }
        release_deferred_texture_scratch()
        refresh_pump_combat_texture_bindings()
        load_spawn_player_textures()
        load_spawn_enemy_textures()
        load_spawn_projectile_textures()
        extendedTexturesReady = true
        backgroundTexturesReady = true
        print("loading: assets ready, heap={heap_usage_percent()}%, character sheets={cached_character_sheet_count()}")
        loadingPhase = LOADING_PHASE_COMBAT_ASSIGN
        return false
    }

    if (loadingPhase == LOADING_PHASE_COMBAT_ASSIGN) {
        if (!advance_level_sprite_texture_assign(SPRITE_ASSIGN_NODES_PER_FRAME)) {
            let pct = int(sprite_assign_progress() * 100.0)
            set_loading_message("Binding world props... {pct}%")
            return false
        }
        loadingPhase = LOADING_PHASE_WAIT_CONTINUE
        readyHudStep = 0
        return false
    }

    if (loadingPhase == LOADING_PHASE_WAIT_CONTINUE) {
        if (!loadingAwaitingContinue) {
            set_loading_continue_visible(true)
        }
        if (loading_continue_input_pressed()) {
            set_loading_continue_visible(false)
            loadingPhase = LOADING_PHASE_SPAWN
        }
        return false
    }

    if (loadingPhase == LOADING_PHASE_SPAWN) {
        if (!spawnTexturesReady) {
            load_spawn_player_textures()
            load_spawn_enemy_textures()
            spawnTexturesReady = true
        }
        set_loading_message("Spawning entities...")
        init_enemy_health_canvas()
        spawn_player()
        if (!isBaseLevel) {
            spawn_enemies()
        }
        readyHudStep = 0
        loadingPhase = LOADING_PHASE_READY
        return false
    }

    if (loadingPhase == LOADING_PHASE_READY) {
        if (readyHudStep == 0) {
            set_loading_message("")
            init_player_hud_step(0)
            readyHudStep++
            return false
        }
        if (readyHudStep == 1) {
            init_player_hud_step(1)
            readyHudStep++
            return false
        }
        if (readyHudStep == 2) {
            init_player_hud_step(2)
            readyHudStep++
            return false
        }
        if (readyHudStep == 3) {
            init_upgrade_picker()
            init_tile_angle_hud()
            gameReady = true
            hide_loading_screen()
            loadingPhase++
            if (textureFileFallbackCount > 0) {
                print("loading: {textureFileFallbackCount} textures loaded via image file fallback")
            }
            return true
        }
        return false
    }

    return false
}
