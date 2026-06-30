"""Project root resolution for scripts under scripts/python/."""
from __future__ import annotations

from pathlib import Path

_PYTHON_ROOT = Path(__file__).resolve().parent.parent
PROJECT_ROOT = _PYTHON_ROOT.parent.parent
PREFABS_DIR = PROJECT_ROOT / "prefabs"
DATA_DIR = _PYTHON_ROOT / "data"
