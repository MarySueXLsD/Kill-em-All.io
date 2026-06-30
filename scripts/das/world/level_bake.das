require engine.core
require scripts/das/core/game_state
require scripts/das/world/prefab_texture_hydrate
require scripts/das/world/world
require scripts/das/world/props
require scripts/das/ui/loading
module level_bake public


[cheat(name="level.hydrate_textures", hint="Apply TileTextureHint.texturePath onto each SpriteRenderer.")]
def hydrate_textures_cheat() {
    complete_level_texture_hydrate()
    print("Hydrated SpriteRenderer.textureId from TileTextureHint.texturePath.")
}


[cheat(name="level.memory_status", hint="Print heap usage and texture load queue status.")]
def memory_status_cheat() {
    print("heap used: {heap_bytes_used()} / {HEAP_LIMIT_BYTES} ({heap_usage_percent()}%)")
    print("character sheets cached: {cached_character_sheet_count()}")
    print("deferred textures remaining: {deferred_textures_remaining()}")
}


[cheat(name="level.texture_status", hint="Print runtime texture load and hydration status.")]
def texture_status_cheat() {
    var mapChildCount = 0
    if (mapRootNode.isAlive) {
        mapChildCount = length(mapRootNode.get_children())
    }
    print("gameTexturesVerified: {gameTexturesVerified}")
    print("prefabTexturesHydrated: {prefabTexturesHydrated}")
    print("world_textures_ready: {world_textures_ready()}")
    print("propTexturesLoaded: {propTexturesLoaded}")
    print("map cell count: {mapChildCount}")
    print("texture probe path: static/UI/Boxes/title_box.png")
    print("texture probe valid: {texture_id_is_valid(textureProbeId)}")
    print("texture file fallbacks used: {textureFileFallbackCount}")
}


[cheat(name="level.hide_map_tiles", hint="Hide ground/grass/road sprites so props are easier to click in the prefab editor.")]
def hide_map_tiles_cheat() {
    set_map_tile_sprites_active(false)
    print("Map tile sprites hidden. Use level.show_map_tiles to restore.")
}


[cheat(name="level.show_map_tiles", hint="Show ground/grass/road sprites again.")]
def show_map_tiles_cheat() {
    set_map_tile_sprites_active(true)
    print("Map tile sprites visible.")
}
