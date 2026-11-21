"""Prepare the 2D follow study from the two existing Pixel Canyon paintings."""
from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/textures/pixel_canyon"
OUTPUT = SOURCE / "follow"
NEAREST = Image.Resampling.NEAREST

# Silhouettes follow the painted contours. Each anchor marks the object's contact
# with the road-side shelf and is stored with the atlas rectangle.
CUTOUTS = {
    "lower_ruin": ("road", (177, 368), [
        (0, 112), (51, 98), (84, 82), (119, 82), (161, 91), (193, 102),
        (216, 120), (242, 120), (245, 210), (264, 229), (282, 237), (284, 261),
        (253, 288), (245, 325), (225, 362), (204, 388), (171, 408), (151, 391),
        (136, 358), (102, 327), (56, 306), (0, 298),
    ]),
    "upper_ruin": ("road", (296, 200), [
        (120, 91), (133, 67), (158, 52), (188, 38), (216, 37), (232, 22),
        (260, 24), (295, 13), (332, 8), (345, 1), (364, 10), (368, 52), (393, 65),
        (411, 61), (426, 76), (422, 113), (435, 130), (443, 157), (454, 174),
        (420, 195), (387, 173), (359, 185), (324, 219), (283, 216),
        (249, 172), (217, 151), (199, 143), (148, 124),
    ]),
    "right_ruin": ("road", (790, 292), [
        (643, 112), (652, 99), (674, 87), (697, 96), (712, 111), (729, 89),
        (729, 49), (740, 35), (758, 40), (779, 68), (793, 94), (819, 84),
        (818, 66), (827, 43), (846, 23), (871, 13), (896, 19), (916, 33),
        (930, 43), (938, 63), (936, 102), (955, 128), (952, 168), (955, 193),
        (917, 205), (885, 229), (849, 258), (820, 297), (777, 317),
        (739, 302), (721, 301), (698, 283), (674, 262), (670, 218), (642, 206),
        (613, 187), (615, 158), (629, 133),
    ]),
    "sunlit_ledge": ("road", (91, 488), [
        (12, 298), (24, 294), (45, 292), (65, 299), (83, 298), (97, 302), (118, 307),
        (133, 315), (148, 326), (150, 354), (164, 377), (176, 393),
        (184, 422), (182, 456), (164, 476), (152, 500), (124, 528), (91, 538),
        (63, 535), (36, 534), (20, 524), (9, 509), (2, 487), (5, 471), (0, 446),
        (3, 429), (1, 412), (10, 396), (8, 373), (15, 358), (6, 340), (10, 330),
    ]),
    "ochre_rocks": ("road", (299, 367), [
        (233, 343), (247, 321), (260, 313), (277, 307), (294, 295), (312, 297),
        (327, 309), (346, 316), (363, 332), (359, 347), (351, 357),
        (332, 372), (305, 378), (283, 368), (267, 368), (243, 359),
    ]),
    "bend_wall": ("overlook", (843, 403), [
        (960, 14), (928, 18), (910, 31), (894, 41), (887, 67), (903, 80),
        (911, 90), (890, 111), (877, 115), (867, 139), (847, 159), (815, 176),
        (794, 193), (786, 210), (789, 232), (778, 246), (764, 253), (751, 278),
        (758, 291), (742, 302), (727, 326), (721, 346), (730, 364), (715, 388),
        (728, 414), (743, 435), (776, 456), (816, 457), (851, 476), (899, 483),
        (929, 498), (960, 502),
    ]),
    "terrace": ("overlook", (297, 318), [
        (138, 222), (145, 209), (165, 198), (198, 189), (226, 186), (246, 193),
        (247, 165), (252, 143), (266, 121), (284, 112), (304, 113), (321, 123),
        (334, 143), (338, 153), (354, 157), (364, 175), (367, 197), (383, 200),
        (395, 223), (383, 250), (377, 267), (362, 280), (341, 303), (317, 316),
        (294, 335), (264, 355), (227, 357), (202, 347), (174, 332), (153, 305),
        (144, 275), (131, 252),
    ]),
    "overlook_ledge": ("overlook", (800, 498), [
        (704, 487), (713, 461), (738, 441), (758, 431), (771, 412), (799, 397),
        (830, 399), (861, 387), (889, 375), (910, 380), (921, 397), (925, 427),
        (944, 442), (953, 459), (958, 486), (949, 504), (932, 523), (907, 533),
        (871, 531), (848, 535), (823, 529), (787, 536), (753, 531), (720, 523), (703, 514),
    ]),
}

HOLES = {
    "terrace": [[(268, 188), (270, 158), (278, 141), (292, 136), (302, 141),
                 (307, 156), (307, 191), (293, 197), (284, 194), (275, 198)]],
    "right_ruin": [[(851, 114), (852, 76), (853, 62), (863, 49), (875, 43),
                    (889, 43), (898, 55), (902, 73), (899, 99), (883, 111)]],
    "lower_ruin": [[(112, 215), (115, 187), (125, 166), (140, 150), (154, 149),
                    (168, 158), (176, 178), (179, 197), (156, 204), (147, 211),
                    (135, 215), (134, 243), (116, 250)]],
}


def extract(image, outline, holes=()):
    mask = Image.new("L", image.size)
    draw = ImageDraw.Draw(mask)
    draw.polygon(outline, fill=255)
    for hole in holes:
        draw.polygon(hole, fill=0)
    bounds = mask.getbbox()
    sprite = image.crop(bounds).convert("RGBA")
    sprite.putalpha(mask.crop(bounds))
    return sprite, bounds


def cutouts(paintings):
    # Pack with transparent padding to keep neighbouring regions separate.
    atlas = Image.new("RGBA", (1024, 1024))
    x, y, row_height = 2, 2, 0
    for name, (source, anchor, outline) in CUTOUTS.items():
        plate = paintings[source]
        if name == "bend_wall":
            # The source painting ends partway through this wall. Continue the
            # rock courses outward so the edge of the source stays buried.
            plate = Image.new("RGB", (1080, 540))
            plate.paste(paintings[source])
            wing = paintings[source].crop((840, 0, 960, 540))
            plate.paste(wing.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (960, 0))
            outline = [(978, 16), *outline, (992, 494), (1044, 471), (1057, 435),
                       (1069, 415), (1079, 376), (1079, 128), (1051, 107),
                       (1043, 64), (1011, 54), (1003, 32)]
        sprite, bounds = extract(plate, outline, HOLES.get(name, ()))
        if x + sprite.width + 2 > atlas.width:
            x, y, row_height = 2, y + row_height + 4, 0
        assert y + sprite.height + 2 <= atlas.height
        atlas.paste(sprite, (x, y))
        pivot = (anchor[0] - bounds[0], anchor[1] - bounds[1])
        print(f"{name}: Rect2({x}, {y}, {sprite.width}, {sprite.height}), Vector2{pivot}")
        x += sprite.width + 4
        row_height = max(row_height, sprite.height)
    atlas.save(OUTPUT / "props.png")


def seam(cost):
    """Find the low-contrast cut down an overlapping pair of painted patches."""
    height, width = cost.shape
    totals = cost[0].copy()
    parents = np.zeros((height, width), dtype=int)
    columns = np.arange(width)
    for row in range(1, height):
        neighbours = np.stack((np.r_[np.inf, totals[:-1]], totals, np.r_[totals[1:], np.inf]))
        moves = np.argmin(neighbours, axis=0)
        parents[row] = columns + moves - 1
        totals = cost[row] + neighbours[moves, columns]
    path = np.zeros(height, dtype=int)
    path[-1] = np.argmin(totals)
    for row in range(height - 1, 0, -1):
        path[row - 1] = parents[row, path[row]]
    return columns[None, :] < path[:, None]


def wrap_tile(surface, overlap):
    repeated = surface[:, -overlap:]
    first = surface[:, :overlap]
    mask = seam(np.square(first - repeated).sum(axis=2))
    first[mask] = repeated[mask]
    return surface[:, :-overlap]


def paving(image, approach):
    # Deskew several clear road samples to the texture's flat ground coordinates.
    patches = []
    for plate, box, scale in [(image, (441, 308, 594, 401), 1.23),
                              (image, (417, 382, 629, 467), 1.00),
                              (approach, (440, 246, 530, 338), 1.18)]:
        patch = plate.crop(box)
        patch = patch.resize((round(patch.width * scale), round(patch.height * scale / .59)), NEAREST)
        patches.append(np.asarray(patch, dtype=np.float32))
    randomizer = random.Random(331)
    size, overlap, count = 84, 16, 8
    step = size - overlap
    width = step * count + overlap
    canvas = np.zeros((width, width, 3), dtype=np.float32)
    for y in range(0, step * count, step):
        for x in range(0, step * count, step):
            target = canvas[y:y + size, x:x + size]
            best_score = float("inf")
            for _ in range(32):
                source = randomizer.choice(patches)
                left = randomizer.randrange(0, source.shape[1] - size + 1)
                top = randomizer.randrange(0, source.shape[0] - size + 1)
                patch = source[top:top + size, left:left + size]
                difference = np.square(patch - target).sum(axis=2)
                score = (difference[:, :overlap].mean() if x else 0) + (difference[:overlap].mean() if y else 0)
                if score < best_score:
                    best_score, selected, cost = score, patch, difference
            keep = np.zeros((size, size), dtype=bool)
            if x:
                keep[:, :overlap] |= seam(cost[:, :overlap])
            if y:
                keep[:overlap, :] |= seam(cost[:overlap, :].T).T
            target[~keep] = selected[~keep]
    tile = wrap_tile(wrap_tile(canvas, overlap).transpose(1, 0, 2), overlap).transpose(1, 0, 2)
    Image.fromarray(tile.astype(np.uint8)).save(OUTPUT / "paving.png")


def verge(approach):
    # Paint a repeatable soil plate in the source palette, with clustered chips
    # and broken strata scales that still read from the low camera.
    size = 256
    randomizer = random.Random(856)
    noise = randomizer.randbytes(size * size)
    grain = Image.frombytes("L", (size, size), noise)
    coarse = Image.frombytes("L", (32, 32), randomizer.randbytes(32 * 32))
    coarse = coarse.resize((size, size), NEAREST)
    texture = Image.blend(grain, coarse, .68)
    tones = np.asarray(texture, dtype=float)
    shade = np.array(approach.getpixel((361, 446)), dtype=float)
    sun = np.array(approach.getpixel((447, 443)), dtype=float)
    low = shade * .35 + np.array((79, 52, 46)) * .65
    high = sun * .35 + np.array((201, 121, 78)) * .65
    base = low + (high - low) * (tones[:, :, None] / 255.0)
    image = Image.fromarray(base.astype(np.uint8))
    draw = ImageDraw.Draw(image)
    for index in range(850):
        x, y = randomizer.randrange(size), randomizer.randrange(size)
        u = randomizer.randint(1, 8)
        v = randomizer.randint(1, 5)
        color = tuple(np.clip(high * randomizer.uniform(.70, 1.07), 0, 255).astype(np.uint8))
        shade = tuple(np.clip(low * randomizer.uniform(.84, 1.19), 0, 255).astype(np.uint8))
        for dx in (0, -size) if x + u >= size else (0,):
            for dy in (0, -size) if y + v + 1 >= size else (0,):
                left, top = x + dx, y + dy
                draw.polygon([(left, top + 2), (left + u, top + 1), (left + u, top + v),
                              (left + 2, top + v + 1)], fill=shade)
                draw.polygon([(left, top + 1), (left + u // 2, top),
                              (left + u, top + 1), (left + u - 1, top + v - 1),
                              (left + 1, top + v)], fill=color)
    image.save(OUTPUT / "verge.png")


def backdrop(overlook, approach):
    # Use a single horizon. Only the far skyline and distant layers belong here.
    background = Image.new("RGB", (1152, 540), "#957b91")
    draw = ImageDraw.Draw(background)
    draw.polygon([(0, 239), (216, 260), (420, 282), (610, 258), (1152, 271),
                  (1152, 540), (0, 540)], fill="#947788")
    for index, color in enumerate(("#8b687d", "#9b7184", "#ae7d87", "#85677e", "#785a72")):
        y = 236 + index * 61
        draw.polygon([(0, y), (82, y - 23), (169, y - 14), (239, y + 17), (365, y - 7),
                      (504, y + 17), (674, y - 34), (951, y + 12), (1152, y - 36),
                      (1152, y + 135), (0, y + 135)], fill=color)
    # Paint over the base with muted vertical formations sampled below the skyline.
    randomizer = random.Random(159)
    for y in (66, 135, 208, 285, 360, 439):
        for x in range(-36, 1110, 94):
            sx = randomizer.randint(3, 62)
            sy = randomizer.randint(100, 173)
            chip = overlook.crop((sx, sy, sx + 66, sy + 90)).resize((128, 135), NEAREST)
            shade = Image.new("RGB", chip.size, "#9b829c")
            chip = Image.blend(chip, shade, .52 + y / 2600)
            mask = Image.new("L", chip.size)
            ImageDraw.Draw(mask).polygon([(0, 34), (16, 20), (33, 18), (43, 9), (83, 5),
                                          (102, 22), (114, 24), (127, 41), (127, 135),
                                          (0, 135)], fill=255)
            background.paste(chip, (x, y + randomizer.randrange(-18, 20)), mask)
    skyline, _ = extract(overlook, [
        (0, 0), (548, 0), (538, 53), (534, 71), (519, 77), (498, 86),
        (473, 106), (451, 115), (404, 146), (370, 168), (352, 137),
        (334, 120), (314, 108), (283, 108), (264, 115), (248, 146),
        (239, 182), (187, 186), (155, 193), (133, 210), (123, 241), (117, 279),
        (91, 298), (77, 280), (68, 272), (60, 257), (40, 257), (22, 274), (0, 265),
    ])
    skyline = skyline.resize((875, 322), NEAREST)
    background.paste(skyline, (0, 0), skyline.getchannel("A").filter(ImageFilter.GaussianBlur(4)))
    right, _ = extract(approach, [
        (587, 0), (959, 0), (959, 132), (935, 104), (918, 46), (897, 22),
        (863, 19), (841, 38), (818, 82), (798, 91), (771, 64), (746, 36),
        (726, 39), (715, 102), (689, 100), (663, 100), (627, 116), (590, 108),
        (565, 91), (548, 58),
    ])
    right = right.resize((572, 215), NEAREST)
    background.paste(right, (580, 0), right.getchannel("A").filter(ImageFilter.GaussianBlur(3)))
    background.save(OUTPUT / "backdrop.png")


def main():
    OUTPUT.mkdir(exist_ok=True)
    paintings = {
        "road": Image.open(SOURCE / "road_to_the_arch.png").convert("RGB"),
        "overlook": Image.open(SOURCE / "arch_overlook.png").convert("RGB"),
    }
    cutouts(paintings)
    paving(paintings["overlook"], paintings["road"])
    verge(paintings["road"])
    backdrop(paintings["overlook"], paintings["road"])


if __name__ == "__main__":
    main()
