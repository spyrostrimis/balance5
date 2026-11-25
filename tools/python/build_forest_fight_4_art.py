"""Pack ImageGen plates and Commander poses for the isometric forest study."""

from math import cos, pi, sin
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "assets/source_inputs/forest_fight_4"
OUTPUT = ROOT / "assets/textures/forest_fight_4"
PLATE_SCALE = 0.825
CELL = 304
BOOT = (152, 284)
# Map original pixels into the larger paintings. Registered by matching
# painted landmarks in both images before fitting the in-game walk.
EXTENSIONS = {
    "forest": (0.705757, 0.705572, -0.708, 316.680),
    "cave": (0.752034, 0.752670, 176.323, -0.864),
}


def smoothstep(start, end, value):
    weight = np.clip((value - start) / (end - start), 0, 1)
    return weight * weight * (3 - 2 * weight)


def plate(name, padding, fog_color, fog_distance, origin):
    source = Image.open(INPUT / f"{name}.png").convert("RGB")
    scale = tuple(round(side * PLATE_SCALE) for side in source.size)
    rgb = np.asarray(source.resize(scale, Image.Resampling.LANCZOS))
    left, top, right, bottom = padding
    y, x = np.ogrid[-top:scale[1] + bottom, -left:scale[0] + right]
    dx = np.maximum(0, np.maximum(-x, x - scale[0]))
    dy = np.maximum(0, np.maximum(-y, y - scale[1]))
    edge_distance = np.hypot(dx, dy)
    u = np.clip(x, 0, scale[0] - 1) + np.where(x < 0, dx, -dx)
    v = np.clip(y, 0, scale[1] - 1) + np.where(y < 0, dy, -dy)
    rgb = rgb[v, u]
    soft = np.asarray(Image.fromarray(rgb).filter(ImageFilter.GaussianBlur(22)))
    fringe = smoothstep(0, 58, edge_distance)[..., None]
    rgb = rgb * (1 - fringe) + soft * fringe
    fog = smoothstep(0, fog_distance, edge_distance)[..., None]
    rgb = rgb * (1 - fog) + fog * fog_color
    extension = Image.open(INPUT / f"{name}-extension.png").convert("RGB")
    sx, sy, ox, oy = EXTENSIONS[name]
    sx, sy = sx / PLATE_SCALE, sy / PLATE_SCALE
    extra = extension.transform(
        (rgb.shape[1], rgb.shape[0]), Image.Transform.AFFINE,
        (sx, 0, ox - left * sx, 0, sy, oy - top * sy), Image.Resampling.BICUBIC,
        fillcolor=fog_color,
    )
    ax, ay = x * sx + ox, y * sy + oy
    coverage = np.minimum(np.minimum(ax, extension.width - ax),
                          np.minimum(ay, extension.height - ay))
    interior = np.minimum(np.minimum(x, scale[0] - x), np.minimum(y, scale[1] - y))
    extension_weight = (smoothstep(0, 42, coverage) * (1 - smoothstep(0, 28, interior)))[..., None]
    rgb = np.clip(rgb * (1 - extension_weight) + np.asarray(extra) * extension_weight, 0, 255).astype(np.uint8)
    if name == "cave":
        world_x, world_y = x + origin[0], y + origin[1]
        # Cover the hillside on a slant, leaving the forest-side foot of the lip in place.
        seam = 1224 + (world_y - 183) * 0.67
        alpha = 255 * smoothstep(seam - 38, seam + 54, world_x)
        alpha *= 1 - smoothstep(265, 515, world_y) * (1 - smoothstep(1510, 1720, world_x))
        rgb = np.dstack((rgb, alpha.astype(np.uint8)))
    Image.fromarray(rgb).save(OUTPUT / f"{name}.webp", quality=94, method=6)
    return source


def cutout(source, name, bounds, silhouette):
    x, y, *_ = bounds
    crop = source.crop(bounds).convert("RGBA")
    mask = Image.new("L", crop.size)
    ImageDraw.Draw(mask).polygon([(sx - x, sy - y) for sx, sy in silhouette], fill=255)
    crop.putalpha(mask.filter(ImageFilter.GaussianBlur(1.25)))
    crop.save(OUTPUT / f"{name}.png")


def paint_world():
    forest = plate("forest", (350, 430, 820, 360), (31, 55, 73), 420, (0, 0))
    cave = plate("cave", (320, 410, 420, 435), (25, 24, 36), 235, (1140, -421))
    cutout(forest, "cave_lip", (1303, 39, 1588, 249), [
        (1308, 208), (1319, 145), (1345, 92), (1395, 50), (1457, 43),
        (1508, 49), (1561, 68), (1584, 123), (1581, 176), (1560, 211),
        (1534, 232), (1521, 243), (1524, 206), (1516, 178), (1503, 153),
        (1481, 139), (1460, 116), (1435, 116), (1414, 125), (1392, 142),
        (1371, 162), (1360, 190), (1343, 214), (1325, 236), (1307, 244),
    ])
    cutout(forest, "fence", (1079, 438, 1213, 573), [
        (1082, 455), (1092, 442), (1108, 450), (1108, 478), (1129, 489),
        (1131, 475), (1144, 471), (1155, 480), (1155, 497), (1171, 505),
        (1172, 497), (1184, 489), (1195, 496), (1197, 518), (1209, 526),
        (1205, 542), (1195, 535), (1194, 563), (1180, 569), (1170, 565),
        (1168, 545), (1104, 510), (1097, 517), (1084, 507),
    ])
    cutout(forest, "tree", (455, 96, 665, 367), [
        (515, 100), (621, 100), (623, 162), (618, 220), (627, 272), (649, 305),
        (659, 338), (637, 332), (620, 317), (605, 324), (590, 359), (569, 355),
        (554, 363), (561, 332), (531, 343), (497, 359), (470, 361), (460, 350),
        (481, 312), (522, 283), (537, 256), (540, 213), (537, 167),
    ])
    cutout(cave, "cave_rock", (943, 521, 1221, 720), [
        (948, 669), (971, 636), (998, 623), (1009, 600), (1027, 574), (1053, 552),
        (1101, 532), (1142, 525), (1173, 539), (1190, 557), (1204, 604),
        (1210, 642), (1205, 671), (1185, 704), (1155, 712), (1122, 706),
        (1062, 716), (1025, 707), (988, 698), (949, 692),
    ])


def standing(source, boot_x):
    alpha = np.asarray(source.getchannel("A")).astype(np.float32)
    outline = Image.fromarray((alpha > 180).astype(np.uint8) * 255).getbbox()
    left, top, right, bottom = outline
    # Drop the low-alpha generated backdrop, retain the painted antialiased edge.
    source.putalpha(Image.fromarray((smoothstep(22, 218, alpha) * 255).astype(np.uint8)))
    ratio = 260 / (bottom - top)
    crop = source.crop((left - 3, top - 3, right + 3, bottom + 3))
    crop = crop.resize(tuple(round(side * ratio) for side in crop.size), Image.Resampling.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL))
    cell.paste(crop, (round(BOOT[0] - (boot_x - left + 3) * ratio), BOOT[1] - round((bottom - top + 3) * ratio)))
    return cell


def step_pose(pose, phase, leg_split):
    def map_point(x, y):
        lower = smoothstep(158, 279, y)
        side = 2 * smoothstep(leg_split - 19, leg_split + 19, x) - 1
        return x - 19 * sin(phase) * lower * side, y + 14 * max(0, cos(phase) * side) * lower

    mesh = []
    edges = [*range(0, CELL, 8), CELL]
    for left, right in zip(edges, edges[1:]):
        for top, bottom in zip(edges, edges[1:]):
            # Pillow samples quadrilaterals in top-left, bottom-left, bottom-right, top-right order.
            points = (map_point(left, top), map_point(left, bottom),
                      map_point(right, bottom), map_point(right, top))
            mesh.append(((left, top, right, bottom), tuple(axis for point in points for axis in point)))
    return pose.transform(pose.size, Image.Transform.MESH, mesh, Image.Resampling.BICUBIC)


def pack_commander():
    sheet = Image.open(INPUT / "commander.png").convert("RGBA")
    width = sheet.width // 4
    poses = [sheet.crop((width * i, 0, width * (i + 1), sheet.height)) for i in range(4)]
    poses.append(Image.open(INPUT / "south.png").convert("RGBA"))
    atlas = Image.new("RGBA", (CELL * 7, CELL * 5))
    for row, (source, boot_x, split) in enumerate(zip(poses, [282, 291, 294, 298, 497], [150, 149, 154, 158, 153])):
        pose = standing(source, boot_x)
        atlas.paste(pose, (0, row * CELL))
        for frame in range(6):
            atlas.paste(step_pose(pose, frame * pi / 3, split), ((frame + 1) * CELL, row * CELL))
    atlas.save(OUTPUT / "commander.webp", lossless=True, method=6)


def cut_rifle():
    old = Image.open(ROOT / "assets/textures/forest_fight_2/commander_hd_combat.png").convert("RGB")
    cutout(old, "rifle", (193, 82, 347, 136), [
        (194, 95), (221, 94), (232, 92), (239, 84), (259, 84), (263, 92),
        (283, 92), (296, 91), (314, 88), (319, 95), (345, 97), (345, 103),
        (317, 104), (310, 107), (299, 108), (292, 104), (281, 103), (274, 108),
        (273, 119), (267, 131), (255, 132), (250, 119), (248, 112), (232, 112),
        (222, 109), (204, 112), (195, 112),
    ])


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    paint_world()
    pack_commander()
    cut_rifle()
