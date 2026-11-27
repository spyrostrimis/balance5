"""Build the Miasaki planet skin for the desert kit.

Miasaki repainted Carbon's terrain (same sizes, same layout) in a pale peach / lavender palette.
This script learns that palette change from the matched Carbon/Miasaki pairs and applies it to the
kit pieces Miasaki never painted (Reusable 4's road joins, banks, cliffs, pebbles, crystal rock),
so a whole map can switch planets.

Writes assets/textures/rts/skins/miasaki/<piece>_hd.png and render_captures/rts_mission_1/miasaki_skin_sheet.png.
The battlefield looks in skins/miasaki first, then in carbon_miasaki, then falls back to the kit.

    C:/Python312/python.exe tools/python/make_planet_skin_miasaki.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CARBON = ROOT / "assets/textures/rts/carbon"
MIASAKI = ROOT / "assets/textures/rts/carbon_miasaki"
KIT = ROOT / "assets/textures/rts/desert_kit"
OUT = ROOT / "assets/textures/rts/skins/miasaki"
SHEET = ROOT / "render_captures/rts_mission_1/miasaki_skin_sheet.png"

PAIRS = ["sand_tile", "road_strip", "rock_mesa", "rock_ridge", "rock_boulders", "rock_outcrop_low",
         "cliff_oasis", "orichalcum_outcrop", "plaza_oval", "outpost_pad"]
# Kit pieces with sand, stone or rock colours and no Miasaki painting. Water, plants, crystals,
# units and the HQ keep their own colours on every planet.
TRANSFER = ["road_join_patch", "road_end_cap", "road_sand_spill", "pebble_scatter", "oasis_bank_sand",
            "oasis_bank_rock", "oasis_cliff_end", "oasis_cliff_ledge", "crystal_base", "crystal_gravel"]


def features(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    one = np.ones_like(r)
    return np.stack([one, r, g, b, r * r, g * g, b * b, r * g, r * b, g * b], axis=1)


def fit() -> np.ndarray:
    xs, ys = [], []
    rng = np.random.default_rng(7)
    for key in PAIRS:
        c = np.asarray(Image.open(CARBON / f"{key}_hd.png").convert("RGBA"), dtype=np.float32) / 255.0
        m = np.asarray(Image.open(MIASAKI / f"{key}_hd.png").convert("RGBA"), dtype=np.float32) / 255.0
        mask = (c[:, :, 3] > 0.8) & (m[:, :, 3] > 0.8)
        src, dst = c[:, :, :3][mask], m[:, :, :3][mask]
        take = rng.choice(len(src), size=min(len(src), 40000), replace=False)
        xs.append(src[take])
        ys.append(dst[take])
    x = features(np.concatenate(xs))
    y = np.concatenate(ys)
    coef, *_ = np.linalg.lstsq(x, y, rcond=None)
    err = np.abs(x @ coef - y).mean() * 255.0
    # A least-squares fit pulls values toward the middle (the repaints are not pixel-aligned), so
    # restore the light/shadow spread Miasaki actually has.
    lum = np.array([0.299, 0.587, 0.114], dtype=np.float32)
    fitted_y, true_y = (x @ coef) @ lum, y @ lum
    global CONTRAST, PIVOT
    CONTRAST = float(true_y.std() / max(fitted_y.std(), 1e-4))
    PIVOT = float(fitted_y.mean())
    print(f"palette fit on {len(x)} pixels, mean error {err:.1f}/255, contrast restore x{CONTRAST:.2f}")
    return coef


CONTRAST = 1.0
PIVOT = 0.5


def apply(coef: np.ndarray, rgba: np.ndarray) -> np.ndarray:
    f = rgba.astype(np.float32) / 255.0
    rgb = f[:, :, :3].reshape(-1, 3)
    mapped = features(rgb) @ coef
    y = mapped @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    target = PIVOT + (y - PIVOT) * CONTRAST
    mapped = mapped * (target / np.maximum(y, 1e-3))[:, None]
    mapped = np.clip(mapped, 0.0, 1.0).reshape(f.shape[0], f.shape[1], 3)
    out = np.concatenate([mapped, f[:, :, 3:4]], axis=2)
    return np.round(out * 255.0).astype(np.uint8)


def main() -> None:
    coef = fit()
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = []
    for key in TRANSFER:
        src = np.asarray(Image.open(KIT / f"{key}_hd.png").convert("RGBA"))
        out = apply(coef, src)
        Image.fromarray(out).save(OUT / f"{key}_hd.png")
        tiles.append((src, out))
        print(f"skins/miasaki/{key}_hd.png")

    # Contact sheet: kit piece over Carbon sand, then the skinned piece over Miasaki sand.
    sand_c = Image.open(CARBON / "sand_tile_hd.png").convert("RGBA")
    sand_m = Image.open(MIASAKI / "sand_tile_hd.png").convert("RGBA")
    cell = 220
    sheet = Image.new("RGBA", (cell * len(tiles), cell * 2))
    for i, (src, out) in enumerate(tiles):
        for row, (img, sand) in enumerate(((src, sand_c), (out, sand_m))):
            tile = sand.crop((0, 0, cell, cell))
            pic = Image.fromarray(img)
            pic.thumbnail((cell - 12, cell - 12))
            tile.alpha_composite(pic, ((cell - pic.width) // 2, (cell - pic.height) // 2))
            sheet.paste(tile, (i * cell, row * cell))
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEET)
    print(f"sheet {SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
