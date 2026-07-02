require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state
require scripts/das/world/prefab_texture_hydrate
module aoe_effects public

var public aoeTextures : array<TextureId>
var public napalmAoeTextures : array<TextureId>
var public playerSpecialAoeTextures : array<TextureId>

let private PLAYER_AOE_KIND_NAPALM = 0
let private PLAYER_AOE_KIND_ENERGETIC_FIRE = 1


def public aoe_damage_hit_reach() : float {
    return player_aoe_hit_radius() + entity_legs_collision_half_width(ENEMY_WORLD_HEIGHT)
}


def public aoe_warning_world_size() : float {
    let diameter = aoe_damage_hit_reach() * 2.0
    return diameter / AOE_WARNING_TEXTURE_FILL
}


def public init_effects_root() {
    effectsRootNode = create_node(NodeData(name = "effects"))
}


def push_aoe_texture_from_cache(texPath : string) {
    let tex = texture_from_cache_only(texPath)
    if (texture_id_is_valid(tex)) {
        push(aoeTextures, tex)
    }
}


def push_napalm_aoe_texture_from_cache(texPath : string) {
    let tex = texture_from_cache_only(texPath)
    if (texture_id_is_valid(tex)) {
        push(napalmAoeTextures, tex)
    }
}


def push_player_special_aoe_texture_from_cache(texPath : string) {
    let tex = texture_from_cache_only(texPath)
    if (texture_id_is_valid(tex)) {
        push(playerSpecialAoeTextures, tex)
    }
}


def refresh_napalm_aoe_textures_from_cache() {
    clear(napalmAoeTextures)
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0001.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0003.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0005.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0007.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0009.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0011.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0013.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0015.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0017.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0019.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0021.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0023.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0025.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0027.png")
    push_napalm_aoe_texture_from_cache("static/Effects/napalm_aoe/0029.png")
}


def refresh_player_special_aoe_textures_from_cache() {
    clear(playerSpecialAoeTextures)
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0001.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0003.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0005.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0007.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0009.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0011.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0013.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0015.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0017.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0019.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0021.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0023.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0025.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0027.png")
    push_player_special_aoe_texture_from_cache("static/Effects/energetic_fire_aoe/0029.png")
}


def public refresh_player_aoe_textures_from_cache() {
    refresh_napalm_aoe_textures_from_cache()
    refresh_player_special_aoe_textures_from_cache()
}


def public refresh_aoe_textures_from_cache() {
    clear(aoeTextures)
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0001.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0003.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0005.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0007.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0009.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0011.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0013.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0015.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0017.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0019.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0021.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0023.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0025.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0027.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0029.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0031.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0033.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0035.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0037.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0039.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0041.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0043.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0045.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0047.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0049.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0051.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0053.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0055.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0057.png")
    push_aoe_texture_from_cache("static/Effects/smoke_explosion_aoe/0059.png")
    refresh_player_aoe_textures_from_cache()
}


def public load_aoe_textures() {
    refresh_aoe_textures_from_cache()
}


def public queue_background_aoe_texture_paths() {
    queue_texture_path("static/Effects/smoke_explosion_aoe/0001.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0003.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0005.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0007.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0009.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0011.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0013.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0015.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0017.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0019.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0021.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0023.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0025.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0027.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0029.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0031.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0033.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0035.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0037.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0039.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0041.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0043.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0045.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0047.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0049.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0051.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0053.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0055.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0057.png")
    queue_texture_path("static/Effects/smoke_explosion_aoe/0059.png")
    queue_texture_path("static/Effects/napalm_aoe/0001.png")
    queue_texture_path("static/Effects/napalm_aoe/0003.png")
    queue_texture_path("static/Effects/napalm_aoe/0005.png")
    queue_texture_path("static/Effects/napalm_aoe/0007.png")
    queue_texture_path("static/Effects/napalm_aoe/0009.png")
    queue_texture_path("static/Effects/napalm_aoe/0011.png")
    queue_texture_path("static/Effects/napalm_aoe/0013.png")
    queue_texture_path("static/Effects/napalm_aoe/0015.png")
    queue_texture_path("static/Effects/napalm_aoe/0017.png")
    queue_texture_path("static/Effects/napalm_aoe/0019.png")
    queue_texture_path("static/Effects/napalm_aoe/0021.png")
    queue_texture_path("static/Effects/napalm_aoe/0023.png")
    queue_texture_path("static/Effects/napalm_aoe/0025.png")
    queue_texture_path("static/Effects/napalm_aoe/0027.png")
    queue_texture_path("static/Effects/napalm_aoe/0029.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0001.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0003.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0005.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0007.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0009.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0011.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0013.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0015.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0017.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0019.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0021.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0023.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0025.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0027.png")
    queue_texture_path("static/Effects/energetic_fire_aoe/0029.png")
}


def public queue_aoe_texture_paths() {
    queue_background_aoe_texture_paths()
}


def player_aoe_texture_count(kind : int) : int {
    if (kind == PLAYER_AOE_KIND_ENERGETIC_FIRE) {
        return length(playerSpecialAoeTextures)
    }
    return length(napalmAoeTextures)
}


def player_aoe_texture_at(kind : int; frame : int) : TextureId {
    if (kind == PLAYER_AOE_KIND_ENERGETIC_FIRE) {
        if (frame >= 0 && frame < length(playerSpecialAoeTextures)) {
            return playerSpecialAoeTextures[frame]
        }
    } elif (frame >= 0 && frame < length(napalmAoeTextures)) {
        return napalmAoeTextures[frame]
    }
    return TextureId()
}


def spawn_player_aoe_visual(
    center : float2;
    kind : int;
    worldSize : float;
    animFps : float;
    frameCount : int
) {
    if (!effectsRootNode.isAlive || player_aoe_texture_count(kind) == 0) {
        return
    }
    let depth = depth_sort_entity_from_world(center)
    let node = create_node(NodeData(
        name = "player_aoe",
        position = float3(center.x, center.y, 0.11),
        scale = float3(worldSize, worldSize, 1.0),
        parent = effectsRootNode
    ))
    add_component(node, new SpriteRenderer(
        textureId = player_aoe_texture_at(kind, 0),
        uvRect = float4(0.0, 0.0, 1.0, 1.0),
        useTextureSizeForScaling = false,
        renderOrder = depth
    ))
    add_component(node, new PlayerAoeEffect(
        center = center,
        kind = kind,
        worldSize = worldSize,
        animFps = animFps,
        frameCount = frameCount
    ))
}


def public spawn_napalm_aoe_visual(center : float2) {
    spawn_player_aoe_visual(
        center,
        PLAYER_AOE_KIND_NAPALM,
        PLAYER_BOW_NAPALM_AOE_WORLD_SIZE,
        PLAYER_BOW_NAPALM_ANIM_FPS,
        PLAYER_BOW_NAPALM_AOE_FRAME_COUNT
    )
}


def public spawn_player_special_aoe_visual(center : float2) {
    spawn_player_aoe_visual(
        center,
        PLAYER_AOE_KIND_ENERGETIC_FIRE,
        PLAYER_SPECIAL_AOE_WORLD_SIZE,
        PLAYER_SPECIAL_AOE_ANIM_FPS,
        PLAYER_SPECIAL_AOE_FRAME_COUNT
    )
}


def public spawn_aoe(center : float2) {
    spawn_player_special_aoe_visual(center)
}


def public apply_enemy_aoe_hit_player(center, fromFeet : float2; damage : int) {
    if (damage <= 0 || playerHp <= 0 || playerDashing) {
        return
    }
    let hitReach = player_aoe_hit_radius() + entity_legs_collision_half_width(ENEMY_WORLD_HEIGHT)
    if (length_sq(playerWorldPosition - center) <= hitReach * hitReach) {
        queue_player_damage(damage, fromFeet)
    }
}


def public spawn_enemy_aoe(center, fromFeet : float2; damage : int) {
    if (!effectsRootNode.isAlive || length(aoeTextures) == 0) {
        return
    }
    let depth = depth_sort_entity_from_world(center)
    let node = create_node(NodeData(
        name = "enemy_aoe",
        position = float3(center.x, center.y, 0.11),
        scale = float3(AOE_WORLD_SIZE, AOE_WORLD_SIZE, 1.0),
        parent = effectsRootNode
    ))
    add_component(node, new SpriteRenderer(
        textureId = aoeTextures[0],
        uvRect = float4(0.0, 0.0, 1.0, 1.0),
        useTextureSizeForScaling = false,
        renderOrder = depth
    ))
    add_component(node, new EnemyAoeEffect(
        center = center,
        fromFeet = fromFeet,
        damage = damage
    ))
}


def public spawn_aoe_warning_outline(center : float2) : NodeId {
    if (!effectsRootNode.isAlive || length(aoeTextures) == 0) {
        return NodeId()
    }
    let warningFrame = min(AOE_WARNING_TEXTURE_FRAME, length(aoeTextures) - 1)
    let warningSize = aoe_warning_world_size()
    let depth = depth_sort_entity_from_world(center) + 40
    let node = create_node(NodeData(
        name = "aoe_warning",
        position = float3(center.x, center.y, 0.11),
        scale = float3(warningSize, warningSize, 1.0),
        parent = effectsRootNode
    ))
    add_component(node, new SpriteRenderer(
        textureId = aoeTextures[warningFrame],
        uvRect = float4(0.0, 0.0, 1.0, 1.0),
        useTextureSizeForScaling = false,
        renderOrder = depth,
        color = AOE_WARNING_FILL_COLOR
    ))
    add_component(node, new AoeWarningOutline(center = center, warningFrame = warningFrame))
    return node
}


[hot_reload_class]
class AoeWarningOutline : Component {
    center : float2
    warningFrame : int = 0
    pulseTimer : float = 0.0

    def override on_update {
        let dt = get_delta_time()
        pulseTimer += dt * 4.5
        let pulse = 0.5 + 0.5 * sin(pulseTimer)
        let fillAlpha = AOE_WARNING_FILL_COLOR.w + 0.18 * pulse
        let edgeAlpha = AOE_WARNING_EDGE_COLOR.w + 0.12 * pulse
        let fillColor = float4(
            AOE_WARNING_FILL_COLOR.x,
            AOE_WARNING_FILL_COLOR.y + 0.08 * pulse,
            AOE_WARNING_FILL_COLOR.z,
            fillAlpha
        )
        let edgeColor = float4(
            AOE_WARNING_EDGE_COLOR.x,
            AOE_WARNING_EDGE_COLOR.y + 0.1 * pulse,
            AOE_WARNING_EDGE_COLOR.z,
            edgeAlpha
        )
        let color = lerp(fillColor, edgeColor, 0.35 + 0.25 * pulse)
        let warningSize = aoe_warning_world_size()
        nodeId.localPosition = float3(center.x, center.y, 0.11)
        nodeId.localScale = float3(warningSize, warningSize, 1.0)
        if (warningFrame >= 0 && warningFrame < length(aoeTextures)) {
            nodeId?.SpriteRenderer.textureId = aoeTextures[warningFrame]
        }
        nodeId?.SpriteRenderer.color = color
        nodeId?.SpriteRenderer.renderOrder = depth_sort_entity_from_world(center) + 40
    }
}


[hot_reload_class]
class EnemyAoeEffect : Component {
    center : float2
    fromFeet : float2
    damage : int
    animTimer : float = 0.0
    damageApplied : bool = false

    def override on_update {
        if (length(aoeTextures) == 0) {
            remove_node(nodeId)
            return
        }

        let dt = get_delta_time()
        animTimer += dt * AOE_ANIM_FPS
        let frame = int(animTimer)
        if (!damageApplied && frame >= ENEMY7_AOE_DAMAGE_FRAME) {
            apply_enemy_aoe_hit_player(center, fromFeet, damage)
            damageApplied = true
        }
        if (frame >= AOE_FRAME_COUNT) {
            remove_node(nodeId)
            return
        }

        let depth = depth_sort_entity_from_world(center)
        nodeId?.SpriteRenderer.textureId = aoeTextures[frame]
        nodeId?.SpriteRenderer.renderOrder = depth
    }
}


[hot_reload_class]
class PlayerAoeEffect : Component {
    center : float2
    kind : int = PLAYER_AOE_KIND_NAPALM
    worldSize : float = AOE_WORLD_SIZE
    animFps : float = AOE_ANIM_FPS
    frameCount : int = PLAYER_AOE_FRAME_COUNT
    animTimer : float = 0.0

    def override on_update {
        if (player_aoe_texture_count(kind) == 0) {
            remove_node(nodeId)
            return
        }

        let dt = get_delta_time()
        animTimer += dt * animFps
        let frame = int(animTimer)
        if (frame >= frameCount) {
            remove_node(nodeId)
            return
        }

        let depth = depth_sort_entity_from_world(center)
        nodeId.localScale = float3(worldSize, worldSize, 1.0)
        nodeId?.SpriteRenderer.textureId = player_aoe_texture_at(kind, frame)
        nodeId?.SpriteRenderer.renderOrder = depth
    }
}
