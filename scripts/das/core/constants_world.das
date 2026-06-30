require engine.core
require scripts/das/core/constants_grid

module constants_world public

let public {
    GROUND_DIR_N = 1
    GROUND_DIR_S = 2
    GROUND_DIR_W = 3
    GROUND_GRASS_NOISE_PATCH = 7
    GROUND_GRASS_NOISE_THRESHOLD = 0.35
    GROUND_SPAWN_GRASS_RADIUS = 10
    GROUND_GRASS_MIN_NEIGHBORS = 2
    GROUND_A5_CANDIDATE_CHANCE = 0.10
    GROUND_A5_MIN_SPACING = 8
    GROUND_ROAD_WAVE_AMPLITUDE = 6.0
    GROUND_ROAD_WAVE_SCALE = 10.0
    GROUND_ROAD_HALF_WIDTH = 2.0
    DEPTH_TILE_OVERLAY_BIAS = 1
    // Grass/fringe sit above every ground tile (ground depth tops out ~190 on this map).
    DEPTH_TILE_GRASS_BIAS = DEPTH_TILE_STRIDE * 2 - 1
    // Global band so every road draws above every grass tile.
    DEPTH_TILE_ROAD_BIAS = DEPTH_TILE_STRIDE * 2
    // Map border palisades: south/west edges behind entities; north edges use fixed foreground band.
    DEPTH_BORDER_WALL_BELOW_BIAS = -50
    DEPTH_FOREGROUND_OVERLAY_HEADROOM = 50
    // Low-collision props (projectile pass-through) sort with entities at the same feet cell.
    DEPTH_PASSABLE_PROP_BIAS = 0
    DEPTH_PROJECTILE_ABOVE_PASSABLE = 1
    // Collision-volume depth sort: nudge render order when legs vs prop segments overlap.
    DEPTH_COLLISION_SORT_BIAS = 2
    COLLISION_DEPTH_Y_EPSILON = 0.02
    COLLISION_DEPTH_PROP_NEAR_MARGIN = 2.0
    COLLISION_DEPTH_SORT_PASSES = 3
    GROUND_A1_PATHS <- [
        "static/Environment/Ground/Type_1_Variation_1_East.png",
        "static/Environment/Ground/Type_1_Variation_1_North.png",
        "static/Environment/Ground/Type_1_Variation_1_South.png",
        "static/Environment/Ground/Type_1_Variation_1_West.png",
    ]
    GROUND_A2_PATHS <- [
        "static/Environment/Ground/Type_1_Variation_2_East.png",
        "static/Environment/Ground/Type_1_Variation_2_North.png",
        "static/Environment/Ground/Type_1_Variation_2_South.png",
        "static/Environment/Ground/Type_1_Variation_2_West.png",
    ]
    GROUND_A3_PATHS <- [
        "static/Environment/Ground/Type_1_Variation_3_East.png",
        "static/Environment/Ground/Type_1_Variation_3_North.png",
        "static/Environment/Ground/Type_1_Variation_3_South.png",
        "static/Environment/Ground/Type_1_Variation_3_West.png",
    ]
    GROUND_A4_PATHS <- [
        "static/Environment/Ground/Type_1_Variation_4_East.png",
        "static/Environment/Ground/Type_1_Variation_4_North.png",
        "static/Environment/Ground/Type_1_Variation_4_South.png",
        "static/Environment/Ground/Type_1_Variation_4_West.png",
    ]
    GROUND_A5_PATHS <- [
        "static/Environment/Ground/Type_1_Variation_5_East.png",
        "static/Environment/Ground/Type_1_Variation_5_North.png",
        "static/Environment/Ground/Type_1_Variation_5_South.png",
        "static/Environment/Ground/Type_1_Variation_5_West.png",
    ]
    // Pre-cropped source bounds in original 256x256 tex space (for UV remapping).
    GROUND_A1_SOURCE_CROPS <- [
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
    ]
    GROUND_A2_SOURCE_CROPS <- [
        float4(61.0, 171.0, 192.0, 241.0),
        float4(61.0, 171.0, 193.0, 241.0),
        float4(63.0, 169.0, 193.0, 241.0),
        float4(63.0, 171.0, 193.0, 241.0),
    ]
    GROUND_A3_SOURCE_CROPS <- [
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
    ]
    GROUND_A4_SOURCE_CROPS <- [
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
        float4(64.0, 176.0, 191.0, 255.0),
    ]
    GROUND_A5_SOURCE_CROPS <- [
        float4(61.0, 171.0, 192.0, 241.0),
        float4(61.0, 171.0, 193.0, 241.0),
        float4(63.0, 169.0, 193.0, 241.0),
        float4(63.0, 171.0, 193.0, 241.0),
    ]
    GROUND_ROAD_PATHS <- [
        "static/Environment/Ground/Type_5_Variation_1_East.png",
        "static/Environment/Ground/Type_5_Variation_1_North.png",
        "static/Environment/Ground/Type_5_Variation_1_South.png",
        "static/Environment/Ground/Type_5_Variation_1_West.png",
    ]
    GROUND_ROAD_SOURCE_CROPS <- [
        float4(68.0, 179.0, 187.0, 238.0),
        float4(70.0, 178.0, 189.0, 238.0),
        float4(66.0, 178.0, 185.0, 237.0),
        float4(68.0, 176.0, 187.0, 236.0),
    ]

    // Environment props (free-placed sprites, not grid tiles). Textures are pre-cropped.
    PROP_MISC_B12_E_PATH = "static/Environment/Misc/Type_2_Variation_12_East.png"
    // Opaque bounds measured from Misc B12_E.png; feet at the bottom diamond tip.
}
