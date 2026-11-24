"""Pack Approach 3's source plates at the 765-high view density."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_inputs/rpg_2d/approach3"
OUTPUT = ROOT / "assets/textures/rpg_2d/approach3"
CELL = (160, 168)
BOOT = (80, 160)
PLATE_SIZE = (1360, 3044)
DENSITY = 765 / 540


def cutout(image: Image.Image, height: int, threshold: int) -> Image.Image:
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= threshold else 0).getbbox()
    image = image.crop(bounds)
    width = round(image.width * height / image.height)
    image = image.resize((width, height), Image.Resampling.LANCZOS)
    image.putalpha(image.getchannel("A").point(lambda value: 255 if value >= threshold else 0))
    return image


def read_poses(filename: str, heights: tuple[int, ...]) -> list[Image.Image]:
    with Image.open(SOURCE / filename) as source:
        width, height = source.width // 3, source.height // 2
        return [
            cutout(
                source.crop((x * width, y * height, (x + 1) * width, (y + 1) * height)),
                heights[y * 3 + x],
                140,
            )
            for y in range(2)
            for x in range(3)
        ]


def switch_leg(pose: Image.Image, bounds: tuple[int, int, int, int]) -> Image.Image:
    """Mirror the leg silhouette only and retain the handed gear and braid."""
    result = pose.copy()
    result.paste(ImageOps.mirror(pose.crop(bounds)), bounds[:2])
    return result


def pack_atlas(frames: list[list[tuple[Image.Image, int, int]]], scale: float) -> Image.Image:
    atlas = Image.new("RGBA", (CELL[0] * 5, CELL[1] * 4))
    for row, poses in enumerate(frames):
        for column, (pose, boot_x, boot_y) in enumerate(poses):
            left = BOOT[0] - round(scale * boot_x)
            top = BOOT[1] - round(scale * boot_y)
            if scale != 1.0:
                pose = pose.resize(
                    (round(pose.width * scale), round(pose.height * scale)),
                    Image.Resampling.LANCZOS,
                )
                pose.putalpha(pose.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
            assert left >= 0 and top >= 0
            assert left + pose.width <= CELL[0] and top + pose.height <= CELL[1]
            atlas.paste(pose, (column * CELL[0] + left, row * CELL[1] + top))
    return atlas


def commander() -> None:
    front = cutout(
        Image.open(ROOT / "assets/textures/units/blue_commander_rpg.png").convert("RGBA"),
        149,
        128,
    )
    front.save(OUTPUT / "commander_front_idle.png")
    back, side, aim, back_walk, side_walk, aim_walk = read_poses(
        "commander_views.png", (149, 149, 149, 146, 148, 144)
    )
    front_a, front_b, back_other, side_other, aim_other, recoil = read_poses(
        "commander_motion.png", (149, 147, 149, 146, 145, 147)
    )
    front_pass_right, back_pass_left, side_pass_right, front_pass_left, back_pass_right, side_pass_left = read_poses(
        "commander_passing.png", (148, 148, 148, 149, 149, 149)
    )
    back_other = switch_leg(back_other, (26, 94, 67, back_other.height))
    frames = [
        [
            (front, 50, 149),
            (front_a, 43, 149),
            (front_pass_right, 48, 148),
            (front_b, 43, 147),
            (front_pass_left, 52, 149),
        ],
        [
            (back, 52, 149),
            (back_walk, 51, 142),
            (back_pass_right, 54, 149),
            (back_other, 51, 149),
            (back_pass_left, 52, 148),
        ],
        [
            (side, 48, 149),
            (side_walk, 52, 148),
            (side_pass_right, 47, 148),
            (side_other, 54, 146),
            (side_pass_left, 47, 149),
        ],
        [(aim, 46, 149), (aim_walk, 59, 144), (aim_other, 54, 145), (recoil, 50, 147)],
    ]
    pack_atlas(frames, 1.0).save(OUTPUT / "commander_765.png")
    pack_atlas(frames, 720 / 765).save(OUTPUT / "commander_720.png")


def masks() -> dict[str, list[tuple[int, int]]]:
    """Traced silhouettes in the original unresized canyon painting."""
    return {
        "lookout_boulder": [
            (477, 644), (478, 626), (488, 614), (503, 605), (519, 600),
            (531, 603), (544, 609), (551, 616), (548, 628), (540, 638),
            (536, 650), (528, 653), (517, 653), (509, 651), (497, 652),
            (491, 647), (484, 648),
        ],
        "bend_rocks": [
            (277, 1133), (283, 1118), (290, 1113), (294, 1101), (296, 1090),
            (304, 1086), (317, 1083), (330, 1086), (339, 1093), (342, 1102),
            (344, 1109), (338, 1118), (328, 1123), (312, 1123), (307, 1133),
            (292, 1138), (289, 1144), (280, 1144),
        ],
    }


def canyon() -> None:
    source = Image.open(SOURCE / "canyon_plate.png").convert("RGB")
    diffuse = source.resize(PLATE_SIZE, Image.Resampling.LANCZOS)
    diffuse = diffuse.filter(ImageFilter.UnsharpMask(radius=0.9, percent=80, threshold=2))
    diffuse.save(OUTPUT / "canyon.png")

    # Restrict surface lighting to shallow relief. Broad shade is already painted.
    luma = diffuse.convert("L")
    broad = np.asarray(luma.filter(ImageFilter.GaussianBlur(7)), dtype=np.float32)
    relief = np.asarray(luma.filter(ImageFilter.GaussianBlur(1.6)), dtype=np.float32) - broad
    dy, dx = np.gradient(relief)
    normal = np.zeros((diffuse.height, diffuse.width, 3), dtype=np.uint8)
    normal[..., 0] = 128 - np.clip(dx * 22, -45, 45)
    normal[..., 1] = 128 + np.clip(dy * 22, -45, 45)
    normal[..., 2] = 255
    relief_map = Image.fromarray(normal)
    relief_map.save(OUTPUT / "canyon_n.png")

    # The cuts share pixels with the ground so their painted foot shadows still line up.
    for name, vertices in masks().items():
        polygon = [
            (round(x * diffuse.width / source.width), round(y * diffuse.height / source.height))
            for x, y in vertices
        ]
        mask = Image.new("L", PLATE_SIZE)
        ImageDraw.Draw(mask).polygon(polygon, fill=255)
        bounds = mask.getbbox()
        prop = diffuse.crop(bounds)
        prop.putalpha(mask.crop(bounds))
        prop.save(OUTPUT / f"{name}.png")
        relief_map.crop(bounds).save(OUTPUT / f"{name}_n.png")
        x = bounds[0] / DENSITY
        y = -182 + bounds[1] / DENSITY
        print(f"{name} top left ({x:.4f}, {y:.4f}), size {prop.size}")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    commander()
    canyon()
