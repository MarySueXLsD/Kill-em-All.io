require engine.core
require scripts/das/core/constants_grid

module constants_props public

let public {
    PROP_MISC_B12_E_CROP = float4(0.0, 0.0, 135.0, 134.0)
    PROP_MISC_B12_E_FEET_PX = float2(73.5, 134.0)
    PROP_MISC_B12_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 2.0
    // Grass just above spawn, nudged toward the road (opens bottom-left toward spawn road).
    PROP_MISC_B12_E_FEET_GRID = float2(40.18, 40.78)
    PROP_MISC_B12_E_EXTRA_FEET_GRIDS <- [
        float2(52.28, 52.18),
    ]
    // Collision lines authored in Misc B12_E.png texture pixels (ax, ay, bx, by).
    PROP_MISC_B12_E_WALL_LINES_PX <- [

        float4(54.0, 67.0, 133.0, 105.0),
        float4(18.0, 90.0, 54.0, 67.0),
        float4(86.0, 125.0, 133.0, 105.0),
    ]
    PROP_MISC_B5_E_PATH = "static/Environment/Misc/Type_2_Variation_5_East.png"
    PROP_MISC_B5_E_CROP = float4(0.0, 0.0, 126.0, 108.0)
    PROP_MISC_B5_E_FEET_PX = float2(36.0, 108.0)
    PROP_MISC_B5_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 2.0
    // SW grass beside the wavy vertical road.
    PROP_MISC_B5_E_FEET_GRID = float2(28.35, 58.22)
    PROP_MISC_B5_E_EXTRA_FEET_GRIDS <- [
        float2(48.22, 65.18),
        float2(18.55, 62.28),
    ]
    PROP_MISC_B5_E_WALL_LINES_PX <- [

        float4(14.0, 37.0, 108.0, 37.0),
        float4(108.0, 37.0, 102.0, 81.0),
        float4(102.0, 81.0, 13.0, 81.0),
        float4(13.0, 81.0, 14.0, 37.0),
    ]
    PROP_MISC_B10_E_PATH = "static/Environment/Misc/Type_2_Variation_10_East.png"
    PROP_MISC_B10_E_CROP = float4(0.0, 0.0, 80.0, 88.0)
    PROP_MISC_B10_E_FEET_PX = float2(53.5, 88.0)
    PROP_MISC_B10_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 2.0
    // NE grass patch, opening toward the center road crossing.
    PROP_MISC_B10_E_FEET_GRID = float2(58.12, 25.35)
    PROP_MISC_B10_E_EXTRA_FEET_GRIDS <- [
        float2(32.18, 28.35),
    ]
    PROP_MISC_B10_E_WALL_LINES_PX <- [

        float4(13.0, 44.0, 77.0, 44.0),
        float4(13.0, 44.0, 8.0, 66.0),
        float4(77.0, 44.0, 76.0, 66.0),
        float4(13.0, 22.0, 62.0, 22.0),
    ]
    PROP_MISC_B8_E_PATH = "static/Environment/Misc/Type_2_Variation_8_East.png"
    PROP_MISC_B8_E_CROP = float4(0.0, 0.0, 112.0, 65.0)
    PROP_MISC_B8_E_FEET_PX = float2(61.0, 65.0)
    PROP_MISC_B8_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 1.5
    // West of spawn on grass beside the vertical road.
    PROP_MISC_B8_E_FEET_GRID = float2(20.42, 40.15)
    PROP_MISC_B8_E_EXTRA_FEET_GRIDS <- [
        float2(10.35, 35.22),
        float2(70.18, 35.28),
    ]
    PROP_MISC_B8_E_WALL_LINES_PX <- [

        float4(9.0, 16.0, 106.0, 16.0),
        float4(106.0, 16.0, 89.0, 48.0),
        float4(89.0, 48.0, 14.0, 48.0),
        float4(14.0, 48.0, 9.0, 16.0),
    ]
    PROP_MISC_B25_E_PATH = "static/Environment/Misc/Type_2_Variation_25_East.png"
    PROP_MISC_B25_E_CROP = float4(0.0, 0.0, 112.0, 82.0)
    PROP_MISC_B25_E_FEET_PX = float2(44.0, 82.0)
    PROP_MISC_B25_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 2.0
    // East of spawn on grass beside the vertical road.
    PROP_MISC_B25_E_FEET_GRID = float2(60.18, 40.28)
    PROP_MISC_B25_E_WALL_LINES_PX <- [

        float4(27.0, 20.0, 95.0, 20.0),
        float4(95.0, 20.0, 107.0, 43.0),
        float4(107.0, 43.0, 2.0, 61.0),
        float4(2.0, 61.0, 27.0, 20.0),
    ]
    PROP_MISC_B3_E_PATH = "static/Environment/Misc/Type_2_Variation_3_East.png"
    PROP_MISC_B3_E_CROP = float4(0.0, 0.0, 118.0, 133.0)
    PROP_MISC_B3_E_FEET_PX = float2(48.5, 133.0)
    PROP_MISC_B3_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 2.0
    // NW grass clearing.
    PROP_MISC_B3_E_FEET_GRID = float2(15.28, 18.35)
    PROP_MISC_B3_E_WALL_LINES_PX <- [

        float4(17.0, 46.0, 116.0, 46.0),
        float4(116.0, 46.0, 118.0, 86.0),
        float4(118.0, 86.0, 4.0, 106.0),
        float4(4.0, 106.0, 17.0, 46.0),
    ]
    PROP_MISC_B14_E_PATH = "static/Environment/Misc/Type_2_Variation_14_East.png"
    PROP_MISC_B14_E_CROP = float4(0.0, 0.0, 137.0, 138.0)
    PROP_MISC_B14_E_FEET_PX = float2(52.0, 138.0)
    PROP_MISC_B14_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 2.0
    // West-side grass beside the vertical road.
    PROP_MISC_B14_E_FEET_GRID = float2(12.35, 52.18)
    PROP_MISC_B14_E_EXTRA_FEET_GRIDS <- [
        float2(55.55, 58.12),
    ]
    PROP_MISC_B14_E_WALL_LINES_PX <- [

        float4(60.0, 55.0, 123.0, 90.0),
        float4(13.0, 103.0, 60.0, 55.0),
        float4(123.0, 90.0, 120.0, 103.0),
    ]
    PROP_MISC_B11_E_PATH = "static/Environment/Misc/Type_2_Variation_11_East.png"
    PROP_MISC_B11_E_CROP = float4(0.0, 0.0, 95.0, 95.0)
    PROP_MISC_B11_E_FEET_PX = float2(58.0, 95.0)
    PROP_MISC_B11_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 2.0
    // NE grass beside the horizontal road.
    PROP_MISC_B11_E_FEET_GRID = float2(65.22, 22.18)
    PROP_MISC_B11_E_WALL_LINES_PX <- [

        float4(21.0, 23.0, 85.0, 23.0),
        float4(85.0, 23.0, 92.0, 71.0),
        float4(92.0, 71.0, 15.0, 71.0),
        float4(15.0, 71.0, 21.0, 23.0),
    ]
    PROP_MISC_B2_E_PATH = "static/Environment/Misc/Type_2_Variation_2_East.png"
    PROP_MISC_B2_E_CROP = float4(0.0, 0.0, 92.0, 78.0)
    PROP_MISC_B2_E_FEET_PX = float2(61.0, 78.0)
    PROP_MISC_B2_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 1.5
    // North grass above the road crossing.
    PROP_MISC_B2_E_FEET_GRID = float2(42.22, 18.35)
    PROP_MISC_B2_E_WALL_LINES_PX <- [

        float4(25.0, 19.0, 70.0, 19.0),
        float4(70.0, 19.0, 91.0, 58.0),
        float4(91.0, 58.0, 4.0, 58.0),
        float4(4.0, 58.0, 25.0, 19.0),
    ]
    PROP_MISC_B7_E_PATH = "static/Environment/Misc/Type_2_Variation_7_East.png"
    PROP_MISC_B7_E_CROP = float4(0.0, 0.0, 71.0, 55.0)
    PROP_MISC_B7_E_FEET_PX = float2(52.0, 55.0)
    PROP_MISC_B7_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 1.5
    // South grass below the road crossing.
    PROP_MISC_B7_E_FEET_GRID = float2(38.18, 62.22)
    PROP_MISC_B7_E_WALL_LINES_PX <- [

        float4(5.0, 13.0, 45.0, 13.0),
        float4(45.0, 13.0, 67.0, 41.0),
        float4(67.0, 41.0, 24.0, 41.0),
        float4(24.0, 41.0, 5.0, 13.0),
    ]
    PROP_MISC_B9_E_PATH = "static/Environment/Misc/Type_2_Variation_9_East.png"
    PROP_MISC_B9_E_CROP = float4(0.0, 0.0, 65.0, 58.0)
    PROP_MISC_B9_E_FEET_PX = float2(14.0, 58.0)
    PROP_MISC_B9_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 1.5
    PROP_MISC_B9_E_FEET_GRID = float2(62.35, 48.22)
    PROP_MISC_B9_E_WALL_LINES_PX <- [

        float4(31.0, 14.0, 61.0, 14.0),
        float4(61.0, 14.0, 57.0, 43.0),
        float4(57.0, 43.0, 3.0, 43.0),
        float4(3.0, 43.0, 31.0, 14.0),
    ]
    PROP_MISC_B40_E_PATH = "static/Environment/Misc/Type_2_Variation_40_East.png"
    PROP_MISC_B40_E_CROP = float4(0.0, 0.0, 131.0, 67.0)
    PROP_MISC_B40_E_FEET_PX = float2(62.5, 67.0)
    PROP_MISC_B40_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 1.5
    PROP_MISC_B40_E_FEET_GRID = float2(35.55, 12.18)
    PROP_MISC_B40_E_WALL_LINES_PX <- [

        float4(36.0, 16.0, 87.0, 16.0),
        float4(87.0, 16.0, 92.0, 50.0),
        float4(92.0, 50.0, 24.0, 50.0),
        float4(24.0, 50.0, 36.0, 16.0),
    ]
    PROP_MISC_B20_E_PATH = "static/Environment/Misc/Type_2_Variation_20_East.png"
    PROP_MISC_B20_E_CROP = float4(0.0, 0.0, 65.0, 63.0)
    PROP_MISC_B20_E_FEET_PX = float2(29.5, 63.0)
    PROP_MISC_B20_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 1.5
    PROP_MISC_B20_E_FEET_GRID = float2(72.22, 62.18)
    PROP_MISC_B20_E_WALL_LINES_PX <- [

        float4(6.0, 15.0, 65.0, 15.0),
        float4(65.0, 15.0, 60.0, 47.0),
        float4(60.0, 47.0, 0.0, 47.0),
        float4(0.0, 47.0, 6.0, 15.0),
    ]
    PROP_MISC_B1_E_PATH = "static/Environment/Misc/Type_2_Variation_1_East.png"
    PROP_MISC_B1_E_CROP = float4(0.0, 0.0, 53.0, 49.0)
    PROP_MISC_B1_E_FEET_PX = float2(32.0, 49.0)
    PROP_MISC_B1_E_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH * 1.0
    PROP_MISC_B1_E_FEET_GRID = float2(22.35, 28.42)
    PROP_MISC_B1_E_WALL_LINES_PX <- [

        float4(7.0, 12.0, 53.0, 12.0),
        float4(53.0, 12.0, 48.0, 36.0),
        float4(48.0, 36.0, 4.0, 36.0),
        float4(4.0, 36.0, 7.0, 12.0),
    ]
    PROP_WALL_LINE_HALF_THICKNESS = 0.08
    PROP_WALL_BLOCKER_SPACING = 0.28

    LEVEL_1_PREFAB_PATH = "prefabs/level_1.prefab"
    BASE_PREFAB_PATH = "prefabs/base.prefab"
    // Compact hub map — grass everywhere, one road, walled courtyard at the origin corner.
    BASE_GRID_WIDTH = 32
    BASE_GRID_HEIGHT = 32
    BASE_MAP_WIDTH = 24
    BASE_MAP_HEIGHT = 24
    BASE_GRID_MIN_X = -(BASE_GRID_WIDTH - BASE_MAP_WIDTH) / 2
    BASE_GRID_MIN_Y = -(BASE_GRID_HEIGHT - BASE_MAP_HEIGHT) / 2
    BASE_PLAYER_SPAWN_GRID_X = 5.0
    BASE_PLAYER_SPAWN_GRID_Y = 5.0
    BASE_COURTYARD_MIN_GX = 2
    BASE_COURTYARD_MAX_GX = 8
    BASE_COURTYARD_MIN_GY = 2
    BASE_COURTYARD_MAX_GY = 8
    BASE_ROAD_GX = 12
    // Wall B1 straight segments + B2 corners for the map border (pre-cropped source).
    WALL_B1_E_PATH = "static/Environment/Wall/Type_2_Variation_1_East.png"
    WALL_B1_W_PATH = "static/Environment/Wall/Type_2_Variation_1_West.png"
    WALL_B1_N_PATH = "static/Environment/Wall/Type_2_Variation_1_North.png"
    WALL_B1_S_PATH = "static/Environment/Wall/Type_2_Variation_1_South.png"
    WALL_B2_E_PATH = "static/Environment/Wall/Type_2_Variation_2_East.png"
    WALL_B2_W_PATH = "static/Environment/Wall/Type_2_Variation_2_West.png"
    WALL_B2_N_PATH = "static/Environment/Wall/Type_2_Variation_2_North.png"
    WALL_B2_S_PATH = "static/Environment/Wall/Type_2_Variation_2_South.png"
    // Opaque bounds, feet anchor, and authored obstacle bottom lines (texture pixels).
    WALL_B1_E_CROP = float4(0.0, 0.0, 100.0, 155.0)
    WALL_B1_E_FEET_PX = float2(50.0, 155.0)
    WALL_B1_E_BOTTOM_PX_A = float2(19.0, 144.0)
    WALL_B1_E_BOTTOM_PX_B = float2(90.0, 109.0)
    WALL_B1_E_BOTTOM_SPAN_PX = 79.2
    WALL_B1_W_CROP = float4(0.0, 0.0, 100.0, 155.0)
    WALL_B1_W_FEET_PX = float2(50.0, 155.0)
    WALL_B1_W_BOTTOM_PX_A = float2(26.0, 141.0)
    WALL_B1_W_BOTTOM_PX_B = float2(92.0, 111.0)
    WALL_B1_W_BOTTOM_SPAN_PX = 72.5
    WALL_B1_N_CROP = float4(0.0, 0.0, 98.0, 155.0)
    WALL_B1_N_FEET_PX = float2(49.0, 155.0)
    WALL_B1_N_BOTTOM_PX_A = float2(90.0, 143.0)
    WALL_B1_N_BOTTOM_PX_B = float2(21.0, 111.0)
    WALL_B1_N_BOTTOM_SPAN_PX = 76.1
    WALL_B1_S_CROP = float4(0.0, 0.0, 100.0, 155.0)
    WALL_B1_S_FEET_PX = float2(50.0, 155.0)
    WALL_B1_S_BOTTOM_PX_A = float2(90.0, 143.0)
    WALL_B1_S_BOTTOM_PX_B = float2(22.0, 110.0)
    WALL_B1_S_BOTTOM_SPAN_PX = 75.6
    WALL_B1_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH
    WALL_B2_E_CROP = float4(0.0, 0.0, 96.0, 179.0)
    WALL_B2_E_FEET_PX = float2(48.0, 179.0)
    WALL_B2_E_BOTTOM_PX <- [

        float2(24.0, 113.0),
        float2(83.0, 137.0),
        float2(24.0, 166.0),
    ]
    WALL_B2_W_CROP = float4(0.0, 0.0, 90.0, 179.0)
    WALL_B2_W_FEET_PX = float2(45.0, 179.0)
    WALL_B2_W_BOTTOM_PX <- [

        float2(82.0, 109.0),
        float2(22.0, 137.0),
        float2(80.0, 165.0),
    ]
    WALL_B2_N_CROP = float4(0.0, 0.0, 146.0, 151.0)
    WALL_B2_N_FEET_PX = float2(73.0, 151.0)
    WALL_B2_N_BOTTOM_PX <- [

        float2(24.0, 138.0),
        float2(81.0, 112.0),
        float2(136.0, 137.0),
    ]
    WALL_B2_S_CROP = float4(0.0, 0.0, 149.0, 150.0)
    WALL_B2_S_FEET_PX = float2(74.5, 150.0)
    WALL_B2_S_BOTTOM_PX <- [

        float2(22.0, 111.0),
        float2(82.0, 140.0),
        float2(139.0, 109.0),
    ]
    WALL_B2_WORLD_WIDTH = GROUND_TILE_WORLD_WIDTH
    PLAYER_IDLE_PATH = "static/Characters/playable_character_kreol/Idle.png"
    PLAYER_WALK_PATH = "static/Characters/playable_character_kreol/Walk.png"
    PLAYER_RUN_PATH = "static/Characters/playable_character_kreol/Run.png"
    PLAYER_ATTACK1_PATH = "static/Characters/playable_character_kreol/Attack1.png"
    PLAYER_ATTACK2_PATH = "static/Characters/playable_character_kreol/Attack2.png"
}
