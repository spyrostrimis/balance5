"""Turn Desert Crossing's painted dune swells into desert-kit relief pieces.

Desert Crossing (assets/textures/rts/desert_reference_pass/) has smooth painted swells and a big
"sand mountain" hump. Painted in their own pale apricot, they would sit on Carbon's grainy sand like
stickers. Carbon's dune shader instead adds a *signed light/shadow delta* (stored around grey 128)
onto whatever sand is underneath, so this script stores only each painting's light and shade relative
to its own mid-tone. The result takes on the sand's colour and grain on every planet skin, and tank
treads flatten it like the other dunes.

Writes assets/textures/rts/desert_kit/<piece>_hd.png and _pixel.png for:
    sand_hill     the single big hump (the "small sand mountain")
    dune_swells   the whole swell field
    ripple_field  the long ripple bands

    C:/Python312/python.exe tools/python/make_desert_kit_hills.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/textures/rts/desert_reference_pass"
OUT = ROOT / "assets/textures/rts/desert_kit"

# (output name, source file, crop box in source pixels or None, gain on the light/shade delta)
PIECES = [
    ("sand_hill", "dune_swells.png", (350, 0, 810, 203), 1.55),
    ("dune_swells", "dune_swells.png", None, 1.3),
    ("ripple_field", "ripple_field.png", None, 1.0),
]
FEATHER = 70  # px of alpha fade on edges created by cropping


def to_delta(rgba: np.ndarray, gain: float) -> np.ndarray:
    f = rgba.astype(np.float32)
    a = f[:, :, 3] / 255.0
    solid = a > 0.85
    mid = np.median(f[:, :, :3][solid], axis=0)
    delta = (f[:, :, :3] - mid[None, None, :]) * gain
    # Fade the relief toward the soft edge so the hill melts into flat sand.
    delta *= np.clip(a * 1.25, 0.0, 1.0)[:, :, None]
    enc = np.clip(128.0 + delta, 0.0, 255.0)
    return np.concatenate([enc, f[:, :, 3:4]], axis=2).round().astype(np.uint8)


def feather_crop(rgba: np.ndarray, left: bool, right: bool) -> np.ndarray:
    out = rgba.astype(np.float32).copy()
    w = out.shape[1]
    ramp = np.ones(w, dtype=np.float32)
    x = np.arange(w, dtype=np.float32)
    if left:
        ramp *= np.clip(x / FEATHER, 0.0, 1.0)
    if right:
        ramp *= np.clip((w - 1 - x) / FEATHER, 0.0, 1.0)
    ramp = ramp * ramp * (3.0 - 2.0 * ramp)
    out[:, :, 3] *= ramp[None, :]
    return out.round().astype(np.uint8)


def pixel_version(hd: np.ndarray) -> np.ndarray:
    img = Image.fromarray(hd).resize((hd.shape[1] // 2, hd.shape[0] // 2), Image.LANCZOS)
    px = np.asarray(img).astype(np.float32)
    # Step the relief into a few bands, like the other Pixel dunes.
    px[:, :, :3] = 128.0 + np.round((px[:, :, :3] - 128.0) / 14.0) * 14.0
    px[:, :, 3] = np.where(px[:, :, 3] > 96, 255, 0)
    return np.clip(px, 0, 255).astype(np.uint8)


def main() -> None:
    for name, src, box, gain in PIECES:
        rgba = np.asarray(Image.open(SRC / src).convert("RGBA"))
        if box is not None:
            x0, y0, x1, y1 = box
            rgba = feather_crop(rgba[y0:y1, x0:x1], left=x0 > 0, right=x1 < rgba.shape[1])
        hd = to_delta(rgba, gain)
        Image.fromarray(hd).save(OUT / f"{name}_hd.png")
        Image.fromarray(pixel_version(hd)).save(OUT / f"{name}_pixel.png")
        print(f"{name}: HD {hd.shape[1]}x{hd.shape[0]} -> world {hd.shape[1] // 2}x{hd.shape[0] // 2}")


if __name__ == "__main__":
    main()
