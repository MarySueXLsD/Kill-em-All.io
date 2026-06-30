"""Static asset path rewrites after folder reorganization."""
from __future__ import annotations

# Longest keys first when applying as substring replacements.
PATH_REPLACEMENTS: dict[str, str] = {
    # Characters — enemy 1 sword, 2 mage, 3 sword+shield
    "static/Characters/Enemy 1/": "static/Characters/skeleton_sword/",
    "static/Characters/Enemy 2/": "static/Characters/skeleton_mage/",
    "static/Characters/Enemy 3/": "static/Characters/skeleton_sword_and_shield/",
    "static/Characters/6mage/": "static/Characters/skeleton_mage_6/",
    "static/Characters/7deathknight/": "static/Characters/death_knight/",
    # Effects — Animations/Effects/* merged under static/Effects/smoke_explosion_aoe/
    "static/Animations/Effects/AoE/": "static/Effects/smoke_explosion_aoe/",
    "static/Animations/Effects/Cone/": "static/Effects/smoke_explosion_aoe/",
    "static/Animations/Effects/Hook/": "static/Effects/smoke_explosion_aoe/",
    # UI subfolders
    "static/UI/health.png": "static/UI/Bars and HPs/health.png",
    "static/UI/hearts.png": "static/UI/Bars and HPs/hearts.png",
    "static/UI/ui_bar.png": "static/UI/Bars and HPs/ui_bar.png",
    "static/UI/exp_ui_bar.png": "static/UI/Bars and HPs/exp_ui_bar.png",
    "static/UI/sword.png": "static/UI/Weapons/sword.png",
    "static/UI/bow.png": "static/UI/Weapons/bow.png",
    "static/UI/character_1.png": "static/UI/Portraits/abbigeil.png",
    "static/UI/character_1_box.png": "static/UI/Boxes/character_1_box.png",
    "static/UI/bottom_bar.png": "static/UI/Boxes/bottom_bar.png",
    "static/UI/title_box.png": "static/UI/Boxes/title_box.png",
    "static/UI/upgrade_box.png": "static/UI/Boxes/upgrade_box.png",
    # Second wave — semantic character folder names (playable_*, enemy_*)
    "static/Characters/playable_character_jack/Attack3.png": "static/Characters/playable_character_kreol/Attack3.png",
    "static/Characters/playable_character_jack/Attack1.png": "static/Characters/playable_character_jack/Melee.png",
    "static/Characters/enemy_dark_knight/Attack1.png": "static/Characters/enemy_dark_knight/Melee.png",
    "static/Characters/Player/": "static/Characters/playable_character_jack/",
    "static/Characters/skeleton_sword_and_shield/": "static/Characters/enemy_barbarian_tank/",
    "static/Characters/skeleton_mage_6/": "static/Characters/enemy_skeleton_wizard/",
    "static/Characters/skeleton_sword/": "static/Characters/enemy_warrior/",
    "static/Characters/skeleton_mage/": "static/Characters/enemy_skeleton_archer/",
    "static/Characters/death_knight/": "static/Characters/enemy_dark_knight/",
    # UI — Bars and HPs renamed to Bars on disk
    "static/UI/Bars and HPs/": "static/UI/Bars/",
}

SORTED_REPLACEMENTS = sorted(PATH_REPLACEMENTS.items(), key=lambda kv: len(kv[0]), reverse=True)


def rewrite_static_path(path: str) -> str:
    out = path
    for old, new in SORTED_REPLACEMENTS:
        out = out.replace(old, new)
    return out


def rewrite_text(text: str) -> str:
    out = text
    while True:
        prev = out
        for old, new in SORTED_REPLACEMENTS:
            out = out.replace(old, new)
        if out == prev:
            break
    return out
