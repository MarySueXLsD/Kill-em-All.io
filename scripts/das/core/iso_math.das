require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
def tile_half_width() : float {
    return TILE_HALF_WIDTH
}


def tile_half_height() : float {
    return GROUND_TILE_WORLD_WIDTH * 0.5 * tan(tileEdgeAngleDeg * PI / 180.0)
}


def tile_diamond_world_height() : float {
    return GROUND_TILE_WORLD_WIDTH * tan(tileEdgeAngleDeg * PI / 180.0)
}


def tile_sprite_world_height() : float {
    // Scale the full crop so the top-face rhombus (not the side faces) matches the grid diamond height.
    return tile_diamond_world_height() * (GROUND_CROP_HEIGHT / GROUND_DIAMOND_FACE_HEIGHT_PX)
}


def tile_world_height() : float {
    return tile_diamond_world_height()
}


def grid_to_world(gx, gy : float) : float2 {
    return float2(
        (gx - gy) * tile_half_width(),
        (gx + gy) * tile_half_height()
    )
}


def world_to_grid(wx, wy : float) : float2 {
    let halfW = tile_half_width()
    let halfH = tile_half_height()
    return float2(
        (wx / halfW + wy / halfH) * 0.5,
        (wy / halfH - wx / halfW) * 0.5
    )
}


def grid_tile_step_length() : float {
    let w0 = grid_to_world(0.0, 0.0)
    let w1 = grid_to_world(1.0, 0.0)
    return length(w1 - w0)
}


def public grid_step_from_world_dir(dir : float2; steps : int) : int2 {
    if (steps <= 0 || length_sq(dir) < 0.0001) {
        return int2(0, 0)
    }
    let nd = normalize(dir)
    let w0 = grid_to_world(0.0, 0.0)
    let target = w0 + nd * grid_tile_step_length() * float(steps)
    let grid = world_to_grid(target.x, target.y)
    return int2(int(round(grid.x)), int(round(grid.y)))
}


def player_feet_from_scene_node() : float2 {
    if (!playerNode.isAlive) {
        return playerWorldPosition
    }
    let nodePos = playerNode.localPosition.xy
    let anchor = entity_sprite_anchor_offset(
        PLAYER_WORLD_HEIGHT,
        PLAYER_SHEET_HEIGHT,
        float(PLAYER_SHEET_ROWS),
        PLAYER_SHEET_WIDTH,
        float(PLAYER_SHEET_COLS)
    )
    return nodePos - anchor
}


def grid_feet_margin() : float {
    let halfW = tile_half_width()
    let halfH = tile_half_height()
    let gridStep = sqrt(halfW * halfW + halfH * halfH)
    return ENTITY_FEET_RADIUS / gridStep
}


def grid_feet_min() : float {
    return -0.5 + grid_feet_margin()
}


def grid_cell_in_playfield(gx, gy : int) : bool {
    return gx >= activeGridMinX && gx < activeGridMinX + activeGridWidth && gy >= activeGridMinY && gy < activeGridMinY + activeGridHeight
}


def grid_feet_max_gx() : float {
    return float(activeMapWidth - 1) + 0.5 - grid_feet_margin()
}


def grid_feet_max_gy() : float {
    return float(activeMapHeight - 1) + 0.5 - grid_feet_margin()
}


def is_grid_in_bounds(gx, gy : float) : bool {
    return gx >= 0.0 && gx < float(activeMapWidth) && gy >= 0.0 && gy < float(activeMapHeight)
}


def public is_feet_in_grid_bounds(pos : float2) : bool {
    let grid = world_to_grid(pos.x, pos.y)
    let minG = grid_feet_min()
    let maxGx = grid_feet_max_gx()
    let maxGy = grid_feet_max_gy()
    return grid.x >= minG && grid.x <= maxGx && grid.y >= minG && grid.y <= maxGy
}


def public is_world_on_grid(pos : float2) : bool {
    let grid = world_to_grid(pos.x, pos.y)
    return is_grid_in_bounds(grid.x, grid.y)
}


def public clamp_feet_to_grid(pos : float2) : float2 {
    let grid = world_to_grid(pos.x, pos.y)
    let gx = clamp(grid.x, grid_feet_min(), grid_feet_max_gx())
    let gy = clamp(grid.y, grid_feet_min(), grid_feet_max_gy())
    return grid_to_world(gx, gy)
}


def public constrain_feet_move_to_grid(from, to : float2) : float2 {
    if (is_feet_in_grid_bounds(to)) {
        return to
    }
    let slideX = clamp_feet_to_grid(float2(to.x, from.y))
    if (is_feet_in_grid_bounds(slideX)) {
        return slideX
    }
    let slideY = clamp_feet_to_grid(float2(from.x, to.y))
    if (is_feet_in_grid_bounds(slideY)) {
        return slideY
    }
    return clamp_feet_to_grid(from)
}


def depth_sort_key(gx, gy : float) : int {
    // Lower gx + gy is closer to the camera (farther down on screen) and draws on top.
    let maxSum = float(activeGridMinX + activeGridMinY + activeGridWidth + activeGridHeight - 2)
    return int(maxSum - (gx + gy))
}


def depth_sort_entity_from_world(pos : float2) : int {
    let grid = world_to_grid(pos.x, pos.y)
    let maxSum = float(activeGridMinX + activeGridMinY + activeGridWidth + activeGridHeight - 2)
    let sum = grid.x + grid.y
    return DEPTH_ENTITY_LAYER + int((maxSum - sum) * float(DEPTH_TILE_STRIDE))
}


def depth_sort_corpse_from_world(pos : float2) : int {
    let grid = world_to_grid(pos.x, pos.y)
    let maxSum = float(activeGridMinX + activeGridMinY + activeGridWidth + activeGridHeight - 2)
    let sum = grid.x + grid.y
    let corpseDepth = DEPTH_CORPSE_LAYER + int((maxSum - sum) * float(DEPTH_CORPSE_STRIDE))
    let maxCorpseDepth = DEPTH_ENTITY_LAYER + DEPTH_BORDER_WALL_BELOW_BIAS - 1
    return min(corpseDepth, maxCorpseDepth)
}


def public depth_sort_foreground_overlay_order() : int {
    let maxSum = float(activeGridMinX + activeGridMinY + activeGridWidth + activeGridHeight - 2)
    let minFeetSum = grid_feet_min() + grid_feet_min()
    // Above Y-sorted player, enemies (+1), projectiles, and AOE overlays (+40).
    return DEPTH_ENTITY_LAYER + int((maxSum - minFeetSum) * float(DEPTH_TILE_STRIDE)) + DEPTH_FOREGROUND_OVERLAY_HEADROOM
}


def wasd_to_iso_velocity(move : float2; speed : float) : float2 {
    var vel = float2(move.x, move.y)
    if (length_sq(vel) > 0.) {
        vel = normalize(vel) * speed
    }
    return vel
}


def wasd_to_iso_direction(move : float2) : float2 {
    return move
}


def uv_rect_from_tile(col, row, cols, rows : int) : float4 {
    let tileW = 1.0 / float(cols)
    let tileH = 1.0 / float(rows)
    let uvX = float(col) * tileW
    // Image rows increase downward; UV origin is bottom-left.
    let uvY = 1.0 - float(row + 1) * tileH
    return float4(uvX, uvY, tileW, tileH)
}


def uv_rect_from_crop(minX, minY, maxX, maxY, texWidth, texHeight : float) : float4 {
    let width = maxX - minX + 1.0
    let height = maxY - minY + 1.0
    // Image pixels are top-down; sprite UVs are bottom-up (OpenGL convention).
    let uvY = 1.0 - (maxY + 1.0) / texHeight
    return float4(
        minX / texWidth,
        uvY,
        width / texWidth,
        height / texHeight
    )
}


def entity_sprite_anchor_offset(worldHeight, sheetHeight, sheetRows, sheetWidth, sheetCols : float) : float2 {
    let tileW = sheetWidth / sheetCols
    let tileH = sheetHeight / sheetRows
    let worldW = worldHeight * (tileW / tileH)
    let pxToWorldX = worldW / tileW
    let pxToWorldY = worldHeight / tileH
    // SpriteRenderer centers the quad on localPosition; offset node to place feet at position.
    return float2(
        (PLAYER_SHEET_FEET_X_PX - tileW * 0.5) * pxToWorldX,
        (PLAYER_SHEET_FEET_Y_PX - tileH * 0.5 + ENTITY_SPRITE_Y_OFFSET_PX) * pxToWorldY
    )
}


def entity_legs_box_size_world(worldHeight : float) : float2 {
    let tileH = PLAYER_SHEET_HEIGHT / float(PLAYER_SHEET_ROWS)
    let pixelToWorld = worldHeight / tileH
    return float2(ENTITY_LEGS_BOX_WIDTH_PX * pixelToWorld, ENTITY_LEGS_BOX_HEIGHT_PX * pixelToWorld)
}


struct LegsBoxBounds {
    minPt : float3
    maxPt : float3
}


struct CollisionYBounds {
    yMin : float
    yMax : float
    xMin : float
    xMax : float
}


def public legs_collision_y_bounds(feet : float2; worldHeight : float) : CollisionYBounds {
    let box = entity_legs_box_bounds(feet, worldHeight)
    return CollisionYBounds(
        yMin = box.minPt.y,
        yMax = box.maxPt.y,
        xMin = box.minPt.x,
        xMax = box.maxPt.x
    )
}


def public collision_y_bounds_overlap(a, b : CollisionYBounds) : bool {
    return a.xMax >= b.xMin && a.xMin <= b.xMax && a.yMax >= b.yMin && a.yMin <= b.yMax
}


def public collision_y_bounds_expand(bounds : CollisionYBounds; margin : float) : CollisionYBounds {
    return CollisionYBounds(
        yMin = bounds.yMin - margin,
        yMax = bounds.yMax + margin,
        xMin = bounds.xMin - margin,
        xMax = bounds.xMax + margin
    )
}


def entity_legs_box_bounds(feet : float2; worldHeight : float) : LegsBoxBounds {
    let size = entity_legs_box_size_world(worldHeight)
    let halfW = size.x * 0.5
    return LegsBoxBounds(
        minPt = float3(feet.x - halfW, feet.y, DEBUG_DRAW_Z),
        maxPt = float3(feet.x + halfW, feet.y + size.y, DEBUG_DRAW_Z + 0.01)
    )
}


def public circle_intersects_legs_box(center : float2; radius : float; feet : float2; worldHeight : float) : bool {
    let bounds = entity_legs_box_bounds(feet, worldHeight)
    let closestX = clamp(center.x, bounds.minPt.x, bounds.maxPt.x)
    let closestY = clamp(center.y, bounds.minPt.y, bounds.maxPt.y)
    let dx = center.x - closestX
    let dy = center.y - closestY
    return dx * dx + dy * dy <= radius * radius
}


// Rows: 0=right, 1=bottom-right, 2=bottom, 3=bottom-left, 4=left, 5=top-left, 6=top, 7=top-right.
def facing_dir_from_row(row : int) : float2 {
    let angle = -float(row) * (PI / 4.0)
    return float2(cos(angle), sin(angle))
}


def direction_to_facing_row(dir : float2) : int {
    if (length_sq(dir) < 0.0001) {
        return 0
    }
    let angle = atan2(dir.y, dir.x)
    var row = int(round(-angle / (PI / 4.0))) % 8
    if (row < 0) {
        row += 8
    }
    return row
}


def public camera_visible_half_extents() : float2 {
    let halfH = cameraOrthoSize
    let res = get_resolution()
    let aspect = float(res.x) / float(res.y)
    return float2(halfH * aspect, halfH)
}


struct VisibleGridBounds {
    minGx : int
    minGy : int
    maxGx : int
    maxGy : int
}


def public visible_grid_bounds_from_camera(center : float2; halfExtents : float2; worldMargin : float2) : VisibleGridBounds {
    var minGx = 1000000
    var minGy = 1000000
    var maxGx = -1000000
    var maxGy = -1000000
    let corners <- [
        center + float2(-halfExtents.x - worldMargin.x, -halfExtents.y - worldMargin.y),
        center + float2(halfExtents.x + worldMargin.x, -halfExtents.y - worldMargin.y),
        center + float2(-halfExtents.x - worldMargin.x, halfExtents.y + worldMargin.y),
        center + float2(halfExtents.x + worldMargin.x, halfExtents.y + worldMargin.y),
    ]
    for (corner in corners) {
        let grid = world_to_grid(corner.x, corner.y)
        let igx = int(floor(grid.x))
        let igy = int(floor(grid.y))
        minGx = min(minGx, igx)
        minGy = min(minGy, igy)
        maxGx = max(maxGx, igx)
        maxGy = max(maxGy, igy)
    }
    return VisibleGridBounds(
        minGx = max(minGx, activeGridMinX),
        minGy = max(minGy, activeGridMinY),
        maxGx = min(maxGx, activeGridMinX + activeGridWidth - 1),
        maxGy = min(maxGy, activeGridMinY + activeGridHeight - 1)
    )
}
