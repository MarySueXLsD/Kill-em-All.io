require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/prop_footprint
require strings
require scripts/das/world/props_collision
require scripts/das/world/props_sprite_math
require scripts/das/world/props_walls
require scripts/das/world/prefab_texture_hydrate
require scripts/das/world/collision_library
require scripts/das/world/tile_texture_hint

module props_sprites public

def record_collision_lines_px(
    feetGrid : float2;
    crop : float4;
    feetPx : float2;
    worldWidth : float;
    wallLinesPx : array<float4>;
    blocksProjectiles : bool = true
) {
    for (linePx in wallLinesPx) {
        let worldA = wall_sprite_pixel_to_world(
            feetGrid, linePx.x, linePx.y, crop, feetPx, worldWidth
        )
        let worldB = wall_sprite_pixel_to_world(
            feetGrid, linePx.z, linePx.w, crop, feetPx, worldWidth
        )
        record_prop_wall_segment(worldA, worldB, blocksProjectiles)
    }
}


def feet_grid_for_collision_asset(node : NodeId; assetIndex : int) : float2 {
    let worldPos = node.worldPosition.xy
    let crop = collision_asset_crop(assetIndex)
    let feetPx = collision_asset_feet_px(assetIndex)
    let worldWidth = collision_asset_world_width(assetIndex)
    let anchorOffset = prop_anchor_offset(crop, feetPx, worldWidth)
    return feet_grid_for_anchor_world_offset(worldPos, anchorOffset)
}


def record_collision_for_asset_index(assetIndex : int; feetGrid : float2) {
    let crop = collision_asset_crop(assetIndex)
    let feetPx = collision_asset_feet_px(assetIndex)
    let worldWidth = collision_asset_world_width(assetIndex)
    let blocksProjectiles = !collision_asset_low(assetIndex)
    let segCount = collision_asset_segment_count(assetIndex)
    for (si in range(segCount)) {
        let linePx = collision_asset_segment(assetIndex, si)
        let worldA = wall_sprite_pixel_to_world(
            feetGrid, linePx.x, linePx.y, crop, feetPx, worldWidth
        )
        let worldB = wall_sprite_pixel_to_world(
            feetGrid, linePx.z, linePx.w, crop, feetPx, worldWidth
        )
        record_prop_wall_segment(worldA, worldB, blocksProjectiles)
    }
}


def accumulate_collision_y_bounds(bounds : CollisionYBounds; point : float2) : CollisionYBounds {
    return CollisionYBounds(
        yMin = min(bounds.yMin, point.y),
        yMax = max(bounds.yMax, point.y),
        xMin = min(bounds.xMin, point.x),
        xMax = max(bounds.xMax, point.x)
    )
}


def empty_collision_y_bounds() : CollisionYBounds {
    return CollisionYBounds(
        yMin = 1e30,
        yMax = -1e30,
        xMin = 1e30,
        xMax = -1e30
    )
}


def collision_y_bounds_valid(bounds : CollisionYBounds) : bool {
    return bounds.yMin <= bounds.yMax && bounds.xMin <= bounds.xMax
}


def collision_asset_world_y_bounds(assetIndex : int; feetGrid : float2) : CollisionYBounds {
    let crop = collision_asset_crop(assetIndex)
    let feetPx = collision_asset_feet_px(assetIndex)
    let worldWidth = collision_asset_world_width(assetIndex)
    var bounds = empty_collision_y_bounds()
    let segCount = collision_asset_segment_count(assetIndex)
    for (si in range(segCount)) {
        let linePx = collision_asset_segment(assetIndex, si)
        bounds = accumulate_collision_y_bounds(
            bounds,
            wall_sprite_pixel_to_world(feetGrid, linePx.x, linePx.y, crop, feetPx, worldWidth)
        )
        bounds = accumulate_collision_y_bounds(
            bounds,
            wall_sprite_pixel_to_world(feetGrid, linePx.z, linePx.w, crop, feetPx, worldWidth)
        )
    }
    if (!collision_y_bounds_valid(bounds)) {
        let feet = grid_to_world(feetGrid.x, feetGrid.y)
        return legs_collision_y_bounds(feet, PLAYER_WORLD_HEIGHT)
    }
    return bounds
}


def spawn_misc_prop(
    texture : TextureId;
    crop : float4;
    feetPx : float2;
    worldWidth : float;
    feetGrid : float2;
    wallLinesPx : array<float4>;
    name : string;
    propId : string
) {
    spawn_prop_sprite(texture, crop, feetPx, worldWidth, feetGrid, name, propsRootNode, propId)
    record_collision_lines_px(feetGrid, crop, feetPx, worldWidth, wallLinesPx, true)
}


def spawn_misc_with_extras(
    texture : TextureId;
    crop : float4;
    feetPx : float2;
    worldWidth : float;
    primaryGrid : float2;
    extraGrids : array<float2>;
    wallLinesPx : array<float4>;
    namePrefix : string;
    propId : string
) {
    spawn_misc_prop(texture, crop, feetPx, worldWidth, primaryGrid, wallLinesPx, namePrefix, propId)
    var copyIdx = 0
    for (extraGrid in extraGrids) {
        spawn_misc_prop(
            texture, crop, feetPx, worldWidth, extraGrid, wallLinesPx,
            "{namePrefix}_copy_{copyIdx}", propId
        )
        copyIdx++
    }
}


def spawn_misc_b12_e() {
    spawn_misc_with_extras(
        miscB12Texture,
        PROP_MISC_B12_E_CROP,
        PROP_MISC_B12_E_FEET_PX,
        PROP_MISC_B12_E_WORLD_WIDTH,
        PROP_MISC_B12_E_FEET_GRID,
        PROP_MISC_B12_E_EXTRA_FEET_GRIDS,
        PROP_MISC_B12_E_WALL_LINES_PX,
        "misc_b12_e",
        "misc_b12_e"
    )
}


def spawn_misc_b5_e() {
    spawn_misc_with_extras(
        miscB5Texture,
        PROP_MISC_B5_E_CROP,
        PROP_MISC_B5_E_FEET_PX,
        PROP_MISC_B5_E_WORLD_WIDTH,
        PROP_MISC_B5_E_FEET_GRID,
        PROP_MISC_B5_E_EXTRA_FEET_GRIDS,
        PROP_MISC_B5_E_WALL_LINES_PX,
        "misc_b5_e",
        "misc_b5_e"
    )
}


def spawn_misc_b10_e() {
    spawn_misc_with_extras(
        miscB10Texture,
        PROP_MISC_B10_E_CROP,
        PROP_MISC_B10_E_FEET_PX,
        PROP_MISC_B10_E_WORLD_WIDTH,
        PROP_MISC_B10_E_FEET_GRID,
        PROP_MISC_B10_E_EXTRA_FEET_GRIDS,
        PROP_MISC_B10_E_WALL_LINES_PX,
        "misc_b10_e",
        "misc_b10_e"
    )
}


def spawn_misc_b8_e() {
    spawn_misc_with_extras(
        miscB8Texture,
        PROP_MISC_B8_E_CROP,
        PROP_MISC_B8_E_FEET_PX,
        PROP_MISC_B8_E_WORLD_WIDTH,
        PROP_MISC_B8_E_FEET_GRID,
        PROP_MISC_B8_E_EXTRA_FEET_GRIDS,
        PROP_MISC_B8_E_WALL_LINES_PX,
        "misc_b8_e",
        "misc_b8_e"
    )
}


def spawn_misc_b25_e() {
    spawn_misc_prop(
        miscB25Texture,
        PROP_MISC_B25_E_CROP,
        PROP_MISC_B25_E_FEET_PX,
        PROP_MISC_B25_E_WORLD_WIDTH,
        PROP_MISC_B25_E_FEET_GRID,
        PROP_MISC_B25_E_WALL_LINES_PX,
        "misc_b25_e",
        "misc_b25_e"
    )
}


def spawn_misc_b3_e() {
    spawn_misc_prop(
        miscB3Texture,
        PROP_MISC_B3_E_CROP,
        PROP_MISC_B3_E_FEET_PX,
        PROP_MISC_B3_E_WORLD_WIDTH,
        PROP_MISC_B3_E_FEET_GRID,
        PROP_MISC_B3_E_WALL_LINES_PX,
        "misc_b3_e",
        "misc_b3_e"
    )
}


def spawn_misc_b14_e() {
    spawn_misc_with_extras(
        miscB14Texture,
        PROP_MISC_B14_E_CROP,
        PROP_MISC_B14_E_FEET_PX,
        PROP_MISC_B14_E_WORLD_WIDTH,
        PROP_MISC_B14_E_FEET_GRID,
        PROP_MISC_B14_E_EXTRA_FEET_GRIDS,
        PROP_MISC_B14_E_WALL_LINES_PX,
        "misc_b14_e",
        "misc_b14_e"
    )
}


def spawn_misc_b11_e() {
    spawn_misc_prop(
        miscB11Texture,
        PROP_MISC_B11_E_CROP,
        PROP_MISC_B11_E_FEET_PX,
        PROP_MISC_B11_E_WORLD_WIDTH,
        PROP_MISC_B11_E_FEET_GRID,
        PROP_MISC_B11_E_WALL_LINES_PX,
        "misc_b11_e",
        "misc_b11_e"
    )
}


def spawn_misc_b2_e() {
    spawn_misc_prop(
        miscB2Texture,
        PROP_MISC_B2_E_CROP,
        PROP_MISC_B2_E_FEET_PX,
        PROP_MISC_B2_E_WORLD_WIDTH,
        PROP_MISC_B2_E_FEET_GRID,
        PROP_MISC_B2_E_WALL_LINES_PX,
        "misc_b2_e",
        "misc_b2_e"
    )
}


def spawn_misc_b7_e() {
    spawn_misc_prop(
        miscB7Texture,
        PROP_MISC_B7_E_CROP,
        PROP_MISC_B7_E_FEET_PX,
        PROP_MISC_B7_E_WORLD_WIDTH,
        PROP_MISC_B7_E_FEET_GRID,
        PROP_MISC_B7_E_WALL_LINES_PX,
        "misc_b7_e",
        "misc_b7_e"
    )
}


def spawn_misc_b9_e() {
    spawn_misc_prop(
        miscB9Texture,
        PROP_MISC_B9_E_CROP,
        PROP_MISC_B9_E_FEET_PX,
        PROP_MISC_B9_E_WORLD_WIDTH,
        PROP_MISC_B9_E_FEET_GRID,
        PROP_MISC_B9_E_WALL_LINES_PX,
        "misc_b9_e",
        "misc_b9_e"
    )
}


def spawn_misc_b40_e() {
    spawn_misc_prop(
        miscB40Texture,
        PROP_MISC_B40_E_CROP,
        PROP_MISC_B40_E_FEET_PX,
        PROP_MISC_B40_E_WORLD_WIDTH,
        PROP_MISC_B40_E_FEET_GRID,
        PROP_MISC_B40_E_WALL_LINES_PX,
        "misc_b40_e",
        "misc_b40_e"
    )
}


def spawn_misc_b20_e() {
    spawn_misc_prop(
        miscB20Texture,
        PROP_MISC_B20_E_CROP,
        PROP_MISC_B20_E_FEET_PX,
        PROP_MISC_B20_E_WORLD_WIDTH,
        PROP_MISC_B20_E_FEET_GRID,
        PROP_MISC_B20_E_WALL_LINES_PX,
        "misc_b20_e",
        "misc_b20_e"
    )
}


def spawn_misc_b1_e() {
    spawn_misc_prop(
        miscB1Texture,
        PROP_MISC_B1_E_CROP,
        PROP_MISC_B1_E_FEET_PX,
        PROP_MISC_B1_E_WORLD_WIDTH,
        PROP_MISC_B1_E_FEET_GRID,
        PROP_MISC_B1_E_WALL_LINES_PX,
        "misc_b1_e",
        "misc_b1_e"
    )
}





def public prop_textures_ready() : bool {
    return propTexturesLoaded
}


def public load_prop_textures() {
    miscB12Texture = request_texture_cached(PROP_MISC_B12_E_PATH)
    miscB5Texture = request_texture_cached(PROP_MISC_B5_E_PATH)
    miscB10Texture = request_texture_cached(PROP_MISC_B10_E_PATH)
    miscB8Texture = request_texture_cached(PROP_MISC_B8_E_PATH)
    miscB25Texture = request_texture_cached(PROP_MISC_B25_E_PATH)
    miscB3Texture = request_texture_cached(PROP_MISC_B3_E_PATH)
    miscB14Texture = request_texture_cached(PROP_MISC_B14_E_PATH)
    miscB11Texture = request_texture_cached(PROP_MISC_B11_E_PATH)
    miscB2Texture = request_texture_cached(PROP_MISC_B2_E_PATH)
    miscB7Texture = request_texture_cached(PROP_MISC_B7_E_PATH)
    miscB9Texture = request_texture_cached(PROP_MISC_B9_E_PATH)
    miscB40Texture = request_texture_cached(PROP_MISC_B40_E_PATH)
    miscB20Texture = request_texture_cached(PROP_MISC_B20_E_PATH)
    miscB1Texture = request_texture_cached(PROP_MISC_B1_E_PATH)
    wallB1ETexture = request_texture_cached(WALL_B1_E_PATH)
    wallB1WTexture = request_texture_cached(WALL_B1_W_PATH)
    wallB1NTexture = request_texture_cached(WALL_B1_N_PATH)
    wallB1STexture = request_texture_cached(WALL_B1_S_PATH)
    wallB2ETexture = request_texture_cached(WALL_B2_E_PATH)
    wallB2WTexture = request_texture_cached(WALL_B2_W_PATH)
    wallB2NTexture = request_texture_cached(WALL_B2_N_PATH)
    wallB2STexture = request_texture_cached(WALL_B2_S_PATH)
    propTexturesLoaded = texture_id_is_valid(miscB1Texture) && texture_id_is_valid(wallB1ETexture)
}


def prop_id_from_node_name(name : string) : string {
    for (id in known_misc_prop_ids()) {
        if (name == id) {
            return id
        }
    }
    return ""
}


def known_misc_prop_ids() : array<string> {
    var ids : array<string>
    push(ids, "misc_b12_e")
    push(ids, "misc_b10_e")
    push(ids, "misc_b14_e")
    push(ids, "misc_b40_e")
    push(ids, "misc_b25_e")
    push(ids, "misc_b20_e")
    push(ids, "misc_b11_e")
    push(ids, "misc_b5_e")
    push(ids, "misc_b8_e")
    push(ids, "misc_b3_e")
    push(ids, "misc_b2_e")
    push(ids, "misc_b7_e")
    push(ids, "misc_b9_e")
    push(ids, "misc_b1_e")
    return <- ids
}


def prop_has_sprite_visual(node : NodeId) : bool {
    if (node?.SpriteRenderer != null) {
        return true
    }
    var inscope children = node.get_children()
    for (child in children) {
        if (child?.SpriteRenderer != null) {
            return true
        }
    }
    return false
}


def prop_anchor_offset_for_id(propId : string) : float2 {
    if (propId == "misc_b12_e") {
        return prop_anchor_offset(PROP_MISC_B12_E_CROP, PROP_MISC_B12_E_FEET_PX, PROP_MISC_B12_E_WORLD_WIDTH)
    }
    if (propId == "misc_b5_e") {
        return prop_anchor_offset(PROP_MISC_B5_E_CROP, PROP_MISC_B5_E_FEET_PX, PROP_MISC_B5_E_WORLD_WIDTH)
    }
    if (propId == "misc_b10_e") {
        return prop_anchor_offset(PROP_MISC_B10_E_CROP, PROP_MISC_B10_E_FEET_PX, PROP_MISC_B10_E_WORLD_WIDTH)
    }
    if (propId == "misc_b8_e") {
        return prop_anchor_offset(PROP_MISC_B8_E_CROP, PROP_MISC_B8_E_FEET_PX, PROP_MISC_B8_E_WORLD_WIDTH)
    }
    if (propId == "misc_b25_e") {
        return prop_anchor_offset(PROP_MISC_B25_E_CROP, PROP_MISC_B25_E_FEET_PX, PROP_MISC_B25_E_WORLD_WIDTH)
    }
    if (propId == "misc_b3_e") {
        return prop_anchor_offset(PROP_MISC_B3_E_CROP, PROP_MISC_B3_E_FEET_PX, PROP_MISC_B3_E_WORLD_WIDTH)
    }
    if (propId == "misc_b14_e") {
        return prop_anchor_offset(PROP_MISC_B14_E_CROP, PROP_MISC_B14_E_FEET_PX, PROP_MISC_B14_E_WORLD_WIDTH)
    }
    if (propId == "misc_b11_e") {
        return prop_anchor_offset(PROP_MISC_B11_E_CROP, PROP_MISC_B11_E_FEET_PX, PROP_MISC_B11_E_WORLD_WIDTH)
    }
    if (propId == "misc_b2_e") {
        return prop_anchor_offset(PROP_MISC_B2_E_CROP, PROP_MISC_B2_E_FEET_PX, PROP_MISC_B2_E_WORLD_WIDTH)
    }
    if (propId == "misc_b7_e") {
        return prop_anchor_offset(PROP_MISC_B7_E_CROP, PROP_MISC_B7_E_FEET_PX, PROP_MISC_B7_E_WORLD_WIDTH)
    }
    if (propId == "misc_b9_e") {
        return prop_anchor_offset(PROP_MISC_B9_E_CROP, PROP_MISC_B9_E_FEET_PX, PROP_MISC_B9_E_WORLD_WIDTH)
    }
    if (propId == "misc_b40_e") {
        return prop_anchor_offset(PROP_MISC_B40_E_CROP, PROP_MISC_B40_E_FEET_PX, PROP_MISC_B40_E_WORLD_WIDTH)
    }
    if (propId == "misc_b20_e") {
        return prop_anchor_offset(PROP_MISC_B20_E_CROP, PROP_MISC_B20_E_FEET_PX, PROP_MISC_B20_E_WORLD_WIDTH)
    }
    if (propId == "misc_b1_e") {
        return prop_anchor_offset(PROP_MISC_B1_E_CROP, PROP_MISC_B1_E_FEET_PX, PROP_MISC_B1_E_WORLD_WIDTH)
    }
    return float2(0.0)
}


def feet_grid_for_marker_node(node : NodeId; propId : string) : float2 {
    let worldPos = node.worldPosition.xy
    if (prop_has_sprite_visual(node)) {
        let anchorOffset = prop_anchor_offset_for_id(propId)
        return feet_grid_for_anchor_world_offset(worldPos, anchorOffset)
    }
    return world_to_grid(worldPos.x, worldPos.y)
}


def resolve_prop_id_from_footprint(node : NodeId) : string {
    var footprint = node?.PropFootprint
    if (footprint != null && length(footprint.propId) > 0) {
        return footprint.propId
    }
    return prop_id_from_node_name(node.name)
}


def record_misc_collision_lines(
    feetGrid : float2;
    crop : float4;
    feetPx : float2;
    worldWidth : float;
    wallLinesPx : array<float4>
) {
    record_collision_lines_px(feetGrid, crop, feetPx, worldWidth, wallLinesPx, true)
}


def record_collision_for_footprint(propId : string; feetGrid : float2) {
    if (propId == "misc_b12_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B12_E_CROP, PROP_MISC_B12_E_FEET_PX, PROP_MISC_B12_E_WORLD_WIDTH,
            PROP_MISC_B12_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b5_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B5_E_CROP, PROP_MISC_B5_E_FEET_PX, PROP_MISC_B5_E_WORLD_WIDTH,
            PROP_MISC_B5_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b10_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B10_E_CROP, PROP_MISC_B10_E_FEET_PX, PROP_MISC_B10_E_WORLD_WIDTH,
            PROP_MISC_B10_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b8_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B8_E_CROP, PROP_MISC_B8_E_FEET_PX, PROP_MISC_B8_E_WORLD_WIDTH,
            PROP_MISC_B8_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b25_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B25_E_CROP, PROP_MISC_B25_E_FEET_PX, PROP_MISC_B25_E_WORLD_WIDTH,
            PROP_MISC_B25_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b3_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B3_E_CROP, PROP_MISC_B3_E_FEET_PX, PROP_MISC_B3_E_WORLD_WIDTH,
            PROP_MISC_B3_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b14_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B14_E_CROP, PROP_MISC_B14_E_FEET_PX, PROP_MISC_B14_E_WORLD_WIDTH,
            PROP_MISC_B14_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b11_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B11_E_CROP, PROP_MISC_B11_E_FEET_PX, PROP_MISC_B11_E_WORLD_WIDTH,
            PROP_MISC_B11_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b2_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B2_E_CROP, PROP_MISC_B2_E_FEET_PX, PROP_MISC_B2_E_WORLD_WIDTH,
            PROP_MISC_B2_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b7_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B7_E_CROP, PROP_MISC_B7_E_FEET_PX, PROP_MISC_B7_E_WORLD_WIDTH,
            PROP_MISC_B7_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b9_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B9_E_CROP, PROP_MISC_B9_E_FEET_PX, PROP_MISC_B9_E_WORLD_WIDTH,
            PROP_MISC_B9_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b40_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B40_E_CROP, PROP_MISC_B40_E_FEET_PX, PROP_MISC_B40_E_WORLD_WIDTH,
            PROP_MISC_B40_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b20_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B20_E_CROP, PROP_MISC_B20_E_FEET_PX, PROP_MISC_B20_E_WORLD_WIDTH,
            PROP_MISC_B20_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "misc_b1_e") {
        record_misc_collision_lines(
            feetGrid, PROP_MISC_B1_E_CROP, PROP_MISC_B1_E_FEET_PX, PROP_MISC_B1_E_WORLD_WIDTH,
            PROP_MISC_B1_E_WALL_LINES_PX
        )
        return
    }
    if (propId == "wall_b1_e") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B1_E_CROP, WALL_B1_E_FEET_PX,
            WALL_B1_E_BOTTOM_PX_A, WALL_B1_E_BOTTOM_PX_B, WALL_B1_WORLD_WIDTH, true
        )
        return
    }
    if (propId == "wall_b1_w") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B1_W_CROP, WALL_B1_W_FEET_PX,
            WALL_B1_W_BOTTOM_PX_A, WALL_B1_W_BOTTOM_PX_B, WALL_B1_WORLD_WIDTH, true
        )
        return
    }
    if (propId == "wall_b1_n") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B1_N_CROP, WALL_B1_N_FEET_PX,
            WALL_B1_N_BOTTOM_PX_A, WALL_B1_N_BOTTOM_PX_B, WALL_B1_WORLD_WIDTH, true
        )
        return
    }
    if (propId == "wall_b1_s") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B1_S_CROP, WALL_B1_S_FEET_PX,
            WALL_B1_S_BOTTOM_PX_A, WALL_B1_S_BOTTOM_PX_B, WALL_B1_WORLD_WIDTH, true
        )
        return
    }
    if (propId == "wall_b2_e") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_E_CROP, WALL_B2_E_FEET_PX,
            WALL_B2_E_BOTTOM_PX[0], WALL_B2_E_BOTTOM_PX[1], WALL_B2_WORLD_WIDTH, true
        )
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_E_CROP, WALL_B2_E_FEET_PX,
            WALL_B2_E_BOTTOM_PX[1], WALL_B2_E_BOTTOM_PX[2], WALL_B2_WORLD_WIDTH, true
        )
        return
    }
    if (propId == "wall_b2_w") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_W_CROP, WALL_B2_W_FEET_PX,
            WALL_B2_W_BOTTOM_PX[0], WALL_B2_W_BOTTOM_PX[1], WALL_B2_WORLD_WIDTH, true
        )
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_W_CROP, WALL_B2_W_FEET_PX,
            WALL_B2_W_BOTTOM_PX[1], WALL_B2_W_BOTTOM_PX[2], WALL_B2_WORLD_WIDTH, true
        )
        return
    }
    if (propId == "wall_b2_n") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_N_CROP, WALL_B2_N_FEET_PX,
            WALL_B2_N_BOTTOM_PX[0], WALL_B2_N_BOTTOM_PX[1], WALL_B2_WORLD_WIDTH, true
        )
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_N_CROP, WALL_B2_N_FEET_PX,
            WALL_B2_N_BOTTOM_PX[1], WALL_B2_N_BOTTOM_PX[2], WALL_B2_WORLD_WIDTH, true
        )
        return
    }
    if (propId == "wall_b2_s") {
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_S_CROP, WALL_B2_S_FEET_PX,
            WALL_B2_S_BOTTOM_PX[0], WALL_B2_S_BOTTOM_PX[1], WALL_B2_WORLD_WIDTH, true
        )
        record_border_wall_bottom_segment(
            feetGrid, WALL_B2_S_CROP, WALL_B2_S_FEET_PX,
            WALL_B2_S_BOTTOM_PX[1], WALL_B2_S_BOTTOM_PX[2], WALL_B2_WORLD_WIDTH, true
        )
    }
}


def set_prop_sprite_visual(node : NodeId; texture : TextureId; crop : float4) {
    if (!node.isAlive || node?.SpriteRenderer == null || !propTexturesLoaded) {
        return
    }
    node?.SpriteRenderer.textureId = texture
    node?.SpriteRenderer.uvRect = prop_uv_rect(crop)
}


def apply_prop_sprite_texture(node : NodeId; propId : string) : bool {
    if (propId == "misc_b12_e") {
        set_prop_sprite_visual(node, miscB12Texture, PROP_MISC_B12_E_CROP)
        return true
    }
    if (propId == "misc_b5_e") {
        set_prop_sprite_visual(node, miscB5Texture, PROP_MISC_B5_E_CROP)
        return true
    }
    if (propId == "misc_b10_e") {
        set_prop_sprite_visual(node, miscB10Texture, PROP_MISC_B10_E_CROP)
        return true
    }
    if (propId == "misc_b8_e") {
        set_prop_sprite_visual(node, miscB8Texture, PROP_MISC_B8_E_CROP)
        return true
    }
    if (propId == "misc_b25_e") {
        set_prop_sprite_visual(node, miscB25Texture, PROP_MISC_B25_E_CROP)
        return true
    }
    if (propId == "misc_b3_e") {
        set_prop_sprite_visual(node, miscB3Texture, PROP_MISC_B3_E_CROP)
        return true
    }
    if (propId == "misc_b14_e") {
        set_prop_sprite_visual(node, miscB14Texture, PROP_MISC_B14_E_CROP)
        return true
    }
    if (propId == "misc_b11_e") {
        set_prop_sprite_visual(node, miscB11Texture, PROP_MISC_B11_E_CROP)
        return true
    }
    if (propId == "misc_b2_e") {
        set_prop_sprite_visual(node, miscB2Texture, PROP_MISC_B2_E_CROP)
        return true
    }
    if (propId == "misc_b7_e") {
        set_prop_sprite_visual(node, miscB7Texture, PROP_MISC_B7_E_CROP)
        return true
    }
    if (propId == "misc_b9_e") {
        set_prop_sprite_visual(node, miscB9Texture, PROP_MISC_B9_E_CROP)
        return true
    }
    if (propId == "misc_b40_e") {
        set_prop_sprite_visual(node, miscB40Texture, PROP_MISC_B40_E_CROP)
        return true
    }
    if (propId == "misc_b20_e") {
        set_prop_sprite_visual(node, miscB20Texture, PROP_MISC_B20_E_CROP)
        return true
    }
    if (propId == "misc_b1_e") {
        set_prop_sprite_visual(node, miscB1Texture, PROP_MISC_B1_E_CROP)
        return true
    }
    if (propId == "wall_b1_e") {
        set_prop_sprite_visual(node, wallB1ETexture, WALL_B1_E_CROP)
        return true
    }
    if (propId == "wall_b1_w") {
        set_prop_sprite_visual(node, wallB1WTexture, WALL_B1_W_CROP)
        return true
    }
    if (propId == "wall_b1_n") {
        set_prop_sprite_visual(node, wallB1NTexture, WALL_B1_N_CROP)
        return true
    }
    if (propId == "wall_b1_s") {
        set_prop_sprite_visual(node, wallB1STexture, WALL_B1_S_CROP)
        return true
    }
    if (propId == "wall_b2_e") {
        set_prop_sprite_visual(node, wallB2ETexture, WALL_B2_E_CROP)
        return true
    }
    if (propId == "wall_b2_w") {
        set_prop_sprite_visual(node, wallB2WTexture, WALL_B2_W_CROP)
        return true
    }
    if (propId == "wall_b2_n") {
        set_prop_sprite_visual(node, wallB2NTexture, WALL_B2_N_CROP)
        return true
    }
    if (propId == "wall_b2_s") {
        set_prop_sprite_visual(node, wallB2STexture, WALL_B2_S_CROP)
        return true
    }
    return false
}


def apply_prefab_prop_textures(root : NodeId) {
    if (!root.isAlive) {
        return
    }
    let propId = resolve_prop_id_from_footprint(root)
    if (length(propId) > 0) {
        apply_prop_sprite_texture(root, propId)
    }
    var inscope children = root.get_children()
    for (child in children) {
        apply_prefab_prop_textures(child)
    }
}


def register_prefab_prop_node(node : NodeId; propId : string) {
    var feetGrid = feet_grid_for_marker_node(node, propId)
    var collisionRecorded = false
    var projectilePassable = false
    var assetIdx = -1
    if (node?.TileTextureHint != null) {
        let texPath = node?.TileTextureHint.texturePath
        assetIdx = find_collision_asset_index(texPath)
        if (assetIdx >= 0) {
            feetGrid = feet_grid_for_collision_asset(node, assetIdx)
            record_collision_for_asset_index(assetIdx, feetGrid)
            collisionRecorded = true
            projectilePassable = collision_asset_low(assetIdx)
        }
    }
    if (!collisionRecorded) {
        record_collision_for_footprint(propId, feetGrid)
    }
    let feet = grid_to_world(feetGrid.x, feetGrid.y)
    apply_border_wall_render_order(node, feet)
    var collisionBounds = assetIdx >= 0 ? collision_asset_world_y_bounds(assetIdx, feetGrid) : sprite_node_collision_y_bounds(node)
    register_prop_sprite_track(node, feet, projectilePassable, collisionBounds)
    if (!is_decor_border_wall_name(node.name) && node?.SpriteRenderer != null) {
        let propIdx = length(propSpriteNodes) - 1
        let propColl = prop_collision_bounds_at(propIdx, node)
        node?.SpriteRenderer.renderOrder = depth_sort_from_sprite_bottom(propColl.yMax)
    }
}


def should_index_prefab_prop_node(node : NodeId; propId : string) : bool {
    if (node?.SpriteRenderer == null) {
        return false
    }
    if (length(propId) > 0) {
        return true
    }
    if (node?.TileTextureHint != null) {
        let texPath = node?.TileTextureHint.texturePath
        return find_collision_asset_index(texPath) >= 0
    }
    return false
}


def index_prefab_props(root : NodeId) {
    if (!root.isAlive) {
        return
    }
    let propId = resolve_prop_id_from_footprint(root)
    if (should_index_prefab_prop_node(root, propId)) {
        register_prefab_prop_node(root, propId)
    }
    var inscope children = root.get_children()
    for (child in children) {
        index_prefab_props(child)
    }
}


def clear_prop_root_children(root : NodeId) {
    if (!root.isAlive) {
        return
    }
    var inscope children = root.get_children()
    for (child in children) {
        remove_node(child)
    }
}


def ensure_level_prop_roots() {
    let levelNode = find_child_recursive("level")
    if (!wallsRootNode.isAlive) {
        wallsRootNode = create_node(NodeData(name = "walls", parent = levelNode))
    }
    if (!propsRootNode.isAlive) {
        propsRootNode = create_node(NodeData(name = "props", parent = levelNode))
    }
}


def refresh_border_wall_render_orders(root : NodeId) {
    if (!root.isAlive) {
        return
    }
    let propId = resolve_prop_id_from_footprint(root)
    if (length(propId) > 0 && is_decor_border_wall_name(root.name) && root?.SpriteRenderer != null) {
        let feetGrid = feet_grid_for_marker_node(root, propId)
        let feet = grid_to_world(feetGrid.x, feetGrid.y)
        apply_border_wall_render_order(root, feet)
    }
    var inscope children = root.get_children()
    for (child in children) {
        refresh_border_wall_render_orders(child)
    }
}


def public refresh_level_prop_visuals() {
    if (!gameTexturesVerified || !propTexturesLoaded || !wallsRootNode.isAlive || !propsRootNode.isAlive) {
        return
    }
    apply_prefab_prop_textures(wallsRootNode)
    apply_prefab_prop_textures(propsRootNode)
    refresh_border_wall_render_orders(wallsRootNode)
}


def public init_world_from_prefab() {
    clear(propBlockers)
    clear(propWallSegmentsA)
    clear(propWallSegmentsB)
    clear(propProjectileWallSegmentsA)
    clear(propProjectileWallSegmentsB)
    clear(borderWallBottomA)
    clear(borderWallBottomB)
    clear(propSpriteNodes)
    clear(propSpriteFeet)
    clear(propSpriteProjectilePassable)
    clear(propCollisionBounds)
    if (!wallsRootNode.isAlive || !propsRootNode.isAlive) {
        print("level.prefab: walls or props node not found")
        return
    }
    organize_border_wall_hierarchy()
    index_prefab_props(wallsRootNode)
    index_prefab_props(propsRootNode)
}


def public spawn_world_legacy() {
    clear(propBlockers)
    clear(propWallSegmentsA)
    clear(propWallSegmentsB)
    clear(propProjectileWallSegmentsA)
    clear(propProjectileWallSegmentsB)
    clear(borderWallBottomA)
    clear(borderWallBottomB)
    clear(propSpriteNodes)
    clear(propSpriteFeet)
    clear(propSpriteProjectilePassable)
    clear(propCollisionBounds)
    ensure_level_prop_roots()
    clear_prop_root_children(wallsRootNode)
    clear_prop_root_children(propsRootNode)
    spawn_border_walls()
    spawn_interior_walls()
    spawn_code_misc_props()
}


def spawn_code_misc_props() {
    spawn_misc_b12_e()
    spawn_misc_b5_e()
    spawn_misc_b10_e()
    spawn_misc_b8_e()
    spawn_misc_b25_e()
    spawn_misc_b3_e()
    spawn_misc_b14_e()
    spawn_misc_b11_e()
    spawn_misc_b2_e()
    spawn_misc_b7_e()
    spawn_misc_b9_e()
    spawn_misc_b40_e()
    spawn_misc_b20_e()
    spawn_misc_b1_e()
}


def cursor_world_position_for_props() : float2 {
    if (!cameraNode.isAlive) {
        return float2(0.0)
    }
    let cam = cameraNode?.Camera
    let mousePos = get_action_vector2("cursor")
    return cam.screenToWorldDepth(mousePos, 0.1).xy
}


def public spawn_prop_by_id(propId : string; feetGrid : float2; name : string) : bool {
    if (propId == "misc_b12_e") {
        spawn_misc_prop(
            miscB12Texture, PROP_MISC_B12_E_CROP, PROP_MISC_B12_E_FEET_PX, PROP_MISC_B12_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B12_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b5_e") {
        spawn_misc_prop(
            miscB5Texture, PROP_MISC_B5_E_CROP, PROP_MISC_B5_E_FEET_PX, PROP_MISC_B5_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B5_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b10_e") {
        spawn_misc_prop(
            miscB10Texture, PROP_MISC_B10_E_CROP, PROP_MISC_B10_E_FEET_PX, PROP_MISC_B10_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B10_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b8_e") {
        spawn_misc_prop(
            miscB8Texture, PROP_MISC_B8_E_CROP, PROP_MISC_B8_E_FEET_PX, PROP_MISC_B8_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B8_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b25_e") {
        spawn_misc_prop(
            miscB25Texture, PROP_MISC_B25_E_CROP, PROP_MISC_B25_E_FEET_PX, PROP_MISC_B25_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B25_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b3_e") {
        spawn_misc_prop(
            miscB3Texture, PROP_MISC_B3_E_CROP, PROP_MISC_B3_E_FEET_PX, PROP_MISC_B3_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B3_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b14_e") {
        spawn_misc_prop(
            miscB14Texture, PROP_MISC_B14_E_CROP, PROP_MISC_B14_E_FEET_PX, PROP_MISC_B14_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B14_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b11_e") {
        spawn_misc_prop(
            miscB11Texture, PROP_MISC_B11_E_CROP, PROP_MISC_B11_E_FEET_PX, PROP_MISC_B11_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B11_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b2_e") {
        spawn_misc_prop(
            miscB2Texture, PROP_MISC_B2_E_CROP, PROP_MISC_B2_E_FEET_PX, PROP_MISC_B2_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B2_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b7_e") {
        spawn_misc_prop(
            miscB7Texture, PROP_MISC_B7_E_CROP, PROP_MISC_B7_E_FEET_PX, PROP_MISC_B7_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B7_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b9_e") {
        spawn_misc_prop(
            miscB9Texture, PROP_MISC_B9_E_CROP, PROP_MISC_B9_E_FEET_PX, PROP_MISC_B9_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B9_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b40_e") {
        spawn_misc_prop(
            miscB40Texture, PROP_MISC_B40_E_CROP, PROP_MISC_B40_E_FEET_PX, PROP_MISC_B40_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B40_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b20_e") {
        spawn_misc_prop(
            miscB20Texture, PROP_MISC_B20_E_CROP, PROP_MISC_B20_E_FEET_PX, PROP_MISC_B20_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B20_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    if (propId == "misc_b1_e") {
        spawn_misc_prop(
            miscB1Texture, PROP_MISC_B1_E_CROP, PROP_MISC_B1_E_FEET_PX, PROP_MISC_B1_E_WORLD_WIDTH,
            feetGrid, PROP_MISC_B1_E_WALL_LINES_PX, name, propId
        )
        return true
    }
    return false
}


def public cursor_feet_grid() : float2 {
    let worldPos = cursor_world_position_for_props()
    return world_to_grid(worldPos.x, worldPos.y)
}


def public print_cursor_grid_coords() {
    let worldPos = cursor_world_position_for_props()
    let grid = world_to_grid(worldPos.x, worldPos.y)
    print("cursor feetGrid = float2({grid.x}, {grid.y})")
    print("cursor worldPos = float2({worldPos.x}, {worldPos.y})")
}


def public spawn_prop_at_cursor_grid(propId : string) : bool {
    let feetGrid = cursor_feet_grid()
    let worldPos = grid_to_world(feetGrid.x, feetGrid.y)
    print("Prop '{propId}' at feetGrid = float2({feetGrid.x}, {feetGrid.y})")
    print("world pos = float2({worldPos.x}, {worldPos.y})")
    print("Add under level/props: SpriteRenderer + PropFootprint propId=\"{propId}\"")
    return true
}


def public print_prop_type_ids() {
    print("misc_b1_e, misc_b2_e, misc_b3_e, misc_b5_e, misc_b7_e, misc_b8_e, misc_b9_e,")
    print("misc_b10_e, misc_b11_e, misc_b12_e, misc_b14_e, misc_b20_e, misc_b25_e, misc_b40_e")
}


def public spawn_world_props() {
    init_world_from_prefab()
}


def public append_prop_blockers(var blockers : array<float2>) {
    for (point in propBlockers) {
        push(blockers, point)
    }
}


def public prop_wall_segment_count() : int {
    return length(propWallSegmentsA)
}


def public prop_wall_segment_a(index : int) : float2 {
    return propWallSegmentsA[index]
}


def public prop_wall_segment_b(index : int) : float2 {
    return propWallSegmentsB[index]
}


def public border_wall_bottom_count() : int {
    return length(borderWallBottomA)
}


def public border_wall_bottom_a(index : int) : float2 {
    return borderWallBottomA[index]
}


def public border_wall_bottom_b(index : int) : float2 {
    return borderWallBottomB[index]
}


def prop_cull_world_margin() : float2 {
    let tileW = tile_half_width()
    let tileH = tile_half_height()
    return float2(tileW * 3.0, tileH * 3.0)
}


def public update_prop_visibility() {
    if (!propsRootNode.isAlive || !cameraNode.isAlive) {
        return
    }
    let camPos = cameraNode.localPosition.xy
    let bounds = visible_grid_bounds_from_camera(camPos, camera_visible_half_extents(), prop_cull_world_margin())
    for (i in range(length(propSpriteNodes))) {
        let node = propSpriteNodes[i]
        if (!node.isAlive) {
            continue
        }
        let feet = propSpriteFeet[i]
        let grid = world_to_grid(feet.x, feet.y)
        let gx = int(floor(grid.x + 0.5))
        let gy = int(floor(grid.y + 0.5))
        let visible = gx >= bounds.minGx && gx <= bounds.maxGx && gy >= bounds.minGy && gy <= bounds.maxGy
        if (node.isActive != visible) {
            node.isActive = visible
        }
    }
}

