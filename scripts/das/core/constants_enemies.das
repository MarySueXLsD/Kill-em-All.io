require engine.core
require scripts/das/core/constants_grid
require scripts/das/core/constants_player

module constants_enemies public

let public {
    ENEMY_SPAWN_PERIOD_DECREASE_PER_LEVEL = 0.35
    ENEMY_SPAWN_PERIOD_MIN_SECONDS = 4.0
    ENEMY_MAX_ON_SCREEN = 50
    ENEMY_OFFSCREEN_SPAWN_MARGIN = 2.5
    ENEMY_MIN_SPAWN_DISTANCE = 8.0
    ENEMY_SPEED = 2.0
    AI_DETOUR_BACK_STEPS = 2
    AI_DETOUR_SIDE_BIAS = 0.75
    AI_DETOUR_CROWD_WEIGHT = 0.5
    AI_PATH_RECOMPUTE_INTERVAL = 0.6
    AI_GOAL_MOVE_THRESHOLD = 1.0
    AI_LOS_SEEK_RECOMPUTE_INTERVAL = 0.5
    AI_OBSTACLE_ROUTE_RANGE = 14.0
    AI_OBSTACLE_ROUTE_LATERAL_STEPS = 5
    AI_OBSTACLE_ROUTE_FORWARD_STEPS = 3
    AI_FLANK_CLEAR_PATH_BONUS = 10000.0
    ENEMY_CHASE_SLOT_RADIUS = 1.6
    ENEMY_WORLD_HEIGHT = 4.0
    ENEMY_WALK_ANIM_FPS = 8.0
    ENEMY_IDLE_ANIM_FPS = 6.0
    ENEMY_ATTACK_ANIM_FPS = 18.0
    ENEMY_DIE_ANIM_FPS = 10.0
    ENEMY_TAKE_DAMAGE_ANIM_FPS = 12.0
    ENEMY_TAKE_DAMAGE_SPEED_DIVISOR = 2.5
    ENEMY_HIT_FLASH_DURATION = 0.3
    ENEMY_CLOSE_MAX_HP = 12
    ENEMY_HP_SCALE_PER_LEVEL = 0.05
    ENEMY7_HP_SCALE_PER_LEVEL = 0.07
    ENEMY_DISTANCE_MAX_HP = 7
    ENEMY3_MAX_HP = ENEMY_CLOSE_MAX_HP * 2
    ENEMY_MAGE_MAX_FRACTION = 0.25
    ENEMY3_MAX_FRACTION = 0.20
    ENEMY6_MAGE_MAX_FRACTION = 0.10
    ENEMY6_UNLOCK_LEVEL = 3
    ENEMY6_SPEED = 3.0
    ENEMY6_MAGE_ATTACK_COOLDOWN = 1.25
    ENEMY6_SPELL_SPREAD_DEG = 16.0
    ENEMY6_DASH_COOLDOWN = 4.0
    ENEMY6_DASH_SPEED = 7.5
    ENEMY6_DASH_TRIGGER_DISTANCE = 3.5

    ENEMY7_MAX_HP = 100
    ENEMY7_WALK_SPEED = PLAYER_SPEED * 1.5
    ENEMY7_CHARGE_SPEED = PLAYER_SPEED * PLAYER_RUN_SPEED_MULTIPLIER
    ENEMY7_MELEE_DAMAGE = 8
    ENEMY7_AOE_DAMAGE = 10
    ENEMY7_MELEE_ATTACK_COOLDOWN = 0.65
    ENEMY7_SPELL_ATTACK_COOLDOWN = 2.0
    ENEMY7_SPELL_SPREAD_DEG = 24.0
    ENEMY7_AOE_COOLDOWN = 2.5
    ENEMY7_AOE_TRY_CHANCE = 0.82
    ENEMY7_CAST_SPELL_FPS = 8.0
    ENEMY7_CAST_SPELL_COLS = PLAYER_SHEET_COLS
    ENEMY7_AOE_DAMAGE_FRAME = 6
    ENEMY7_CHARGE_MELEE_COOLDOWN = 0.35
    ENEMY7_AOE_SIDE_TILE_STEPS = 3
    ENEMY7_AOE_BEHIND_TILE_STEPS = 3
    ENEMY7_SPAWN_LEVEL_FIRST = 5
    ENEMY7_SPAWN_LEVEL_TIER_TWO = 10
    ENEMY7_SPAWN_LEVEL_TIER_THREE = 15
    ENEMY7_TIER_ONE_COUNT = 1
    ENEMY7_TIER_TWO_COUNT = 2
    ENEMY7_TIER_THREE_COUNT = 3
    ENEMY7_AOE_CHARGE_DURATION = 0.65
    ENEMY_HEART_HUD_OFFSET_ABOVE_TOP_PX = -15.0
    // Top opaque pixel Y within a sprite tile (same for all enemy kinds).
    ENEMY_TOP_OPAQUE_Y_PX = 37.0

    ENEMY_HEART_SPRITE_PATH = "static/UI/Bars/hearts.png"
    ENEMY_HEART_FRAME_COUNT = 5
    ENEMY_HEART_SEGMENT_COUNT = 4
    ENEMY_HEART_HUD_SIZE = 28.0
    ENEMY_HEART_HUD_SPACING = 2.0
    ENEMY_HEART_HUD_WAVE_CLEARANCE = 8.0
    ENEMY_HEART_SHAKE_AMPLITUDE = 3.0

    ENEMY1_DIE_PATH = "static/Characters/enemy_warrior/Die.png"
    ENEMY2_DIE_PATH = "static/Characters/enemy_skeleton_archer/Die.png"
    ENEMY3_DIE_PATH = "static/Characters/enemy_barbarian_tank/Die.png"

    ENEMY2_PREFERRED_DISTANCE = 4.0
    ENEMY2_APPROACH_MARGIN = 0.75
    ENEMY2_CLOSE_DISTANCE = 2.0
    ENEMY2_DASH_COOLDOWN = 5.0
    ENEMY2_DASH_SPEED = 6.0
    ENEMY_MELEE_ATTACK_DISTANCE = 1.25
    ENEMY_MELEE_DAMAGE = 5
    ENEMY_SPELL_DAMAGE = 3
    ENEMY_SKELETON_ATTACK_COOLDOWN = 0.5
    ENEMY_MAGE_ATTACK_COOLDOWN = 2.0
    ENEMY2_SPELL_MAX_DISTANCE = ENEMY2_PREFERRED_DISTANCE + ENEMY2_APPROACH_MARGIN
    ENEMY2_SPELL_PROJECTILE_COL = 7
    ENEMY_SPELL_PROJECTILE_SPEED = 3.25
    ENEMY_SPELL_PROJECTILE_MAX_RANGE = 14.0
    ENEMY_SPELL_PROJECTILE_HIT_RADIUS = 0.4
    ENEMY_SPELL_PROJECTILE_TEXTURE_PATH = "static/Effects/smoke_explosion_aoe/0017.png"
    ENEMY_SPELL_PROJECTILE_WORLD_SIZE = 2.0

    // Kind 1 — skeleton sword (melee)
    ENEMY1_IDLE_PATH = "static/Characters/enemy_warrior/Idle.png"
    ENEMY1_WALK_PATH = "static/Characters/enemy_warrior/Walk.png"
    ENEMY1_ATTACK1_PATH = "static/Characters/enemy_warrior/Attack1.png"
    ENEMY1_TAKE_DAMAGE_PATH = "static/Characters/enemy_warrior/TakeDamage.png"
    // Kind 2 — skeleton mage (ranged)
    ENEMY2_IDLE_PATH = "static/Characters/enemy_skeleton_archer/Idle.png"
    ENEMY2_WALK_PATH = "static/Characters/enemy_skeleton_archer/Walk.png"
    ENEMY2_ATTACK1_PATH = "static/Characters/enemy_skeleton_archer/Attack1.png"
    ENEMY2_SPECIAL1_PATH = "static/Characters/enemy_skeleton_archer/Special1.png"
    // Kind 3 — skeleton sword and shield (tanky melee)
    ENEMY3_IDLE_PATH = "static/Characters/enemy_barbarian_tank/Idle.png"
    ENEMY3_WALK_PATH = "static/Characters/enemy_barbarian_tank/Walk.png"
    ENEMY3_ATTACK1_PATH = "static/Characters/enemy_barbarian_tank/Attack1.png"
    ENEMY3_TAKE_DAMAGE_PATH = "static/Characters/enemy_barbarian_tank/TakeDamage.png"

    ENEMY6_IDLE_PATH = "static/Characters/enemy_skeleton_wizard/Idle.png"
    ENEMY6_WALK_PATH = "static/Characters/enemy_skeleton_wizard/Walk.png"
    ENEMY6_ATTACK1_PATH = "static/Characters/enemy_skeleton_wizard/Attack1.png"
    ENEMY6_TAKE_DAMAGE_PATH = "static/Characters/enemy_skeleton_wizard/TakeDamage.png"
    ENEMY6_DIE_PATH = "static/Characters/enemy_skeleton_wizard/Die.png"
    ENEMY6_SPECIAL1_PATH = "static/Characters/enemy_skeleton_wizard/Special1.png"

    ENEMY7_IDLE_PATH = "static/Characters/enemy_dark_knight/Idle.png"
    ENEMY7_WALK_PATH = "static/Characters/enemy_dark_knight/Walk.png"
    ENEMY7_RUN_PATH = "static/Characters/enemy_dark_knight/Run.png"
    ENEMY7_ATTACK1_PATH = "static/Characters/enemy_dark_knight/Melee.png"
    ENEMY7_CAST_SPELL_PATH = "static/Characters/enemy_dark_knight/CastSpell.png"
    ENEMY7_SPECIAL1_PATH = "static/Characters/enemy_dark_knight/Special1.png"
    ENEMY7_TAKE_DAMAGE_PATH = "static/Characters/enemy_dark_knight/TakeDamage.png"
    ENEMY7_DIE_PATH = "static/Characters/enemy_dark_knight/Die.png"

    ENEMY1_EXP_REWARD = 5
    ENEMY2_EXP_REWARD = 8
    ENEMY3_EXP_REWARD = 10
    ENEMY6_EXP_REWARD = 12
    ENEMY7_EXP_REWARD = 50
    EXP_POPUP_DURATION = 1.5
    EXP_POPUP_RISE_PX_PER_SEC = 60.0
    EXP_POPUP_FONT_SIZE = 20.0
    EXP_POPUP_SIDE_OFFSET_CANVAS = 52.0
    EXP_POPUP_VERTICAL_OFFSET_CANVAS = 36.0
    EXP_POPUP_STACK_OFFSET_CANVAS = 24.0
    EXP_LEVEL_HUD_Y = 12.0
    EXP_HUD_Y = 32.0

    WAVE_TITLE_BOX_PATH = "static/UI/Boxes/title_box.png"
    WAVE_TITLE_HUD_WIDTH = 130.0
    WAVE_TITLE_HUD_HEIGHT = 88.0
}
