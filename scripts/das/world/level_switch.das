require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
require scripts/das/world/level
require scripts/das/world/world
require scripts/das/world/props
require scripts/das/world/collision
require scripts/das/combat/player
require scripts/das/combat/enemies
require scripts/das/world/prefab_texture_hydrate
require scripts/das/combat/aoe_effects
require scripts/das/ui/loading
module level_switch public


def clear_runtime_entities() {
    clear_all_enemies()
    if (enemiesRootNode.isAlive) {
        remove_node(enemiesRootNode)
    }
    enemiesRootNode = NodeId()
    if (effectsRootNode.isAlive) {
        var inscope children = effectsRootNode.get_children()
        for (child in children) {
            if (child.isAlive) {
                remove_node(child)
            }
        }
    }
}


def public switch_to_level(prefabPath : string) : bool {
    if (!gameReady) {
        print("level.switch: wait until loading finishes")
        return false
    }
    if (length(prefabPath) == 0) {
        print("level.switch: empty prefab path")
        return false
    }

    clear_runtime_entities()

    if (levelRootNode.isAlive) {
        remove_node(levelRootNode)
    }
    levelRootNode = NodeId()
    playerNode = NodeId()
    mapRootNode = NodeId()
    wallsRootNode = NodeId()
    propsRootNode = NodeId()
    playerSpawnFeetValid = false
    reset_prefab_textures_hydrated()

    let prefab = request_prefab(prefabPath)
    levelRootNode = instantiate_prefab(prefab)
    if (!levelRootNode.isAlive) {
        print("level.switch: failed to instantiate {prefabPath}")
        return false
    }

    if (!bind_level_scene_nodes()) {
        print("level.switch: scene bind failed for {prefabPath}")
        return false
    }

    begin_level_texture_hydrate()
    build_map()
    apply_procedural_visuals_if_ready()
    init_world_from_prefab()
    build_grid_wall_blockers()
    if (!effectsRootNode.isAlive) {
        init_effects_root()
    }
    spawn_player()
    if (!isBaseLevel) {
        spawn_enemies()
        deathKnightBossTierSpawned = 0
    }
    invalidate_map_visibility_cache()
    print("level.switch: now on {levelRootNode.name} ({prefabPath})")
    return true
}


def public switch_to_level_by_name(levelName : string) : bool {
    if (levelName == "base") {
        return switch_to_level(BASE_PREFAB_PATH)
    }
    if (levelName == "level_1" || levelName == "1") {
        return switch_to_level(LEVEL_1_PREFAB_PATH)
    }
    print("level.switch: unknown level '{levelName}' (use base or level_1)")
    return false
}
