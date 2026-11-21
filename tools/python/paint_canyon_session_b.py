"""Paint Session B at one world pixel scale from the two Balance canyon references."""
from pathlib import Path
import math
import random

from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/textures/rpg_2d/session_b"
SIZE = (1584, 1408)
ROAD = [
    (480, 1500, 83), (489, 1245, 83), (513, 1086, 81), (541, 982, 77),
    (572, 913, 72), (611, 859, 69), (673, 809, 66), (769, 764, 67),
    (874, 733, 72), (975, 703, 78), (1067, 661, 94), (1168, 624, 103),
    (1248, 584, 98), (1362, 566, 67), (1412, 491, 56),
]
SHELF = [
    (-130, 997), (91, 1007), (152, 983), (239, 978), (312, 939), (390, 933),
    (421, 897), (458, 883), (468, 830), (519, 800), (550, 765), (613, 753),
    (659, 718), (693, 676), (706, 609), (739, 572), (765, 525), (829, 489),
    (908, 480), (941, 454), (1012, 451), (1080, 438), (1138, 455), (1203, 454),
    (1263, 481), (1316, 473), (1373, 459), (1416, 429), (1640, 393),
    (1710, 1460), (-130, 1460),
]
# These are foot contours. The height and thickness of each shelf are painted upward from them.
NEAR = [
    (733, 1470, 145), (692, 1332, 181), (679, 1268, 177), (661, 1232, 162),
    (668, 1173, 147), (656, 1123, 157), (675, 1087, 179), (679, 1036, 180),
    (708, 989, 197), (718, 945, 208), (748, 907, 214), (766, 884, 205),
    (807, 864, 179), (853, 849, 156), (894, 847, 137), (933, 837, 123),
    (984, 820, 105), (1040, 821, 95), (1086, 808, 91), (1140, 812, 94),
    (1201, 798, 129), (1266, 807, 159), (1320, 785, 200), (1418, 741, 235),
    (1490, 713, 225), (1660, 640, 203),
]
OUTER = [
    (-95, 1084, 166), (-6, 1058, 166), (51, 1081, 153), (105, 1079, 152),
    (171, 1095, 140), (193, 1075, 142), (225, 1102, 151), (277, 1110, 157),
    (310, 1143, 139), (311, 1174, 118), (350, 1222, 141), (337, 1276, 170),
    (375, 1373, 172), (380, 1480, 173),
]
DECK = [(750, 582), (779, 552), (849, 531), (922, 520), (983, 541),
        (1017, 582), (990, 615), (923, 644), (844, 658), (790, 652), (748, 625)]
STAIR = [(931, 638), (992, 611), (1034, 656), (971, 683)]
SANDSTONE = ("#593640", "#844340", "#a74d3d", "#bd633f", "#d9844c", "#ef9a5a", "#f8b575")
MASONRY = ("#725247", "#926754", "#ae7c5e", "#c99468", "#e3ae7a", "#f2c58d")
rng = random.Random(5347)
num_rng = np.random.default_rng(5347)


def rgb(color):
    return tuple(bytes.fromhex(color.lstrip("#"))) if isinstance(color, str) else color


def mix(a, b, weight):
    return tuple(round(x + (y - x) * weight) for x, y in zip(rgb(a), rgb(b)))


def tone(color, amount):
    return tuple(max(0, min(255, n + amount)) for n in rgb(color))


def lerp(a, b, t):
    return (round(a[0] + (b[0] - a[0]) * t), round(a[1] + (b[1] - a[1]) * t))


def add(point, dx, dy):
    return (point[0] + dx, point[1] + dy)


def flat(image, points, color):
    ImageDraw.Draw(image).polygon(points, fill=rgb(color))


# Restrict pixel grain to a few shades and favour short clusters over single white specks.
grain = num_rng.choice([-8, -4, 0, 0, 0, 3, 6], (SIZE[1] // 2, SIZE[0] // 2))
grain = grain.repeat(2, 0).repeat(2, 1)
grain += num_rng.choice([-4, 0, 0, 3], (SIZE[1], SIZE[0]))
plates = ROOT / "assets/textures/pixel_canyon"


def sandstone_grain():
    # Reuse only the tonal clusters of two small exposed rock-top swatches.
    # Geometry, outlines and lighting in this map come from the new drawing.
    with Image.open(plates / "road_to_the_arch.png") as source:
        first = source.crop((17, 297, 60, 314)).convert("L")
    with Image.open(plates / "arch_overlook.png") as source:
        second = source.crop((854, 392, 888, 409)).convert("L")
    samples = [np.asarray(sample, dtype=float) for sample in (first, second)]
    texture = np.zeros((SIZE[1], SIZE[0]), dtype=float)
    yy, xx = np.indices(texture.shape)
    for i, sample in enumerate(samples):
        texture += (sample[(yy + xx // (12 + i * 19)) % sample.shape[0],
                           (xx + yy // 4) % sample.shape[1]] - sample.mean()) * (.19 - i * .058)
    return texture


rock_grain = sandstone_grain()


def tint_surface(image, points, color, strength=1.0, stone=False):
    left = max(0, math.floor(min(p[0] for p in points)))
    right = min(SIZE[0], math.ceil(max(p[0] for p in points)) + 1)
    top = max(0, math.floor(min(p[1] for p in points)))
    bottom = min(SIZE[1], math.ceil(max(p[1] for p in points)) + 1)
    if left >= right or top >= bottom:
        return
    mask = Image.new("L", (right - left, bottom - top))
    ImageDraw.Draw(mask).polygon([add(point, -left, -top) for point in points], fill=255)
    texture = grain[top:bottom, left:right] * strength
    if stone:
        texture = texture + rock_grain[top:bottom, left:right]
    patch = np.asarray(rgb(color))[None, None, :] + texture[:, :, None]
    image.paste(Image.fromarray(np.clip(patch, 0, 255).astype(np.uint8)), (left, top), mask)


def polygon_mask(points):
    mask = Image.new("L", SIZE)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask


def chipped_quad(a, b, c, d):
    return [lerp(a, b, .08), lerp(a, b, .92), lerp(b, c, .19), lerp(b, c, .81),
            lerp(c, d, .10), lerp(c, d, .88), lerp(d, a, .20), lerp(d, a, .83)]


def horizontal_stone(image, top, shade, height=3):
    d = ImageDraw.Draw(image)
    side = [add(p, -1, height) for p in top]
    d.polygon(side, fill=tone(shade, -42))
    d.polygon(top, fill=rgb(shade))
    d.line([top[0], top[1], top[2]], fill=tone(shade, 27), width=2)
    d.line([top[4], top[5]], fill=tone(shade, -16), width=2)
    if rng.random() < .72:
        p = lerp(top[0], top[5], .45)
        q = lerp(top[1], top[4], .6)
        p = lerp(p, q, rng.uniform(.15, .55))
        d.line([p, add(p, rng.randint(2, 5), -1)], fill=tone(shade, rng.choice((12, 17, -13))))


def curve(points):
    """Smooth the hand-placed road anchors without altering its width or scale."""
    output = []
    for i, (a, b) in enumerate(zip(points, points[1:])):
        p, q = points[max(0, i - 1)], points[min(len(points) - 1, i + 2)]
        segments = max(2, math.ceil(math.dist(a[:2], b[:2]) / 9))
        for n in range(segments):
            t = n / segments
            values = [0.5 * ((2 * a[k]) + (b[k] - p[k]) * t
                      + (2 * p[k] - 5 * a[k] + 4 * b[k] - q[k]) * t*t
                      + (-p[k] + 3 * a[k] - 3 * b[k] + q[k]) * t*t*t) for k in range(3)]
            output.append(values)
    return output + [list(points[-1])]


def road_edges(path, extra=0):
    edges = [[], []]
    for i, (x, y, width) in enumerate(path):
        a = path[max(0, i - 1)]
        b = path[min(len(path) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        rx = -dy / length * (width + extra)
        ry = dx / length * (width + extra)
        edges[0].append((round(x + rx), round(y + ry)))
        edges[1].append((round(x - rx), round(y - ry)))
    return edges


def resample(points, interval):
    samples = [points[0]]
    carried = 0.0
    for p, q in zip(points, points[1:]):
        length = math.dist(p, q)
        if length == 0:
            continue
        travelled = interval - carried
        while travelled <= length:
            samples.append(lerp(p, q, travelled / length))
            travelled += interval
        carried = length - (travelled - interval)
    return samples


def pavement(color_flat, roughness=1):
    paving = Image.new("RGB", SIZE, rgb(color_flat))
    swatches = ("#9f7061", "#b48164", "#c78f6c", "#d99a6f", "#e8ad79",
                "#c59779", "#947875", "#baa18a", "#d9a781", "#b99178")
    y = -12
    while y < SIZE[1] + 10:
        step = rng.randrange(10, 15)
        x = -rng.randrange(6, 30)
        while x < SIZE[0]:
            width = rng.randrange(15, 29)
            height = step - rng.randrange(0, 3)
            lean = rng.randrange(-4, 5)
            cy = y + rng.randrange(-2, 3)
            shade = tone(rng.choice(swatches), rng.randrange(-7, 8) * roughness)
            points = [
                (x + rng.randint(2, 5), cy + rng.randint(0, 2)),
                (x + width // 2, cy - rng.randint(0, 2)),
                (x + width - rng.randint(4, 6), cy + rng.randint(-1, 2)),
                (x + width + lean // 2 - 2, cy + height // 2),
                (x + width + lean - 4, cy + height - rng.randint(1, 4)),
                (x + width // 2 + lean, cy + height - 1),
                (x + lean + 3, cy + height - rng.randint(1, 3)),
                (x, cy + height // 2),
            ]
            horizontal_stone(paving, points, shade, 2)
            x += width
        y += step
    return paving


def curb(image, edge, side):
    segments = resample(edge, 23)
    for i, (p, q) in enumerate(zip(segments, segments[1:])):
        if side < 0 and 940 < (p[0] + q[0]) / 2 < 1022:
            continue  # Stair mouth.
        if i in (19, 39):
            continue  # Two worn gaps in the old curb.
        dx, dy = q[0] - p[0], q[1] - p[1]
        length = math.hypot(dx, dy)
        if length == 0:
            continue
        width = rng.choice((9, 10, 12, 13))
        px, py = round(-dy / length * width * side), round(dx / length * width * side)
        a, b = lerp(p, q, .05), lerp(p, q, .94)
        stone = chipped_quad(a, b, add(b, px, py), add(a, px, py))
        flat(image, [add(point, -3, 5) for point in stone], "#785044")
        horizontal_stone(image, stone, rng.choice(("#c89876", "#d9aa81", "#bc8b72", "#edb789")), 3)


def rock_bands(image, upper, lower, color_set=SANDSTONE, count=5, weather=1.0):
    """Paint linked top, vertical face courses and ledge seams on one footprint."""
    for row in range(count):
        t, t_next = row / count, (row + 1) / count
        for i in range(len(upper) - 1):
            a, b = lerp(upper[i], lower[i], t), lerp(upper[i + 1], lower[i + 1], t)
            d, c = lerp(upper[i], lower[i], t_next), lerp(upper[i + 1], lower[i + 1], t_next)
            if math.dist(a, b) < 4:
                continue
            dx = b[0] - a[0]
            angle = (b[1] - a[1]) / max(15, abs(dx))
            index = min(len(color_set) - 2, max(1, 3 - int(t * 2) + (1 if angle > .45 else 0)))
            shade = tone(color_set[index], rng.randrange(-12, 11))
            tint_surface(image, [a, b, c, d], shade, weather, stone=True)
            pen = ImageDraw.Draw(image)
            pen.line((a, b), fill=tone(shade, 19), width=2)
            pen.line((d, c), fill=tone(shade, -26), width=2)
            n_joints = max(1, round(math.dist(a, b) / 22))
            for n in range(1, n_joints + 1):
                bias = (n - rng.uniform(.16, .78)) / n_joints
                p = lerp(a, b, bias)
                q = lerp(d, c, min(.96, bias + rng.uniform(-.10, .11)))
                mid = add(lerp(p, q, .45), rng.randint(-2, 2), -1)
                pen.line((p, mid, q), fill=tone(shade, -21), width=1)
                pen.line((add(p, 2, 1), add(mid, 1, 1)), fill=tone(shade, 11))
            for n in range(max(1, abs(dx) // 10)):
                bias = rng.uniform(.1, .85)
                p = lerp(lerp(a, b, bias), lerp(d, c, bias), rng.uniform(.22, .84))
                q = add(p, rng.randint(3, 10), rng.choice((-1, 0, 1)))
                pen.line((p, q), fill=tone(shade, rng.choice((-17, -10, 12, 20))), width=rng.choice((1, 2)))


def top_plate(image, contour, back, color, texture=1.0):
    # The broad back edge ends inside the connected mass. Split the front rim
    # into small linked facets where the exposed cap turns.
    outline = contour + back
    tint_surface(image, outline, color, texture, stone=True)
    details = image.copy()
    d = ImageDraw.Draw(details)
    for i, (p, q) in enumerate(zip(contour, contour[1:])):
        dx, dy = q[0] - p[0], q[1] - p[1]
        if math.hypot(dx, dy) < 3:
            continue
        inner = add(p, rng.randint(18, 62), -rng.randint(18, 55))
        inner_q = add(q, rng.randint(15, 68), -rng.randint(20, 65))
        shade = tone(color, rng.randint(-21, 22))
        tint_surface(details, [p, q, inner_q, inner], shade, texture, stone=True)
        d.line((p, lerp(p, q, .8)), fill=tone(shade, 25), width=2)
        d.line((lerp(q, inner_q, .24), inner_q, lerp(inner, inner_q, .6)), fill=tone(shade, -17))
        for n in range(4):
            v = lerp(p, inner, rng.uniform(.12, .94))
            v = lerp(v, lerp(q, inner_q, .36), rng.uniform(.1, .6))
            d.line((v, add(v, rng.randint(5, 18), rng.randint(-3, 1))),
                   fill=tone(shade, rng.randint(-13, 13)))
    cap = polygon_mask(outline)
    bounds = cap.getbbox()
    if bounds:
        left, top, right, bottom = bounds
        # Broad, interrupted strata on the cap. Clipping keeps fractures and
        # eroded gold bands on the same landform as its face.
        area_rng = random.Random(sum(p[0] * 17 + p[1] for p in contour))
        for row, y in enumerate(range(top + 10, bottom, 29)):
            for x in range(left - 12 + (row % 2) * 23, right, 56):
                px = x + area_rng.randint(-13, 10)
                py = y + area_rng.randint(-10, 9)
                if not (0 <= px < SIZE[0] and 0 <= py < SIZE[1] and cap.getpixel((px, py))):
                    continue
                width = area_rng.randint(24, 63)
                angle = area_rng.randint(-13, -4)
                p = (px, py)
                q = add(p, width, angle)
                fork = add(p, width // 3, angle // 2)
                ash = tone(color, area_rng.randint(-23, -10))
                lit = tone(color, area_rng.randint(13, 29))
                d.line((p, fork, q), fill=ash, width=area_rng.choice((1, 2, 3)))
                d.line((add(p, 4, 2), add(fork, 0, 3), add(q, -5, 3)), fill=lit, width=2)
                if row % 2 == 0:
                    d.line((fork, add(fork, 3, 5), add(fork, -2, 8)), fill=ash)
                for n in range(3):
                    start = lerp(p, q, area_rng.uniform(.13, .86))
                    start = add(start, area_rng.randint(-4, 5), area_rng.randint(4, 13))
                    d.line((start, add(start, area_rng.randint(2, 11), -1)), fill=area_rng.choice((ash, lit)))
    image.paste(details, (0, 0), cap)


def cliff(image, base, back, plateau, palette=SANDSTONE):
    foot = [p[:2] for p in base]
    crest = [(x, y - height) for x, y, height in base]
    # Intermediate ledges are part of the same face. Each lip overrides the
    # course beneath it, leaving a ledge top in the same upper-right sun.
    bottom = foot
    for depth, retreat, count in ((.41, 7, 3), (.72, 17, 2), (1.0, 25, 3)):
        top = [add(lerp(p, q, depth), retreat, 0) for p, q in zip(foot, crest)]
        rock_bands(image, top, bottom, palette, count)
        ImageDraw.Draw(image).line(bottom, fill=rgb(palette[0]), width=2)
        bottom = top
        if depth < 1.0:
            lip = [add(point, 11, -7) for point in top]
            tint_surface(image, top + list(reversed(lip)), palette[-2], .8)
            bottom = lip
    cap = [add(p, 25, 0) for p in crest]
    top_plate(image, cap, back, plateau)
    return cap, foot


def mesa(image, x, y, width, depth, height, palette):
    # Distant baked forms have low contrast but share the near cliff's angle.
    edge = [(x + width * offset, y + depth * (slope + rng.uniform(-.19, .16)))
            for offset, slope in [(-.54, -.61), (-.5, -.33), (-.39, -.4), (-.33, -.04), (-.19, .17),
                                  (-.07, .4), (.10, .23), (.28, .31), (.37, .03), (.53, -.25)]]
    top = [(round(a), round(b)) for a, b in edge]
    foot = [add(point, rng.randrange(-6, 7), height) for point in top]
    shadow_from(image, foot, -width * .24, depth * .62, "#70566e", 67)
    rock_bands(image, top, foot, palette, rng.randint(3, 6), .4)
    ridge = [(x + width*.38, y - depth*.78), (x + width*.17, y - depth),
             (x - width*.17, y - depth*.94), (x - width*.42, y - depth*.83)]
    top_plate(image, top, [(round(a), round(b)) for a, b in ridge], palette[-1], .44)


def valley(image):
    d = ImageDraw.Draw(image)
    for y in range(SIZE[1]):
        d.line((0, y, SIZE[0], y), fill=mix("#e6b7a6", "#7e6287", min(1, y / 1300)))
    # Dry streambed below the shelf provides a separate value and connects the valley floor.
    tint_surface(image, [(145, -75), (286, -30), (478, 93), (582, 205), (532, 307),
        (383, 384), (307, 479), (347, 565), (506, 611), (607, 706), (573, 800), (423, 878),
        (296, 993), (186, 1081), (82, 1408), (-104, 1462), (-100, 1180), (44, 1011),
        (167, 875), (344, 789), (412, 725), (381, 682), (250, 662), (165, 593), (158, 494),
        (231, 399), (359, 319), (434, 226), (395, 168), (275, 103), (150, 63)], "#bc9ba8", .45)
    for x, y, w, depth, drop in [
        (905, 64, 350, 90, 55), (1221, 80, 460, 109, 62), (552, 86, 201, 58, 57),
        (215, 118, 355, 82, 76), (722, 185, 357, 74, 101), (1078, 236, 460, 100, 126),
        (1388, 222, 318, 111, 181), (59, 298, 276, 104, 128),
        (374, 285, 216, 72, 96), (405, 317, 240, 64, 101), (589, 425, 279, 75, 123),
        (74, 460, 440, 85, 98), (100, 507, 382, 105, 146),
        (356, 674, 194, 58, 113), (200, 790, 231, 67, 112),
    ]:
        mesa(image, x, y, w, depth, drop, ("#906e86", "#98758b", "#a78193", "#bd939c", "#d5a6a1", "#d5a29b"))
    for _ in range(235):
        x, y = rng.randint(0, 950), rng.randint(200, 1070)
        if y < 984:
            d.line((x, y, x + rng.randint(3, 18), y), fill=tone("#ad8998", rng.randint(-6, 8)))


def shadow_from(image, foot, dx, dy, color="#644257", opacity=115):
    cast_shadow(image, foot + [add(point, dx, dy) for point in reversed(foot)], color, opacity)


def cast_shadow(image, path, color, opacity):
    cast = Image.new("RGBA", SIZE)
    ImageDraw.Draw(cast).polygon(path, fill=(*rgb(color), opacity))
    image.paste(cast, (0, 0), cast)


def ground_detail(image, mask):
    detail = image.copy()
    d = ImageDraw.Draw(detail)
    for _ in range(17300):
        x, y = rng.randrange(SIZE[0]), rng.randrange(435, SIZE[1])
        if not mask.getpixel((x, y)):
            continue
        shade = rng.choice(("#ba825f", "#d5a276", "#e5b582", "#a06b54", "#ca946e"))
        length = rng.choice((1, 1, 2, 3, 4, 6))
        d.line((x, y, x + length, y - length // 3), fill=rgb(shade), width=rng.choice((1, 1, 2)))
    image.paste(detail, (0, 0), mask)


def bush(image, x, y, width, color=("#584547", "#735346", "#86704b", "#a58a53", "#d0a964", "#eac480")):
    d = ImageDraw.Draw(image)
    d.ellipse((x - width*.53, y - width*.15, x + width*.52, y + width*.10), fill=rgb(color[0]))
    for _ in range(int(width*1.55)):
        dx = rng.uniform(-.49, .48) * width
        h = rng.uniform(.14, .68) * width * (1.0 - .65*abs(dx)/width)
        p = (round(x + dx), round(y - h))
        base = (round(x + dx*.35), y + rng.randint(-3, 3))
        d.line((base, p), fill=rgb(rng.choice(color[1:4])), width=rng.choice((1, 2, 2)))
        d.line((p, add(p, rng.choice((2, 3, -2)), rng.choice((2, 3, 4)))), fill=rgb(rng.choice(color[2:6])))
    for _ in range(width // 4):
        p = (x + rng.randrange(-width//2, width//2), y + rng.randrange(1, 6))
        d.point(p, fill=rgb(color[4]))


def stone_fret(image, top, bottom, columns, courses=4):
    rock_bands(image, top, bottom, MASONRY, courses, .85)
    d = ImageDraw.Draw(image)
    for row in range(courses):
        for i in range(len(top) - 1):
            a, b = lerp(top[i], bottom[i], (row + .85) / courses), lerp(top[i + 1], bottom[i + 1], (row + .85) / courses)
            for n in range(columns):
                p = lerp(a, b, (n + (row % 2) * .55) / columns)
                d.line((p, add(p, 1, -max(3, round((bottom[i][1] - top[i][1]) / courses) - 3))),
                       fill=tone(MASONRY[1], -12))


def stairs(image):
    a, b, c, d = STAIR
    shadow_from(image, [a, d, c], -13, 12, "#543c42", 140)
    for i in range(7):
        t = i / 7
        u = (i + 1) / 7
        left, right = lerp(a, d, t), lerp(b, c, t)
        end_l, end_r = lerp(a, d, u), lerp(b, c, u)
        # A pale chipped nosing on step five is the return reference.
        color = "#f3c796" if i == 4 else rng.choice(("#cf9f79", "#d9ab82", "#dfb389"))
        tint_surface(image, [left, right, end_r, end_l], color)
        lip_l, lip_r = lerp(left, end_l, .62), lerp(right, end_r, .62)
        tint_surface(image, [lip_l, lip_r, end_r, end_l], "#9d735f")
        pen = ImageDraw.Draw(image)
        pen.line((lip_l, lip_r), fill=rgb("#eec299" if i != 4 else "#fff0bb"), width=2)
        n = lerp(lip_l, lip_r, .40 if i % 2 else .61)
        pen.line((n, add(n, 1, 3)), fill=rgb("#825a53"))
        if i == 4:
            flat(image, [add(n, -10, -2), add(n, 0, -6), add(n, 5, -3), add(n, 0, 0)], "#fbe2ac")
            pen.point(add(n, -7, -2), fill=rgb("#fff2c1"))
    return lerp(lerp(a, d, .67), lerp(b, c, .67), .53)


def parapet(image, points):
    samples = resample(points, 28)
    for p, q in zip(samples, samples[1:]):
        flat(image, [p, q, add(q, -9, 9), add(p, -9, 9)], "#8d655b")
        a, b = add(p, 0, -19), add(q, 0, -19)
        d = ImageDraw.Draw(image)
        d.line((a, b), fill=rgb("#a87861"), width=7)
        d.line((add(a, 1, -3), add(b, 1, -3)), fill=rgb("#ebbf8d"), width=4)
        d.line((add(a, 1, -5), add(b, 1, -5)), fill=rgb("#f5d09c"))
        for post in (p, lerp(p, q, .5)):
            x, y = post
            tint_surface(image, [(x-3, y-21), (x+5, y-21), (x+5, y), (x-3, y+2)], "#b4856e")
            tint_surface(image, [(x-3, y-21), (x+5, y-21), (x+8, y-25), (x, y-25)], "#edc491")


def terrace(image, paving):
    front = [DECK[i] for i in (10, 9, 8, 7, 6, 5)]
    # Support the masonry with exposed sandstone beneath the front and left wall.
    footing = [add(p, -6, 69) for p in front]
    mid = [add(p, -2, 35) for p in front]
    shadow_from(image, footing, -12, 13, "#563c4b", 117)
    rock_bands(image, mid, footing, SANDSTONE, 3)
    stone_fret(image, front, mid, 4, 3)
    image.paste(paving, (0, 0), polygon_mask(DECK))
    ImageDraw.Draw(image).line(DECK + [DECK[0]], fill=rgb("#e8b587"), width=3)
    parapet(image, [(984, 551), (918, 532), (850, 543), (779, 565), (761, 592), (755, 622)])
    bush(image, 777, 633, 34)
    bush(image, 965, 570, 22)
    return stairs(image)


def arch(image):
    x0, x1 = 1104, 1336
    spring, base = 555, 607
    centers = (1160, 1277)
    stone_colors = ("#ba8d71", "#c59c7c", "#d6ad86", "#e0b78e", "#d0a37d", "#efc18f")
    back_dx, back_dy = 8, -15

    def arc_shape(center, radius_outer, radius_inner, a, b, dx=0, dy=0):
        angles = np.linspace(a, b, 6)
        return [(round(center + math.cos(angle) * radius_outer + dx), round(spring - math.sin(angle) * radius_outer + dy))
                for angle in angles] + [
                (round(center + math.cos(angle) * radius_inner + dx), round(spring - math.sin(angle) * radius_inner + dy))
                for angle in reversed(angles)]

    piers = [(1104, 1125), (1203, 1232), (1314, 1336)]
    for left, right in piers:
        cast_shadow(image, [(left, base), (right, base), (right-31, base+44),
                            (left-48, base+44)], "#554157", 105)
        tint_surface(image, [(right, spring), (right+back_dx, spring+back_dy),
                              (right+back_dx, base+back_dy), (right, base)], "#ac7b62")
        for y in range(spring - 7, base, 10):
            next_y = min(base, y + 9)
            tint_surface(image, [(left, y), (right, y), (right, next_y), (left, next_y)], rng.choice(stone_colors))
            pen = ImageDraw.Draw(image)
            pen.line((left, y, right, y), fill=rgb("#7e5d58"))
            pen.line((left, y+1, right-2, y+1), fill=rgb("#e4bb92"))
            seam = left + (right-left) * (.37 if y % 3 else .68)
            pen.line((seam, y+2, seam, next_y), fill=rgb("#a27d69"))
            pen.line((left+2, y+3, left+2, next_y), fill=rgb("#ad836c"))
        horizontal_stone(image, [(left-3, base-7), (right+3, base-7),
                         (right+3, base+2), (right+1, base+3), (left-4, base+3), (left-5, base+1),
                         (left-5, base-3), (left-4, base-6)], "#c19471", 3)
    for center in centers:
        tint_surface(image, arc_shape(center, 54, 39, 0, math.pi, back_dx, back_dy), "#a17b69")
        for i in range(15):
            a, b = i * math.pi / 15, (i+1) * math.pi / 15
            poly = arc_shape(center, 55, 38, a + .007, b - .007)
            shade = mix(rng.choice(stone_colors), "#806075", .22 * (i / 15))
            tint_surface(image, poly, shade, .8)
            ImageDraw.Draw(image).line(poly[:6], fill=tone(shade, 24), width=2)
            ImageDraw.Draw(image).line(poly[6:], fill=tone(shade, -32), width=2)
    pen = ImageDraw.Draw(image)
    tint_surface(image, [(x0, spring-62), (x1, spring-62), (x1, spring-56), (x0, spring-56)], "#c99d79")
    tint_surface(image, [(x0, spring-62), (x1, spring-62), (x1+8, spring-75), (x0+8, spring-75)], "#f0c693")
    for x in range(x0+13, x1, 17):
        pen.line((x, spring-56, x+7, spring-74), fill=rgb("#ad846c"))
    pen.line((x0 + 7, spring - 75, x1 + 8, spring - 75), fill=rgb("#ffe0a9"), width=2)
    for x in (1124, 1227, 1326):
        bush(image, x, base+4, 19)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    world = Image.new("RGB", SIZE)
    valley(world)
    rim = SHELF[:-2]
    rock_bands(world, rim, [add(p, -13, 82) for p in rim],
               ("#6a4e62", "#855565", "#aa665c", "#b7806c", "#d19678", "#e7aa81"), 5)
    tint_surface(world, SHELF, "#bf855d", 1.35, stone=True)
    mask = polygon_mask(SHELF)
    ground_detail(world, mask)
    path = curve(ROAD)
    right, left = road_edges(path)
    paving = pavement("#88615c")
    world.paste(paving, (0, 0), polygon_mask(right + list(reversed(left))))
    curb(world, right, 1)
    curb(world, left, -1)
    shadow_from(world, [p[:2] for p in NEAR], -37, 19, opacity=130)
    shadow_from(world, [p[:2] for p in NEAR], -10, 6, "#47333e", 142)
    shadow_from(world, [p[:2] for p in OUTER], -20, 16, opacity=120)
    # The left wall joins the outer shelf and frames the approach.
    cliff(world, OUTER, [(403, 1510), (-170, 1510), (-170, 830)], "#c5764b")
    cliff(world, [(-95, 1060, 103), (5, 1030, 101), (70, 1050, 104), (126, 1073, 115),
        (163, 1121, 108), (188, 1163, 116), (174, 1234, 132), (204, 1299, 152),
        (255, 1383, 158), (287, 1480, 168)],
        [(319, 1510), (-170, 1510), (-170, 861)], "#d68953")
    stair_mark = terrace(world, paving)
    arch(world)
    for x, y, w in [(399, 1200, 35), (384, 1103, 40), (438, 886, 24),
                    (469, 996, 28), (622, 1100, 38), (613, 1021, 29), (680, 928, 29),
                    (515, 886, 32), (546, 827, 22), (603, 777, 33), (625, 779, 24),
                    (679, 738, 25), (737, 716, 29), (755, 725, 18), (823, 684, 28),
                    (859, 668, 23), (920, 512, 20), (1007, 552, 25), (1044, 589, 28),
                    (1077, 619, 20), (1345, 611, 35), (1388, 536, 38), (1441, 514, 45),
                    (1360, 708, 26), (1265, 754, 24), (980, 765, 26), (829, 813, 25)]:
        bush(world, x, y, w)
    foreground = Image.new("RGBA", SIZE)
    cliff(foreground, NEAR, [(1710, 430), (1710, 1480), (800, 1490)], "#cc7c4d")
    # Elevated plateaus bend into the cap, with a broad lower terrace beside the arch.
    upper = [(778, 1495, 126), (773, 1318, 117), (754, 1224, 119), (745, 1159, 105),
        (746, 1092, 118), (787, 1045, 106), (811, 982, 130), (842, 929, 151), (846, 879, 145),
        (907, 855, 145), (964, 809, 131), (1026, 790, 108), (1080, 785, 99), (1141, 798, 89),
        (1190, 798, 69), (1262, 819, 74), (1362, 808, 95), (1458, 769, 112), (1650, 692, 112)]
    cliff(foreground, upper, [(1710, 540), (1710, 1510), (863, 1510)], "#d88d55",
          ("#794740", "#9e5745", "#b66a50", "#cb7e54", "#e49361", "#f2af77", "#fac088"))
    highest = [(937, 1470, 113), (901, 1394, 119), (896, 1322, 116), (906, 1246, 106),
        (894, 1188, 99), (925, 1128, 98), (909, 1067, 118), (935, 998, 119),
        (987, 967, 112), (1041, 912, 104), (1125, 877, 85), (1198, 893, 94),
        (1300, 926, 101), (1397, 897, 102), (1538, 838, 115), (1660, 830, 112)]
    cliff(foreground, highest, [(1710, 660), (1710, 1510), (966, 1510)], "#dd995f")
    inner = [(1111, 1510, 97), (1070, 1446, 94), (1040, 1380, 90), (1049, 1289, 104),
        (1067, 1212, 107), (1154, 1144, 83), (1174, 1082, 89), (1253, 1027, 67),
        (1346, 1055, 70), (1421, 1048, 85), (1562, 973, 104), (1680, 934, 115)]
    cliff(foreground, inner, [(1710, 805), (1710, 1510), (1150, 1520)], "#dd9563")
    for x, y, w in [(758, 1024, 27), (766, 924, 30), (815, 835, 32), (875, 816, 22),
                    (928, 798, 25), (1010, 784, 22), (1125, 787, 25), (1321, 752, 36),
                    (1400, 683, 39), (786, 1079, 38), (800, 1187, 34), (774, 1311, 24)]:
        bush(foreground, x, y, w)
    world.save(DEST / "bend_ground.png")
    box = foreground.getbbox()
    foreground.crop(box).save(DEST / "near_wall.png")
    overview = world.copy()
    overview.paste(foreground, (0, 0), foreground)
    overview.thumbnail((990, 990), Image.Resampling.NEAREST)
    print("Foreground offset", box[:2])
    print("Distinctive stair pixel", stair_mark)
    for side, points in enumerate(road_edges(path, 3)):
        print("Road edge", side, [p for p in resample(points, 44) if 485 < p[1] < 1290])
    scratch = ROOT / "tmp/canyon_session_b"
    scratch.mkdir(parents=True, exist_ok=True)
    overview.save(scratch / "map_preview.png")


if __name__ == "__main__":
    main()
