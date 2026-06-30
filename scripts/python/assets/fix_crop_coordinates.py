"""Set correct pre-cropped prop/wall pixel coordinates in constants.das."""
from __future__ import annotations

import re
from pathlib import Path

CONSTANTS = Path(__file__).resolve().parents[3] / "scripts" / "das" / "core" / "constants.das"

REPLACEMENTS = {
    "PROP_MISC_B12_E_FEET_PX = float2(-55.0, 20.5)": "PROP_MISC_B12_E_FEET_PX = float2(73.5, 134.0)",
    "PROP_MISC_B5_E_FEET_PX = float2(-69.0, -20.0)": "PROP_MISC_B5_E_FEET_PX = float2(36.0, 108.0)",
    "PROP_MISC_B10_E_FEET_PX = float2(-84.0, -19.0)": "PROP_MISC_B10_E_FEET_PX = float2(53.5, 88.0)",
    "PROP_MISC_B8_E_FEET_PX = float2(-69.0, -22.0)": "PROP_MISC_B8_E_FEET_PX = float2(61.0, 65.0)",
    "PROP_MISC_B25_E_FEET_PX = float2(-123.0, 62.0)": "PROP_MISC_B25_E_FEET_PX = float2(44.0, 82.0)",
    "PROP_MISC_B3_E_FEET_PX = float2(-61.0, 4.5)": "PROP_MISC_B3_E_FEET_PX = float2(48.5, 133.0)",
    "PROP_MISC_B14_E_FEET_PX = float2(-53.0, -3.0)": "PROP_MISC_B14_E_FEET_PX = float2(52.0, 138.0)",
    "PROP_MISC_B11_E_FEET_PX = float2(-66.0, -6.0)": "PROP_MISC_B11_E_FEET_PX = float2(58.0, 95.0)",
    "PROP_MISC_B2_E_FEET_PX = float2(-78.0, -5.0)": "PROP_MISC_B2_E_FEET_PX = float2(61.0, 78.0)",
    "PROP_MISC_B7_E_FEET_PX = float2(-79.0, -43.0)": "PROP_MISC_B7_E_FEET_PX = float2(52.0, 55.0)",
    "PROP_MISC_B9_E_FEET_PX = float2(-99.0, -46.0)": "PROP_MISC_B9_E_FEET_PX = float2(14.0, 58.0)",
    "PROP_MISC_B40_E_FEET_PX = float2(-65.0, -43.5)": "PROP_MISC_B40_E_FEET_PX = float2(62.5, 67.0)",
    "PROP_MISC_B20_E_FEET_PX = float2(-96.0, -31.5)": "PROP_MISC_B20_E_FEET_PX = float2(29.5, 63.0)",
    "PROP_MISC_B1_E_FEET_PX = float2(-94.0, -31.0)": "PROP_MISC_B1_E_FEET_PX = float2(32.0, 49.0)",
    "WALL_B1_E_FEET_PX = float2(-94.0, 54.0)": "WALL_B1_E_FEET_PX = float2(50.0, 155.0)",
    "WALL_B1_E_BOTTOM_PX_A = float2(-94.0, 23.0)": "WALL_B1_E_BOTTOM_PX_A = float2(19.0, 144.0)",
    "WALL_B1_E_BOTTOM_PX_B = float2(-94.0, 94.0)": "WALL_B1_E_BOTTOM_PX_B = float2(90.0, 109.0)",
    "WALL_B1_W_FEET_PX = float2(-44.0, 27.0)": "WALL_B1_W_FEET_PX = float2(50.0, 155.0)",
    "WALL_B1_W_BOTTOM_PX_A = float2(-44.0, 3.0)": "WALL_B1_W_BOTTOM_PX_A = float2(26.0, 141.0)",
    "WALL_B1_W_BOTTOM_PX_B = float2(-44.0, 69.0)": "WALL_B1_W_BOTTOM_PX_B = float2(92.0, 111.0)",
    "WALL_B1_N_FEET_PX = float2(-92.0, 75.0)": "WALL_B1_N_FEET_PX = float2(49.0, 155.0)",
    "WALL_B1_N_BOTTOM_PX_A = float2(-92.0, 116.0)": "WALL_B1_N_BOTTOM_PX_A = float2(90.0, 143.0)",
    "WALL_B1_N_BOTTOM_PX_B = float2(-92.0, 47.0)": "WALL_B1_N_BOTTOM_PX_B = float2(21.0, 111.0)",
    "WALL_B1_S_FEET_PX = float2(-45.0, 4.0)": "WALL_B1_S_FEET_PX = float2(50.0, 155.0)",
    "WALL_B1_S_BOTTOM_PX_A = float2(-45.0, 44.0)": "WALL_B1_S_BOTTOM_PX_A = float2(90.0, 143.0)",
    "WALL_B1_S_BOTTOM_PX_B = float2(-45.0, 22.0)": "WALL_B1_S_BOTTOM_PX_B = float2(22.0, 110.0)",
    "WALL_B2_E_FEET_PX = float2(-94.0, 54.0)": "WALL_B2_E_FEET_PX = float2(48.0, 179.0)",
    "WALL_B2_W_FEET_PX = float2(-57.0, 54.0)": "WALL_B2_W_FEET_PX = float2(45.0, 179.0)",
    "WALL_B2_N_FEET_PX = float2(-46.0, 27.0)": "WALL_B2_N_FEET_PX = float2(73.0, 151.0)",
    "WALL_B2_S_FEET_PX = float2(-47.0, 6.0)": "WALL_B2_S_FEET_PX = float2(74.5, 150.0)",
}


def main() -> None:
    text = CONSTANTS.read_text(encoding="utf-8")
    for old, new in REPLACEMENTS.items():
        if old not in text:
            # try generic float2 replace by prefix
            prefix = old.split(" = ")[0]
            m = re.search(rf"{re.escape(prefix)} = float2\([^)]+\)", text)
            if not m:
                print("missing", prefix)
                continue
            text = text.replace(m.group(0), new, 1)
        else:
            text = text.replace(old, new, 1)
    CONSTANTS.write_text(text, encoding="utf-8", newline="\n")
    print("patched", len(REPLACEMENTS), "coordinates")


if __name__ == "__main__":
    main()
