require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/prop_footprint
require strings
require scripts/das/world/props_collision
require scripts/das/world/props_sprite_math

module props_walls public

def outside_border_walls_root_name() : string {
    return "outside_border_walls"
}


def border_wall_compass_group_names() : array<string> {
    var names : array<string>
    push(names, "west_border_walls")
    push(names, "east_border_walls")
    push(names, "north_border_walls")
    push(names, "south_border_walls")
    return <- names
}


def border_wall_edge_tag_from_root(rootName : string) : string {
    if (starts_with(rootName, "Wall_edge_")) {
        return slice(rootName, length("Wall_edge_"))
    }
    if (rootName == "west_border_walls") {
        return "lt"
    }
    if (rootName == "east_border_walls") {
        return "br"
    }
    if (rootName == "north_border_walls") {
        return "tr"
    }
    if (rootName == "south_border_walls") {
        return "bl"
    }
    return ""
}


def wall_edge_short_from_root(name : string) : string {
    return border_wall_edge_tag_from_root(name)
}


def wall_segment_has_edge_tag(name : string; edge : string) : bool {
    return find(name, "_{edge}_") >= 0
}


def is_decor_border_wall_name(name : string) : bool {
    if (starts_with(name, "Wall_corner_")) {
        return true
    }
    return wall_segment_has_edge_tag(name, "lt") || wall_segment_has_edge_tag(name, "tr") || wall_segment_has_edge_tag(name, "bl") || wall_segment_has_edge_tag(name, "br")
}


def is_border_wall_direction_name(name : string) : bool {
    if (name == outside_border_walls_root_name()) {
        return true
    }
    for (group in border_wall_compass_group_names()) {
        if (name == group) {
            return true
        }
    }
    return name == "Wall_edge_lt" || name == "Wall_edge_br" || name == "Wall_edge_tr" || name == "Wall_edge_bl"
}


def is_border_wall_compass_group_name(name : string) : bool {
    for (group in border_wall_compass_group_names()) {
        if (name == group) {
            return true
        }
    }
    return false
}


def is_border_wall_direction_prefix(prefix : string) : bool {
    return length(border_wall_edge_tag_from_root(prefix)) > 0
}


def border_wall_direction_names() : array<string> {
    return <- border_wall_compass_group_names()
}


def ensure_outside_border_walls_root() : NodeId {
    let rootName = outside_border_walls_root_name()
    let existing = find_child(wallsRootNode, rootName)
    if (existing.isAlive) {
        return existing
    }
    return create_node(NodeData(name = rootName, parent = wallsRootNode))
}


def ensure_border_wall_direction_root(direction : string) : NodeId {
    let outsideRoot = ensure_outside_border_walls_root()
    let existing = find_child(outsideRoot, direction)
    if (existing.isAlive) {
        return existing
    }
    return create_node(NodeData(name = direction, parent = outsideRoot))
}


def wall_prop_direction_letter(propId : string) : string {
    if (length(propId) == 0) {
        return "e"
    }
    return slice(propId, length(propId) - 1, length(propId))
}


def wall_b1_segment_name(propId : string; edgeRootName : string; index : int) : string {
    let edge = wall_edge_short_from_root(edgeRootName)
    let dir = wall_prop_direction_letter(propId)
    return "Wall_type2_var1_{dir}_{edge}_{index}"
}


def wall_interior_segment_name(propId : string; interiorPrefix : string; index : int) : string {
    let dir = wall_prop_direction_letter(propId)
    let tag = starts_with(interiorPrefix, "interior_wall_") ? slice(interiorPrefix, length("interior_wall_")) : interiorPrefix
    return "Wall_type2_var1_{dir}_in_{tag}_{index}"
}


def ensure_border_wall_direction_roots() {
    for (direction in border_wall_direction_names()) {
        ensure_border_wall_direction_root(direction)
    }
}


def organize_border_wall_hierarchy() {
    if (!wallsRootNode.isAlive) {
        return
    }
    ensure_border_wall_direction_roots()
    let outsideRoot = ensure_outside_border_walls_root()
    var inscope wallsChildren = wallsRootNode.get_children()
    for (child in wallsChildren) {
        if (!child.isAlive || is_border_wall_direction_name(child.name)) {
            continue
        }
        if (child.name == outside_border_walls_root_name()) {
            continue
        }
        for (direction in border_wall_direction_names()) {
            let edge = border_wall_edge_tag_from_root(direction)
            if (!wall_segment_has_edge_tag(child.name, edge)) {
                continue
            }
            let parent = find_child(outsideRoot, direction)
            if (parent.isAlive) {
                child.set_parent(parent, AddChildStrategy.KeepLocalTransform)
            }
            break
        }
    }
    for (legacyName in array<string>("Wall_edge_lt", "Wall_edge_br", "Wall_edge_tr", "Wall_edge_bl")) {
        let legacyRoot = find_child(wallsRootNode, legacyName)
        if (!legacyRoot.isAlive) {
            continue
        }
        let edge = border_wall_edge_tag_from_root(legacyName)
        var compassName = ""
        for (direction in border_wall_direction_names()) {
            if (border_wall_edge_tag_from_root(direction) == edge) {
                compassName = direction
                break
            }
        }
        if (length(compassName) == 0) {
            continue
        }
        let compassRoot = ensure_border_wall_direction_root(compassName)
        var inscope legacyChildren = legacyRoot.get_children()
        for (legacyChild in legacyChildren) {
            if (legacyChild.isAlive) {
                legacyChild.set_parent(compassRoot, AddChildStrategy.KeepLocalTransform)
            }
        }
    }
}


def border_wall_foreground_render_order(feet : float2) : int {
    let grid = world_to_grid(feet.x, feet.y)
    return depth_sort_foreground_overlay_order() + depth_sort_key(grid.x, grid.y)
}


def border_wall_render_order_for_name(name : string; feet : float2) : int {
    if (wall_segment_has_edge_tag(name, "lt") || wall_segment_has_edge_tag(name, "tr") || name == "Wall_corner_n" || name == "Wall_corner_e") {
        return border_wall_foreground_render_order(feet)
    }
    if (wall_segment_has_edge_tag(name, "bl") || wall_segment_has_edge_tag(name, "br") || name == "Wall_corner_s" || name == "Wall_corner_w") {
        return depth_sort_entity_from_world(feet) + DEPTH_BORDER_WALL_BELOW_BIAS
    }
    return depth_sort_entity_from_world(feet)
}


def apply_border_wall_render_order(node : NodeId; feet : float2) {
    if (!is_decor_border_wall_name(node.name) || node?.SpriteRenderer == null) {
        return
    }
    node?.SpriteRenderer.renderOrder = border_wall_render_order_for_name(node.name, feet)
}


def spawn_prop_sprite(
    texture : TextureId;
    crop : float4;
    feetPx : float2;
    worldWidth : float;
    feetGrid : float2;
    name : string;
    parent : NodeId;
    propId : string;
    renderOrderBias : int = 0;
    explicitRenderOrder : int = -1
) : NodeId {
    let feet = grid_to_world(feetGrid.x, feetGrid.y)
    let anchor = prop_anchor_offset(crop, feetPx, worldWidth)
    let scale = prop_scale(crop, worldWidth)
    let depth = explicitRenderOrder >= 0 ? explicitRenderOrder : depth_sort_entity_from_world(feet) + renderOrderBias
    let node = create_node(NodeData(
        name = name,
        position = float3(feet.x + anchor.x, feet.y + anchor.y, 0.0),
        scale = float3(scale.x, scale.y, 1.0),
        parent = parent
    ))
    add_component(node, new SpriteRenderer(
        textureId = texture,
        uvRect = prop_uv_rect(crop),
        useTextureSizeForScaling = false,
        renderOrder = depth
    ))
    add_component(node, new PropFootprint(propId = propId))
    register_prop_sprite_track(node, feet, false, sprite_node_collision_y_bounds(node))
    return node
}


def wall_sprite_pixel_to_world(
    feetGrid : float2;
    px, py : float;
    crop : float4;
    feetPx : float2;
    worldWidth : float
) : float2 {
    let feet = grid_to_world(feetGrid.x, feetGrid.y)
    let feetLocal = prop_pixel_to_local(feetPx.x, feetPx.y, crop, worldWidth)
    let pointLocal = prop_pixel_to_local(px, py, crop, worldWidth)
    return feet + pointLocal - feetLocal
}


def wall_sprite_point_world_offset(
    px, py : float;
    crop : float4;
    feetPx : float2;
    worldWidth : float
) : float2 {
    let feetLocal = prop_pixel_to_local(feetPx.x, feetPx.y, crop, worldWidth)
    let pointLocal = prop_pixel_to_local(px, py, crop, worldWidth)
    return pointLocal - feetLocal
}


def wall_bottom_mid_world_offset(
    crop : float4;
    feetPx : float2;
    bottomPxA, bottomPxB : float2;
    worldWidth : float
) : float2 {
    let offsetA = wall_sprite_point_world_offset(bottomPxA.x, bottomPxA.y, crop, feetPx, worldWidth)
    let offsetB = wall_sprite_point_world_offset(bottomPxB.x, bottomPxB.y, crop, feetPx, worldWidth)
    return (offsetA + offsetB) * 0.5
}


def wall_bottom_span_world(
    crop : float4;
    bottomSpanPx : float
) : float {
    return WALL_B1_WORLD_WIDTH * (bottomSpanPx / prop_crop_width(crop))
}


def feet_grid_for_anchor_world_offset(anchorWorld : float2; anchorOffsetFromFeet : float2) : float2 {
    let feetWorld = anchorWorld - anchorOffsetFromFeet
    return world_to_grid(feetWorld.x, feetWorld.y)
}


def record_border_wall_bottom_segment(
    feetGrid : float2;
    crop : float4;
    feetPx : float2;
    bottomPxA, bottomPxB : float2;
    worldWidth : float;
    collision : bool
) {
    let worldA = wall_sprite_pixel_to_world(
        feetGrid, bottomPxA.x, bottomPxA.y, crop, feetPx, worldWidth
    )
    let worldB = wall_sprite_pixel_to_world(
        feetGrid, bottomPxB.x, bottomPxB.y, crop, feetPx, worldWidth
    )
    push(borderWallBottomA, worldA)
    push(borderWallBottomB, worldB)
    if (collision) {
        record_prop_wall_segment(worldA, worldB, true)
    }
}


def spawn_border_wall_segment(
    texture : TextureId;
    crop : float4;
    feetPx : float2;
    bottomPxA, bottomPxB : float2;
    feetGrid : float2;
    worldWidth : float;
    name : string;
    parent : NodeId;
    propId : string;
    collision : bool
) {
    let feet = grid_to_world(feetGrid.x, feetGrid.y)
    let depth = border_wall_render_order_for_name(name, feet)
    spawn_prop_sprite(
        texture, crop, feetPx, worldWidth, feetGrid, name, parent, propId, 0, depth
    )
    record_border_wall_bottom_segment(
        feetGrid, crop, feetPx, bottomPxA, bottomPxB, worldWidth, collision
    )
}


def spawn_border_edge_walls(
    gx0, gy0, gx1, gy1 : float;
    textureA, textureB : TextureId;
    cropA, cropB : float4;
    feetPxA, feetPxB : float2;
    bottomPxA_a, bottomPxA_b, bottomPxB_a, bottomPxB_b : float2;
    spanPxA, spanPxB : float;
    namePrefix : string;
    propIdA, propIdB : string;
    collision : bool
) {
    let borderStart = grid_to_world(gx0, gy0)
    let borderEnd = grid_to_world(gx1, gy1)
    let edgeVec = borderEnd - borderStart
    let edgeLen = length(edgeVec)
    let spanA = wall_bottom_span_world(cropA, spanPxA)
    let spanB = wall_bottom_span_world(cropB, spanPxB)
    let avgSpan = (spanA + spanB) * 0.5
    let count = max(1, int(round(edgeLen / avgSpan)))
    let midOffsetA = wall_bottom_mid_world_offset(
        cropA, feetPxA, bottomPxA_a, bottomPxA_b, WALL_B1_WORLD_WIDTH
    )
    let midOffsetB = wall_bottom_mid_world_offset(
        cropB, feetPxB, bottomPxB_a, bottomPxB_b, WALL_B1_WORLD_WIDTH
    )
    let segmentParent = is_border_wall_direction_prefix(namePrefix) ? ensure_border_wall_direction_root(namePrefix) : wallsRootNode
    for (i in range(count)) {
        let t = (float(i) + 0.5) / float(count)
        let bottomMid = borderStart + edgeVec * t
        let useA = (i % 2) == 0
        if (useA) {
            let feetGrid = feet_grid_for_anchor_world_offset(bottomMid, midOffsetA)
            let segmentName = is_border_wall_direction_prefix(namePrefix) ? wall_b1_segment_name(propIdA, namePrefix, i) : wall_interior_segment_name(propIdA, namePrefix, i)
            spawn_border_wall_segment(
                textureA, cropA, feetPxA, bottomPxA_a, bottomPxA_b,
                feetGrid, WALL_B1_WORLD_WIDTH, segmentName, segmentParent, propIdA, collision
            )
        } else {
            let feetGrid = feet_grid_for_anchor_world_offset(bottomMid, midOffsetB)
            let segmentName = is_border_wall_direction_prefix(namePrefix) ? wall_b1_segment_name(propIdB, namePrefix, i) : wall_interior_segment_name(propIdB, namePrefix, i)
            spawn_border_wall_segment(
                textureB, cropB, feetPxB, bottomPxB_a, bottomPxB_b,
                feetGrid, WALL_B1_WORLD_WIDTH, segmentName, segmentParent, propIdB, collision
            )
        }
    }
}


def spawn_border_corner(
    cornerGx, cornerGy : float;
    texture : TextureId;
    crop : float4;
    feetPx : float2;
    bottomPx : array<float2>;
    worldWidth : float;
    name : string;
    propId : string;
    collision : bool
) {
    let cornerWorld = grid_to_world(cornerGx, cornerGy)
    let apexOffset = wall_sprite_point_world_offset(
        bottomPx[1].x, bottomPx[1].y, crop, feetPx, worldWidth
    )
    let feetGrid = feet_grid_for_anchor_world_offset(cornerWorld, apexOffset)
    let feet = grid_to_world(feetGrid.x, feetGrid.y)
    let depth = border_wall_render_order_for_name(name, feet)
    spawn_prop_sprite(
        texture, crop, feetPx, worldWidth, feetGrid, name, wallsRootNode, propId, 0, depth
    )
    record_border_wall_bottom_segment(
        feetGrid, crop, feetPx, bottomPx[0], bottomPx[1], worldWidth, collision
    )
    record_border_wall_bottom_segment(
        feetGrid, crop, feetPx, bottomPx[1], bottomPx[2], worldWidth, collision
    )
}


def spawn_border_corners(minG, maxG : float) {
    spawn_border_corner(
        minG, minG,
        wallB2NTexture, WALL_B2_N_CROP, WALL_B2_N_FEET_PX, WALL_B2_N_BOTTOM_PX,
        WALL_B2_WORLD_WIDTH, "Wall_corner_n", "wall_b2_n", false
    )
    spawn_border_corner(
        maxG, minG,
        wallB2ETexture, WALL_B2_E_CROP, WALL_B2_E_FEET_PX, WALL_B2_E_BOTTOM_PX,
        WALL_B2_WORLD_WIDTH, "Wall_corner_e", "wall_b2_e", false
    )
    spawn_border_corner(
        maxG, maxG,
        wallB2STexture, WALL_B2_S_CROP, WALL_B2_S_FEET_PX, WALL_B2_S_BOTTOM_PX,
        WALL_B2_WORLD_WIDTH, "Wall_corner_s", "wall_b2_s", false
    )
    spawn_border_corner(
        minG, maxG,
        wallB2WTexture, WALL_B2_W_CROP, WALL_B2_W_FEET_PX, WALL_B2_W_BOTTOM_PX,
        WALL_B2_WORLD_WIDTH, "Wall_corner_w", "wall_b2_w", false
    )
}


def spawn_border_walls() {
    let minG = -0.5
    let maxG = float(activeMapWidth - 1) + 0.5
    ensure_border_wall_direction_roots()
    // Left-top edge: gx = min, gy max -> min. Bottom-right edge: gx = max, gy min -> max.
    spawn_border_edge_walls(
        minG, maxG, minG, minG,
        wallB1NTexture, wallB1STexture,
        WALL_B1_N_CROP, WALL_B1_S_CROP,
        WALL_B1_N_FEET_PX, WALL_B1_S_FEET_PX,
        WALL_B1_N_BOTTOM_PX_A, WALL_B1_N_BOTTOM_PX_B,
        WALL_B1_S_BOTTOM_PX_A, WALL_B1_S_BOTTOM_PX_B,
        WALL_B1_N_BOTTOM_SPAN_PX, WALL_B1_S_BOTTOM_SPAN_PX,
        "west_border_walls", "wall_b1_n", "wall_b1_s", false
    )
    spawn_border_edge_walls(
        maxG, minG, maxG, maxG,
        wallB1STexture, wallB1NTexture,
        WALL_B1_S_CROP, WALL_B1_N_CROP,
        WALL_B1_S_FEET_PX, WALL_B1_N_FEET_PX,
        WALL_B1_S_BOTTOM_PX_A, WALL_B1_S_BOTTOM_PX_B,
        WALL_B1_N_BOTTOM_PX_A, WALL_B1_N_BOTTOM_PX_B,
        WALL_B1_S_BOTTOM_SPAN_PX, WALL_B1_N_BOTTOM_SPAN_PX,
        "east_border_walls", "wall_b1_s", "wall_b1_n", false
    )
    // Top-right edge: gy = min, gx min -> max. Bottom-left edge: gy = max, gx max -> min.
    spawn_border_edge_walls(
        minG, minG, maxG, minG,
        wallB1ETexture, wallB1WTexture,
        WALL_B1_E_CROP, WALL_B1_W_CROP,
        WALL_B1_E_FEET_PX, WALL_B1_W_FEET_PX,
        WALL_B1_E_BOTTOM_PX_A, WALL_B1_E_BOTTOM_PX_B,
        WALL_B1_W_BOTTOM_PX_A, WALL_B1_W_BOTTOM_PX_B,
        WALL_B1_E_BOTTOM_SPAN_PX, WALL_B1_W_BOTTOM_SPAN_PX,
        "north_border_walls", "wall_b1_e", "wall_b1_w", false
    )
    spawn_border_edge_walls(
        maxG, maxG, minG, maxG,
        wallB1WTexture, wallB1ETexture,
        WALL_B1_W_CROP, WALL_B1_E_CROP,
        WALL_B1_W_FEET_PX, WALL_B1_E_FEET_PX,
        WALL_B1_W_BOTTOM_PX_A, WALL_B1_W_BOTTOM_PX_B,
        WALL_B1_E_BOTTOM_PX_A, WALL_B1_E_BOTTOM_PX_B,
        WALL_B1_W_BOTTOM_SPAN_PX, WALL_B1_E_BOTTOM_SPAN_PX,
        "south_border_walls", "wall_b1_w", "wall_b1_e", false
    )
}


def spawn_interior_walls() {
    // West camp palisade along the north grass belt.
    spawn_border_edge_walls(
        10.0, 30.0, 22.0, 30.0,
        wallB1ETexture, wallB1WTexture,
        WALL_B1_E_CROP, WALL_B1_W_CROP,
        WALL_B1_E_FEET_PX, WALL_B1_W_FEET_PX,
        WALL_B1_E_BOTTOM_PX_A, WALL_B1_E_BOTTOM_PX_B,
        WALL_B1_W_BOTTOM_PX_A, WALL_B1_W_BOTTOM_PX_B,
        WALL_B1_E_BOTTOM_SPAN_PX, WALL_B1_W_BOTTOM_SPAN_PX,
        "interior_wall_w_n", "wall_b1_e", "wall_b1_w", true
    )
    // East camp palisade along the north grass belt.
    spawn_border_edge_walls(
        58.0, 30.0, 70.0, 30.0,
        wallB1ETexture, wallB1WTexture,
        WALL_B1_E_CROP, WALL_B1_W_CROP,
        WALL_B1_E_FEET_PX, WALL_B1_W_FEET_PX,
        WALL_B1_E_BOTTOM_PX_A, WALL_B1_E_BOTTOM_PX_B,
        WALL_B1_W_BOTTOM_PX_A, WALL_B1_W_BOTTOM_PX_B,
        WALL_B1_E_BOTTOM_SPAN_PX, WALL_B1_W_BOTTOM_SPAN_PX,
        "interior_wall_e_n", "wall_b1_e", "wall_b1_w", true
    )
    // South grass belt palisade.
    spawn_border_edge_walls(
        25.0, 60.0, 40.0, 60.0,
        wallB1WTexture, wallB1ETexture,
        WALL_B1_W_CROP, WALL_B1_E_CROP,
        WALL_B1_W_FEET_PX, WALL_B1_E_FEET_PX,
        WALL_B1_W_BOTTOM_PX_A, WALL_B1_W_BOTTOM_PX_B,
        WALL_B1_E_BOTTOM_PX_A, WALL_B1_E_BOTTOM_PX_B,
        WALL_B1_W_BOTTOM_SPAN_PX, WALL_B1_E_BOTTOM_SPAN_PX,
        "interior_wall_s", "wall_b1_w", "wall_b1_e", true
    )
    // West vertical palisade linking the south field pens.
    spawn_border_edge_walls(
        10.0, 62.0, 10.0, 50.0,
        wallB1NTexture, wallB1STexture,
        WALL_B1_N_CROP, WALL_B1_S_CROP,
        WALL_B1_N_FEET_PX, WALL_B1_S_FEET_PX,
        WALL_B1_N_BOTTOM_PX_A, WALL_B1_N_BOTTOM_PX_B,
        WALL_B1_S_BOTTOM_PX_A, WALL_B1_S_BOTTOM_PX_B,
        WALL_B1_N_BOTTOM_SPAN_PX, WALL_B1_S_BOTTOM_SPAN_PX,
        "interior_wall_w_v", "wall_b1_n", "wall_b1_s", true
    )
    // East vertical palisade on the far grass field.
    spawn_border_edge_walls(
        70.0, 50.0, 70.0, 62.0,
        wallB1NTexture, wallB1STexture,
        WALL_B1_N_CROP, WALL_B1_S_CROP,
        WALL_B1_N_FEET_PX, WALL_B1_S_FEET_PX,
        WALL_B1_N_BOTTOM_PX_A, WALL_B1_N_BOTTOM_PX_B,
        WALL_B1_S_BOTTOM_PX_A, WALL_B1_S_BOTTOM_PX_B,
        WALL_B1_N_BOTTOM_SPAN_PX, WALL_B1_S_BOTTOM_SPAN_PX,
        "interior_wall_e_v", "wall_b1_n", "wall_b1_s", true
    )
}


def public spawn_walls_if_missing() {
    if (!wallsRootNode.isAlive) {
        return
    }
    if (length(wallsRootNode.get_children()) > 0) {
        return
    }
    spawn_border_walls()
    spawn_interior_walls()
}


