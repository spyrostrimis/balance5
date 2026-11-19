"""Build pixel-art versions of the canyon textures for the HD-2D A/B test.

Each texture is area-downsampled so one texel covers 1/DENSITY metres in the game (using the
metres-per-repeat its shader applies), then colour maps are quantized to one shared palette sampled
from the canyon goal image and the source art, without dithering. Normal and ORM maps are only
downsampled. Bush sprites get a hard alpha.

This approximates hand-pixelled textures well enough to judge the look. Final art would be authored
in Aseprite or with a pixel-art generator at the chosen density.

Usage (from the project root):
    C:/Python312/python.exe tools/python/build_pixel_textures.py
Writes assets/textures/pixel_ab/d32/ and d64/.
"""
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "textures" / "canyon_pbr"
OUT = ROOT / "assets" / "textures" / "pixel_ab"
GOAL = ROOT / "docs" / "references" / "rpg_canyon_goal.jpg"
DENSITIES = (32, 64)
PALETTE_COLOURS = 48

# basename -> (metres per repeat along U, along V, kind)
# Scales come from the shaders: hd2d_octopath_rock, hd2d_canyon_ground_crisp, hd2d_chatgpt_boulder.
TEXTURES = {
    "d_sandstone_strata_albedo": (1 / 0.34, 1 / 0.72, "colour"),
    "d_sandstone_strata_normal": (1 / 0.34, 1 / 0.72, "data"),
    "d_basalt_cap_albedo": (1 / 1.05, 1 / 1.05, "colour"),
    "d_basalt_cap_normal": (1 / 1.05, 1 / 1.05, "data"),
    "d_boulder_rock_albedo": (1 / 0.65, 1 / 0.65, "colour"),
    "d_boulder_rock_normal": (1 / 0.65, 1 / 0.65, "data"),
    "chatgpt_cobble_albedo": (3.2, 3.2, "colour"),
    "chatgpt_cobble_normal": (3.2, 3.2, "data"),
    "chatgpt_cobble_orm": (3.2, 3.2, "data"),
    "hd2d_sand_albedo": (1 / 0.46, 1 / 0.24, "colour"),
    "hd2d_sand_normal": (1 / 0.46, 1 / 0.24, "data"),
    "pure_dune_sand_albedo": (1 / 0.24, 1 / 0.24, "colour"),
    "pure_dune_sand_normal": (1 / 0.24, 1 / 0.24, "data"),
    "chatgpt_sandstone_albedo": (1.65, 1.65, "colour"),
    "chatgpt_sandstone_normal": (1.65, 1.65, "data"),
    "chatgpt_sandstone_orm": (1.65, 1.65, "data"),
}
# Sprites: base pixel size 0.005 m per source pixel in scenes/canyon/modules/bush_*.tscn.
SPRITES = {"hd2d_bush_cluster": 0.005, "d_sage_bush_2": 0.005}


def build_palette() -> Image.Image:
    samples = [Image.open(GOAL).convert("RGB").resize((344, 192), Image.BOX)]
    for name, (_, _, kind) in TEXTURES.items():
        if kind == "colour":
            samples.append(Image.open(SRC / f"{name}.png").convert("RGB").resize((96, 96), Image.BOX))
    for name in SPRITES:
        im = Image.open(SRC / f"{name}.png").convert("RGBA")
        samples.append(im.convert("RGB").resize((96, 54), Image.BOX))
    width = sum(s.width for s in samples)
    sheet = Image.new("RGB", (width, max(s.height for s in samples)))
    x = 0
    for s in samples:
        sheet.paste(s, (x, 0))
        x += s.width
    return sheet.quantize(colors=PALETTE_COLOURS, method=Image.Quantize.MEDIANCUT)


def pixelate_colour(im: Image.Image, size, palette: Image.Image) -> Image.Image:
    small = im.convert("RGB").resize(size, Image.BOX)
    small = small.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    return small.quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")


def main() -> None:
    palette = build_palette()
    for density in DENSITIES:
        out = OUT / f"d{density}"
        out.mkdir(parents=True, exist_ok=True)
        for name, (mu, mv, kind) in TEXTURES.items():
            src = Image.open(SRC / f"{name}.png")
            size = (max(4, round(mu * density)), max(4, round(mv * density)))
            if kind == "colour":
                result = pixelate_colour(src, size, palette)
            else:
                result = src.convert("RGB").resize(size, Image.BOX)
            result.save(out / f"{name}.png")
            print(f"d{density} {name}: {src.size} -> {size}")
        for name, pixel_size in SPRITES.items():
            src = Image.open(SRC / f"{name}.png").convert("RGBA")
            factor = density * pixel_size  # target texels per source pixel
            size = (max(4, round(src.width * factor)), max(4, round(src.height * factor)))
            small = src.resize(size, Image.BOX)
            alpha = small.getchannel("A").point(lambda a: 255 if a >= 110 else 0)
            colour = pixelate_colour(small, size, palette)
            colour.putalpha(alpha)
            colour.save(out / f"{name}.png")
            print(f"d{density} {name}: {src.size} -> {size}")
    palette.convert("RGB").save(OUT / "palette_preview.png")


if __name__ == "__main__":
    main()
