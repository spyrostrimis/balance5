"""Turn the repainted Blue Field HQ into desert kit art.

Input:  assets/source_inputs/desert_kit/blue_field_hq_steep.png   (ChatGPT, transparent or plain light background)
Output: assets/textures/rts/desert_kit/blue_field_hq_hd.png, blue_field_hq_pixel.png,
        portrait_blue_hq_hd.png, portrait_blue_hq_pixel.png
        and world_size in scenes/rts/desert_kit/pieces/blue_field_hq.tscn (width kept at 140 world units)

Uses the same cutout, lamp-dimming, HD/Pixel and portrait steps as Reusable 4.

    C:/Python312/python.exe tools/python/make_desert_kit_hq.py
"""

from __future__ import annotations

import re
import sys

import numpy as np
from PIL import Image

import make_rts_reusable_4 as r4

ROOT = r4.ROOT
SRC = ROOT / "assets/source_inputs/desert_kit/blue_field_hq_steep.png"
KIT = ROOT / "assets/textures/rts/desert_kit"
PIECE = ROOT / "scenes/rts/desert_kit/pieces/blue_field_hq.tscn"
WORLD_WIDTH = 140


def key_out_plain_background(rgba: np.ndarray) -> np.ndarray:
    """If ChatGPT returned an opaque image, make the corner colour transparent."""
    if rgba[:, :, 3].min() < 250:
        return rgba
    corners = np.array([rgba[0, 0, :3], rgba[0, -1, :3], rgba[-1, 0, :3], rgba[-1, -1, :3]], dtype=np.float32)
    bg = corners.mean(axis=0)
    dist = np.linalg.norm(rgba[:, :, :3].astype(np.float32) - bg[None, None, :], axis=2)
    alpha = np.clip((dist - 10.0) / 26.0, 0.0, 1.0) * 255.0
    out = rgba.copy()
    out[:, :, 3] = alpha.astype(np.uint8)
    return out


def main() -> None:
    if not SRC.exists():
        sys.exit(f"Missing {SRC.relative_to(ROOT)}: generate it with prompt 1 in assets/source_inputs/desert_kit/PROMPTS.md")
    r4.OUT = KIT  # write into the shared kit instead of reusable_4
    src = key_out_plain_background(np.array(Image.open(SRC).convert("RGBA")))
    h, w, _ = src.shape
    cut = r4.clean_alpha_cutout(r4.crop_tight_rgba(src, (0, 0, w, h), pad=8), erode_rim=True)

    # Dim the door lamps like Reusable 4 so Orichalcum stays the brightest gold.
    f = cut.astype(np.float32)
    yy = np.linspace(0.0, 1.0, f.shape[0], dtype=np.float32)[:, None]
    lamps = (yy > 0.6) & (f[:, :, 0] > 225.0) & (f[:, :, 1] > 155.0) & (f[:, :, 2] < 120.0)
    f[lamps, 0] = 208.0 + (f[lamps, 0] - 208.0) * 0.35
    f[lamps, 1] = 142.0 + (f[lamps, 1] - 142.0) * 0.35
    final = np.round(np.clip(f, 0, 255)).astype(np.uint8)

    world_h = int(round(WORLD_WIDTH * final.shape[0] / final.shape[1]))
    r4.save_r4_pair("blue_field_hq", final, (WORLD_WIDTH, world_h), skirt_hd=4, sharp_hd=0.20, sharp_pix=0.36, alpha_cut=84)
    r4.make_r4_portrait(final, (218, 184, 136), (138, 104, 68), "blue_hq")

    text = PIECE.read_text(encoding="utf-8")
    text = re.sub(r"world_size = Vector2\([^)]*\)", f"world_size = Vector2({WORLD_WIDTH}, {world_h})", text, count=1)
    PIECE.write_text(text, encoding="utf-8")
    print(f"HQ written to {KIT.relative_to(ROOT)}; piece world_size = ({WORLD_WIDTH}, {world_h}).")
    print("Open Mission 1, press F1 and check the HQ's blocked cells match the new building.")


if __name__ == "__main__":
    main()
