require engine.core
require scripts/das/core/constants
require scripts/das/core/game_state
require scripts/das/ui/enemy_hud
require scripts/das/ui/upgrade_picker
module exp_progression public


def process_player_level_ups() {
    while (true) {
        let needed = exp_required_for_level(playerLevel)
        if (playerExp < needed) {
            break
        }
        playerExp -= needed
        playerLevel += 1
        queue_upgrade_pick()
    }
}


def exp_reward_for_kind(kind : int) : int {
    if (kind == 2) {
        return ENEMY2_EXP_REWARD
    }
    if (kind == 3) {
        return ENEMY3_EXP_REWARD
    }
    if (kind == 6) {
        return ENEMY6_EXP_REWARD
    }
    if (kind == 7) {
        return ENEMY7_EXP_REWARD
    }
    return ENEMY1_EXP_REWARD
}


def public grant_player_exp(amount : int) {
    if (amount <= 0) {
        return
    }
    playerExp += amount
    process_player_level_ups()
    spawn_exp_popup(playerWorldPosition, amount)
}


def public grant_enemy_kill_exp(kind : int; atFeet : float2) {
    let amount = exp_reward_for_kind(kind)
    if (amount <= 0) {
        return
    }
    playerExp += amount
    process_player_level_ups()
    spawn_exp_popup(playerWorldPosition, amount)
}
