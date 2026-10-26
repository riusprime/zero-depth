"""v0.9.5 MM: cuts the owner's main-menu picture into the menu's backdrop (the owner's art, not generated).

  python -I scripts/art/cut_menu_backdrop.py

- docs/art/reference/v0.9.5_main_menu.webp -> assets/ui/menu/backdrop.png: 1920 x 1080 (Lanczos), everything left of
  x = 40 % black and fading in over the next 10 %, so the picture's own baked buttons never show behind the real ones.
- The logo is the owner's transparent PNG, used as sent: docs/art/reference/v0.9.5_logo.png = assets/ui/menu/logo.png.
Needs Pillow and numpy (requirements-dev.txt does not; a throwaway venv is fine).
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / "docs" / "art" / "reference"
OUT = ROOT / "assets" / "ui" / "menu"

BLACK_UNTIL = 0.40
FADE_OVER = 0.10


def backdrop() -> None:
    img = Image.open(REF / "v0.9.5_main_menu.webp").convert("RGB")
    img = img.resize((1920, 1080), Image.LANCZOS)
    a = np.asarray(img).astype(np.float32)
    x = (np.arange(1920, dtype=np.float32) + 0.5) / 1920.0
    t = np.clip((x - BLACK_UNTIL) / FADE_OVER, 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    a *= t[None, :, None]
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8)).save(OUT / "backdrop.png", optimize=True)


if __name__ == "__main__":
    backdrop()
    print("wrote", OUT / "backdrop.png")
