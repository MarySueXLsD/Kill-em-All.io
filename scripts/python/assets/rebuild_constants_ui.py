#!/usr/bin/env python3
"""Rebuild constants_ui.das from transcript-recovered values + new static paths."""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_TOOLS_ROOT))

from lib.static_path_migration import rewrite_text

PROJECT = Path(__file__).resolve().parents[3]
OUT = PROJECT / "scripts" / "das" / "core" / "constants_ui.das"
TRANSCRIPTS = Path(
    r"c:\Users\syanavi\.cursor\projects\c-Users-syanavi-Documents-My-Games-eden-launcher-projects\agent-transcripts"
)

# Logical block order (matches pre-split constants.das UI section).
BLOCKS: list[tuple[str, list[str]]] = [
    (
        "Player health HUD",
        [
            "PLAYER_HEALTH_SPRITE_PATH",
            "PLAYER_HEALTH_FRAME_COUNT",
            "PLAYER_HEALTH_SEGMENT_COUNT",
            "PLAYER_HEALTH_HUD_SIZE",
            "PLAYER_HEALTH_HUD_BOTTOM_MARGIN",
            "PLAYER_HEALTH_HUD_GAP_AFTER_PORTRAIT",
            "PLAYER_HEALTH_SHAKE_DURATION",
            "PLAYER_HEALTH_SHAKE_AMPLITUDE",
        ],
    ),
    (
        "Cooldown bars",
        [
            "PLAYER_UI_BAR_SPRITE_PATH",
            "PLAYER_UI_BAR_TEX_WIDTH",
            "PLAYER_UI_BAR_TEX_HEIGHT",
            "PLAYER_UI_BAR_HUD_WIDTH",
            "PLAYER_UI_BAR_HUD_HEIGHT",
            "PLAYER_UI_BAR_FILL_MIN_X",
            "PLAYER_UI_BAR_FILL_MIN_Y",
            "PLAYER_UI_BAR_FILL_MAX_X",
            "PLAYER_UI_BAR_FILL_MAX_Y",
            "PLAYER_COOLDOWN_HUD_LABEL_WIDTH",
            "PLAYER_COOLDOWN_HUD_LABEL_GAP",
            "PLAYER_COOLDOWN_HUD_LABEL_LEVEL_GAP",
            "PLAYER_COOLDOWN_HUD_LABEL_FONT_SIZE",
            "PLAYER_COOLDOWN_HUD_LABEL_COLOR",
            "PLAYER_COOLDOWN_HUD_LEVEL_COLOR",
            "PLAYER_COOLDOWN_HUD_BAR_SPACING",
            "PLAYER_COOLDOWN_HUD_DASH_FILL_COLOR",
            "PLAYER_COOLDOWN_HUD_AOE_FILL_COLOR",
        ],
    ),
    (
        "EXP bar",
        [
            "PLAYER_EXP_UI_BAR_SPRITE_PATH",
            "PLAYER_EXP_UI_BAR_TEX_WIDTH",
            "PLAYER_EXP_UI_BAR_TEX_HEIGHT",
            "PLAYER_EXP_UI_BAR_HUD_WIDTH",
            "PLAYER_EXP_UI_BAR_HUD_HEIGHT",
            "PLAYER_EXP_UI_BAR_HUD_LEVEL_GAP",
            "PLAYER_EXP_UI_BAR_FILL_MIN_X",
            "PLAYER_EXP_UI_BAR_FILL_MIN_Y",
            "PLAYER_EXP_UI_BAR_FILL_MAX_X",
            "PLAYER_EXP_UI_BAR_FILL_MAX_Y",
            "PLAYER_EXP_UI_BAR_FILL_COLOR",
            "PLAYER_EXP_UI_BAR_LABEL_FONT_SIZE",
            "PLAYER_EXP_UI_BAR_LABEL_COLOR",
            "PLAYER_EXP_UI_BAR_LABEL_GAP",
            "PLAYER_EXP_UI_BAR_LABEL_DOWN_OFFSET",
        ],
    ),
    (
        "Character portrait + bottom bar",
        [
            "PLAYER_CHARACTER_NAME",
            "PLAYER_CHARACTER_NAME_FONT_SIZE",
            "PLAYER_CHARACTER_NAME_COLOR",
            "PLAYER_CHARACTER_NAME_LEVEL_GAP",
            "PLAYER_CHARACTER_LEVEL_FONT_SIZE",
            "PLAYER_CHARACTER_LEVEL_COLOR",
            "PLAYER_CHARACTER_LEVEL_ABILITY_GAP",
            "PLAYER_CHARACTER_TEXT_TOP_CLEARANCE",
            "PLAYER_CHARACTER_PORTRAIT_PATH",
            "PLAYER_CHARACTER_PORTRAIT_BOX_PATH",
            "PLAYER_CHARACTER_PORTRAIT_BOX_TEX_SIZE",
            "PLAYER_CHARACTER_PORTRAIT_BOX_INSET_PX",
            "PLAYER_CHARACTER_PORTRAIT_HUD_LEFT_MARGIN",
            "PLAYER_CHARACTER_PORTRAIT_HUD_BOTTOM_MARGIN",
            "PLAYER_CHARACTER_PORTRAIT_HUD_TOP_MARGIN",
            "PLAYER_CHARACTER_PORTRAIT_TEXT_GAP",
            "PLAYER_BOTTOM_BAR_PATH",
            "PLAYER_BOTTOM_BAR_TEX_SIZE",
            "PLAYER_BOTTOM_BAR_SLICE_LEFT",
            "PLAYER_BOTTOM_BAR_SLICE_RIGHT",
            "PLAYER_BOTTOM_BAR_SLICE_TOP",
            "PLAYER_BOTTOM_BAR_SLICE_BOTTOM",
            "PLAYER_BOTTOM_BAR_TILE_SCALE",
            "PLAYER_BOTTOM_BAR_HUD_TARGET_HEIGHT",
        ],
    ),
    (
        "Weapon HUD",
        [
            "PLAYER_WEAPON_SWORD_PATH",
            "PLAYER_WEAPON_BOW_PATH",
            "PLAYER_WEAPON_HUD_SIZE",
            "PLAYER_WEAPON_HUD_BOTTOM_MARGIN",
            "PLAYER_WEAPON_HUD_RIGHT_MARGIN",
            "PLAYER_WEAPON_HUD_LEFT_OFFSET",
            "PLAYER_WEAPON_HUD_TEXT_Y_OFFSET",
            "PLAYER_WEAPON_HUD_ICON_DOWN_OFFSET",
            "PLAYER_WEAPON_HUD_TEXT_COLUMN_WIDTH",
            "PLAYER_WEAPON_HUD_TEXT_GAP",
        ],
    ),
    (
        "Wave title HUD",
        [
            "WAVE_TITLE_HUD_TOP_MARGIN",
            "WAVE_TITLE_HUD_FONT_SIZE",
            "WAVE_TITLE_HUD_TEXT_COLOR",
        ],
    ),
    (
        "Upgrade picker",
        [
            "UPGRADE_BOX_PATH",
            "UPGRADE_BOX_TEX_SIZE",
            "UPGRADE_BOX_HUD_WIDTH",
            "UPGRADE_BOX_HUD_HEIGHT",
            "UPGRADE_PICKER_CARD_SPACING",
            "UPGRADE_PICKER_BOTTOM_MARGIN",
            "UPGRADE_PICKER_HEADER_GAP",
            "UPGRADE_PICKER_SLIDE_HIDDEN_OFFSET",
            "UPGRADE_PICKER_SLIDE_DURATION",
            "UPGRADE_OVERLAY_ALPHA",
            "UPGRADE_PICKER_TITLE_FONT_SIZE",
            "UPGRADE_PICKER_HEADER_FONT_SIZE",
            "UPGRADE_PICKER_CARD_TITLE_FONT_SIZE",
            "UPGRADE_PICKER_CARD_BODY_FONT_SIZE",
            "UPGRADE_PICKER_CARD_STAT_FONT_SIZE",
            "UPGRADE_PICKER_CARD_TEXT_PAD_X",
            "UPGRADE_PICKER_CARD_TITLE_Y",
            "UPGRADE_PICKER_CARD_DESC_Y",
            "UPGRADE_PICKER_CARD_STAT_Y",
            "UPGRADE_PICKER_CARD_HOVER_LIFT",
            "UPGRADE_PICKER_CARD_HOVER_LERP_SPEED",
            "UPGRADE_PICKER_OPEN_DELAY",
            "UPGRADE_PICKER_INPUT_LOCK_DURATION",
        ],
    ),
    (
        "Upgrade stat bonuses",
        [
            "UPGRADE_VITALITY_HP_BONUS",
            "UPGRADE_MOVE_SPEED_BONUS",
            "UPGRADE_SWORD_DAMAGE_BONUS",
            "UPGRADE_BOW_DAMAGE_BONUS",
            "UPGRADE_SPECIAL_DAMAGE_BONUS",
            "UPGRADE_SPECIAL_COOLDOWN_REDUCTION",
            "UPGRADE_AOE_RADIUS_SCALE",
            "UPGRADE_FLEET_DASH_COOLDOWN_REDUCTION",
            "UPGRADE_CAMERA_ZOOM_OUT",
            "UPGRADE_CRIT_BONUS",
            "UPGRADE_KNOCKBACK_BONUS",
            "UPGRADE_LIFE_STEAL_BONUS",
            "UPGRADE_ATTACK_SPEED_BONUS",
            "UPGRADE_MIN_ABILITY_COOLDOWN",
        ],
    ),
]

MANUAL_DEFAULTS: dict[str, str] = {
    "PLAYER_HEALTH_FRAME_COUNT": "9",
    "PLAYER_HEALTH_SEGMENT_COUNT": "8",
}


def load_transcript_constants() -> dict[str, str]:
    consts: dict[str, list[str]] = defaultdict(list)
    for path in TRANSCRIPTS.rglob("*.jsonl"):
        for line in path.open(encoding="utf-8"):
            if "constants" not in line:
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue
            for part in data.get("message", {}).get("content", []):
                if part.get("name") not in ("StrReplace", "Write"):
                    continue
                inp = part.get("input", {})
                p = inp.get("path", "").replace("\\", "/")
                if not any(x in p for x in ("constants.das", "constants_ui.das", "constants_monolith")):
                    continue
                text = inp.get("new_string") or inp.get("contents") or ""
                for m in re.finditer(r"^\s+([A-Z][A-Z0-9_]+)\s*=\s*(.+)$", text, re.M):
                    consts[m.group(1)].append(m.group(2).strip())
    return {k: v[-1] for k, v in consts.items()}


def main() -> int:
    recovered = load_transcript_constants()
    lines = ["require engine.core", "", "let public {"]
    missing: list[str] = []

    for _title, names in BLOCKS:
        for name in names:
            if name in MANUAL_DEFAULTS:
                value = MANUAL_DEFAULTS[name]
            elif name in recovered:
                value = recovered[name]
            else:
                missing.append(name)
                continue
            if '"' in value:
                value = rewrite_text(value)
            lines.append(f"    {name} = {value}")

    lines.append("}")
    lines.append("")

    if missing:
        print("warning: missing values:", ", ".join(missing), file=sys.stderr)
        return 1

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT} ({len(lines)} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
