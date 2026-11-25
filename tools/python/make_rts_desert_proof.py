"""Extract the reusable painted modules and their pixel treatments from the source sheets."""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageColor, ImageFilter

import rts_palette
from smooth_texture import cosine_wrap

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/source_inputs/rts/desert_proof"
OUT = ROOT / "assets/textures/rts/desert_proof"
SAND = "bc804a cd9457 d9a365 e6b77a f1cd91"
STONE = "684532 8a6143 ab805b be9872 d3af88 e9c5a0"
ROCK = "35292a 493333 5e4236 77513b 94643e b4814c ca9a60 edb877"
AMBER = "af6519 de8c24 f4b541 ffdf84"
WATER = "183d46 1b5a63 247e84 3b9a96 6cb5a1 575130 73703d 979450"
BLUE = "273847 405867 627987 9cb5b8 28568a 427ab4"


def seam(image, y_axis=True):
    pixels = np.asarray(image, dtype=np.float32)
    mixed = cosine_wrap([pixels], 25, 1)
    if y_axis:
        mixed = cosine_wrap(mixed, 25, 0)
    return Image.fromarray(np.clip(mixed[0], 0, 255).astype(np.uint8))


def pixel_art(image, size, palette, soft_alpha=False):
    small = image.resize(size, Image.Resampling.BOX)
    data = np.array(small)
    rgb = cv2.bilateralFilter(data[..., :3].copy(), 5, 17, 1.4)
    colors = np.array([ImageColor.getrgb("#" + hex_color) for hex_color in palette.split()], np.uint8)
    quantized = rts_palette.map_to_palette(rgb, colors)
    if data.shape[2] == 4:
        alpha = np.digitize(data[..., 3], [48, 128, 208]).astype(np.uint8) * 85 if soft_alpha else (
            (data[..., 3] >= 118).astype(np.uint8) * 255)
        quantized = np.dstack((quantized, alpha))
    return Image.fromarray(quantized)


def save_pair(name, image, pixel_size, palette, soft_alpha=False):
    hd_size = tuple(2 * side for side in pixel_size)
    image.resize(hd_size, Image.Resampling.LANCZOS).save(OUT / f"{name}_hd.png")
    pixel_art(image, pixel_size, palette, soft_alpha).save(OUT / f"{name}_pixel.png")


def extract(atlas, index):
    column, row = index % 3, index // 3
    cell = atlas.crop((column * 512, row * 512, (column + 1) * 512, (row + 1) * 512))
    alpha = cell.getchannel("A")
    box = alpha.point(lambda v: 255 if v >= 25 else 0).getbbox()
    bounds = tuple(max(0, x - 3) if i < 2 else min(512, x + 3) for i, x in enumerate(box))
    image = cell.crop(bounds)
    alpha = image.getchannel("A").point(lambda v: 0 if v < 9 else v)
    image.putalpha(alpha)
    return image


def paving_texture(atlas):
    stone = atlas.crop((146, 734, 358, 833)).convert("RGB").resize((244, 144), Image.Resampling.LANCZOS)
    stone = seam(stone, y_axis=False).convert("RGBA")
    y, x = np.mgrid[0:144, 0:244].astype(np.float32)
    nibble = 2.5 * np.sin(x * 2.0 * np.pi / 61.0) + 1.5 * np.sin(x * 2.0 * np.pi / 12.2)
    edge = np.minimum(y + nibble, 143.0 - y - nibble)
    stone.putalpha(Image.fromarray((np.clip(edge / 10.0, 0, 1) * 255).astype(np.uint8)))
    return stone


def shadow_textures():
    for suffix, size in [("hd", 256), ("pixel", 96)]:
        y, x = np.mgrid[0:size, 0:size].astype(np.float32)
        distance = np.hypot(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5) / (size * 0.5)
        t = np.clip((distance - 0.22) / 0.78, 0, 1)
        opacity = 1.0 - t * t * (3.0 - 2.0 * t)
        if suffix == "pixel":
            opacity = np.rint(opacity * 4) / 4
        rgba = np.zeros((size, size, 4), dtype=np.uint8)
        rgba[..., :3] = (78, 48, 45)
        rgba[..., 3] = np.rint(opacity * 255).astype(np.uint8)
        Image.fromarray(rgba).save(OUT / f"shadow_{suffix}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.open(SRC / "terrain_kit.png").convert("RGBA")
    sand = Image.open(SRC / "sand.png").convert("RGB").resize((576, 576), Image.Resampling.LANCZOS)
    sand = seam(sand)
    sand.filter(ImageFilter.GaussianBlur(0.35)).save(OUT / "sand_hd.png")
    pixel_art(sand.filter(ImageFilter.GaussianBlur(8.0)), (288, 288), SAND).save(OUT / "sand_pixel.png")
    art = [
        ("cliff", (292, 187), ROCK, False),
        ("dune", (194, 146), SAND, True),
        ("crystal", (128, 89), ROCK + " " + AMBER, False),
        ("flagstones", (145, 110), STONE, False),
        ("oasis", (99, 77), WATER + " " + ROCK, False),
        ("outpost", (101, 102), BLUE + " " + ROCK + " " + STONE, False),
    ]
    for index, (name, size, palette, soft_alpha) in enumerate(art):
        image = extract(atlas, index)
        if name == "dune":
            y, x = np.mgrid[0:image.height, 0:image.width].astype(np.float32)
            d = np.hypot((x / image.width - 0.5) * 2.0, (y / image.height - 0.5) * 2.0)
            rgba = np.array(image)
            fade = np.clip((1.0 - d) / 0.29, 0, 1)
            rgba[..., 3] = np.rint(rgba[..., 3] * fade).astype(np.uint8)
            image = Image.fromarray(rgba)
        save_pair(name, image, size, palette, soft_alpha)
    save_pair("paving", paving_texture(atlas), (122, 72), STONE, True)
    pebble = Image.open(ROOT / "assets/textures/kitbash/pebble_3.png").convert("RGBA")
    save_pair("pebble", pebble.crop(pebble.getbbox()), (24, 18), ROCK)
    shadow_textures()


if __name__ == "__main__":
    main()
