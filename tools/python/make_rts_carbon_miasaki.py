"""Fit Miasaki's ImageGen paint to Carbon's reusable sprite geometry and texture formats."""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_inputs/rts_carbon_miasaki"
CARBON = ROOT / "assets/textures/rts/carbon"
OUTPUT = ROOT / "assets/textures/rts/carbon_miasaki"
SAND = np.array([225.0, 167.0, 114.0], dtype=np.float32)


def read(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        return np.array(image.convert("RGBA"), dtype=np.float32)


def original(key: str) -> np.ndarray:
    return read(CARBON / f"{key}_hd.png")


def paint(key: str) -> np.ndarray:
    return read(SOURCE / f"{key}.png")


def write(key: str, pixels: np.ndarray) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rgba = np.clip(np.rint(pixels), 0, 255).astype(np.uint8)
    Image.fromarray(rgba).save(OUTPUT / f"{key}_hd.png", optimize=True)


def resize(pixels: np.ndarray, width: int, height: int) -> np.ndarray:
    return cv2.resize(pixels, (width, height), interpolation=cv2.INTER_AREA)


def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb @ np.array([0.24, 0.65, 0.11], dtype=np.float32)


def ramp(value: np.ndarray, knots: list[float], colors: list[tuple[int, int, int]]) -> np.ndarray:
    return np.stack([np.interp(value, knots, channel) for channel in zip(*colors)], axis=-1)


def smoothstep(low: float, high: float, value: np.ndarray) -> np.ndarray:
    fraction = np.clip((value - low) / (high - low), 0.0, 1.0)
    return fraction * fraction * (3.0 - 2.0 * fraction)


def blend(base: np.ndarray, top: np.ndarray, strength: np.ndarray | float) -> np.ndarray:
    return base + (top - base) * np.expand_dims(strength, -1)


def tile_axis(rgb: np.ndarray, axis: int) -> np.ndarray:
    size = rgb.shape[axis]
    weight = np.sin(np.pi * np.arange(size, dtype=np.float32) / size) ** 2
    weights = weight[None, :] if axis == 1 else weight[:, None]
    return blend(np.roll(rgb, size // 2, axis), rgb, weights)


def sand_tile() -> None:
    sand = original("sand_tile")
    h, w = sand.shape[:2]
    rgb = resize(paint("sand")[:, :, :3], w, h)
    rgb = tile_axis(tile_axis(rgb, 0), 1)
    # Keep the brush grain, with restrained contrast behind infantry.
    sand[:, :, :3] = SAND + (rgb - rgb.mean((0, 1))) * 0.53
    write("sand_tile", sand)


def stone_grade(rgb: np.ndarray) -> np.ndarray:
    red, green, blue = np.moveaxis(rgb, -1, 0)
    value = luminance(rgb)
    limestone = ramp(value, [24, 54, 86, 112, 157, 221], [
        (35, 31, 44), (62, 53, 75), (105, 93, 113),
        (153, 131, 134), (216, 175, 139), (255, 224, 171),
    ])
    # Sage near the spring and teal in the water keep their own material colours.
    green_mask = smoothstep(8, 35, green - red)
    greens = ramp(value, [30, 70, 125, 193], [
        (26, 43, 34), (55, 78, 54), (119, 136, 77), (203, 198, 114),
    ])
    limestone = blend(limestone, greens, green_mask)
    water_mask = smoothstep(12, 55, np.minimum(green, blue) - red)
    water = rgb * np.array([0.9, 0.84, 0.88]) + np.array([8, 9, 12])
    limestone = blend(limestone, water, water_mask)
    # The thin contact skirt in Carbon was baked to the original orange sand.
    skirt = np.exp(-np.sum((rgb - np.array([212, 124, 44])) ** 2, axis=-1) / 460)
    return blend(limestone, SAND, skirt * 0.92)


def alpha_bounds(sprite: np.ndarray, threshold: int = 180) -> tuple[int, int, int, int]:
    rows, columns = np.nonzero(sprite[:, :, 3] >= threshold)
    return columns.min(), rows.min(), columns.max() + 1, rows.max() + 1


def fit_asset(source: np.ndarray, base: np.ndarray, base_alpha: int = 180) -> np.ndarray:
    x0, y0, x1, y1 = alpha_bounds(base, base_alpha)
    sl, st, sr, sb = alpha_bounds(source)
    dest = np.zeros_like(base)
    dest[y0:y1, x0:x1] = resize(source[st:sb, sl:sr], x1 - x0, y1 - y0)
    return dest


def repaint_piece(key: str, source: np.ndarray, *, mirrored: bool = False) -> None:
    base = original(key)
    if mirrored:
        base = np.ascontiguousarray(base[:, ::-1])
    src = fit_asset(source, base)
    old = base[:, :, :3]
    underpainting = stone_grade(old)
    src_rgb = src[:, :, :3]
    support = smoothstep(110, 235, src[:, :, 3])
    # Carbon supplies the final alpha, so paint can never expand the map footprint.
    shaded = blend(underpainting, src_rgb, support)
    if key == "cliff_oasis" or key.startswith("rock_"):
        shadow = 1.0 - smoothstep(37, 102, luminance(old))
        shadow *= old[:, :, 0] > old[:, :, 1] - 3
        shaded *= 1.0 - shadow[:, :, None] * np.array([0.23, 0.21, 0.13])
    if key == "orichalcum_outcrop":
        # Keep the amber concentrated on the crystals and the surrounding stone cool.
        amber = smoothstep(26, 112, src_rgb[:, :, 0] - src_rgb[:, :, 2])
        amber *= smoothstep(185, 232, src_rgb[:, :, 0]) * support
        shaded = blend(shaded, src_rgb * np.array([1.09, 1.02, 0.72]), amber * 0.65)
    if key == "road_strip":
        shaded = tile_axis(shaded, 1)
    base[:, :, :3] = shaded
    # Godot still mirrors this sprite at draw time, exactly as it does in Carbon.
    write(key + "_mirrored" if mirrored else key, base[:, ::-1] if mirrored else base)


def cells(atlas: np.ndarray, columns: int, rows: int):
    h, w = atlas.shape[:2]
    for y in range(rows):
        for x in range(columns):
            yield atlas[y * h // rows:(y + 1) * h // rows, x * w // columns:(x + 1) * w // columns]


def repaint_dunes() -> None:
    for suffix, source in zip("abc", cells(paint("dunes"), 3, 1)):
        key = f"dune_cluster_{suffix}"
        dune = original(key)
        fitted = fit_asset(source, dune, base_alpha=5)
        value = luminance(fitted[:, :, :3])
        opaque = fitted[:, :, 3] > 210
        relief = (value - np.median(value[opaque])) * smoothstep(110, 235, fitted[:, :, 3])
        original_relief = luminance(dune[:, :, :3]) - 128
        relative = relief * 0.74 + original_relief * 0.30
        # Carbon's dune shader expects signed colour deltas centred on 128.
        # Its live track texture can then flatten the new painted crests too.
        dune[:, :, :3] = 128 + relative[:, :, None] * np.array([1.10, 0.95, 0.67])
        write(key, dune)


def repaint_tank(key: str, rows: int) -> None:
    base = original(key)
    source = paint(key)
    for cell, sample in zip(cells(base, 8, rows), cells(source, 8, rows)):
        fitted = fit_asset(sample, cell)
        support = smoothstep(130, 238, fitted[:, :, 3])
        # Carbon's sheet still defines every silhouette and mount point.
        cell[:, :, :3] = blend(cell[:, :, :3], fitted[:, :, :3], support * 0.66)
    write(key, base)


def unit_palette(source: np.ndarray, faction: str) -> list[tuple[int, int, int]]:
    rgb = source[:, :, :3]
    red, green, blue = np.moveaxis(rgb, -1, 0)
    chroma = (red - green) if faction == "red" else (blue - red)
    opaque = (source[:, :, 3] > 235) & (chroma > 33)
    colors = rgb[opaque]
    values = luminance(colors)
    bins = np.percentile(values, [15, 42, 67, 86])
    sampled = [np.median(colors[np.argsort(np.abs(values - center))[:120]], axis=0) for center in bins]
    if faction == "red":
        sampled = [color * np.array([1.04, 0.77, 1.03]) + np.array([7, 1, 8]) for color in sampled]
    return [tuple(int(channel) for channel in color) for color in sampled]


def repaint_infantry(key: str) -> None:
    base = original(key)
    source = paint(key)
    rgb = base[:, :, :3]
    red, green, blue = np.moveaxis(rgb, -1, 0)
    faction = key.split("_")[0]
    value = luminance(rgb)
    palette = unit_palette(source, faction)
    if faction == "red":
        chroma = red - green
        metal = ramp(value, [14, 49, 89, 149, 228], [
            (21, 21, 31), (44, 38, 56), (86, 76, 99), (143, 128, 145), (238, 218, 184),
        ])
        armor = ramp(value, [39, 77, 114, 164], palette)
        grade = blend(metal, armor, smoothstep(15, 53, chroma))
    else:
        chroma = blue - red
        cloth = ramp(value, [15, 65, 114, 174, 241], [
            (17, 24, 38), (62, 50, 64), (113, 89, 85), (191, 151, 120), (255, 236, 193),
        ])
        armor = ramp(value, [37, 85, 131, 198], palette)
        grade = blend(cloth, armor, smoothstep(8, 38, chroma))
    base[:, :, :3] = blend(rgb, grade, 0.83)
    # The generated sheets may wander between poses. Only apply their paint
    # variation inside corresponding, opaque silhouette areas.
    for cell, sample in zip(cells(base, 8, 4), cells(source, 8, 4)):
        fitted = fit_asset(sample, cell)
        value = luminance(fitted[:, :, :3])
        brush = value - cv2.GaussianBlur(value, (0, 0), 1.2)
        solid = (cell[:, :, 3] > 235) & (fitted[:, :, 3] > 235)
        solid = cv2.erode(solid.astype(np.uint8), np.ones((3, 3), np.uint8))
        cell[:, :, :3] += np.clip(brush, -14, 14)[:, :, None] * solid[:, :, None] * 0.20
    write(key, base)


def repaint_portraits() -> None:
    key = "portrait_blue_commander"
    h, w = original(key).shape[:2]
    write(key, resize(paint("portrait_blue"), w, h))
    keys = ("blue_tank", "red_tank", "blue_squad", "red_squad", "red_commander", "orichalcum")
    for role, image in zip(keys, cells(paint("portraits"), 3, 2)):
        key = f"portrait_{role}"
        h, w = original(key).shape[:2]
        crop_y, crop_x = round(image.shape[0] * 0.05), round(image.shape[1] * 0.05)
        write(key, resize(image[crop_y:-crop_y, crop_x:-crop_x], w, h))


def proof() -> None:
    sand_tile()
    repaint_piece("cliff_oasis", paint("cliff"))
    repaint_piece("outpost_pad", paint("outpost"))
    repaint_infantry("red_soldier")
    repaint_tank("blue_tank_hull", 2)
    repaint_tank("blue_tank_turret", 1)


def full_map() -> None:
    rocks = ("rock_mesa", "rock_ridge", "rock_boulders", "rock_outcrop_low")
    for key, source in zip(rocks, cells(paint("rocks"), 2, 2)):
        repaint_piece(key, source)
    for key, source in zip(rocks[1:], cells(paint("mirrored_rocks"), 3, 1)):
        repaint_piece(key, source, mirrored=True)
    for key, source in zip(("road_strip", "plaza_oval"), cells(paint("paving"), 1, 2)):
        repaint_piece(key, source)
    for key, source in zip(("scrub_large", "scrub_small"), cells(paint("scrub"), 2, 1)):
        repaint_piece(key, source)
    repaint_piece("orichalcum_outcrop", paint("orichalcum"))
    repaint_dunes()
    for key in ("blue_soldier", "blue_commander", "red_commander"):
        repaint_infantry(key)
    repaint_tank("red_tank_hull", 2)
    repaint_tank("red_tank_turret", 1)
    repaint_portraits()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proof", action="store_true", help="Only build the northeast proof set.")
    args = parser.parse_args()
    proof()
    if not args.proof:
        full_map()
