require engine.core
require scripts/das/world/tile_texture_hint
require scripts/das/world/level
require scripts/das/core/game_state
module prefab_texture_hydrate public

let public HEAP_LIMIT_BYTES = 104857600
// ~6% headroom below the Eden script heap cap (game loading may use up to ~94%).
let public HEAP_SAFETY_MARGIN = 6291456
// Book frames are fully pinned before game texture streaming starts.
let public LOADING_ANIM_HEAP_RESERVE_BYTES = 0
let public MAX_TEXTURE_LOADS_PER_FRAME_WHILE_LOADING = 8
let public LARGE_DECODE_BYTES = 8388608
let public SMALL_DECODE_BYTES = 524288
let public MAX_TEXTURE_LOADS_PER_FRAME = 8
let public HYDRATE_WALK_NODES_PER_FRAME = 64
let public SPRITE_ASSIGN_NODES_PER_FRAME = 64
let public TEXTURE_BIND_REFRESH_INTERVAL = 8

let private HYDRATE_PHASE_COLLECT = 0
let private HYDRATE_PHASE_PATHS = 1
let private HYDRATE_PHASE_ASSIGN = 2

var public prefabTexturesHydrated : bool = false
var public textureFileFallbackCount : int = 0
var private cachedTexturePaths : array<string>
var private cachedTextureIds : array<TextureId>
var private remainingFileFallbackBudget : int = 0
var private hydrateUniquePaths : array<string>
var private hydratePhase : int = 0
var private hydratePathCursor : int = 0
var private hydrateWalkStack : array<NodeId>
var private hydrateWalkNodesVisited : int = 0
var private deferredPaths : array<string>
var private deferredPathCursor : int = 0
var private textureLoadFrameTick : int = 0
var private spriteAssignWalkActive : bool = false
var private spriteAssignNodesVisited : int = 0
var private streamLoadsSinceRefresh : int = 0


def public reset_prefab_textures_hydrated() {
    prefabTexturesHydrated = false
}


def public reset_texture_loading_state() {
    clear_texture_request_cache()
    clear(hydrateUniquePaths)
    hydratePhase = HYDRATE_PHASE_COLLECT
    hydratePathCursor = 0
    clear(hydrateWalkStack)
    hydrateWalkNodesVisited = 0
    clear(deferredPaths)
    deferredPathCursor = 0
    textureFileFallbackCount = 0
    remainingFileFallbackBudget = 0
    textureLoadFrameTick = 0
    spriteAssignWalkActive = false
    spriteAssignNodesVisited = 0
    streamLoadsSinceRefresh = 0
}


def public clear_texture_request_cache() {
    clear(cachedTexturePaths)
    clear(cachedTextureIds)
}


def public heap_bytes_used() : int {
    return int(heap_bytes_allocated()) + int(string_heap_bytes_allocated())
}


def public loading_animation_heap_cap() : int {
    return HEAP_LIMIT_BYTES - HEAP_SAFETY_MARGIN
}


def public effective_game_texture_heap_cap() : int {
    let cap = loading_animation_heap_cap()
    if (!gameReady) {
        return cap - LOADING_ANIM_HEAP_RESERVE_BYTES
    }
    return cap
}


def estimated_decode_bytes(texPath : string) : int {
    if (is_character_texture_path(texPath)) {
        return LARGE_DECODE_BYTES
    }
    return SMALL_DECODE_BYTES
}


def public memory_can_load_texture(texPath : string) : bool {
    if (!gameReady && loadingBookBlocksGameLoads) {
        return false
    }
    let used = heap_bytes_used()
    let need = estimated_decode_bytes(texPath)
    return used + need < effective_game_texture_heap_cap()
}


def compute_texture_load_budget() : int {
    let used = heap_bytes_used()
    let room = effective_game_texture_heap_cap() - used
    if (room < SMALL_DECODE_BYTES) {
        return 0
    }
    var budget = 1
    if (room >= LARGE_DECODE_BYTES + SMALL_DECODE_BYTES * 2) {
        budget = MAX_TEXTURE_LOADS_PER_FRAME
    }
    if (!gameReady && budget > MAX_TEXTURE_LOADS_PER_FRAME_WHILE_LOADING) {
        budget = MAX_TEXTURE_LOADS_PER_FRAME_WHILE_LOADING
    }
    return budget
}


def public heap_usage_percent() : int {
    return int(100.0 * float(heap_bytes_used()) / float(HEAP_LIMIT_BYTES))
}


def public begin_texture_load_frame() {
    textureLoadFrameTick++
    remainingFileFallbackBudget = compute_texture_load_budget()
}


def public texture_id_is_valid(tex : TextureId) : bool {
    return valid(tex)
}


def is_ground_tile_texture_path(texPath : string) : bool {
    return find(texPath, "/Environment/Ground/") >= 0
}


def is_playable_character_texture_path(texPath : string) : bool {
    return find(texPath, "/Characters/playable_character_") >= 0
}


def is_character_texture_path(texPath : string) : bool {
    return find(texPath, "/Characters/") >= 0
}


def count_cached_character_sheets() : int {
    var count = 0
    for (i in range(length(cachedTexturePaths))) {
        if (is_character_texture_path(cachedTexturePaths[i]) && texture_id_is_valid(cachedTextureIds[i])) {
            count++
        }
    }
    return count
}


def should_load_during_hydrate(texPath : string) : bool {
    return is_playable_character_texture_path(texPath)
}


def path_cached_valid(texPath : string) : bool {
    if (length(texPath) == 0) {
        return false
    }
    for (i in range(length(cachedTexturePaths))) {
        if (cachedTexturePaths[i] == texPath && texture_id_is_valid(cachedTextureIds[i])) {
            return true
        }
    }
    return false
}


def lookup_texture_cache(texPath : string) : TextureId {
    for (i in range(length(cachedTexturePaths))) {
        if (cachedTexturePaths[i] == texPath) {
            return cachedTextureIds[i]
        }
    }
    return TextureId()
}


def upsert_texture_cache(texPath : string; tex : TextureId) {
    for (i in range(length(cachedTexturePaths))) {
        if (cachedTexturePaths[i] == texPath) {
            cachedTextureIds[i] = tex
            return
        }
    }
    push(cachedTexturePaths, texPath)
    push(cachedTextureIds, tex)
}


def queue_hydrate_unique_path(texPath : string) {
    if (length(texPath) == 0 || is_ground_tile_texture_path(texPath) || path_cached_valid(texPath)) {
        return
    }
    for (i in range(length(hydrateUniquePaths))) {
        if (hydrateUniquePaths[i] == texPath) {
            return
        }
    }
    push(hydrateUniquePaths, texPath)
}


def request_texture_from_image_file(texPath : string) : TextureId {
    if (remainingFileFallbackBudget <= 0) {
        return TextureId()
    }
    remainingFileFallbackBudget--
    var created : TextureId
    var loaded = false
    get_image_content(texPath) $(var bitmap : Bitmap) {
        created = create_texture(bitmap, TextureDeclaration(
            filter = TextureFilter.Point,
            sRGB = true,
            addressing = TextureAddress.Clamp,
            generateMipLevels = false
        ))
        loaded = true
    }
    if (loaded && texture_id_is_valid(created)) {
        textureFileFallbackCount++
        return created
    }
    return TextureId()
}


def public texture_from_cache_only(texPath : string) : TextureId {
    if (path_cached_valid(texPath)) {
        return lookup_texture_cache(texPath)
    }
    return TextureId()
}


def public request_texture_cached(texPath : string) : TextureId {
    if (length(texPath) == 0) {
        return TextureId()
    }
    if (path_cached_valid(texPath)) {
        return lookup_texture_cache(texPath)
    }
    let tex = request_texture_from_image_file(texPath)
    if (texture_id_is_valid(tex)) {
        upsert_texture_cache(texPath, tex)
    }
    return tex
}


def public queue_texture_path(texPath : string) {
    if (length(texPath) == 0 || path_cached_valid(texPath)) {
        return
    }
    for (i in range(length(deferredPaths))) {
        if (deferredPaths[i] == texPath) {
            return
        }
    }
    push(deferredPaths, texPath)
}


def public cached_character_sheet_count() : int {
    return count_cached_character_sheets()
}


def public advance_deferred_texture_loads(maxLoads : int) : bool {
    var loadsAttempted = 0
    let loadLimit = min(maxLoads, MAX_TEXTURE_LOADS_PER_FRAME)
    while (deferredPathCursor < length(deferredPaths)) {
        let texPath = deferredPaths[deferredPathCursor]
        if (!path_cached_valid(texPath)) {
            if (!memory_can_load_texture(texPath)) {
                break
            }
            if (loadsAttempted >= loadLimit || remainingFileFallbackBudget <= 0) {
                break
            }
            request_texture_cached(texPath)
            loadsAttempted++
            streamLoadsSinceRefresh++
            if (!path_cached_valid(texPath)) {
                print("texture load failed, skipping: {texPath}")
                deferredPathCursor++
                continue
            }
        }
        deferredPathCursor++
    }
    return deferredPathCursor >= length(deferredPaths)
}


def public should_refresh_texture_bindings() : bool {
    if (streamLoadsSinceRefresh >= TEXTURE_BIND_REFRESH_INTERVAL) {
        streamLoadsSinceRefresh = 0
        return true
    }
    return false
}


def public begin_deferred_texture_batch() {
    clear(deferredPaths)
    deferredPathCursor = 0
}


def public release_deferred_texture_scratch() {
    clear(deferredPaths)
    deferredPathCursor = 0
}


def public release_hydrate_loading_scratch() {
    clear(hydrateWalkStack)
}


def public queue_remaining_hydrate_paths() {
    for (i in range(length(hydrateUniquePaths))) {
        let texPath = hydrateUniquePaths[i]
        if (!is_ground_tile_texture_path(texPath) && !should_load_during_hydrate(texPath)) {
            queue_texture_path(texPath)
        }
    }
    clear(hydrateUniquePaths)
}


def public begin_level_sprite_texture_assign() {
    reset_hydrate_walk_stack()
    spriteAssignWalkActive = true
    spriteAssignNodesVisited = 0
}


def public advance_level_sprite_texture_assign(maxNodes : int) : bool {
    if (!spriteAssignWalkActive) {
        begin_level_sprite_texture_assign()
    }
    var processed = 0
    while (length(hydrateWalkStack) > 0 && processed < maxNodes) {
        let node = hydrateWalkStack[length(hydrateWalkStack) - 1]
        pop(hydrateWalkStack)
        visit_hydrate_node_assign(node)
        if (node.isAlive) {
            var inscope children = node.get_children()
            for (child in children) {
                push(hydrateWalkStack, child)
            }
        }
        spriteAssignNodesVisited++
        processed++
    }
    let done = length(hydrateWalkStack) == 0
    if (done) {
        spriteAssignWalkActive = false
    }
    return done
}


def public sprite_assign_progress() : float {
    return min(1.0, float(spriteAssignNodesVisited) / 2500.0)
}


def public assign_level_sprite_textures() {
    begin_level_sprite_texture_assign()
    while (!advance_level_sprite_texture_assign(SPRITE_ASSIGN_NODES_PER_FRAME)) {
    }
}


def public deferred_textures_remaining() : int {
    return length(deferredPaths) - deferredPathCursor
}


// Eden does not load SpriteRenderer.textureId from hand-written prefab fields.
// TileTextureHint.texturePath is the authored source; this copies it onto SpriteRenderer.
class PrefabTextureHydrator : Component {
}


def reset_hydrate_walk_stack() {
    clear(hydrateWalkStack)
    if (playerNode.isAlive) {
        push(hydrateWalkStack, playerNode)
    }
    if (propsRootNode.isAlive) {
        push(hydrateWalkStack, propsRootNode)
    }
    if (wallsRootNode.isAlive) {
        push(hydrateWalkStack, wallsRootNode)
    }
}


def visit_hydrate_node_collect(node : NodeId) {
    if (!node.isAlive || node?.SpriteRenderer == null || node?.TileTextureHint == null) {
        return
    }
    let texPath = node?.TileTextureHint.texturePath
    if (length(texPath) > 0) {
        queue_hydrate_unique_path(texPath)
    }
}


def visit_hydrate_node_assign(node : NodeId) {
    if (!node.isAlive || node?.SpriteRenderer == null) {
        return
    }
    let current = node?.SpriteRenderer.textureId
    if (texture_id_is_valid(current)) {
        return
    }
    if (node?.TileTextureHint == null) {
        return
    }
    let texPath = node?.TileTextureHint.texturePath
    if (length(texPath) == 0 || is_ground_tile_texture_path(texPath) || !path_cached_valid(texPath)) {
        return
    }
    node?.SpriteRenderer.textureId = lookup_texture_cache(texPath)
}


def advance_hydrate_walk(collectPaths : bool; maxNodes : int) : bool {
    var processed = 0
    while (length(hydrateWalkStack) > 0 && processed < maxNodes) {
        let node = hydrateWalkStack[length(hydrateWalkStack) - 1]
        pop(hydrateWalkStack)
        if (collectPaths) {
            visit_hydrate_node_collect(node)
        } else {
            visit_hydrate_node_assign(node)
        }
        if (node.isAlive) {
            var inscope children = node.get_children()
            for (child in children) {
                push(hydrateWalkStack, child)
            }
        }
        hydrateWalkNodesVisited++
        processed++
    }
    return length(hydrateWalkStack) == 0
}


def public begin_level_texture_hydrate() {
    bind_level_scene_nodes()
    clear(hydrateUniquePaths)
    hydratePhase = HYDRATE_PHASE_COLLECT
    hydratePathCursor = 0
    hydrateWalkNodesVisited = 0
    reset_hydrate_walk_stack()
    prefabTexturesHydrated = false
}


def advance_hydrate_texture_paths() : bool {
    while (hydratePathCursor < length(hydrateUniquePaths)) {
        let texPath = hydrateUniquePaths[hydratePathCursor]
        if (!should_load_during_hydrate(texPath)) {
            hydratePathCursor++
            continue
        }
        if (!path_cached_valid(texPath)) {
            if (!memory_can_load_texture(texPath)) {
                return false
            }
            request_texture_cached(texPath)
            if (!path_cached_valid(texPath)) {
                print("hydrate texture load failed, skipping: {texPath}")
                hydratePathCursor++
                continue
            }
        }
        hydratePathCursor++
    }
    return true
}


def public advance_level_texture_hydrate(maxNodes : int) : bool {
    if (hydratePhase == HYDRATE_PHASE_COLLECT) {
        if (!advance_hydrate_walk(true, maxNodes)) {
            return false
        }
        hydratePhase = HYDRATE_PHASE_PATHS
        hydratePathCursor = 0
    }

    if (hydratePhase == HYDRATE_PHASE_PATHS) {
        if (!advance_hydrate_texture_paths()) {
            return false
        }
        hydratePhase = HYDRATE_PHASE_ASSIGN
        hydrateWalkNodesVisited = 0
        reset_hydrate_walk_stack()
    }

    if (hydratePhase == HYDRATE_PHASE_ASSIGN) {
        if (!advance_hydrate_walk(false, maxNodes)) {
            return false
        }
        prefabTexturesHydrated = true
        return true
    }

    return false
}


def public hydrate_level_progress() : float {
    if (hydratePhase == HYDRATE_PHASE_COLLECT) {
        return 0.05
    }
    if (hydratePhase == HYDRATE_PHASE_PATHS) {
        let pathTotal = length(hydrateUniquePaths)
        if (pathTotal == 0) {
            return 0.5
        }
        return 0.1 + 0.5 * float(hydratePathCursor) / float(pathTotal)
    }
    if (hydratePhase == HYDRATE_PHASE_ASSIGN) {
        return 0.6 + 0.4 * min(1.0, float(hydrateWalkNodesVisited) / 2500.0)
    }
    return 1.0
}


def public hydrate_level_prefab_textures() {
    if (hydratePhase == HYDRATE_PHASE_COLLECT && length(hydrateWalkStack) == 0 && !prefabTexturesHydrated) {
        begin_level_texture_hydrate()
    }
    begin_texture_load_frame()
    advance_level_texture_hydrate(HYDRATE_WALK_NODES_PER_FRAME)
}


def public complete_level_texture_hydrate() {
    begin_level_texture_hydrate()
    begin_texture_load_frame()
    advance_level_texture_hydrate(HYDRATE_WALK_NODES_PER_FRAME)
}
