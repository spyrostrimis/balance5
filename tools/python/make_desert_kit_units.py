"""Brighten the Blue uniforms for the shared desert kit.

Reads the Reusable 4 sprite sheets (painted shading, navy cobalt) and writes the desert kit copies
with the cobalt lifted towards Reusable 3's brightness, so Blue squads read as blue rather than as
dark blobs on orange sand at Command zoom. Shading is kept by scaling value and saturation
multiplicatively, only on cobalt pixels, with a soft hue/saturation mask so edges do not band.

Idempotent: always starts from assets/textures/rts/reusable_4.

    C:/Python312/python.exe tools/python/make_desert_kit_units.py
"""

import colorsys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/textures/rts/reusable_4"
DST = ROOT / "assets/textures/rts/desert_kit"

SHEETS = ["blue_soldier", "blue_commander"]
VALUE_GAIN = 1.22
VALUE_LIFT = 0.09  # lifts the navy shadows so the shoulders read as one cobalt mass
SAT_GAIN = 1.08
HUE_CENTRE = 0.615  # cobalt
HUE_WIDTH = 0.075


def _smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def brighten(src: Path, dst: Path) -> tuple[int, int]:
    im = Image.open(src).convert("RGBA")
    out = im.copy()
    px = out.load()
    changed = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            hue_w = 1.0 - _smooth(HUE_WIDTH * 0.6, HUE_WIDTH, abs(h - HUE_CENTRE))
            sat_w = _smooth(0.18, 0.38, s)
            w = hue_w * sat_w
            if w <= 0.0:
                continue
            nv = min(1.0, v * (1.0 + (VALUE_GAIN - 1.0) * w) + VALUE_LIFT * w)
            ns = min(1.0, s * (1.0 + (SAT_GAIN - 1.0) * w))
            nr, ng, nb = colorsys.hsv_to_rgb(h, ns, nv)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
            changed += 1
    out.save(dst)
    return changed, im.width * im.height


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    for sheet in SHEETS:
        for variant in ("hd", "pixel"):
            name = f"{sheet}_{variant}.png"
            changed, total = brighten(SRC / name, DST / name)
            print(f"{name}: brightened {changed} of {total} pixels")


if __name__ == "__main__":
    main()
