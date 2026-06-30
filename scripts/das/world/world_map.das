require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/world_terrain
require scripts/das/world/prefab_texture_hydrate

module world_map public

var private a1Textures : array<TextureId>
var private a2Textures : array<TextureId>
var private a3Textures : array<TextureId>
var private a4Textures : array<TextureId>
var private a5Textures : array<TextureId>
var private e1Textures : array<TextureId>
var private mapCullResX : int = -1
var private mapCullBounds : VisibleGridBounds
var private mapCullBoundsValid : bool = false
var private mapCellNodes : array<NodeId>
var private mapCellVisible : array<bool>
var private batchedMapCells : array<NodeId>
var private batchedMapCellCursor : int = 0
var private batchedMapSetupDone : bool = false

let public MAP_CELLS_PER_FRAME = 32



def public world_textures_ready() : bool {
    if (length(a1Textures) < 4 || length(a2Textures) < 4 || length(e1Textures) < 4) {
        return false
    }
    for (i in range(4)) {
        if (!texture_id_is_valid(a1Textures[i]) || !texture_id_is_valid(a2Textures[i]) || !texture_id_is_valid(e1Textures[i])) {
            return false
        }
    }
    return true
}


def apply_a1_tile(node : NodeId; gx, gy : int) {
    if (!node.isAlive || !world_textures_ready()) {
        return
    }
    let dir = pick_a1_direction(gx, gy)
    let layoutCrop = ground_sprite_layout_crop()
    refresh_tile_sprite(node, layoutCrop)
    node?.SpriteRenderer.textureId = a1Textures[dir]
    node?.SpriteRenderer.uvRect = tile_uv_rect_for_precropped(GROUND_A1_SOURCE_CROPS[dir])
}


def apply_interior_grass_tile(node : NodeId; grassDir : int; useA5 : bool) {
    if (!node.isAlive || !world_textures_ready()) {
        return
    }
    let layoutCrop = ground_sprite_layout_crop()
    refresh_tile_sprite(node, layoutCrop)
    if (useA5) {
        node?.SpriteRenderer.textureId = a5Textures[grassDir]
        node?.SpriteRenderer.uvRect = tile_uv_rect_for_layout_in_texture(
            GROUND_TILE_LAYOUT_CROP,
            GROUND_A5_SOURCE_CROPS[grassDir]
        )
    } else {
        node?.SpriteRenderer.textureId = a2Textures[grassDir]
        node?.SpriteRenderer.uvRect = tile_uv_rect_for_layout_in_texture(
            GROUND_TILE_LAYOUT_CROP,
            GROUND_A2_SOURCE_CROPS[grassDir]
        )
    }
}


def find_cell_child_by_name(cellChildren : array<NodeId>; childName : string) : NodeId {
    for (child in cellChildren) {
        if (child.isAlive && child.name == childName) {
            return child
        }
    }
    let invalid : NodeId
    return invalid
}


def map_cell_grid_from_node(cell : NodeId) : int2 {
    let pos = cell.localPosition.xy
    let grid = world_to_grid(pos.x, pos.y)
    return int2(int(round(grid.x)), int(round(grid.y)))
}


def apply_road_fill_tile(node : NodeId; gx, gy : int) {
    if (!node.isAlive || !world_textures_ready()) {
        return
    }
    node.isActive = true
    let roadDir = pick_e1_direction(gx, gy)
    let layoutCrop = ground_sprite_layout_crop()
    refresh_tile_sprite(node, layoutCrop)
    node?.SpriteRenderer.textureId = e1Textures[roadDir]
    node?.SpriteRenderer.uvRect = tile_uv_rect_for_precropped(GROUND_ROAD_SOURCE_CROPS[roadDir])
}


def crop_width(crop : float4) : float {
    return crop.z - crop.x + 1.0
}


def crop_height(crop : float4) : float {
    return crop.w - crop.y + 1.0
}


def ground_sprite_layout_crop() : float4 {
    return float4(
        GROUND_CROP_MIN_X,
        GROUND_CROP_MIN_Y,
        GROUND_CROP_MAX_X,
        GROUND_CROP_MAX_Y
    )
}


def tile_uv_rect_for_precropped(sourceCrop : float4) : float4 {
    let w = crop_width(sourceCrop)
    let h = crop_height(sourceCrop)
    return uv_rect_from_crop(0.0, 0.0, w - 1.0, h - 1.0, w, h)
}


def tile_uv_rect_for_layout_in_texture(layoutCrop, textureSourceCrop : float4) : float4 {
    let texW = crop_width(textureSourceCrop)
    let texH = crop_height(textureSourceCrop)
    let localMinX = layoutCrop.x - textureSourceCrop.x
    let localMinY = layoutCrop.y - textureSourceCrop.y
    let localMaxX = layoutCrop.z - textureSourceCrop.x
    let localMaxY = layoutCrop.w - textureSourceCrop.y
    return uv_rect_from_crop(localMinX, localMinY, localMaxX, localMaxY, texW, texH)
}


def tile_scale_for_crop(crop : float4) : float2 {
    let cropH = crop_height(crop)
    return float2(GROUND_TILE_WORLD_WIDTH, tile_diamond_world_height() * (cropH / GROUND_DIAMOND_FACE_HEIGHT_PX))
}


def tile_anchor_for_crop(crop : float4) : float2 {
    let cropW = crop_width(crop)
    let cropH = crop_height(crop)
    let diamondCx = (GROUND_DIAMOND_LEFT_X_PX + GROUND_DIAMOND_RIGHT_X_PX) * 0.5
    let diamondCy = (GROUND_DIAMOND_TOP_Y_PX + GROUND_DIAMOND_BOTTOM_Y_PX) * 0.5
    let spriteCx = (cropW - 1.0) * 0.5
    let spriteCy = (cropH - 1.0) * 0.5
    let pxOffset = float2(spriteCx - diamondCx, spriteCy - diamondCy)
    let spriteW = GROUND_TILE_WORLD_WIDTH
    let spriteH = tile_diamond_world_height() * (cropH / GROUND_DIAMOND_FACE_HEIGHT_PX)
    return float2(
        pxOffset.x * spriteW / cropW,
        pxOffset.y * spriteH / cropH
    )
}


def debug_hud_label() : string {
    return "{player_weapon_hud_line()}\nGrid angle: {tileEdgeAngleDeg}°\nZoom: {cameraOrthoSize}"
}


def public init_tile_angle_hud() {
    tileAngleHudNode = create_debug_text(debug_hud_label(), float2(12.0, 72.0), float2(0.0, 0.0))
    tileAngleHudNode.name = "tile_angle_hud"
    tileAngleHudNode.isActive = debugHudVisible
}


def public update_tile_angle_hud() {
    if (!tileAngleHudNode.isAlive || !debugHudVisible) {
        return
    }
    tileAngleHudNode?.UIText.text = debug_hud_label()
}


def public invalidate_map_visibility_cache() {
    mapCullResX = -1
    mapCullBoundsValid = false
}


def map_cull_world_margin() : float2 {
    let tileW = tile_half_width()
    let tileH = tile_half_height()
    let spriteH = tile_sprite_world_height()
    return float2(tileW * 2.5 + spriteH, tileH * 2.5 + spriteH)
}


def map_cell_index_from_grid(gx, gy : int) : int {
    return (gy - activeGridMinY) * activeGridWidth + (gx - activeGridMinX)
}


def set_map_cell_visible(gx, gy : int; visible : bool) {
    let idx = map_cell_index_from_grid(gx, gy)
    if (idx < 0 || idx >= length(mapCellNodes)) {
        return
    }
    if (mapCellVisible[idx] == visible) {
        return
    }
    mapCellVisible[idx] = visible
    let cell = mapCellNodes[idx]
    if (cell.isAlive) {
        cell.isActive = visible
    }
}


def register_map_cell(gx, gy : int; cell : NodeId) {
    let idx = map_cell_index_from_grid(gx, gy)
    if (idx < 0 || idx >= length(mapCellNodes)) {
        return
    }
    mapCellNodes[idx] = cell
    mapCellVisible[idx] = true
}


def init_map_cell_storage() {
    let count = activeGridWidth * activeGridHeight
    mapCellNodes |> resize(count)
    mapCellVisible |> resize(count)
    for (i in range(count)) {
        mapCellVisible[i] = true
    }
}


def map_cull_bounds_unchanged(a, b : VisibleGridBounds) : bool {
    return a.minGx == b.minGx && a.minGy == b.minGy && a.maxGx == b.maxGx && a.maxGy == b.maxGy
}


def apply_map_visibility_bounds(bounds, prevBounds : VisibleGridBounds; hasPrev : bool) {
    var minGx = bounds.minGx
    var maxGx = bounds.maxGx
    var minGy = bounds.minGy
    var maxGy = bounds.maxGy
    if (!hasPrev) {
        minGx = activeGridMinX
        maxGx = activeGridMinX + activeGridWidth - 1
        minGy = activeGridMinY
        maxGy = activeGridMinY + activeGridHeight - 1
    } else {
        minGx = min(minGx, prevBounds.minGx)
        maxGx = max(maxGx, prevBounds.maxGx)
        minGy = min(minGy, prevBounds.minGy)
        maxGy = max(maxGy, prevBounds.maxGy)
    }
    for (gy in range(minGy, maxGy + 1)) {
        for (gx in range(minGx, maxGx + 1)) {
            let visible = gx >= bounds.minGx && gx <= bounds.maxGx && gy >= bounds.minGy && gy <= bounds.maxGy
            set_map_cell_visible(gx, gy, visible)
        }
    }
}


def public last_map_visibility_bounds() : VisibleGridBounds {
    return mapCullBounds
}


def public map_visibility_ready() : bool {
    return mapCullBoundsValid
}


def public update_map_visibility() {
    if (!mapRootNode.isAlive || !cameraNode.isAlive || length(mapCellNodes) == 0) {
        return
    }
    let camPos = cameraNode.localPosition.xy
    let res = get_resolution()
    let bounds = visible_grid_bounds_from_camera(camPos, camera_visible_half_extents(), map_cull_world_margin())
    if (mapCullBoundsValid && map_cull_bounds_unchanged(bounds, mapCullBounds) && res.x == mapCullResX) {
        return
    }
    let prevBounds = mapCullBounds
    let hadPrev = mapCullBoundsValid
    mapCullResX = res.x
    mapCullBounds = bounds
    mapCullBoundsValid = true
    apply_map_visibility_bounds(bounds, prevBounds, hadPrev)
}


def refresh_tile_sprite(node : NodeId; crop : float4) {
    if (!node.isAlive) {
        return
    }
    let anchor = tile_anchor_for_crop(crop)
    let tileScale = tile_scale_for_crop(crop)
    node.localPosition = float3(anchor.x, anchor.y, 0.0)
    node.localScale = float3(tileScale.x, tileScale.y, 1.0)
}


def apply_grass_fringe_tile(node : NodeId; overlay : GrassOverlayChoice) {
    if (!node.isAlive || !world_textures_ready()) {
        return
    }
    if (overlay.kind != GrassOverlayKind.Edge && overlay.kind != GrassOverlayKind.Corner) {
        node.isActive = false
        return
    }
    node.isActive = true
    let layoutCrop = ground_sprite_layout_crop()
    refresh_tile_sprite(node, layoutCrop)
    if (overlay.kind == GrassOverlayKind.Edge) {
        node?.SpriteRenderer.textureId = a3Textures[overlay.dir]
        node?.SpriteRenderer.uvRect = tile_uv_rect_for_layout_in_texture(
            GROUND_TILE_LAYOUT_CROP,
            GROUND_A3_SOURCE_CROPS[overlay.dir]
        )
    } else {
        node?.SpriteRenderer.textureId = a4Textures[overlay.dir]
        node?.SpriteRenderer.uvRect = tile_uv_rect_for_layout_in_texture(
            GROUND_TILE_LAYOUT_CROP,
            GROUND_A4_SOURCE_CROPS[overlay.dir]
        )
    }
}


def refresh_road_layer(cellChildren : array<NodeId>; gx, gy : int) {
    let depth = depth_sort_key(float(gx), float(gy))
    let fillNode = find_cell_child_by_name(cellChildren, "road_fill")
    if (!is_road_at(gx, gy)) {
        if (fillNode.isAlive) {
            fillNode.isActive = false
        }
        return
    }
    if (!fillNode.isAlive) {
        return
    }
    fillNode?.SpriteRenderer.renderOrder = depth + DEPTH_TILE_ROAD_BIAS
    apply_road_fill_tile(fillNode, gx, gy)
}


def tile_tint_for_cell(gx, gy : int) : float4 {
    if (is_outside_world_cell(gx, gy)) {
        return GROUND_OUTSIDE_WORLD_COLOR
    }
    return float4(1.0, 1.0, 1.0, 1.0)
}


def set_sprite_tint(node : NodeId; tint : float4) {
    if (node.isAlive) {
        node?.SpriteRenderer.color = tint
    }
}


def refresh_grass_cell_layers(cellChildren : array<NodeId>; gx, gy : int; overlay : GrassOverlayChoice) {
    let a1Dir = pick_a1_direction(gx, gy)
    let tint = tile_tint_for_cell(gx, gy)
    let groundNode = find_cell_child_by_name(cellChildren, "ground")
    if (groundNode.isAlive) {
        apply_a1_tile(groundNode, gx, gy)
        set_sprite_tint(groundNode, tint)
    }
    if (length(cellChildren) < 2) {
        refresh_road_layer(cellChildren, gx, gy)
        return
    }
    if (is_grass_cell(gx, gy)) {
        if (overlay.kind == GrassOverlayKind.Interior) {
            cellChildren[1].isActive = true
            let useA5 = should_use_a5_interior(gx, gy)
            let grassDir = useA5 ? pick_a5_direction(gx, gy) : a1Dir
            apply_interior_grass_tile(cellChildren[1], grassDir, useA5)
        } elif (overlay.kind == GrassOverlayKind.Edge || overlay.kind == GrassOverlayKind.Corner) {
            cellChildren[1].isActive = true
            apply_grass_fringe_tile(cellChildren[1], overlay)
        } else {
            cellChildren[1].isActive = false
        }
        set_sprite_tint(cellChildren[1], tint)
    } elif (!is_road_at(gx, gy)) {
        cellChildren[1].isActive = false
    }
    refresh_road_layer(cellChildren, gx, gy)
}


def refresh_map_cell_geometry(cellChildren : array<NodeId>; gx, gy : int) {
    let layoutCrop = ground_sprite_layout_crop()
    let tint = tile_tint_for_cell(gx, gy)
    let depth = depth_sort_key(float(gx), float(gy))

    let groundNode = find_cell_child_by_name(cellChildren, "ground")
    if (groundNode.isAlive) {
        refresh_tile_sprite(groundNode, layoutCrop)
        groundNode?.SpriteRenderer.renderOrder = depth
        set_sprite_tint(groundNode, tint)
    }

    let grass = find_cell_child_by_name(cellChildren, "grass")
    if (grass.isAlive && grass.isActive) {
        refresh_tile_sprite(grass, layoutCrop)
        grass?.SpriteRenderer.renderOrder = depth + DEPTH_TILE_GRASS_BIAS
        set_sprite_tint(grass, tint)
    }

    let fringe = find_cell_child_by_name(cellChildren, "fringe")
    if (fringe.isAlive && fringe.isActive) {
        refresh_tile_sprite(fringe, layoutCrop)
        fringe?.SpriteRenderer.renderOrder = depth + DEPTH_TILE_GRASS_BIAS
        set_sprite_tint(fringe, tint)
    }

    let roadFill = find_cell_child_by_name(cellChildren, "road_fill")
    if (roadFill.isAlive && roadFill.isActive) {
        refresh_tile_sprite(roadFill, layoutCrop)
        roadFill?.SpriteRenderer.renderOrder = depth + DEPTH_TILE_ROAD_BIAS
        set_sprite_tint(roadFill, tint)
    }
}


def refresh_map_cell(cell : NodeId) {
    if (!cell.isAlive) {
        return
    }
    let grid = map_cell_grid_from_node(cell)
    let gx = grid.x
    let gy = grid.y
    let worldPos = grid_to_world(float(gx), float(gy))
    cell.localPosition = float3(worldPos.x, worldPos.y, 0.0)
    var inscope cellChildren = cell.get_children()
    if (length(cellChildren) < 1) {
        return
    }
    refresh_map_cell_geometry(cellChildren, gx, gy)
}


def public refresh_map_tile_geometry() {
    if (!mapRootNode.isAlive) {
        return
    }
    var inscope children = mapRootNode.get_children()
    for (cell in children) {
        refresh_map_cell(cell)
    }
}


def cell_has_active_child_named(cell : NodeId; childName : string) : bool {
    var inscope children = cell.get_children()
    for (child in children) {
        if (child.isAlive && child.name == childName && child.isActive) {
            return true
        }
    }
    return false
}


def update_terrain_mask_for_cell(cell : NodeId) {
    if (!cell.isAlive) {
        return
    }
    let grid = map_cell_grid_from_node(cell)
    let gx = grid.x
    let gy = grid.y
    if (is_outside_world_cell(gx, gy)) {
        return
    }
    let maskIdx = grass_cell_index(gx, gy)
    if (cell_has_active_child_named(cell, "road_fill")) {
        roadCells[maskIdx] = true
    }
    if (cell_has_active_child_named(cell, "grass") || cell_has_active_child_named(cell, "fringe")) {
        grassCells[maskIdx] = true
    }
}


def public begin_batched_map_build() {
    init_map_cell_storage()
    batchedMapCellCursor = 0
    batchedMapSetupDone = false
    clear(batchedMapCells)
    if (!mapRootNode.isAlive) {
        print("level.prefab: map node not found")
        batchedMapSetupDone = true
        return
    }
    if (length(mapRootNode.get_children()) == 0) {
        print("level.prefab map is empty. Run: python scripts/python/bake/bake_level_prefab.py")
        batchedMapSetupDone = true
        return
    }
    let count = activeMapWidth * activeMapHeight
    grassCells |> resize(count)
    roadCells |> resize(count)
    for (i in range(count)) {
        grassCells[i] = false
        roadCells[i] = false
    }
    batchedMapCells <- mapRootNode.get_children()
    for (cell in batchedMapCells) {
        if (!cell.isAlive) {
            continue
        }
        let grid = map_cell_grid_from_node(cell)
        register_map_cell(grid.x, grid.y, cell)
    }
    batchedMapSetupDone = true
}


def public advance_batched_map_build(maxCells : int) : bool {
    if (!batchedMapSetupDone) {
        begin_batched_map_build()
    }
    if (length(batchedMapCells) == 0) {
        return true
    }
    var processed = 0
    while (batchedMapCellCursor < length(batchedMapCells) && processed < maxCells) {
        let cell = batchedMapCells[batchedMapCellCursor]
        update_terrain_mask_for_cell(cell)
        refresh_map_cell(cell)
        batchedMapCellCursor++
        processed++
    }
    let done = batchedMapCellCursor >= length(batchedMapCells)
    if (done) {
        generate_a5_mask()
        invalidate_map_visibility_cache()
    }
    return done
}


def public batched_map_build_progress() : float {
    if (length(batchedMapCells) == 0) {
        return 1.0
    }
    return float(batchedMapCellCursor) / float(length(batchedMapCells))
}


def public release_map_build_scratch() {
    clear(batchedMapCells)
    batchedMapCellCursor = 0
    batchedMapSetupDone = false
}


def public set_tile_edge_angle_deg(angle : float) {
    tileEdgeAngleDeg = clamp(angle, TILE_ANGLE_MIN_DEG, TILE_ANGLE_MAX_DEG)
    refresh_map_tile_geometry()
    update_tile_angle_hud()
}


def public nudge_tile_edge_angle_deg(delta : float) {
    set_tile_edge_angle_deg(tileEdgeAngleDeg + delta)
}


def load_texture_array(paths : array<string>) : array<TextureId> {
    var textures : array<TextureId>
    textures |> resize(length(paths))
    for (i in range(length(paths))) {
        textures[i] = request_texture_cached(paths[i])
    }
    return <- textures
}


def public load_world_textures() {
    a1Textures <- load_texture_array(GROUND_A1_PATHS)
    a2Textures <- load_texture_array(GROUND_A2_PATHS)
    a3Textures <- load_texture_array(GROUND_A3_PATHS)
    a4Textures <- load_texture_array(GROUND_A4_PATHS)
    a5Textures <- load_texture_array(GROUND_A5_PATHS)
    e1Textures <- load_texture_array(GROUND_ROAD_PATHS)
}


def public queue_world_texture_paths() {
    for (path in GROUND_A1_PATHS) {
        queue_texture_path(path)
    }
    for (path in GROUND_A2_PATHS) {
        queue_texture_path(path)
    }
    for (path in GROUND_A3_PATHS) {
        queue_texture_path(path)
    }
    for (path in GROUND_A4_PATHS) {
        queue_texture_path(path)
    }
    for (path in GROUND_A5_PATHS) {
        queue_texture_path(path)
    }
    for (path in GROUND_ROAD_PATHS) {
        queue_texture_path(path)
    }
}


def spawn_tile_layer(
    parent : NodeId;
    name : string;
    texture : TextureId;
    layoutCrop : float4;
    uvRect : float4;
    renderOrder : int;
    tint : float4 = float4(1.0, 1.0, 1.0, 1.0)
) : NodeId {
    let anchor = tile_anchor_for_crop(layoutCrop)
    let tileScale = tile_scale_for_crop(layoutCrop)
    let node = create_node(NodeData(
        name = name,
        position = float3(anchor.x, anchor.y, 0.0),
        scale = float3(tileScale.x, tileScale.y, 1.0),
        parent = parent
    ))
    add_component(node, new SpriteRenderer(
        textureId = texture,
        uvRect = uvRect,
        useTextureSizeForScaling = false,
        renderOrder = renderOrder,
        color = tint
    ))
    return node
}


def spawn_grass_overlay_layers(
    cell : NodeId;
    gx, gy : int;
    depth : int;
    a1Dir : int;
    tint : float4 = float4(1.0, 1.0, 1.0, 1.0)
) {
    if (!is_grass_cell(gx, gy)) {
        return
    }
    let layoutCrop = ground_sprite_layout_crop()
    let overlay = pick_grass_overlay(gx, gy)
    if (overlay.kind == GrassOverlayKind.Interior) {
        let useA5 = should_use_a5_interior(gx, gy)
        let grassDir = useA5 ? pick_a5_direction(gx, gy) : a1Dir
        let grassTex = useA5 ? a5Textures[grassDir] : a2Textures[a1Dir]
        let sourceCrop = useA5 ? GROUND_A5_SOURCE_CROPS[grassDir] : GROUND_A2_SOURCE_CROPS[grassDir]
        spawn_tile_layer(
            cell,
            "grass",
            grassTex,
            layoutCrop,
            tile_uv_rect_for_layout_in_texture(GROUND_TILE_LAYOUT_CROP, sourceCrop),
            depth + DEPTH_TILE_GRASS_BIAS,
            tint
        )
    } elif (overlay.kind == GrassOverlayKind.Edge || overlay.kind == GrassOverlayKind.Corner) {
        let fringeNode = create_node(NodeData(name = "fringe", parent = cell))
        add_component(fringeNode, new SpriteRenderer(
            textureId = a3Textures[GROUND_DIR_E],
            uvRect = float4(0.0, 0.0, 1.0, 1.0),
            useTextureSizeForScaling = false,
            renderOrder = depth + DEPTH_TILE_GRASS_BIAS,
            color = tint
        ))
        apply_grass_fringe_tile(fringeNode, overlay)
    }
}


def spawn_outside_world_cell(gx, gy : int) {
    let worldPos = grid_to_world(float(gx), float(gy))
    let depth = depth_sort_key(float(gx), float(gy))
    let cell = create_node(NodeData(
        name = "cell_{gx}_{gy}",
        position = float3(worldPos.x, worldPos.y, 0.0),
        parent = mapRootNode
    ))
    register_map_cell(gx, gy, cell)
    let a1Dir = pick_a1_direction(gx, gy)
    let layoutCrop = ground_sprite_layout_crop()
    spawn_grass_overlay_layers(cell, gx, gy, depth, a1Dir, GROUND_OUTSIDE_WORLD_COLOR)
    spawn_tile_layer(
        cell,
        "ground",
        a1Textures[a1Dir],
        layoutCrop,
        tile_uv_rect_for_precropped(GROUND_A1_SOURCE_CROPS[a1Dir]),
        depth,
        GROUND_OUTSIDE_WORLD_COLOR
    )
}


def spawn_map_cell(gx, gy : int) {
    if (is_outside_world_cell(gx, gy)) {
        spawn_outside_world_cell(gx, gy)
        return
    }
    let worldPos = grid_to_world(float(gx), float(gy))
    let depth = depth_sort_key(float(gx), float(gy))
    let cell = create_node(NodeData(
        name = "cell_{gx}_{gy}",
        position = float3(worldPos.x, worldPos.y, 0.0),
        parent = mapRootNode
    ))
    register_map_cell(gx, gy, cell)
    let a1Dir = pick_a1_direction(gx, gy)
    let layoutCrop = ground_sprite_layout_crop()
    if (is_road_at(gx, gy)) {
        let fillNode = spawn_tile_layer(
            cell,
            "road_fill",
            e1Textures[GROUND_DIR_E],
            layoutCrop,
            tile_uv_rect_for_precropped(GROUND_ROAD_SOURCE_CROPS[GROUND_DIR_E]),
            depth + DEPTH_TILE_ROAD_BIAS
        )
        apply_road_fill_tile(fillNode, gx, gy)
    }
    spawn_grass_overlay_layers(cell, gx, gy, depth, a1Dir)
    spawn_tile_layer(
        cell,
        "ground",
        a1Textures[a1Dir],
        layoutCrop,
        tile_uv_rect_for_precropped(GROUND_A1_SOURCE_CROPS[a1Dir]),
        depth
    )
}


def adopt_map_from_prefab() {
    var inscope children = mapRootNode.get_children()
    for (cell in children) {
        if (!cell.isAlive) {
            continue
        }
        let grid = map_cell_grid_from_node(cell)
        register_map_cell(grid.x, grid.y, cell)
    }
}


def apply_map_cell_textures(cell : NodeId; gx, gy : int) {
    var inscope cellChildren = cell.get_children()
    let tint = tile_tint_for_cell(gx, gy)
    let depth = depth_sort_key(float(gx), float(gy))
    let overlay = pick_grass_overlay(gx, gy)

    let ground = find_cell_child_by_name(cellChildren, "ground")
    if (ground.isAlive) {
        apply_a1_tile(ground, gx, gy)
        ground?.SpriteRenderer.renderOrder = depth
        set_sprite_tint(ground, tint)
    }

    let grass = find_cell_child_by_name(cellChildren, "grass")
    if (grass.isAlive && grass.isActive) {
        grass?.SpriteRenderer.renderOrder = depth + DEPTH_TILE_GRASS_BIAS
        if (overlay.kind == GrassOverlayKind.Interior) {
            let useA5 = should_use_a5_interior(gx, gy)
            let a1Dir = pick_a1_direction(gx, gy)
            let grassDir = useA5 ? pick_a5_direction(gx, gy) : a1Dir
            apply_interior_grass_tile(grass, grassDir, useA5)
        } elif (overlay.kind == GrassOverlayKind.Edge || overlay.kind == GrassOverlayKind.Corner) {
            apply_grass_fringe_tile(grass, overlay)
        }
        set_sprite_tint(grass, tint)
    }

    let fringe = find_cell_child_by_name(cellChildren, "fringe")
    if (fringe.isAlive && fringe.isActive) {
        fringe?.SpriteRenderer.renderOrder = depth + DEPTH_TILE_GRASS_BIAS
        apply_grass_fringe_tile(fringe, overlay)
        set_sprite_tint(fringe, tint)
    }

    refresh_road_layer(cellChildren, gx, gy)
}


def public apply_map_prefab_textures() {
    if (!world_textures_ready()) {
        return
    }
    var inscope children = mapRootNode.get_children()
    for (cell in children) {
        if (!cell.isAlive) {
            continue
        }
        let grid = map_cell_grid_from_node(cell)
        apply_map_cell_textures(cell, grid.x, grid.y)
    }
}


def public build_map() {
    init_map_cell_storage()
    if (!mapRootNode.isAlive) {
        print("level.prefab: map node not found")
        return
    }
    if (length(mapRootNode.get_children()) == 0) {
        print("level.prefab map is empty. Run: python scripts/python/bake/bake_level_prefab.py")
        return
    }
    adopt_map_from_prefab()
    rebuild_terrain_masks_from_prefab()
    generate_a5_mask()
    refresh_map_tile_geometry()
    invalidate_map_visibility_cache()
}


def public refresh_level_prefab_visuals() : bool {
    if (!gameTexturesVerified) {
        return false
    }
    if (!mapRootNode.isAlive || length(mapRootNode.get_children()) == 0) {
        return false
    }
    if (length(grassCells) != activeMapWidth * activeMapHeight) {
        init_map_cell_storage()
        adopt_map_from_prefab()
        rebuild_terrain_masks_from_prefab()
        generate_a5_mask()
    }
    refresh_map_tile_geometry()
    apply_map_prefab_textures()
    invalidate_map_visibility_cache()
    return true
}


def rebuild_terrain_masks_from_prefab() {
    let count = activeMapWidth * activeMapHeight
    grassCells |> resize(count)
    roadCells |> resize(count)
    for (i in range(count)) {
        grassCells[i] = false
        roadCells[i] = false
    }
    var inscope children = mapRootNode.get_children()
    for (cell in children) {
        if (!cell.isAlive) {
            continue
        }
        let grid = map_cell_grid_from_node(cell)
        let gx = grid.x
        let gy = grid.y
        if (is_outside_world_cell(gx, gy)) {
            continue
        }
        let maskIdx = grass_cell_index(gx, gy)
        if (cell_has_active_child_named(cell, "road_fill")) {
            roadCells[maskIdx] = true
        }
        if (cell_has_active_child_named(cell, "grass") || cell_has_active_child_named(cell, "fringe")) {
            grassCells[maskIdx] = true
        }
    }
}


def public build_map_legacy() {
    generate_grass_mask()
    generate_road_mask()
    generate_a5_mask()
    init_map_cell_storage()
    if (!mapRootNode.isAlive) {
        let levelNode = find_child_recursive("level")
        mapRootNode = create_node(NodeData(name = "map", parent = levelNode))
    }
    var inscope existing = mapRootNode.get_children()
    for (child in existing) {
        remove_node(child)
    }
    for (gy in range(activeGridMinY, activeGridMinY + activeGridHeight)) {
        for (gx in range(activeGridMinX, activeGridMinX + activeGridWidth)) {
            spawn_map_cell(gx, gy)
        }
    }
    invalidate_map_visibility_cache()
}


def public map_center_world() : float2 {
    return grid_to_world(float(activeMapWidth) * 0.5, float(activeMapHeight) * 0.5)
}


def is_map_tile_layer_name(name : string) : bool {
    return name == "ground" || name == "grass" || name == "fringe" || name == "road_fill"
}


// Toggle ground/grass/road sprites. Hide while placing props in the prefab editor
// (Eden picks lowest uid among overlaps: props < grass < ground when baked in that order).
def public set_map_tile_sprites_active(active : bool) {
    if (!mapRootNode.isAlive) {
        return
    }
    var inscope cells = mapRootNode.get_children()
    for (cell in cells) {
        if (!cell.isAlive) {
            continue
        }
        var inscope layers = cell.get_children()
        for (layer in layers) {
            if (layer.isAlive && is_map_tile_layer_name(layer.name)) {
                layer.isActive = active
            }
        }
    }
}
