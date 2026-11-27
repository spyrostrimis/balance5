"""Cut the owner's HUD mockup E (assets/source_inputs/hud/hud_E_classic.png) into live HUD chrome.

The mockup's painted frame, buttons, labels and commander portrait are kept as they are. Everything
that changes in play (unit name, health, stat values, ability strip, hold bar and state, counters,
minimap) is painted out with OpenCV inpainting so the game can draw it live with sharp fonts.

Writes assets/textures/ui/hud_mockup_e/top_bar.png, sidebar.png, mend_icon.png and a check sheet in
render_captures/rts_mission_1/hud_mockup_e_chrome.png.
Coordinates are mockup pixels (1672 x 941); the game maps them to its 960 x 540 HUD space.

    C:/Python312/python.exe tools/python/make_hud_mockup_e.py
"""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/source_inputs/hud/hud_E_classic.png"
OUT = ROOT / "assets/textures/ui/hud_mockup_e"
SHEET = ROOT / "render_captures/rts_mission_1/hud_mockup_e_chrome.png"

TOP = (0, 0, 1672, 62)
SIDE = (1262, 62, 1672, 941)
# Areas painted out (mockup coordinates).
DYNAMIC = [
    (835, 8, 905, 54),      # Orichalcum value
    (1133, 8, 1200, 54),    # Forces value
    (1410, 8, 1505, 54),    # Hold value
    (1446, 84, 1660, 122),  # unit name
    (1452, 128, 1654, 154),  # health bar + text
    (1598, 168, 1656, 264),  # stat values
    (1288, 288, 1652, 340),  # ability strip contents
    (1303, 578, 1647, 610),  # hold progress bar
    (1300, 612, 1648, 650),  # hold state text
    (1300, 683, 1642, 892),  # minimap
]
MEND_ICON = (1291, 289, 1362, 338)


def main() -> None:
    img = cv2.cvtColor(np.asarray(Image.open(SRC).convert("RGB")), cv2.COLOR_RGB2BGR)
    icon = img[MEND_ICON[1]:MEND_ICON[3], MEND_ICON[0]:MEND_ICON[2]].copy()
    mask = np.zeros(img.shape[:2], np.uint8)
    for x0, y0, x1, y1 in DYNAMIC:
        mask[y0:y1, x0:x1] = 255
    clean = cv2.inpaint(img, mask, 6, cv2.INPAINT_TELEA)
    # Inpainting smears the bright text colours; settle the painted-out areas toward the local panel tone.
    for x0, y0, x1, y1 in DYNAMIC:
        region = clean[y0:y1, x0:x1].astype(np.float32)
        ring = np.concatenate([img[max(y0 - 3, 0):y0, x0:x1].reshape(-1, 3), img[y1:y1 + 3, x0:x1].reshape(-1, 3)]).astype(np.float32)
        tone = np.median(ring, axis=0) if len(ring) else region.mean(axis=(0, 1))
        clean[y0:y1, x0:x1] = np.clip(region * 0.35 + tone * 0.65, 0, 255).astype(np.uint8)
    clean = cv2.cvtColor(clean, cv2.COLOR_BGR2RGB)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(clean[TOP[1]:TOP[3], TOP[0]:TOP[2]]).save(OUT / "top_bar.png")
    Image.fromarray(clean[SIDE[1]:SIDE[3], SIDE[0]:SIDE[2]]).save(OUT / "sidebar.png")
    Image.fromarray(cv2.cvtColor(icon, cv2.COLOR_BGR2RGB)).save(OUT / "mend_icon.png")
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(clean).save(SHEET)
    print("chrome written to", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
