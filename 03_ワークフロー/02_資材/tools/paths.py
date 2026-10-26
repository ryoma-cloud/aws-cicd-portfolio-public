"""Resolve release assets independently of where workflow helper modules live."""
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
ASSET_ROOT = PROJECT_ROOT / '02_資材'
TEMP_ROOT = ASSET_ROOT / '02_temporary'
WORKFLOW_ASSETS = PROJECT_ROOT / '03_ワークフロー' / '02_資材'
