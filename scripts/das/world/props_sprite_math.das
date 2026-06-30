require scripts/das/core/iso_math

module props_sprite_math public

def prop_crop_width(crop : float4) : float {
    return crop.z - crop.x + 1.0
}


def prop_crop_height(crop : float4) : float {
    return crop.w - crop.y + 1.0
}


def prop_uv_rect(crop : float4) : float4 {
    return uv_rect_from_crop(crop.x, crop.y, crop.z, crop.w, prop_crop_width(crop), prop_crop_height(crop))
}


def prop_scale(crop : float4; worldWidth : float) : float2 {
    let cropW = prop_crop_width(crop)
    let cropH = prop_crop_height(crop)
    return float2(worldWidth, worldWidth * (cropH / cropW))
}


def prop_pixel_to_local(px, py : float; crop : float4; worldWidth : float) : float2 {
    let cropW = prop_crop_width(crop)
    let cropH = prop_crop_height(crop)
    let spriteCx = (cropW - 1.0) * 0.5
    let spriteCy = (cropH - 1.0) * 0.5
    let scale = prop_scale(crop, worldWidth)
    return float2(
        (px - crop.x - spriteCx) * scale.x / cropW,
        (spriteCy - (py - crop.y)) * scale.y / cropH
    )
}


def prop_anchor_offset(crop : float4; feetPx : float2; worldWidth : float) : float2 {
    let feetLocal = prop_pixel_to_local(feetPx.x, feetPx.y, crop, worldWidth)
    return float2(-feetLocal.x, -feetLocal.y)
}
