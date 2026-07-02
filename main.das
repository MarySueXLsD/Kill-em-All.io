require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/core/input
require scripts/das/core/camera
require scripts/das/world/world
require scripts/das/world/collision
require scripts/das/combat/player
require scripts/das/combat/enemies
require scripts/das/combat/aoe_effects
require scripts/das/combat/projectiles
require scripts/das/world/props
require scripts/das/world/collision_depth_sort
require scripts/das/debug/debug_draw
require scripts/das/ui/loading
require scripts/das/ui/disclaimer
require scripts/das/ui/enemy_hud
require scripts/das/ui/player_hud
require scripts/das/ui/upgrade_picker
require scripts/das/world/level
require scripts/das/world/level_bake
require scripts/das/world/level_switch
require scripts/das/world/prefab_texture_hydrate

def ensure_prefab_textures_hydrated() {
    if (prefab_texture_hydrate::prefabTexturesHydrated || !gameReady) {
        return
    }
    hydrate_level_prefab_textures()
}

def update_tile_angle_tuning() {
    var angleChanged = false
    if (is_action_just_pressed("tileAngleUp")) {
        nudge_tile_edge_angle_deg(TILE_ANGLE_STEP_DEG)
        angleChanged = true
    }
    if (is_action_just_pressed("tileAngleDown")) {
        nudge_tile_edge_angle_deg(-TILE_ANGLE_STEP_DEG)
        angleChanged = true
    }
    if (angleChanged) {
        build_grid_wall_blockers()
    }
}

def update_debug_controls() {
    if (is_action_just_pressed("debugBorders")) {
        debugBordersEnabled = !debugBordersEnabled
    }
    if (is_action_just_pressed("debugToggleEnemies")) {
        enemiesActive = !enemiesActive
        if (enemiesActive) {
            respawn_all_enemies()
        } else {
            clear_all_enemies()
        }
    }
    if (is_action_just_pressed("debugToggleHud")) {
        debugHudVisible = !debugHudVisible
        if (tileAngleHudNode.isAlive) {
            tileAngleHudNode.isActive = debugHudVisible
        }
    }
    update_tile_angle_hud()
}

[cheat(name="props.print_cursor", hint="Print cursor feetGrid and world position for prop placement.")]
def print_cursor_grid() {
    print_cursor_grid_coords()
}

[cheat(name="props.list_types", hint="List all misc prop type ids.")]
def list_prop_types() {
    print_prop_type_ids()
}

[cheat(name="props.spawn_b1_at_cursor", hint="Print grid coords for misc_b1_e at cursor (does not spawn into prefab).")]
def spawn_misc_b1_at_cursor() {
    spawn_prop_at_cursor_grid("misc_b1_e")
}

[cheat(name="props.spawn_b12_at_cursor", hint="Print grid coords for misc_b12_e at cursor (does not spawn into prefab).")]
def spawn_misc_b12_at_cursor() {
    spawn_prop_at_cursor_grid("misc_b12_e")
}

[cheat(name="level.prefab_help", hint="World textures live in TileTextureHint.texturePath; PrefabTextureHydrator applies them.")]
def level_prefab_help() {
    print("Author textures in prefab on TileTextureHint.texturePath, e.g. static/Environment/Ground/Type_1_Variation_1_East.png")
    print("Rebake layout: python scripts/python/bake/bake_level_prefab.py")
    print("Hydrate: automatic on load, or cheat level.hydrate_textures while playing")
    print("Prefab prop placement: props/walls bake before map (lowest uid wins). Use level.hide_map_tiles while placing props.")
    print("If picks are wrong after hand-editing, run: python scripts/python/prefab/fix_prefab_pick_uids.py")
    print("Rebake layout: python scripts/python/bake/bake_level_prefab.py (then fix_prefab_pick_uids if needed)")
    var mapChildCount = 0
    if (mapRootNode.isAlive) {
        mapChildCount = length(mapRootNode.get_children())
    }
    print("Current map cell count: {mapChildCount}")
}

[cheat(name="props.spawn_at_cursor", hint="Print placement coords for a prop id at cursor, e.g. props.spawn_at_cursor misc_b1_e")]
def spawn_prop_at_cursor(propId : string) {
    spawn_prop_at_cursor_grid(propId)
}

[cheat(name="level.base", hint="Switch to the base hub (walk/run/dash only).")]
def cheat_level_base() {
    switch_to_level(BASE_PREFAB_PATH)
}

[cheat(name="level.1", hint="Switch to level_1 (full combat map).")]
def cheat_level_1() {
    switch_to_level(LEVEL_1_PREFAB_PATH)
}

[cheat(name="level.switch", hint="Switch level by name: base or level_1")]
def cheat_level_switch(levelName : string) {
    switch_to_level_by_name(levelName)
}

[export]
def on_initialize() {
    show_mouse_cursor(true)
    init_input()
    init_disclaimer_screen()
}

[export]
def on_post_initialize() {
    bind_level_scene_nodes()
    ensure_render_settings()
}

[export]
def on_update() {
    ensure_prefab_textures_hydrated()
    if (is_disclaimer_active()) {
        if (update_disclaimer()) {
            init_loading_screen()
            return
        }
        return
    }
    if (!gameReady) {
        update_loading_screen()
        advance_loading()
        return
    }

    if (is_upgrade_picker_active()) {
        update_upgrade_picker()
        return
    }

    if (is_upgrade_picker_delaying()) {
        update_upgrade_picker()
    }

    enemyFrameStamp += 1
    ensure_enemy_frame_cache(enemyFrameStamp)

    flush_exp_popup_spawns()
    update_tile_angle_tuning()
    update_debug_controls()
    sync_camera_ortho_size()
    update_camera_follow()
    update_map_visibility()
    if (!playerDashing) {
        update_prop_visibility()
    }
    update_dash_ghosts()
    update_enemy_spawning()
    update_death_knight_boss_spawning()
    if (!playerDashing) {
        update_enemy_health_bar_positions()
    }
    flush_exp_popup_spawns()
    update_exp_popups()
    update_player_health_hud()
    draw_character_debug_hitboxes()
}


[export]
def on_post_update() {
    if (!gameReady || is_disclaimer_active() || is_upgrade_picker_active()) {
        return
    }
    if (!playerDashing) {
        player::sync_player_world_position()
        update_collision_depth_sorting()
    }
}


[export]
def on_resolution_changed(res : int2) {
    resize_loading_screen()
    resize_enemy_health_canvas()
    layout_player_bottom_huds()
    resize_upgrade_picker()
    invalidate_map_visibility_cache()
}
