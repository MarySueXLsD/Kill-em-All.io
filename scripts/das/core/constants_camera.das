require engine.core

module constants_camera public

let public {
    CAMERA_ZOOM_SCROLL_AMOUNT = 0.8
    CAMERA_ZOOM_SMOOTH = 12.0
    CAMERA_FOLLOW_LERP = 6.0
    // Blend camera target toward cursor (0 = player only, 1 = halfway to cursor).
    CAMERA_LOOK_AHEAD_BLEND = 0.22
    // Cap look-ahead offset in world units so distant cursor clicks do not yank the view.
    CAMERA_LOOK_AHEAD_MAX_OFFSET = 2.8
    CAMERA_Z = -5.0

    GROUND_TEXTURE_PATH = "static/Environment/Ground/Type_1_Variation_1_South.png"
    // Screen-facing directions for A2/A3/A4 overlays: 0=E(top), 1=N(left), 2=S(right), 3=W(down).
    GROUND_DIR_E = 0
}
