require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
module level public

var public levelRootNode : NodeId


def public bind_level_scene_nodes() : bool {
    levelRootNode = find_child_recursive("base")
    if (!levelRootNode.isAlive) {
        levelRootNode = find_child_recursive("level_1")
    }
    if (!levelRootNode.isAlive) {
        levelRootNode = find_child_recursive("level")
    }
    if (!levelRootNode.isAlive) {
        return false
    }
    if (levelRootNode.name == "base") {
        configure_base_level_profile()
    } else {
        configure_level_1_profile()
    }
    let cam = find_child(levelRootNode, "camera")
    if (cam.isAlive) {
        cameraNode = cam
        cameraOrthoSize = player_camera_ortho_size()
        cameraOrthoSizeTarget = cameraOrthoSize
        cam?.Camera.orthographic = true
        cam?.Camera.orthographicSize = cameraOrthoSize
    }
    let map = find_child(levelRootNode, "map")
    if (map.isAlive) {
        mapRootNode = map
    }
    let walls = find_child(levelRootNode, "walls")
    if (walls.isAlive) {
        wallsRootNode = walls
    }
    let props = find_child(levelRootNode, "props")
    if (props.isAlive) {
        propsRootNode = props
    }
    let player = find_child(levelRootNode, "player")
    if (player.isAlive) {
        playerNode = player
        playerSpawnFeet = player_feet_from_scene_node()
        playerSpawnFeetValid = true
        snap_camera_to_prefab_player()
    }
    return cameraNode.isAlive && mapRootNode.isAlive && wallsRootNode.isAlive && propsRootNode.isAlive
}


def snap_camera_to_prefab_player() {
    if (!cameraNode.isAlive || !playerNode.isAlive) {
        return
    }
    let feet = player_feet_from_scene_node()
    let anchor = entity_sprite_anchor_offset(
        PLAYER_WORLD_HEIGHT,
        PLAYER_SHEET_HEIGHT,
        float(PLAYER_SHEET_ROWS),
        PLAYER_SHEET_WIDTH,
        float(PLAYER_SHEET_COLS)
    )
    cameraNode.localPosition = float3(feet.x + anchor.x, feet.y + anchor.y, CAMERA_Z)
}


def public ensure_render_settings() {
    if (find_child_recursive("render_settings").isAlive) {
        return
    }
    create_render_settings()
}
