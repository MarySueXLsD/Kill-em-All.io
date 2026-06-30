require engine.core

module constants_combat public

let public {
    AOE_WORLD_SIZE = 3.2
    AOE_HIT_RADIUS = 1.5
    AOE_WARNING_TEXTURE_FRAME = 4
    AOE_WARNING_FILL_COLOR = float4(1.0, 0.12, 0.08, 0.42)
    AOE_WARNING_EDGE_COLOR = float4(1.0, 0.25, 0.12, 0.78)
    // Frame 0009.png fills ~88% of its UV square; scale warning to match damage disc.
    AOE_WARNING_TEXTURE_FILL = 0.88

    ENEMY_SPAWN_BATCH_COUNT = 6
    ENEMY_SPAWN_PERIOD_SECONDS = 16.0
    ENEMY_SPAWN_COUNT_PER_LEVEL = 1
}
