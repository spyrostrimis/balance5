"""Prepare Reusable 3 HD and Pixel textures from the kept paint and Carbon sheets."""
import numpy as np
from PIL import Image

from make_rts_reusable_2_carbon import (
    OUT as CARBON, PALETTE, ROOT, crop_tight_rgba, quantize_rgba, resize_premult, save_png,
)

SOURCE = ROOT / "assets/source_inputs/rts_reusable_3"
OUT = ROOT / "assets/textures/rts/reusable_3"
UNIT_PALETTE = np.vstack((PALETTE, [[21, 67, 150], [33, 98, 207], [81, 148, 247],
                                   [105, 17, 37], [174, 20, 45], [239, 51, 66]]))
SHEETS = {
    "dunes": (2, 2, [("dune_fork", (152, 100)), ("dune_end", (124, 75)),
                      ("dune_shoulder", (152, 98)), ("dune_ripples", (140, 88))]),
    "oasis": (3, 2, [("spring_water", (134, 86)), ("bank_sand", (104, 76)),
                      ("bank_rock", (116, 96)), ("cliff_ledge", (174, 108)),
                      ("cliff_end", (100, 58)), ("reeds", (32, 26))]),
    "crystals": (2, 2, [("crystal_base", (134, 93)), ("crystal_wide", (76, 43)),
                         ("crystal_tall", (62, 60)), ("crystal_gravel", (78, 38))]),
    "hq": (1, 1, [("blue_field_hq", (116, 108))]),
    "tree": (1, 1, [("spring_tree", (98, 62))]),
}


def paint_uniform(frame, key, column, bob):
    """Glaze locally, keeping the original highlight, shadow, silhouette and weapon pixels."""
    yy, xx = np.indices(frame.shape[:2])
    y = yy + bob
    x = frame.shape[1] - 1 - xx if column in (1, 2, 3) else xx
    rgb = frame[:, :, :3].astype(np.float32)
    light = rgb @ np.array([0.299, 0.587, 0.114])
    alpha = frame[:, :, 3]
    if key == "blue_commander":
        # Existing scarf tail plus a broad band across the shoulder line, clear of the face.
        scarf = ((y >= 19) & (y <= 24) & (x >= 15) & (x <= 24)
                 & ((y >= 21) | (x <= 18)) & (light > 59))
        scarf |= ((y >= 13) & (y <= 21) & (x < 17) & (light > 100) & (rgb[:, :, 0] > rgb[:, :, 2] + 18))
        tint = np.array([233, 223, 187]) + (light[:, :, None] - 153) * 0.47
        amount = np.where(scarf, 0.91, 0.0)
    else:
        rear = column in (3, 4, 5)
        # Shoulder silhouette, with separate front and rear hems. Preserve the grey diagonal rifle.
        shoulder = ((y >= 12) & (y <= (22 if rear else 20)) & (x >= 8) & (x <= 19)
                    & ((x <= 17) | (y <= 17) | rear))
        weapon = (y >= 18) & (x >= 15) & (rgb.max(axis=2) - rgb.min(axis=2) < 30) & (light < 92)
        amount = np.where(shoulder & ~weapon & (light > 36), 0.92, 0.0)
        rim = ((y <= 15) & (y >= 12)).astype(float)[:, :, None]
        variation = (light[:, :, None] - 113) * 0.59 + rim * 23
        base = [30, 86, 200] if key == "blue_soldier" else [168, 21, 44]
        tint = np.array(base) + variation
    blend = (amount * np.clip((alpha.astype(float) - 65) / 130, 0, 1))[:, :, None]
    frame[:, :, :3] = np.clip(rgb * (1 - blend) + tint * blend, 0, 255).astype(np.uint8)


def save_units():
    for key in ("blue_soldier", "red_soldier", "blue_commander"):
        hd = np.array(Image.open(CARBON / f"{key}_hd.png").convert("RGBA"))
        height, width = hd.shape[0] // 4, hd.shape[1] // 8
        pixel = np.zeros((height * 2, width * 4, 4), dtype=np.uint8)
        for row in range(4):
            for col in range(8):
                frame = hd[row * height:(row + 1) * height, col * width:(col + 1) * width]
                paint_uniform(frame, key, col, int(row in (1, 3)))
                down = resize_premult(frame, (width // 2, height // 2), sharpen=0.35)
                py, px = row * height // 2, col * width // 2
                pixel[py:py + height // 2, px:px + width // 2] = quantize_rgba(
                    down, UNIT_PALETTE, alpha_cutoff=88, outline=True)
        save_png(hd, OUT / f"{key}_hd.png")
        save_png(pixel, OUT / f"{key}_pixel.png")


def dune_delta(paint, strength):
    # Encode only relief around neutral grey. Carbon mixes this with its own sand and crushes the
    # relief wherever its two tread lanes cover it. Inset alpha feather keeps texture joins quiet.
    rgb = paint[:, :, :3].astype(np.float32)
    light = rgb @ np.array([0.299, 0.587, 0.114])
    neutral = np.median(light[paint[:, :, 3] > 150])
    delta = (light - neutral) * strength
    for channel, response in enumerate((0.95, 1.05, 0.78)):
        paint[:, :, channel] = np.clip(128 + delta * response, 54, 200)
    return paint


def save_paintings():
    for sheet, (columns, rows, parts) in SHEETS.items():
        source = np.array(Image.open(SOURCE / f"{sheet}.png").convert("RGBA"))
        h, w = source.shape[:2]
        for index, (name, size) in enumerate(parts):
            col, row = index % columns, index // columns
            crop = crop_tight_rgba(source, (col * w // columns, row * h // rows,
                                           (col + 1) * w // columns, (row + 1) * h // rows))
            if sheet == "dunes":
                flattened = Image.fromarray(crop).rotate(-8, Image.Resampling.BICUBIC, expand=True)
                crop = np.array(flattened)
                crop = crop_tight_rgba(crop, (0, 0, flattened.width, flattened.height))
                strengths = (1.18, 0.94, 0.63, 0.46)
                crop = dune_delta(crop, strengths[index])
            hd = resize_premult(crop, tuple(n * 2 for n in size), sharpen=0.12)
            pixel = resize_premult(crop, size, sharpen=0.22)
            if sheet == "dunes":
                pixel[:, :, :3] = np.clip(np.round(pixel[:, :, :3].astype(float) / 6) * 6 + 2, 0, 255)
            else:
                pixel = quantize_rgba(pixel, UNIT_PALETTE, alpha_cutoff=94)
            save_png(hd, OUT / f"{name}_hd.png")
            save_png(pixel, OUT / f"{name}_pixel.png")


if __name__ == "__main__":
    save_units()
    save_paintings()
