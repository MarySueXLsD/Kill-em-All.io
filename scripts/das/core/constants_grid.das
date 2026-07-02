require engine.core

module constants_grid public

let public {
    // Tight padding around the 80x80 playfield (was 160 — 25k nodes).
    GRID_WIDTH = 96
    GRID_HEIGHT = 96
    MAP_WIDTH = 80
    MAP_HEIGHT = 80
    GRID_MIN_X = -(GRID_WIDTH - MAP_WIDTH) / 2
    GRID_MIN_Y = -(GRID_HEIGHT - MAP_HEIGHT) / 2
    GROUND_OUTSIDE_WORLD_COLOR = float4(0.72, 0.72, 0.72, 1.0)

    // Ground tile layout window in original 256x256 tex space (shared by all layers).
    GROUND_TILE_LAYOUT_CROP = float4(64.0, 176.0, 191.0, 255.0)
    GROUND_CROP_MIN_X = 0.0
    GROUND_CROP_MIN_Y = 0.0
    GROUND_CROP_MAX_X = 127.0
    GROUND_CROP_MAX_Y = 79.0
    GROUND_CROP_WIDTH = GROUND_CROP_MAX_X - GROUND_CROP_MIN_X + 1.0
    GROUND_CROP_HEIGHT = GROUND_CROP_MAX_Y - GROUND_CROP_MIN_Y + 1.0
    // Top-face rhombus within the crop (excludes 3D side faces below y=63).
    GROUND_DIAMOND_TOP_Y_PX = 0.0
    GROUND_DIAMOND_BOTTOM_Y_PX = 63.0
    GROUND_DIAMOND_LEFT_X_PX = 0.0
    GROUND_DIAMOND_RIGHT_X_PX = 127.0
    GROUND_DIAMOND_FACE_HEIGHT_PX = GROUND_DIAMOND_BOTTOM_Y_PX - GROUND_DIAMOND_TOP_Y_PX
    GROUND_DIAMOND_FACE_WIDTH_PX = GROUND_DIAMOND_RIGHT_X_PX - GROUND_DIAMOND_LEFT_X_PX

    // Tile diamond edge angle from horizontal; grid spacing and sprite height derive from this.
    // Derived from the top-face rhombus in the ground texture (63px tall, 127px wide).
    GROUND_TILE_WORLD_WIDTH = 1.0
    GROUND_TILE_EDGE_ANGLE_DEG = atan(GROUND_DIAMOND_FACE_HEIGHT_PX / GROUND_DIAMOND_FACE_WIDTH_PX) * 180.0 / PI
    TILE_ANGLE_STEP_DEG = 0.5
    TILE_ANGLE_MIN_DEG = 10.0
    TILE_ANGLE_MAX_DEG = 45.0
    TILE_HALF_WIDTH = GROUND_TILE_WORLD_WIDTH * 0.5

    // Depth sorting stride for tile layers and entity interleaving by screen Y.
    DEPTH_TILE_STRIDE = 100
    // Finer steps within one grid cell so Y-sort does not tie and fall back to node Z.
    DEPTH_ENTITY_SUBCELL = 10
    // World-space sprite bottom Y -> renderOrder steps (lower yMin draws in front).
    DEPTH_WORLD_Y_SORT_SCALE = 1000

    PLAYER_SPEED = 2.0
    PLAYER_RUN_SPEED_MULTIPLIER = 2.0
    TERRAIN_SPEED_ROAD_MULTIPLIER = 1.2
}
