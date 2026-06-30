#!/usr/bin/env python3
"""Merge character/UI texture ref IDs (preserved GUID hashes) into texture_ref_ids.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_TOOLS_ROOT))

from lib.static_path_migration import rewrite_text

PROJECT = Path(__file__).resolve().parents[3]
REF_IDS_JSON = PROJECT / "scripts" / "python" / "data" / "texture_ref_ids.json"

# Snapshot before static folder migration (same refIds after .meta GUIDs move with PNGs).
_LEGACY_REF_IDS: dict[str, int] = {
    "static/Characters/skeleton_mage_6/Attack1.png": 2134117090564571151,
    "static/Characters/skeleton_mage_6/Die.png": 9184708670805969939,
    "static/Characters/skeleton_mage_6/Idle.png": 2105719370629528710,
    "static/Characters/skeleton_mage_6/Special1.png": -7230488897809524438,
    "static/Characters/skeleton_mage_6/TakeDamage.png": 1610203036007392186,
    "static/Characters/skeleton_mage_6/Walk.png": -3112335525607372419,
    "static/Characters/enemy_dark_knight/Attack1.png": 6794021812598779525,
    "static/Characters/enemy_dark_knight/CastSpell.png": -8011754780757361626,
    "static/Characters/enemy_dark_knight/Die.png": -1831787403798034091,
    "static/Characters/enemy_dark_knight/Idle.png": 4312691596965141013,
    "static/Characters/enemy_dark_knight/Run.png": -7919882921164548632,
    "static/Characters/enemy_dark_knight/Special1.png": -5050508844486464025,
    "static/Characters/enemy_dark_knight/TakeDamage.png": 2287278189616822751,
    "static/Characters/enemy_dark_knight/Walk.png": 697975018769669882,
    "static/Characters/skeleton_sword/Attack1.png": 5716216597902117397,
    "static/Characters/skeleton_sword/Die.png": 1701268720425214880,
    "static/Characters/skeleton_sword/Idle.png": -2626790038950407779,
    "static/Characters/skeleton_sword/TakeDamage.png": 7139218119571012394,
    "static/Characters/skeleton_sword/Walk.png": 8213506284735860397,
    "static/Characters/skeleton_mage/Attack1.png": -3003759997176008176,
    "static/Characters/skeleton_mage/Die.png": 2619697781751511717,
    "static/Characters/skeleton_mage/Idle.png": 9140363263077344537,
    "static/Characters/skeleton_mage/Special1.png": -6829415318857091699,
    "static/Characters/skeleton_mage/Walk.png": -4741264795433906161,
    "static/Characters/skeleton_sword_and_shield/Attack1.png": 7065555270897920606,
    "static/Characters/skeleton_sword_and_shield/Die.png": 4838989644337843789,
    "static/Characters/skeleton_sword_and_shield/Idle.png": 7566882895570526979,
    "static/Characters/skeleton_sword_and_shield/TakeDamage.png": -5825498765141094591,
    "static/Characters/skeleton_sword_and_shield/Walk.png": 987806551359466568,
    "static/Characters/playable_character_jack/Attack1.png": 4190583632433965371,
    "static/Characters/playable_character_jack/Attack3.png": 2725367782720631811,
    "static/Characters/playable_character_jack/Idle.png": -6361988228254301852,
    "static/Characters/playable_character_jack/Run.png": 6490924968328363517,
    "static/Characters/playable_character_jack/Special1.png": -5106679607258646077,
    "static/Characters/playable_character_jack/TakeDamage.png": -4028678232045853673,
    "static/Characters/playable_character_jack/Walk.png": -5069481628598337749,
    "static/UI/Boxes/bottom_bar.png": 7111323970956978485,
    "static/UI/Weapons/bow.png": -8070212373640890830,
    "static/UI/Portraits/abbigeil.png": 5072730325190396421,
    "static/UI/Boxes/character_1_box.png": -2003426324279334074,
    "static/UI/Bars/exp_ui_bar.png": 5421012267794161509,
    "static/UI/Bars and HPs/health.png": -8578445606641318120,
    "static/UI/Bars and HPs/hearts.png": 7431939220011336795,
    "static/UI/Weapons/sword.png": 7582790568533204218,
    "static/UI/Boxes/title_box.png": 6783195991828087987,
    "static/UI/Bars and HPs/ui_bar.png": 8048871885749969274,
    "static/UI/Boxes/upgrade_box.png": 3463740954209819252,
}


def main() -> int:
    current: dict[str, int] = {}
    if REF_IDS_JSON.exists():
        current = json.loads(REF_IDS_JSON.read_text(encoding="utf-8"))

    migrated = {rewrite_text(k): v for k, v in _LEGACY_REF_IDS.items()}
    added = 0
    for key, val in migrated.items():
        if key not in current:
            current[key] = val
            added += 1
        elif current[key] != val:
            print(f"warning: refId drift for {key}: keep {current[key]}, legacy {val}", file=sys.stderr)

    REF_IDS_JSON.write_text(
        json.dumps(current, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"merged {added} character/UI refIds ({len(current)} total)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
