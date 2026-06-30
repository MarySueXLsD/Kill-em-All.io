require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
require scripts/das/combat/player

module camera public


def public sync_camera_ortho_size() {
    cameraOrthoSizeTarget = player_camera_ortho_size()
    let dt = get_delta_time()
    let t = clamp(CAMERA_ZOOM_SMOOTH * dt, 0.0, 1.0)
    cameraOrthoSize = lerp(cameraOrthoSize, cameraOrthoSizeTarget, t)
    cameraNode?.Camera.orthographicSize = cameraOrthoSize
}


def camera_look_ahead_target(playerPos : float2) : float2 {
    let cursorPos = cursor_world_position()
    var offset = lerp(float2(0.0), cursorPos - playerPos, CAMERA_LOOK_AHEAD_BLEND)
    let maxOffsetSq = CAMERA_LOOK_AHEAD_MAX_OFFSET * CAMERA_LOOK_AHEAD_MAX_OFFSET
    if (length_sq(offset) > maxOffsetSq) {
        offset = normalize(offset) * CAMERA_LOOK_AHEAD_MAX_OFFSET
    }
    return playerPos + offset
}


def public update_camera_follow() {
    if (!playerNode.isAlive) {
        return
    }
    let playerPos = playerNode.localPosition.xy
    let target = camera_look_ahead_target(playerPos)
    if (playerDashing) {
        cameraNode.localPosition = float3(target.x, target.y, CAMERA_Z)
        return
    }
    let dt = get_delta_time()
    let t = clamp(CAMERA_FOLLOW_LERP * dt, 0.0, 1.0)
    let camPos = cameraNode.localPosition
    cameraNode.localPosition = float3(
        lerp(camPos.x, target.x, t),
        lerp(camPos.y, target.y, t),
        CAMERA_Z
    )
}
