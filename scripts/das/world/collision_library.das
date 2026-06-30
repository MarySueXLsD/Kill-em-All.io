require engine.core
require scripts/das/data/collision_library_data
require scripts/das/core/constants
require strings

module collision_library public


def public collision_library_asset_count() : int {
    return COLLISION_ASSET_COUNT
}


def public collision_library_baked_at() : string {
    return COLLISION_LIBRARY_BAKED_AT
}


def public find_collision_asset_index(texPath : string) : int {
    if (length(texPath) == 0 || COLLISION_ASSET_COUNT <= 0) {
        return -1
    }
    var lo = 0
    var hi = COLLISION_ASSET_COUNT - 1
    while (lo <= hi) {
        let mid = (lo + hi) / 2
        let midPath = COLLISION_TEX_PATHS[mid]
        if (midPath == texPath) {
            return mid
        }
        if (midPath < texPath) {
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    return -1
}


def public collision_asset_crop(index : int) : float4 {
    return COLLISION_CROPS[index]
}


def public collision_asset_feet_px(index : int) : float2 {
    return COLLISION_FEET_PX[index]
}


def public collision_asset_world_width_mul(index : int) : float {
    return COLLISION_WORLD_WIDTH_MUL[index]
}


def public collision_asset_world_width(index : int) : float {
    return GROUND_TILE_WORLD_WIDTH * COLLISION_WORLD_WIDTH_MUL[index]
}


def public collision_asset_low(index : int) : bool {
    return COLLISION_LOW[index]
}


def public collision_asset_segment_count(index : int) : int {
    return COLLISION_SEGMENT_OFFSETS[index + 1] - COLLISION_SEGMENT_OFFSETS[index]
}


def public collision_asset_segment(index, segIndex : int) : float4 {
    let base = COLLISION_SEGMENT_OFFSETS[index]
    return COLLISION_SEGMENTS[base + segIndex]
}
