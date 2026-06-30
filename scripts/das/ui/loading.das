require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
require scripts/das/world/world
require scripts/das/combat/player
require scripts/das/combat/enemies
require scripts/das/combat/aoe_effects
require scripts/das/combat/projectiles
require scripts/das/world/collision
require scripts/das/world/collision_library
require scripts/das/world/props
require scripts/das/world/prefab_texture_hydrate
require scripts/das/ui/enemy_hud
require scripts/das/ui/player_hud public
require scripts/das/ui/upgrade_picker
module loading public

let private TEXTURE_PROBE_PATH = "static/UI/Boxes/title_box.png"

let private LOADING_PHASE_HYDRATE = 0
let private LOADING_PHASE_WORLD = 1
let private LOADING_PHASE_UI_TEXTURES = 2
let private LOADING_PHASE_COLLISION = 3
let private LOADING_PHASE_STREAM = 4
let private LOADING_PHASE_COMBAT_ASSIGN = 5
let private LOADING_PHASE_SPAWN = 6
let private LOADING_PHASE_READY = 7

var private loadingLabelNode : NodeId
var private loadingPhase : int = 0
var private hydrateBegun : bool = false
var private uiPathsQueued : bool = false
var private streamPathsQueued : bool = false
var private worldPathsQueued : bool = false
var private mapBuildBegun : bool = false
var private spawnTexturesReady : bool = false
var private readyHudStep : int = 0
var public backgroundTexturesReady : bool = false
var public extendedTexturesReady : bool = false
var public textureProbeId : TextureId


def set_loading_message(msg : string) {
    if (loadingLabelNode.isAlive) {
        loadingLabelNode?.UIText.text = msg
    }
}


def queue_ui_texture_paths() {
    queue_player_hud_texture_paths()
    queue_upgrade_picker_texture_paths()
    queue_enemy_hud_texture_paths()
    queue_texture_path(TEXTURE_PROBE_PATH)
}


def queue_spawn_combat_texture_paths() {
    queue_spawn_projectile_texture_paths()
}


def queue_stream_texture_paths() {
    queue_spawn_projectile_texture_paths()
    queue_texture_path(ENEMY1_IDLE_PATH)
    queue_texture_path(ENEMY2_IDLE_PATH)
    queue_texture_path(ENEMY3_IDLE_PATH)
    queue_spawn_player_texture_paths()
    queue_pump_enemy_texture_paths()
    queue_background_combat_texture_paths()
    queue_background_player_texture_paths()
    queue_remaining_hydrate_paths()
    queue_texture_path(ENEMY2_SPECIAL1_PATH)
    queue_texture_path(ENEMY6_IDLE_PATH)
    queue_texture_path(ENEMY6_WALK_PATH)
    queue_texture_path(ENEMY6_ATTACK1_PATH)
    queue_texture_path(ENEMY6_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY6_DIE_PATH)
    queue_texture_path(ENEMY6_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_IDLE_PATH)
    queue_texture_path(ENEMY7_WALK_PATH)
    queue_texture_path(ENEMY7_RUN_PATH)
    queue_texture_path(ENEMY7_ATTACK1_PATH)
    queue_texture_path(ENEMY7_CAST_SPELL_PATH)
    queue_texture_path(ENEMY7_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY7_DIE_PATH)
    queue_texture_path(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
    queue_background_projectile_texture_paths()
    queue_background_aoe_texture_paths()
}


def queue_background_combat_texture_paths() {
    queue_texture_path(ENEMY1_ATTACK1_PATH)
    queue_texture_path(ENEMY2_ATTACK1_PATH)
    queue_texture_path(ENEMY3_ATTACK1_PATH)
    queue_texture_path(ENEMY1_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY3_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY1_DIE_PATH)
    queue_texture_path(ENEMY2_DIE_PATH)
    queue_texture_path(ENEMY3_DIE_PATH)
}


def queue_extended_background_texture_paths() {
    queue_background_player_texture_paths()
    queue_texture_path(ENEMY6_IDLE_PATH)
    queue_texture_path(ENEMY6_WALK_PATH)
    queue_texture_path(ENEMY6_ATTACK1_PATH)
    queue_texture_path(ENEMY6_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY6_DIE_PATH)
    queue_texture_path(ENEMY7_IDLE_PATH)
    queue_texture_path(ENEMY7_WALK_PATH)
    queue_texture_path(ENEMY7_ATTACK1_PATH)
    queue_texture_path(ENEMY7_TAKE_DAMAGE_PATH)
    queue_texture_path(ENEMY7_DIE_PATH)
    queue_texture_path(ENEMY2_SPECIAL1_PATH)
    queue_texture_path(ENEMY6_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_CAST_SPELL_PATH)
    queue_texture_path(ENEMY7_SPECIAL1_PATH)
    queue_texture_path(ENEMY7_RUN_PATH)
    queue_texture_path(ENEMY_SPELL_PROJECTILE_TEXTURE_PATH)
    queue_background_projectile_texture_paths()
    queue_background_aoe_texture_paths()
}


def queue_pump_combat_texture_paths() {
    queue_spawn_player_texture_paths()
    queue_pump_enemy_texture_paths()
    queue_background_combat_texture_paths()
    queue_extended_background_texture_paths()
}


def queue_combat_texture_paths() {
    queue_spawn_combat_texture_paths()
    queue_stream_texture_paths()
}


def assign_ui_texture_modules() {
    load_player_hud_textures()
    load_upgrade_picker_textures()
    load_enemy_hud_textures()
    textureProbeId = request_texture_cached(TEXTURE_PROBE_PATH)
}


def assign_spawn_combat_texture_modules() {
    load_spawn_player_textures()
    load_spawn_enemy_textures()
    load_spawn_projectile_textures()
}


def refresh_pump_combat_texture_bindings() {
    refresh_spawn_player_textures_from_cache()
    refresh_spawn_enemy_textures_from_cache()
    refresh_extended_enemy_textures_from_cache()
    refresh_projectile_textures_from_cache()
    refresh_aoe_textures_from_cache()
}


def assign_combat_texture_modules() {
    assign_spawn_combat_texture_modules()
    refresh_pump_combat_texture_bindings()
    assign_level_sprite_textures()
}


def public verify_game_textures_loaded() : bool {
    let ok = prefabTexturesHydrated && texture_id_is_valid(playerBottomBarTexture)
    gameTexturesVerified = ok
    if (!ok) {
        print("loading: texture verification (hydrated={prefabTexturesHydrated}, hud={texture_id_is_valid(playerBottomBarTexture)})")
    }
    return ok
}


def public load_all_game_textures() {
    assign_ui_texture_modules()
    assign_combat_texture_modules()
    load_world_textures()
    load_prop_textures()
}


def public reload_game_textures_for_runtime() {
    gameTexturesVerified = false
    reset_texture_loading_state()
    queue_ui_texture_paths()
    queue_combat_texture_paths()
}


def public ensure_game_textures_loaded() {
    if (gameTexturesVerified) {
        return
    }
}


def public apply_procedural_visuals_if_ready() {
    if (!gameTexturesVerified) {
        return
    }
    if (!world_textures_ready() || !propTexturesLoaded) {
        return
    }
    apply_map_prefab_textures()
    refresh_level_prop_visuals()
}


def public pump_background_texture_loads() : bool {
    return extendedTexturesReady
}


def public init_loading_screen() {
    loadingPhase = LOADING_PHASE_HYDRATE
    hydrateBegun = false
    uiPathsQueued = false
    worldPathsQueued = false
    mapBuildBegun = false
    spawnTexturesReady = false
    readyHudStep = 0
    streamPathsQueued = false
    backgroundTexturesReady = false
    extendedTexturesReady = false
    gameReady = false
    gameTexturesVerified = false
    reset_prefab_textures_hydrated()
    reset_texture_loading_state()
    loadingLabelNode = create_debug_text("Loading...", float2(0.0, 0.0), float2(0.5, 0.5))
    loadingLabelNode.name = "loading_label"
    loadingLabelNode?.UIText.fontScaling = false
    loadingLabelNode?.UIText.autoResizeFrame = true
    set_loading_message("Starting...")
}


def public hide_loading_screen() {
    if (loadingLabelNode.isAlive) {
        remove_node(loadingLabelNode)
    }
}


def public advance_loading() : bool {
    if (gameReady) {
        return true
    }

    begin_texture_load_frame()

    if (loadingPhase == LOADING_PHASE_HYDRATE) {
        if (!hydrateBegun) {
            begin_level_texture_hydrate()
            hydrateBegun = true
        }
        if (!advance_level_texture_hydrate(HYDRATE_WALK_NODES_PER_FRAME)) {
            let pct = int(hydrate_level_progress() * 100.0)
            set_loading_message("Binding world... {pct}%")
            return false
        }
        release_hydrate_loading_scratch()
        begin_deferred_texture_batch()
        set_loading_message("Loading terrain...")
        loadingPhase = LOADING_PHASE_WORLD
        return false
    }

    if (loadingPhase == LOADING_PHASE_WORLD) {
        if (!worldPathsQueued) {
            queue_world_texture_paths()
            worldPathsQueued = true
        }
        if (!advance_deferred_texture_loads(MAX_TEXTURE_LOADS_PER_FRAME)) {
            let left = deferred_textures_remaining()
            set_loading_message("Loading terrain... ({left} left)")
            return false
        }
        release_deferred_texture_scratch()
        load_world_textures()
        if (!mapBuildBegun) {
            begin_batched_map_build()
            mapBuildBegun = true
        }
        if (!advance_batched_map_build(MAP_CELLS_PER_FRAME)) {
            let pct = int(batched_map_build_progress() * 100.0)
            set_loading_message("Building map... {pct}%")
            return false
        }
        init_world_from_prefab()
        apply_map_prefab_textures()
        release_map_build_scratch()
        begin_deferred_texture_batch()
        loadingPhase = LOADING_PHASE_UI_TEXTURES
        return false
    }

    if (loadingPhase == LOADING_PHASE_UI_TEXTURES) {
        if (!uiPathsQueued) {
            queue_ui_texture_paths()
            uiPathsQueued = true
            set_loading_message("Loading UI...")
        }
        if (!advance_deferred_texture_loads(MAX_TEXTURE_LOADS_PER_FRAME)) {
            let left = deferred_textures_remaining()
            set_loading_message("Loading UI... ({left} left)")
            return false
        }
        release_deferred_texture_scratch()
        assign_ui_texture_modules()
        verify_game_textures_loaded()
        begin_deferred_texture_batch()
        loadingPhase = LOADING_PHASE_COLLISION
        return false
    }

    if (loadingPhase == LOADING_PHASE_COLLISION) {
        set_loading_message("Preparing collision...")
        build_grid_wall_blockers()
        print(
            "collision library: {collision_library_asset_count()} assets (baked {collision_library_baked_at()})"
        )
        init_effects_root()
        begin_deferred_texture_batch()
        loadingPhase = LOADING_PHASE_STREAM
        return false
    }

    if (loadingPhase == LOADING_PHASE_STREAM) {
        if (!streamPathsQueued) {
            queue_stream_texture_paths()
            streamPathsQueued = true
            set_loading_message("Loading assets...")
        }
        if (!advance_deferred_texture_loads(MAX_TEXTURE_LOADS_PER_FRAME)) {
            let left = deferred_textures_remaining()
            let heapPct = heap_usage_percent()
            set_loading_message("Loading assets... ({left} left, {heapPct}% heap)")
            if (should_refresh_texture_bindings()) {
                refresh_pump_combat_texture_bindings()
                load_spawn_player_textures()
                load_spawn_enemy_textures()
                load_spawn_projectile_textures()
            }
            return false
        }
        release_deferred_texture_scratch()
        refresh_pump_combat_texture_bindings()
        load_spawn_player_textures()
        load_spawn_enemy_textures()
        load_spawn_projectile_textures()
        extendedTexturesReady = true
        backgroundTexturesReady = true
        print("loading: assets ready, heap={heap_usage_percent()}%, character sheets={cached_character_sheet_count()}")
        loadingPhase = LOADING_PHASE_COMBAT_ASSIGN
        return false
    }

    if (loadingPhase == LOADING_PHASE_COMBAT_ASSIGN) {
        if (!advance_level_sprite_texture_assign(SPRITE_ASSIGN_NODES_PER_FRAME)) {
            let pct = int(sprite_assign_progress() * 100.0)
            set_loading_message("Binding world props... {pct}%")
            return false
        }
        loadingPhase = LOADING_PHASE_SPAWN
        return false
    }

    if (loadingPhase == LOADING_PHASE_SPAWN) {
        if (!spawnTexturesReady) {
            load_spawn_player_textures()
            load_spawn_enemy_textures()
            spawnTexturesReady = true
        }
        set_loading_message("Spawning entities...")
        init_enemy_health_canvas()
        spawn_player()
        if (!isBaseLevel) {
            spawn_enemies()
        }
        readyHudStep = 0
        loadingPhase = LOADING_PHASE_READY
        return false
    }

    if (loadingPhase == LOADING_PHASE_READY) {
        if (readyHudStep == 0) {
            set_loading_message("Ready")
            init_player_hud_step(0)
            readyHudStep++
            return false
        }
        if (readyHudStep == 1) {
            init_player_hud_step(1)
            readyHudStep++
            return false
        }
        if (readyHudStep == 2) {
            init_player_hud_step(2)
            readyHudStep++
            return false
        }
        if (readyHudStep == 3) {
            init_upgrade_picker()
            init_tile_angle_hud()
            gameReady = true
            hide_loading_screen()
            loadingPhase++
            if (textureFileFallbackCount > 0) {
                print("loading: {textureFileFallbackCount} textures loaded via image file fallback")
            }
            return true
        }
        return false
    }

    return false
}
