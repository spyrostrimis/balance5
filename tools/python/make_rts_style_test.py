"""Generate the RTS style tests: one 960x540 art-pixel screen with every layer, twice.

    C:/Python312/python.exe tools/python/make_rts_style_test.py

Follows docs/RTS_ART_RULES.md: art pixels (1 art px = 2 reference px = 2 screen px at 1080p),
32 art px tiles, the 48-colour desert palette, light from the top-left.
Test 1 makes every surface procedurally. Tests 2-5 (style_test/t2/ to t5/) take the painted
textures in assets/source_inputs/rts/, shrinks and colour-matches them, and adds the tool fixes
listed in the art rules §6b. The scene's T key switches between them. Writes to
assets/textures/rts/style_test/:
  sand.png, sand_dunes.png   ground without / with dune ripples (opaque)
  road.png, rocks.png, scatter.png   transparent layers (rocks include their cast shadows)
  unit_*.png                 stand-in units (soldier squads, commanders, tanks)
  reference_half.png         the Mission 1 reference at art scale, for the R key
and the scene scenes/maps/rts_style_test.tscn that stacks them.
The layout loosely follows docs/references/rts_mission1_desert_red.webp so the two can be compared.
"""
from pathlib import Path
import json

import cv2
import numpy as np
from PIL import Image

import rts_palette

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "textures" / "rts" / "style_test"
SCENE = ROOT / "scenes" / "maps" / "rts_style_test.tscn"
W, H = 960, 540
SEED = 11

# Light from the top-left, a little above: x right, y down, z up (towards the viewer).
LIGHT = np.array([-0.5, -0.7, 0.75])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

# Material colours measured from the reference (tools/python/rts_palette.py prints them).
SAND = np.array([228, 135, 40], np.float32)
CREST = np.array([255, 196, 71], np.float32)
TROUGH = np.array([169, 84, 22], np.float32)
ROAD = np.array([210, 160, 117], np.float32)
ROAD_JOINT = np.array([150, 106, 74], np.float32)
ROCK = np.array([92, 72, 62], np.float32)
ROCK_LIGHT = np.array([138, 112, 96], np.float32)
ROCK_DARK = np.array([48, 36, 32], np.float32)
WALL = np.array([96, 62, 38], np.float32)
OUTLINE = np.array([34, 24, 20], np.float32)
SHADOW = np.array([90, 40, 10], np.float32)

rng = np.random.default_rng(SEED)
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)


# --- helpers --------------------------------------------------------------------------------

def noise(cx: int, cy: int | None = None) -> np.ndarray:
    """Smooth value noise in [0, 1] with features about cx by cy pixels."""
    cy = cy or cx
    gw, gh = W // cx + 3, H // cy + 3
    grid = rng.random((gh, gw)).astype(np.float32)
    return cv2.resize(grid, (gw * cx, gh * cy), interpolation=cv2.INTER_CUBIC)[:H, :W]


def fbm(*cells: int) -> np.ndarray:
    total, weight = np.zeros((H, W), np.float32), 0.0
    for i, c in enumerate(cells):
        w = 0.55 ** i
        total += noise(c) * w
        weight += w
    return total / weight


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def lambert(height: np.ndarray) -> np.ndarray:
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n @ LIGHT - LIGHT[2]  # 0 on flat ground, + facing the light, - facing away


def blob(parts: list, warp: float = 0.35) -> np.ndarray:
    """Union of noisy ellipses: parts are (cx, cy, rx, ry)."""
    field = np.full((H, W), -9.0, np.float32)
    for cx, cy, rx, ry in parts:
        field = np.maximum(field, 1 - ((XX - cx) / rx) ** 2 - ((YY - cy) / ry) ** 2)
    return field + warp * (fbm(40, 18, 8) - 0.5) * 2 > 0


def shift(mask: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(mask)
    ys, yd = (slice(0, H - dy), slice(dy, H)) if dy >= 0 else (slice(-dy, H), slice(0, H + dy))
    xs, xd = (slice(0, W - dx), slice(dx, W)) if dx >= 0 else (slice(-dx, W), slice(0, W + dx))
    out[yd, xd] = mask[ys, xs]
    return out


def voronoi(cell: float) -> np.ndarray:
    """Cell labels for jittered seeds about `cell` pixels apart."""
    seeds = np.ones((H, W), np.uint8)
    for gy in np.arange(-cell, H + cell, cell):
        for gx in np.arange(-cell, W + cell, cell):
            x, y = int(gx + rng.random() * cell), int(gy + rng.random() * cell)
            if 0 <= x < W and 0 <= y < H:
                seeds[y, x] = 0
    _, labels = cv2.distanceTransformWithLabels(seeds, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_CCOMP)
    return labels


def edges_of(labels: np.ndarray) -> np.ndarray:
    e = np.zeros((H, W), bool)
    e[:, :-1] |= labels[:, :-1] != labels[:, 1:]
    e[:-1, :] |= labels[:-1, :] != labels[1:, :]
    return e


def dist_inside(mask: np.ndarray) -> np.ndarray:
    return cv2.distanceTransform(mask.astype(np.uint8), cv2.DIST_L2, 3)


def lerp(a, b, t):
    t = np.asarray(t, np.float32)[..., None] if np.ndim(t) else t
    return a + (b - a) * t


def save(name: str, rgb: np.ndarray, alpha: np.ndarray | None = None) -> None:
    rgb8 = rts_palette.map_to_palette(np.clip(rgb, 0, 255).astype(np.uint8), PALETTE)
    if alpha is None:
        Image.fromarray(rgb8).save(OUT / name)
    else:
        a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
        Image.fromarray(np.dstack([rgb8, a])).save(OUT / name)


# --- layout (art pixels; the reference halved, then extended to 960 x 540) -----------------

ROCK_CORE = (318, 222, 56, 36)
PLAZA = (312, 224, 94, 68)
ROAD_LINE = [(-10, 116), (55, 124), (100, 146), (160, 164), (225, 196),
             (390, 262), (430, 300), (480, 335), (545, 372), (600, 398), (660, 414), (780, 442), (970, 474)]
CLIFFS = [
    ([(70, 18, 54, 28), (40, 30, 30, 20)], 8),                                   # north-west mesa
    ([(520, 14, 70, 26), (585, 60, 38, 56), (612, 130, 40, 52), (700, 36, 95, 62),
      (810, 92, 125, 58), (920, 40, 80, 70), (650, 170, 22, 40)], 11),             # north-east cliffs
    ([(30, 430, 120, 60), (-10, 370, 40, 45), (130, 500, 120, 40)], 11),           # south-west cliffs
    ([(845, 438, 46, 24)], 6),                                                    # small mesa
]
UNITS = [  # (texture, x, y) centres in art pixels
    ("unit_blue_tank.png", 106, 132), ("unit_blue_squad.png", 166, 158), ("unit_blue_commander.png", 196, 150),
    ("unit_red_squad.png", 452, 330), ("unit_red_commander.png", 478, 318), ("unit_red_tank.png", 528, 362),
    ("unit_red_squad.png", 602, 172),
]


# --- ground ---------------------------------------------------------------------------------

def make_sand() -> np.ndarray:
    tone = 1 + 0.07 * (fbm(120, 60) - 0.5) * 2
    rgb = SAND * tone[..., None]
    worms_dark = np.abs(noise(7) - 0.5) < 0.03
    worms_light = np.abs(noise(6) - 0.5) < 0.03
    rgb[worms_dark] *= 0.93
    rgb[worms_light] = lerp(rgb[worms_light], CREST, 0.35)
    specks = rng.random((H, W))
    rgb[specks < 0.004] *= 0.82
    rgb[specks > 0.996] = lerp(rgb[specks > 0.996], CREST, 0.6)
    return rgb


def make_dunes(sand: np.ndarray) -> np.ndarray:
    angle = -0.26 + 0.5 * (fbm(220, 110) - 0.5)
    warp = 26 * (fbm(90, 45) - 0.5)
    phase = (YY * np.cos(angle) - XX * np.sin(angle) + warp) / 21.0
    s = phase - np.floor(phase)
    ridge = np.where(s < 0.68, s / 0.68, (1 - s) / 0.32)          # gentle windward, steep lee
    amp = smoothstep(0.5, 0.66, fbm(300, 150, 75))                  # dunes come in fields, flat sand between
    amp *= 0.75 + 0.25 * noise(40)                                  # crests fade in and out along their length
    height = cv2.GaussianBlur((ridge * amp * 4.0).astype(np.float32), (0, 0), 1.6)
    rel = np.clip(lambert(height) * 2.6, -1, 1)
    rgb = sand.copy()
    up, down = rel > 0, rel < 0
    rgb[up] = lerp(rgb[up], CREST, rel[up] * 0.9)
    rgb[down] = lerp(rgb[down], TROUGH, -rel[down] * 0.85)
    return rgb


# --- rocks with height ------------------------------------------------------------------------

def render_rock(top: np.ndarray, wall_h: int, cell: float, rgb: np.ndarray, alpha: np.ndarray,
                shadow_offset: tuple[int, int] = (5, 4), boulders: int = 0) -> np.ndarray:
    """Draw a raised rock: cracked slab top, a visible front (south) wall, outline and cast
    shadow, into rgb/alpha. Returns the footprint."""
    wall_k = np.zeros((H, W), np.int32)
    for k in range(wall_h, 0, -1):
        wall_k[shift(top, 0, k) & ~top] = k
    wall = wall_k > 0
    foot = top | wall

    # Cast shadow on the ground, down-right of the footprint.
    sh = cv2.GaussianBlur(shift(foot, *shadow_offset).astype(np.float32), (0, 0), 1.6)
    sh_only = (sh > 0.05) & ~foot & (alpha < 0.99)
    rgb[sh_only] = SHADOW
    alpha[sh_only] = np.maximum(alpha[sh_only], sh[sh_only] * 0.5)

    # Top: slabs bevelled at their cracks and at the rock edge, plus a few boulders.
    labels = voronoi(cell)
    cracks = edges_of(labels) & top
    height = np.minimum(dist_inside(top & ~cracks), 3.0) * 0.7 + np.minimum(dist_inside(top), 4.0) * 0.6
    if boulders:
        inner = dist_inside(top) > 7
        ys, xs = np.nonzero(inner)
        for i in rng.choice(len(ys), min(boulders, len(ys)), replace=False):
            r = rng.uniform(1.6, 3.4)
            d2 = (XX - xs[i]) ** 2 + (YY - ys[i]) ** 2
            height += np.sqrt(np.maximum(0, r * r - d2)) * 1.1
    slab_tone = (rng.random(labels.max() + 1).astype(np.float32) - 0.5) * 0.22
    grain = (noise(3) - 0.5) * 0.3
    shade = np.clip(lambert(height) * 2.2, -1, 1) + slab_tone[labels] + grain
    col = np.where(shade[..., None] > 0, lerp(ROCK, ROCK_LIGHT, np.clip(shade, 0, 1)),
                   lerp(ROCK, ROCK_DARK, np.clip(-shade, 0, 1)))
    col[cracks] = ROCK_DARK

    # Front wall: vertical streaks, darker towards the foot.
    streak = cv2.resize(rng.random((H // 6 + 2, W // 2 + 2)).astype(np.float32), None, fx=2, fy=6,
                        interpolation=cv2.INTER_LINEAR)[:H, :W]
    depth = wall_k / max(wall_h, 1)
    wall_col = WALL[None, None] * (1.2 - 0.6 * depth[..., None]) * (0.7 + 0.6 * streak[..., None])
    wall_col[wall_k == 1] = ROCK_LIGHT  # lit lip where the top meets the wall
    col = np.where(wall[..., None], wall_col, col)

    rgb[foot] = col[foot]
    alpha[foot] = 1.0
    ring = foot & ~cv2.erode(foot.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    rgb[ring] = OUTLINE
    return foot


def make_rocks() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)
    feet = np.zeros((H, W), bool)
    for parts, wall_h in CLIFFS:
        feet |= render_rock(blob(parts), wall_h, 21, rgb, alpha, boulders=len(parts) * 22)

    # The Orichalcum rock: low wall, big slabs, a gravel skirt and gold crystals.
    cx, cy, rx, ry = ROCK_CORE
    top = blob([ROCK_CORE, (cx - 30, cy + 8, 26, 22), (cx + 28, cy - 6, 26, 24)], 0.25)
    skirt = cv2.dilate((top | shift(top, 0, 4)).astype(np.uint8), np.ones((15, 15), np.uint8)).astype(bool)
    gravel = skirt & ~top & (rng.random((H, W)) < 0.45 * (1 - dist_inside(skirt) / 8 * 0) )
    rgb[gravel] = lerp(ROCK_DARK, ROCK, rng.random(gravel.sum()))
    alpha[gravel] = 1.0
    foot = render_rock(top, 5, 15, rgb, alpha, shadow_offset=(3, 3))
    feet |= foot
    inner = dist_inside(top) > 5
    ys, xs = np.nonzero(inner)
    weight = np.exp(-(((xs - cx) / (rx * 0.6)) ** 2 + ((ys - cy) / (ry * 0.6)) ** 2))
    picks = rng.choice(len(ys), 60, replace=False, p=weight / weight.sum())
    gold, light, dark = np.array([250, 190, 60.]), np.array([255, 240, 160.]), np.array([175, 95, 25.])
    for i in picks:
        x, y = xs[i], ys[i]
        size = rng.integers(1, 3)
        for dy in range(-size - 1, size + 2):
            for dx in range(-size, size + 1):
                if abs(dx) * 1.6 + abs(dy) <= size + 1 and 0 <= x + dx < W and 0 <= y + dy < H:
                    rgb[y + dy, x + dx] = gold if dx + dy >= 0 else light
        rgb[min(y + size + 1, H - 1), x] = dark
    return rgb, alpha, feet


# --- road ---------------------------------------------------------------------------------------

def make_road(feet: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    dist = np.full((H, W), 1e9, np.float32)
    pts = np.array(ROAD_LINE, np.float32)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((XX - a[0]) * ab[0] + (YY - a[1]) * ab[1]) / (ab @ ab), 0, 1)
        dist = np.minimum(dist, np.hypot(XX - a[0] - t * ab[0], YY - a[1] - t * ab[1]))
    edge_noise = (fbm(30, 12, 5) - 0.5) * 7
    cx, cy, rx, ry = PLAZA
    plaza = 1 - ((XX - cx) / rx) ** 2 - ((YY - cy) / ry) ** 2 + (fbm(36, 14) - 0.5) * 0.25 > 0
    road = ((dist + edge_noise) < 12.5) | plaza
    road &= ~feet

    labels = voronoi(11.5)
    joints = edges_of(labels) & road
    height = np.minimum(dist_inside(road & ~joints), 2.0)
    tone = (rng.random(labels.max() + 1).astype(np.float32) - 0.5) * 0.12
    shade = np.clip(lambert(height) * 1.4, -1, 1) * 0.5 + tone[labels]
    col = ROAD[None, None] * (1 + shade[..., None])
    col[joints] = ROAD_JOINT
    rim = road & ~cv2.erode(road.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    col[rim] = lerp(col[rim], ROAD_JOINT, 0.6)

    rgb = col
    alpha = road.astype(np.float32)
    # Stone markers in a dotted ring around the plaza.
    for t in np.arange(0, 2 * np.pi, 2 * np.pi / 64):
        x = int(cx + (rx + 7) * np.cos(t))
        y = int(cy + (ry + 7) * np.sin(t))
        if 0 < x < W - 1 and 0 < y < H - 1 and not road[y, x] and not feet[y, x]:
            rgb[y, x] = [92, 80, 72]
            rgb[y - 1, x - 1] = [160, 145, 130]
            alpha[y, x] = alpha[y - 1, x - 1] = 1.0
    return rgb, alpha


# --- scatter ------------------------------------------------------------------------------------

def make_scatter(blocked: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)

    def put(x, y, c, a=1.0):
        if 0 <= x < W and 0 <= y < H and not blocked[y, x]:
            rgb[y, x] = c
            alpha[y, x] = a

    for _ in range(170):  # pebbles
        x, y = int(rng.uniform(2, W - 3)), int(rng.uniform(2, H - 3))
        if blocked[y, x]:
            continue
        big = rng.random() < 0.3
        base = np.array([118, 104, 94.]) if rng.random() < 0.6 else np.array([78, 66, 60.])
        put(x + 1, y + 1, SHADOW, 0.55)
        if big:
            put(x + 2, y + 1, SHADOW, 0.55)
            put(x + 1, y + 2, SHADOW, 0.55)
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                put(x + dx, y + dy, base)
        else:
            put(x, y, base)
        put(x, y, base * 1.45)
    for _ in range(40):  # scrub tufts
        x, y = int(rng.uniform(4, W - 5)), int(rng.uniform(4, H - 5))
        if blocked[max(0, y - 3):y + 4, max(0, x - 3):x + 4].any():
            continue
        for dx, dy in ((1, 1), (2, 2), (0, 2), (2, 0), (3, 1), (1, 3)):
            put(x + dx, y + dy, SHADOW, 0.5)
        for dx, dy in ((0, 0), (-1, -1), (1, -1), (-1, 1), (1, 1), (0, -2), (-2, 0), (2, 0), (0, 2)):
            put(x + dx, y + dy, [92, 128, 38])
        put(x, y, [52, 80, 26])
        for dx, dy in ((-1, -1), (0, -2), (-2, 0)):
            put(x + dx, y + dy, [150, 182, 70])
    return rgb, alpha


# --- stand-in units -----------------------------------------------------------------------------

SOLDIER = [
    "..hhh..",
    ".hHHHk.",
    ".hHHHk.",
    "..fff..",
    ".lBBBd.",
    "lBBBBBd",
    "lBBBBBd",
    ".BBBBd.",
    ".BBBdd.",
    "..L.L..",
    "..L.L..",
]
COMMANDER = [
    "...ggg...",
    "..gGGGk..",
    "..gGGGk..",
    "...fff...",
    ".ssssssd.",
    ".lBBcBBd.",
    "lBBcccBBd",
    "lBBBcBBBd",
    ".BBBBBBd.",
    ".BBBBBBd.",
    ".BBBBBdd.",
    "..LL.LL..",
    "..LL.LL..",
]
TEAMS = {
    "blue": {"l": (130, 175, 255), "B": (46, 96, 222), "d": (22, 42, 120)},
    "red": {"l": (255, 128, 104), "B": (204, 44, 32), "d": (112, 22, 16)},
}
COMMON = {"h": (238, 236, 232), "H": (190, 192, 202), "k": (110, 110, 124), "f": (226, 178, 138),
          "L": (40, 32, 36), "g": (255, 222, 120), "G": (226, 170, 60), "s": (236, 228, 206),
          "c": (110, 240, 240)}


def draw_figure(pattern: list[str], team: str) -> np.ndarray:
    colors = dict(COMMON, **TEAMS[team])
    if team == "red":
        colors["c"] = colors["G"]  # gold emblem instead of the healer's cyan cross
    h, w = len(pattern), len(pattern[0])
    img = np.zeros((h + 2, w + 2, 4), np.uint8)
    for y, row in enumerate(pattern):
        for x, ch in enumerate(row):
            if ch != ".":
                img[y + 1, x + 1] = (*colors[ch], 255)
    solid = img[..., 3] > 0
    ring = cv2.dilate(solid.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & ~solid
    img[ring] = (*OUTLINE.astype(int), 255)
    return img


def compose_units(figures: list[tuple[np.ndarray, int, int]], size: int) -> np.ndarray:
    """Place figures (with a soft shadow down-right of each) on a transparent canvas."""
    canvas = np.zeros((size, size, 4), np.float32)
    for fig, ox, oy in sorted(figures, key=lambda f: f[2]):
        h, w = fig.shape[:2]
        sx, sy = ox + w // 2 + 1, oy + h - 2
        for yy in range(-1, 2):
            for xx in range(-3, 4):
                if (xx / 3.5) ** 2 + yy ** 2 <= 1 and 0 <= sy + yy < size and 0 <= sx + xx < size:
                    canvas[sy + yy, sx + xx] = (*SHADOW, max(canvas[sy + yy, sx + xx, 3], 120))
        a = fig[..., 3] > 0
        canvas[oy:oy + h, ox:ox + w][a] = fig[a]
    return canvas


def save_rgba(name: str, rgba: np.ndarray) -> None:
    rgb = rts_palette.map_to_palette(np.clip(rgba[..., :3], 0, 255).astype(np.uint8), PALETTE)
    Image.fromarray(np.dstack([rgb, rgba[..., 3].astype(np.uint8)])).save(OUT / name)


def make_units() -> None:
    for team in ("blue", "red"):
        s = draw_figure(SOLDIER, team)
        squad = compose_units([(s, 2, 3), (s, 13, 1), (s, 6, 14), (s, 17, 13)], 30)
        save_rgba(f"unit_{team}_squad.png", squad)
        save_rgba(f"unit_{team}_commander.png", compose_units([(draw_figure(COMMANDER, team), 2, 1)], 16))
    tank = Image.open(ROOT / "assets" / "textures" / "units" / "blue_tank.png").convert("RGBA")
    tank = np.array(tank.resize((tank.width // 2, tank.height // 2), Image.BOX)).astype(np.float32)
    tank[..., 3] = np.where(tank[..., 3] > 110, 255, 0)
    save_rgba("unit_blue_tank.png", tank)
    red = tank.copy()
    bluish = red[..., 2] > red[..., 0] + 25
    red[bluish] = red[bluish][:, [2, 1, 0, 3]] * [1.0, 0.6, 0.6, 1.0]
    save_rgba("unit_red_tank.png", red)


# --- style test 2: painted textures for surfaces, plus the tool fixes from test 1 ------------------
# Inputs: assets/source_inputs/rts/*.png (ChatGPT, prompts in docs/RTS_ART_RULES.md §7).
# Each texture is shrunk to art scale, colour-matched to the reference material, then shaped,
# lit and outlined by the tools below. Output goes to style_test/t2/.

SRC = ROOT / "assets" / "source_inputs" / "rts"
# (mean, std) RGB per material at art scale, measured on reference_half.png. Sand and road std are
# for the flat surface only (ripples and cracks are added separately); wall is estimated (§6).
TARGETS = {
    "sand": ((229, 136, 41), (16, 15, 7)),
    "road": ((205, 155, 113), (13, 12, 11)),
    "rock": ((84, 64, 56), (26, 21, 17)),
    "wall": ((108, 74, 50), (30, 22, 16)),
}
# How many source pixels make one art pixel, chosen so features match the reference's sizes:
# sand grain ~1 art px, rock slabs ~50 art px, road plates ~25 art px, wall columns ~2-3 art px.
SHRINK = {"sand.png": 3.2, "rock_top.png": 5.5, "road.png": 10.0, "cliff_wall.png": 9.0}
CREST_HI = np.array([255, 216, 112], np.float32)
DEEP = np.array([22, 14, 10], np.float32)
SHADOW_DARK = np.array([70, 30, 8], np.float32)
MARKER = np.array([216, 208, 196], np.float32)
GOLD = np.array([255, 196, 70], np.float32)


def load_source(name: str, factor: float, gray: bool = False) -> np.ndarray:
    im = Image.open(SRC / name).convert("L" if gray else "RGB")
    size = (max(1, round(im.width / factor)), max(1, round(im.height / factor)))
    return np.array(im.resize(size, Image.BOX)).astype(np.float32)


def seamless(tex: np.ndarray) -> np.ndarray:
    from smooth_texture import cosine_wrap
    m = max(2, min(tex.shape[:2]) // 16)
    return cosine_wrap(cosine_wrap([tex], m, 0), m, 1)[0]


def match_colour(rgb: np.ndarray, material: str) -> np.ndarray:
    """Shift and scale each channel so the texture has the reference material's mean and contrast."""
    mean_t, std_t = (np.array(v, np.float32) for v in TARGETS[material])
    flat = rgb.reshape(-1, 3)
    ratio = np.clip(std_t / (flat.std(0) + 1e-3), 0.3, 3.0)
    return (rgb - flat.mean(0)) * ratio + mean_t


def tile(tex: np.ndarray, ox: int | None = None, oy: int | None = None) -> np.ndarray:
    th, tw = tex.shape[:2]
    ox = int(rng.integers(0, tw)) if ox is None else ox % tw
    oy = int(rng.integers(0, th)) if oy is None else oy % th
    reps = (H // th + 2, W // tw + 2) + ((1,) if tex.ndim == 3 else ())
    return np.tile(tex, reps)[oy:oy + H, ox:ox + W]


def stretched_noise(u: np.ndarray, v: np.ndarray, cell_u: float, cell_v: float) -> np.ndarray:
    """Smooth noise sampled at arbitrary (u, v) pixel coordinates, cell_u by cell_v features."""
    big = cv2.resize(rng.random((64, 64)).astype(np.float32), (512, 512), interpolation=cv2.INTER_CUBIC)
    mx = (u / cell_u * 8).astype(np.float32)
    my = (v / cell_v * 8).astype(np.float32)
    return cv2.remap(big, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)


def make_sand2() -> np.ndarray:
    tex = match_colour(seamless(load_source("sand.png", SHRINK["sand.png"])), "sand")
    tone = 1 + 0.06 * (fbm(140, 70) - 0.5) * 2
    return tile(tex) * tone[..., None]


def make_dunes2(sand: np.ndarray) -> np.ndarray:
    """Ripples as the reference draws them: a thin bright crest, a short dark shadow just below it,
    a gentle brightening up the windward side; short crests that end and fork, in packs."""
    angle = -0.26 + 0.5 * (fbm(220, 110) - 0.5)
    warp = 22 * (fbm(90, 45) - 0.5)
    across = YY * np.cos(angle) - XX * np.sin(angle) + warp
    along = XX * np.cos(angle) + YY * np.sin(angle)
    phase = across / 15.0
    s = phase - np.floor(phase)
    ripple = np.floor(phase)
    fields = smoothstep(0.46, 0.58, fbm(300, 150, 75))
    segments = smoothstep(0.3, 0.46, stretched_noise(along, ripple * 3.1 + 7, 30, 1))
    amp = fields * segments * (0.7 + 0.3 * noise(30))
    # Light profile across one ripple: the lit face brightens up to the crest, then a sharp drop
    # into the dark lee face, which slowly recovers. Broad faces, not thin lines.
    profile = np.where(s < 0.62, -0.25 + 1.25 * (s / 0.62) ** 1.5,
                       np.where(s < 0.7, 1 - 2 * (s - 0.62) / 0.08, -1 + 0.75 * (s - 0.7) / 0.3))
    p = profile * amp
    rgb = sand.copy()
    rgb = lerp(rgb, CREST_HI, np.clip(p, 0, 1) * 0.8)
    rgb = lerp(rgb, TROUGH * 0.9, np.clip(-p, 0, 1) * 0.88)

    # Small ripple packs between the fields, traced from the painted dunes image.
    src = np.array(Image.open(SRC / "dunes.png").convert("L")).astype(np.float32)
    # At 1:1 its ripples are about 13 px apart, like the reference; only the crests are traced,
    # and each gets the same short shadow below it as the big fields.
    rel = tile(cv2.GaussianBlur(src, (0, 0), 1.5) - cv2.GaussianBlur(src, (0, 0), 6))
    crest_p = np.clip((rel - 7) / 10, 0, 1)
    shadow_p = np.clip(np.roll(crest_p, 3, axis=0) - crest_p, 0, 1)
    outside = (1 - fields) * 0.8
    rgb = lerp(rgb, TROUGH * 0.92, shadow_p * outside * 0.7)
    rgb = lerp(rgb, CREST_HI, crest_p * outside * 0.7)
    return rgb


def rubble(foot: np.ndarray, rock_tex: np.ndarray, rgb: np.ndarray, alpha: np.ndarray, chance: float) -> None:
    """Loose stones along the foot of a rock."""
    near = np.zeros((H, W), bool)
    for k in (1, 2, 3):
        near |= shift(foot, 0, k)
    near &= ~foot
    ys, xs = np.nonzero(near & (rng.random((H, W)) < chance))
    for y, x in zip(ys, xs):
        base = rock_tex[y, x]
        for dx, dy, c in ((1, 1, SHADOW_DARK), (0, 0, base * 1.25), (1, 0, base), (0, 1, base * 0.8)):
            if 0 <= y + dy < H and 0 <= x + dx < W and not foot[y + dy, x + dx]:
                rgb[y + dy, x + dx] = c
                alpha[y + dy, x + dx] = 1.0


def cast_shadow(foot: np.ndarray, offset: tuple[int, int], rgb: np.ndarray, alpha: np.ndarray) -> None:
    """Shadow down-right plus a soft contact darkening all round (ambient occlusion)."""
    sh = cv2.GaussianBlur(shift(foot, *offset).astype(np.float32), (0, 0), 1.4) * 0.62
    ao = cv2.GaussianBlur(foot.astype(np.float32), (0, 0), 3.0) * 0.3
    a = np.maximum(sh, ao)
    sel = (a > 0.03) & ~foot & (alpha < 0.99)
    rgb[sel] = SHADOW_DARK
    alpha[sel] = np.maximum(alpha[sel], a[sel])


def edge_ring(piece: np.ndarray, col: np.ndarray, rgb: np.ndarray, soft: bool) -> None:
    """Outline a rock piece. Hard: a black line all round (tests 1-2). Soft (test 3): a lit rim on
    edges facing the top-left and a darkened edge (not black) facing down-right, like the reference."""
    ring = piece & ~cv2.erode(piece.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    if not soft:
        rgb[ring] = OUTLINE
        return
    lit = ring & (~shift(piece, 0, 1) | ~shift(piece, 1, 0))
    dark = ring & ~lit
    rgb[lit] = lerp(col[lit], ROCK_LIGHT, 0.55)
    rgb[dark] = col[dark] * 0.4


def render_rock2(top: np.ndarray, wall_h: int, rgb: np.ndarray, alpha: np.ndarray, tex: dict,
                 offset: tuple[int, int] = (5, 4), soft: bool = False) -> np.ndarray:
    hcol = (wall_h - 1 + np.floor(noise(4)[0] * 3)).astype(np.int32)  # slightly jagged foot, per column
    wall_k = np.zeros((H, W), np.int32)
    for k in range(int(hcol.max()), 0, -1):
        wall_k[shift(top, 0, k) & ~top & (k <= hcol[None, :])] = k
    wall = wall_k > 0
    foot = top | wall
    cast_shadow(foot, offset, rgb, alpha)

    # Top: painted rock, re-lit from the top-left with its height map and a bevelled rim.
    height = tex["rock_h"] * 0.02 + np.minimum(dist_inside(top), 4.0) * 0.8
    shade = np.clip(lambert(cv2.GaussianBlur(height, (0, 0), 1.0)) * 1.6, -1, 1)
    col = tex["rock"] * (1 + 0.35 * shade[..., None])
    col[tex["rock_cracks"]] = lerp(col[tex["rock_cracks"]], DEEP, 0.8)

    # Front wall: the painted cliff strip, sampled by depth, darker towards the jagged foot.
    strip = tex["wall"]
    sh_, sw_ = strip.shape[:2]
    frac = (wall_k - 1) / np.maximum(hcol[None, :] - 1, 1)
    rows = np.clip((frac * (sh_ - 1)).astype(np.int32), 0, sh_ - 1)
    cols = (XX.astype(np.int32) % sw_)
    wall_col = strip[rows, cols] * (1.05 - 0.4 * frac[..., None])
    wall_col[wall_k == 1] = lerp(wall_col[wall_k == 1], ROCK_LIGHT, 0.5)  # lit lip
    col = np.where(wall[..., None], wall_col, col)

    rgb[foot] = col[foot]
    alpha[foot] = 1.0
    edge_ring(foot, col, rgb, soft)
    rubble(foot, tex["rock"], rgb, alpha, 0.035)
    return foot


def render_stepped_rock(top: np.ndarray, rgb: np.ndarray, alpha: np.ndarray, tex: dict,
                        soft: bool = False) -> np.ndarray:
    """The Orichalcum rock as a pile of slabs, each raised to its own height with its own front face,
    highest in the middle, drawn back to front."""
    cx, cy, rx, ry = ROCK_CORE
    labels = voronoi(14)
    slabs = []
    for lab in np.unique(labels[top]):
        region = (labels == lab) & top
        if region.sum() < 8:
            continue
        ys, xs = np.nonzero(region)
        centre = np.hypot((xs.mean() - cx) / rx, (ys.mean() - cy) / ry)
        raise_by = int(np.clip(2 + 6 * (1 - centre) + rng.integers(0, 3), 2, 9))
        slabs.append((ys.max(), region, raise_by))
    whole = np.zeros((H, W), bool)
    for _, region, r in slabs:
        for k in range(r + 1):
            whole |= shift(region, 0, -k)
    cast_shadow(whole, (3, 3), rgb, alpha)
    strip = tex["wall"]
    sh_, sw_ = strip.shape[:2]
    for _, region, r in sorted(slabs, key=lambda t: t[0]):
        top_i = shift(region, 0, -r)
        face = np.zeros((H, W), bool)
        face_k = np.zeros((H, W), np.int32)
        for k in range(r - 1, -1, -1):
            layer = shift(region, 0, -k) & ~top_i
            face_k[layer & ~face] = r - k
            face |= layer
        rows = np.clip(((face_k - 1) / max(r - 1, 1) * (sh_ - 1)).astype(np.int32), 0, sh_ - 1)
        face_col = strip[rows, XX.astype(np.int32) % sw_] * 0.62  # faces darker than tops: the steps read
        height = tex["rock_h"] * 0.02 + np.minimum(dist_inside(top_i), 3.0) * 0.9
        shade = np.clip(lambert(height) * 1.8, -1, 1)
        top_col = shift_img(tex["rock"], -r) * (1.5 + 0.4 * shade[..., None])  # lit slab tops
        rgb[face] = face_col[face]
        rgb[top_i] = top_col[top_i]
        alpha[face | top_i] = 1.0
        piece = face | top_i
        edge_ring(piece, np.where(face[..., None], face_col, top_col), rgb, soft)
    return whole


def shift_img(img: np.ndarray, dy: int) -> np.ndarray:
    return np.roll(img, dy, axis=0)


def place_crystals(rgb: np.ndarray, alpha: np.ndarray, rock: np.ndarray) -> None:
    """Small faceted crystals, densest in the middle, each lit top-left, with a warm glow.
    The painted crystals.png cluster turns into an orange smear at 44 px, so these are drawn."""
    cx, cy, rx, ry = ROCK_CORE
    inner = rock & (dist_inside(rock) > 3)
    ys, xs = np.nonzero(inner)
    weight = np.exp(-(((xs - cx) / (rx * 0.5)) ** 2 + ((ys - cy + 6) / (ry * 0.5)) ** 2))
    glow = np.zeros((H, W), np.float32)
    picks = rng.choice(len(ys), 55, replace=False, p=weight / weight.sum())
    light, mid, dark = np.array([255, 246, 190.]), np.array([255, 196, 60.]), np.array([196, 104, 20.])
    for i in sorted(picks, key=lambda k: ys[k]):
        x, y = xs[i], ys[i]
        tall = int(rng.integers(2, 4))
        for dy in range(-tall, 2):
            half = 1 if -tall < dy < 1 else 0
            for dx in range(-half, half + 1):
                if 0 <= x + dx < W and 0 <= y + dy < H:
                    rgb[y + dy, x + dx] = light if (dx < 0 or dy == -tall) else (dark if dx > 0 or dy == 1 else mid)
                    alpha[y + dy, x + dx] = 1.0
        glow[y, x] = 1.0
    glow = cv2.GaussianBlur(glow, (0, 0), 3.5) * 9
    on_rock = rock & (glow > 0.03)
    rgb[on_rock] = lerp(rgb[on_rock], GOLD, np.clip(glow[on_rock], 0, 0.45))


def place_crystals_painted(rgb: np.ndarray, alpha: np.ndarray, rock: np.ndarray) -> None:
    """Kept for reference: the painted cluster shrunk to 44 px (style test 2, first pass)."""
    src = np.array(Image.open(SRC / "crystals.png").convert("RGB")).astype(np.float32)
    a = np.clip((src.max(2) - 22) / 50, 0, 1)
    ys, xs = np.nonzero(a > 0.05)
    src, a = src[ys.min():ys.max() + 1, xs.min():xs.max() + 1], a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    width = 44
    size = (width, round(src.shape[0] * width / src.shape[1]))
    pre = cv2.resize(src * a[..., None], size, interpolation=cv2.INTER_AREA)
    a_s = cv2.resize(a, size, interpolation=cv2.INTER_AREA)
    col = pre / np.maximum(a_s[..., None], 1e-3)
    cx, cy = ROCK_CORE[0], ROCK_CORE[1] - 7
    x0, y0 = cx - size[0] // 2, cy - size[1] // 2
    region = (slice(y0, y0 + size[1]), slice(x0, x0 + size[0]))
    keep = (a_s > 0.5) & rock[region] & (col.max(2) > 120)  # crystals only, not the dark rock
    # Glow: warm light on the rock around the crystals.
    glow = np.zeros((H, W), np.float32)
    glow[region] = cv2.GaussianBlur(a_s, (0, 0), 4) * 0.35
    on_rock = rock & (glow > 0.02)
    rgb[on_rock] = lerp(rgb[on_rock], GOLD, glow[on_rock])
    rgb[region][keep] = col[keep]
    alpha[region][keep] = 1.0


def place_crystals2(rgb: np.ndarray, alpha: np.ndarray, rock: np.ndarray) -> None:
    """Test 3: the owner's crystals2.png (fewer, bigger crystals) shrunk to 66 px; only the bright
    crystals are kept, sitting on the tool-made slab pile, with a warm glow."""
    place_crystals2_sized(rgb, alpha, rock, 66)


def place_crystals2_sized(rgb: np.ndarray, alpha: np.ndarray, rock: np.ndarray, width: int) -> None:
    src = np.array(Image.open(SRC / "crystals2.png").convert("RGB")).astype(np.float32)
    a = np.clip((src.max(2) - 22) / 50, 0, 1)
    ys, xs = np.nonzero(a > 0.05)
    src = src[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    size = (width, round(src.shape[0] * width / src.shape[1]))
    col = cv2.resize(src, size, interpolation=cv2.INTER_AREA)
    bright = col.max(2) > 175
    cx, cy = ROCK_CORE[0], ROCK_CORE[1] - 6
    x0, y0 = cx - size[0] // 2, cy - size[1] // 2
    region = (slice(y0, y0 + size[1]), slice(x0, x0 + size[0]))
    keep = bright & rock[region]
    glow = np.zeros((H, W), np.float32)
    glow[region] = cv2.GaussianBlur(keep.astype(np.float32), (0, 0), 3.0) * 1.2
    on_rock = rock & (glow > 0.03)
    rgb[on_rock] = lerp(rgb[on_rock], GOLD, np.clip(glow[on_rock], 0, 0.5))
    rgb[region][keep] = col[keep] * 1.08
    alpha[region][keep] = 1.0


def make_rocks2(tex: dict, soft: bool = False, crystals=None) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)
    feet = np.zeros((H, W), bool)
    for parts, wall_h in CLIFFS:
        wall_h += 2
        top = blob(parts)
        jag = (noise(5) - 0.5) > 0.32  # nibble small bites out of the rim
        top &= ~(jag & (dist_inside(top) < 3))
        feet |= render_rock2(top, wall_h, rgb, alpha, tex, soft=soft)
    cx, cy, rx, ry = ROCK_CORE
    top = blob([ROCK_CORE, (cx - 30, cy + 8, 26, 22), (cx + 28, cy - 6, 26, 24)], 0.45)
    rock = render_stepped_rock(top, rgb, alpha, tex, soft=soft)
    (crystals or place_crystals)(rgb, alpha, rock)
    feet |= rock
    rubble(rock, tex["rock"], rgb, alpha, 0.05)
    return rgb, alpha, feet


def make_road2(feet: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    tex = match_colour(seamless(load_source("road.png", SHRINK["road.png"])), "road")
    hsrc = np.array(Image.open(SRC / "road_height.png").convert("L")).astype(np.float32)
    crack_src = (hsrc < cv2.GaussianBlur(hsrc, (0, 0), 6) - 14).astype(np.float32)
    crack = cv2.resize(crack_src, (tex.shape[1], tex.shape[0]), interpolation=cv2.INTER_AREA) > 0.12
    ox, oy = int(rng.integers(0, tex.shape[1])), int(rng.integers(0, tex.shape[0]))
    col, crack = tile(tex, ox, oy), tile(crack, ox, oy)
    col[crack] = lerp(col[crack], ROAD_JOINT, 0.45)

    dist = np.full((H, W), 1e9, np.float32)
    pts = np.array(ROAD_LINE, np.float32)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((XX - a[0]) * ab[0] + (YY - a[1]) * ab[1]) / (ab @ ab), 0, 1)
        dist = np.minimum(dist, np.hypot(XX - a[0] - t * ab[0], YY - a[1] - t * ab[1]))
    ragged = (fbm(30, 12, 5) - 0.5) * 7 + (rng.random((H, W)) - 0.5) * 1.2
    cx, cy, rx, ry = PLAZA
    plaza = 1 - ((XX - cx) / rx) ** 2 - ((YY - cy) / ry) ** 2 + (fbm(36, 14) - 0.5) * 0.25 \
        + (rng.random((H, W)) - 0.5) * 0.03 > 0
    road = (((dist + ragged) < 12.5) | plaza) & ~feet
    edge = 1 - smoothstep(0, 3.5, dist_inside(road))
    col = lerp(col, SAND * 0.97, 0.45 * edge)  # sand blown over the edges
    alpha = road.astype(np.float32)
    for t in np.arange(0, 2 * np.pi, 2 * np.pi / 64):
        x = int(cx + (rx + 7) * np.cos(t))
        y = int(cy + (ry + 7) * np.sin(t))
        if 0 < x < W - 2 and 0 < y < H - 2 and not road[y, x] and not feet[y, x]:
            col[y, x] = MARKER
            col[y + 1, x + 1] = SHADOW_DARK
            alpha[y, x] = 1.0
            alpha[y + 1, x + 1] = 0.6
    return col, alpha


def make_test2() -> None:
    (OUT / "t2").mkdir(exist_ok=True)
    sand = make_sand2()
    save("t2/sand.png", sand)
    save("t2/sand_dunes.png", make_dunes2(sand))
    rock = match_colour(seamless(load_source("rock_top.png", SHRINK["rock_top.png"])), "rock")
    rock_h = seamless(load_source("rock_top_height.png", SHRINK["rock_top.png"], gray=True))
    ox, oy = int(rng.integers(0, rock.shape[1])), int(rng.integers(0, rock.shape[0]))
    wall = match_colour(load_source("cliff_wall.png", SHRINK["cliff_wall.png"]), "wall")
    # Cracks: pixels clearly lower than their surroundings in the (already aligned) height map.
    cracks = rock_h < cv2.GaussianBlur(rock_h, (0, 0), 3) - 14
    tex = {"rock": tile(rock, ox, oy), "rock_h": tile(rock_h, ox, oy), "rock_cracks": tile(cracks, ox, oy), "wall": wall}
    rocks_rgb, rocks_a, feet = make_rocks2(tex)
    road_rgb, road_a = make_road2(feet)
    save("t2/road.png", road_rgb, road_a)
    save("t2/rocks.png", rocks_rgb, rocks_a)
    sc_rgb, sc_a = make_scatter(feet | (road_a > 0))
    save("t2/scatter.png", sc_rgb, sc_a)


# --- style test 3: constant sand relief, owner's second inputs, kitbash scatter, soft edges ------
# The reference sand varies 2-4x more than test 2 at 5-30 px sizes (measured: light std 7.3 / 8.0
# vs 3.1 / 1.9) and its colour varies more. Average brightness and saturation were already equal.

KITBASH = ROOT / "assets" / "textures" / "kitbash"
SAND_RIPPLED = ((229, 136, 41), (30, 30, 12))  # whole reference sand, ripples included


def warp_image(img: np.ndarray, amp_x: float, amp_y: float, cell: int) -> np.ndarray:
    """Bend a tiled texture with smooth offsets so its rows curve and repeats hide."""
    dx = amp_x * (fbm(cell, cell // 2) - 0.5) * 2
    dy = amp_y * (fbm(cell, cell // 2) - 0.5) * 2
    return cv2.remap(img.astype(np.float32), XX + dx, YY + dy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def make_sand3() -> np.ndarray:
    """dunes2.png (a dense ripple field) as the ground, bent so rows curve, plus a gentle rolling
    relief lit from the top-left and slow shifts between redder and yellower sand."""
    flat = load_source("dunes2.png", 2.3)
    tex = flat.reshape(-1, 3)
    mu, sd = tex.mean(0), tex.std(0) + 1e-3
    mean_t, std_t = (np.array(v, np.float32) for v in SAND_RIPPLED)
    base = (seamless(flat) - mu) * np.clip(std_t / sd, 0.3, 3) + mean_t
    rgb = warp_image(tile(base), 26, 14, 160)
    # Fine grain from sand.png on top: dunes2 loses its grain when shrunk.
    grain = load_source("sand.png", SHRINK["sand.png"]).mean(2)
    grain = tile(seamless(grain - cv2.GaussianBlur(grain, (0, 0), 2)))
    rgb += grain[..., None] * 1.1
    relief = (fbm(64, 32, 16) - 0.5) * 2 * RELIEF
    p = np.clip(lambert(relief) * 3.2, -1, 1)
    rgb = lerp(rgb, CREST_HI, np.clip(p, 0, 1) * 0.55)
    rgb = lerp(rgb, TROUGH * 0.92, np.clip(-p, 0, 1) * 0.6)
    hue = (noise(90) - 0.5) * 2
    rgb = lerp(rgb, np.array([236, 118, 30], np.float32), np.clip(-hue, 0, 1) * 0.32)  # redder
    rgb = lerp(rgb, np.array([246, 170, 56], np.float32), np.clip(hue, 0, 1) * 0.32)  # yellower
    return rgb


RELIEF = 16.0


def make_dunes3(sand: np.ndarray) -> np.ndarray:
    """A few bigger dune fields over the rippled ground: shorter rows, deeper shadows. Kept near the
    ground ripples' own direction; crossing them at an angle looked crosshatched."""
    angle = -0.08 + 0.25 * (fbm(220, 110) - 0.5)
    warp = 30 * (fbm(90, 45) - 0.5)
    across = YY * np.cos(angle) - XX * np.sin(angle) + warp
    along = XX * np.cos(angle) + YY * np.sin(angle)
    phase = across / 17.0
    s = phase - np.floor(phase)
    fields = smoothstep(0.52, 0.64, fbm(260, 130, 65))
    segments = smoothstep(0.38, 0.52, stretched_noise(along, np.floor(phase) * 3.1 + 7, 20, 1))
    amp = fields * segments
    profile = np.where(s < 0.62, -0.25 + 1.25 * (s / 0.62) ** 1.5,
                       np.where(s < 0.7, 1 - 2 * (s - 0.62) / 0.08, -1 + 0.75 * (s - 0.7) / 0.3))
    p = profile * amp
    rgb = lerp(sand, CREST_HI, np.clip(p, 0, 1) * 0.8)
    return lerp(rgb, TROUGH * 0.8, np.clip(-p, 0, 1) * 0.95)


def kitbash_sprite(name: str, scale: float = 1.0) -> np.ndarray:
    im = Image.open(KITBASH / name).convert("RGBA")
    if scale != 1.0:
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    return np.array(im).astype(np.float32)


def make_scatter_kitbash(blocked: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Pebbles, specks and shrubs from the Desert Kitbash Mini-Map, each with its own soft shadow."""
    rgba = np.zeros((H, W, 4), np.float32)
    kinds = ([(f"pebble_{i}.png", 0.6, 9) for i in range(6)] + [(f"speck_{i}.png", 1.0, 22) for i in range(6)]
             + [(f"shrub_{i}.png", SHRUB_SCALE, 6) for i in range(6)])
    for name, scale, count in kinds:
        spr = kitbash_sprite(name, scale)
        h, w = spr.shape[:2]
        for _ in range(count):
            x, y = int(rng.integers(0, W - w)), int(rng.integers(0, H - h))
            if blocked[y:y + h, x:x + w].any():
                continue
            a = spr[..., 3:4] / 255
            dst = rgba[y:y + h, x:x + w]
            dst[..., :3] = spr[..., :3] * a + dst[..., :3] * (1 - a)
            dst[..., 3:4] = np.maximum(dst[..., 3:4], a)
    rgb = rgba[..., :3]
    alpha = np.where(rgba[..., 3] > 0.5, 1.0, rgba[..., 3])  # solid sprites, soft shadows
    return rgb, alpha


SHRUB_SCALE = 0.75


def make_test3() -> None:
    (OUT / "t3").mkdir(exist_ok=True)
    sand = make_sand3()
    save("t3/sand.png", sand)
    save("t3/sand_dunes.png", make_dunes3(sand))
    rock = match_colour(seamless(load_source("rock_top.png", SHRINK["rock_top.png"])), "rock")
    rock_h = seamless(load_source("rock_top_height.png", SHRINK["rock_top.png"], gray=True))
    ox, oy = int(rng.integers(0, rock.shape[1])), int(rng.integers(0, rock.shape[0]))
    wall = match_colour(load_source("cliff_wall2.png", SHRINK["cliff_wall.png"]), "wall")
    cracks = rock_h < cv2.GaussianBlur(rock_h, (0, 0), 3) - 14
    tex = {"rock": tile(rock, ox, oy), "rock_h": tile(rock_h, ox, oy), "rock_cracks": tile(cracks, ox, oy), "wall": wall}
    rocks_rgb, rocks_a, feet = make_rocks2(tex, soft=True, crystals=place_crystals2)
    road_rgb, road_a = make_road2(feet)
    save("t3/road.png", road_rgb, road_a)
    save("t3/rocks.png", rocks_rgb, rocks_a)
    sc_rgb, sc_a = make_scatter_kitbash(feet | (road_a > 0))
    save("t3/scatter.png", sc_rgb, sc_a)


# --- style test 4: orderly dunes -----------------------------------------------------------------
# Test 3 matched the reference's numbers but looked messy: its ripples were soft smeared swells
# under blotchy relief, and the scatter was big, dark and everywhere. The reference's crests are
# crisp lines at an even spacing, in long parallel rows that follow one wind, with calm sand
# between the rows' fields, and small, sparse scatter.

WIND = -0.17          # radians: crests run slightly up to the right, as in the reference
RIPPLE_GAP = 17.0     # art px between crests


def wind_coords(warp_amp: float = 8.0) -> tuple[np.ndarray, np.ndarray]:
    warp = warp_amp * (fbm(320, 160) - 0.5) * 2  # long, gentle bends only
    across = YY * np.cos(WIND) - XX * np.sin(WIND) + warp
    along = XX * np.cos(WIND) + YY * np.sin(WIND)
    return across, along


def make_sand4() -> np.ndarray:
    """Grainy flat sand with broad swells stretched along the wind (not round blotches), and
    slow drifts between redder and yellower sand."""
    tex = match_colour(seamless(load_source("sand.png", SHRINK["sand.png"])), "sand")
    rgb = tile(tex)
    across, along = wind_coords()
    swell = (stretched_noise(along, across, 220, 70) - 0.5) * 2 * 22.0
    p = np.clip(lambert(swell) * 3.0, -1, 1)
    rgb = lerp(rgb, CREST_HI, np.clip(p, 0, 1) * 0.45)
    rgb = lerp(rgb, TROUGH * 0.92, np.clip(-p, 0, 1) * 0.5)
    hue = (stretched_noise(along, across, 260, 120) - 0.5) * 2
    rgb = lerp(rgb, np.array([236, 118, 30], np.float32), np.clip(-hue, 0, 1) * 0.3)
    rgb = lerp(rgb, np.array([246, 170, 56], np.float32), np.clip(hue, 0, 1) * 0.3)
    return rgb


def distance_to_road() -> np.ndarray:
    """Art px from the road's centre line or the plaza round the Orichalcum rock."""
    dist = np.full((H, W), 1e9, np.float32)
    pts = np.array(ROAD_LINE, np.float32)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((XX - a[0]) * ab[0] + (YY - a[1]) * ab[1]) / (ab @ ab), 0, 1)
        dist = np.minimum(dist, np.hypot(XX - a[0] - t * ab[0], YY - a[1] - t * ab[1]))
    cx, cy, rx, ry = PLAZA
    plaza = np.maximum(np.hypot((XX - cx) / rx, (YY - cy) / ry) - 1, 0) * min(rx, ry)
    return np.minimum(dist, plaza)


def make_dunes4(sand: np.ndarray) -> np.ndarray:
    """Dunes where the reference has them: big fields towards the edges, calm sand in a wide band
    round the road and plaza. Inside a field the ripples are strong and crisp, an even 15 px apart,
    in long rows following one wind that turns only slowly across the map."""
    angle = WIND + 0.3 * (fbm(400, 200) - 0.5)
    along = XX * np.cos(angle) + YY * np.sin(angle)
    across0 = YY * np.cos(angle) - XX * np.sin(angle)
    # Crests wave gently along their length (about every 80 px), and neighbouring rows wave
    # together, so the field stays orderly instead of straight like a comb.
    wave = (stretched_noise(along, across0, 42, 170) - 0.5) * 2 * 7.0
    across = across0 + 8.0 * (fbm(320, 160) - 0.5) * 2 + wave
    phase = across / RIPPLE_GAP
    s = phase - np.floor(phase)
    row = np.floor(phase)
    calm = distance_to_road()
    fields = smoothstep(45, 105, calm + 40 * (fbm(120, 60) - 0.5))       # calm round road and plaza
    fields *= smoothstep(0.25, 0.4, stretched_noise(along, across, 320, 120))  # a few calm gaps elsewhere
    rows = smoothstep(0.22, 0.36, stretched_noise(along, row * 3.1 + 7, 80, 1))  # rows end now and then
    amp = fields * rows
    # One ripple: a broad lit face rising to a sharp crest, a sharp dark shadow below it that
    # fades out, then plain sand until the next lit face.
    lit = np.clip((s - 0.15) / 0.49, 0, 1) ** 1.4 * (s < 0.64)
    shadow = np.where((s >= 0.64) & (s < 0.95), 1 - (s - 0.64) / 0.42, 0)
    rgb = lerp(sand, CREST_HI, (lit * amp * 0.85).astype(np.float32))
    return lerp(rgb, TROUGH * 0.85, (shadow * amp * 0.85).astype(np.float32))


def make_scatter4(blocked: np.ndarray, near: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Kitbash pebbles, specks and shrubs, smaller and sparser, gathered near rocks and the road
    (debris collects there) instead of spread evenly over open sand."""
    rgba = np.zeros((H, W, 4), np.float32)
    closeness = np.exp(-cv2.distanceTransform((~near).astype(np.uint8), cv2.DIST_L2, 3) / 40.0)
    kinds = ([(f"pebble_{i}.png", 0.45, 6) for i in range(6)] + [(f"speck_{i}.png", 0.8, 12) for i in range(6)]
             + [(f"shrub_{i}.png", 0.5, 4) for i in range(6)])
    for name, scale, count in kinds:
        spr = kitbash_sprite(name, scale)
        h, w = spr.shape[:2]
        placed = tries = 0
        while placed < count and tries < count * 40:
            tries += 1
            x, y = int(rng.integers(0, W - w)), int(rng.integers(0, H - h))
            if blocked[y:y + h, x:x + w].any() or rng.random() > 0.15 + 0.85 * closeness[y + h // 2, x + w // 2]:
                continue
            a = spr[..., 3:4] / 255
            dst = rgba[y:y + h, x:x + w]
            dst[..., :3] = spr[..., :3] * a + dst[..., :3] * (1 - a)
            dst[..., 3:4] = np.maximum(dst[..., 3:4], a)
            placed += 1
    alpha = np.where(rgba[..., 3] > 0.5, 1.0, rgba[..., 3])
    return rgba[..., :3], alpha


def place_crystals4(rgb: np.ndarray, alpha: np.ndarray, rock: np.ndarray) -> None:
    """crystals2 a little larger, plus small tool crystals around it so the field looks fuller."""
    place_crystals2_sized(rgb, alpha, rock, 78)
    cx, cy, rx, ry = ROCK_CORE
    ring = rock & (dist_inside(rock) > 3)
    ys, xs = np.nonzero(ring)
    d = np.hypot((xs - cx) / rx, (ys - cy) / ry)
    weight = np.exp(-((d - 0.55) / 0.2) ** 2)
    light, mid, dark = np.array([255, 246, 190.]), np.array([255, 196, 60.]), np.array([196, 104, 20.])
    for i in rng.choice(len(ys), 22, replace=False, p=weight / weight.sum()):
        x, y = xs[i], ys[i]
        for dy, dx, c in ((-2, 0, light), (-1, -1, light), (-1, 0, mid), (-1, 1, dark), (0, 0, mid), (1, 0, dark)):
            rgb[y + dy, x + dx] = c
            alpha[y + dy, x + dx] = 1.0


def make_test4() -> None:
    (OUT / "t4").mkdir(exist_ok=True)
    sand = make_sand4()
    save("t4/sand.png", sand)
    save("t4/sand_dunes.png", make_dunes4(sand))
    rock = match_colour(seamless(load_source("rock_top.png", SHRINK["rock_top.png"])), "rock") * 1.15  # lighter tops
    rock_h = seamless(load_source("rock_top_height.png", SHRINK["rock_top.png"], gray=True))
    ox, oy = int(rng.integers(0, rock.shape[1])), int(rng.integers(0, rock.shape[0]))
    wall = match_colour(load_source("cliff_wall2.png", SHRINK["cliff_wall.png"]), "wall")
    cracks = rock_h < cv2.GaussianBlur(rock_h, (0, 0), 3) - 14
    tex = {"rock": tile(rock, ox, oy), "rock_h": tile(rock_h, ox, oy), "rock_cracks": tile(cracks, ox, oy), "wall": wall}
    rocks_rgb, rocks_a, feet = make_rocks2(tex, soft=True, crystals=place_crystals4)
    road_rgb, road_a = make_road2(feet)
    save("t4/road.png", road_rgb, road_a)
    save("t4/rocks.png", rocks_rgb, rocks_a)
    road = road_a > 0
    sc_rgb, sc_a = make_scatter4(feet | road, feet | road)
    save("t4/scatter.png", sc_rgb, sc_a)


# --- style test 5: test 4's order with test 3's softer ripples, and cliff ledges -------------------
# The reference sits between tests 3 and 4: test 4's calm centre and wind-following fields, but
# softer, more varied ripples like the owner's dunes2.png. Here dunes2 is sampled along the wind
# (so its rows turn with it and wave together) and shown only inside test 4's fields.

def dune_fields(along: np.ndarray, across: np.ndarray) -> np.ndarray:
    calm = distance_to_road()
    fields = smoothstep(38, 90, calm + 40 * (fbm(120, 60) - 0.5))
    return fields * smoothstep(0.12, 0.3, stretched_noise(along, across, 320, 120))


def make_dunes5(sand: np.ndarray) -> np.ndarray:
    angle = WIND + 0.3 * (fbm(400, 200) - 0.5)
    along = XX * np.cos(angle) + YY * np.sin(angle)
    across0 = YY * np.cos(angle) - XX * np.sin(angle)
    wave = (stretched_noise(along, across0, 42, 170) - 0.5) * 2 * 6.0
    across = across0 + 8.0 * (fbm(320, 160) - 0.5) * 2 + wave
    flat = load_source("dunes2.png", 2.4)
    mu, sd = flat.reshape(-1, 3).mean(0), flat.reshape(-1, 3).std(0) + 1e-3
    mean_t, std_t = (np.array(v, np.float32) for v in SAND_RIPPLED)
    rip = seamless((flat - mu) * np.clip(std_t / sd, 0.3, 3) + mean_t)
    th, tw = rip.shape[:2]
    oy, ox = float(rng.integers(0, th)), float(rng.integers(0, tw))
    mx = np.mod(along + ox, tw).astype(np.float32)
    my = np.mod(across + oy, th).astype(np.float32)
    ripples = cv2.remap(rip.astype(np.float32), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    # Keep the sand's own colour and swells; take only the ripples' light and shade.
    lum = ripples.mean(2)
    rel = lum - cv2.GaussianBlur(lum, (0, 0), 10)
    amp = dune_fields(along, across0)
    p = np.clip(rel / 26.0, -1, 1) * amp
    rgb = lerp(sand, CREST_HI, np.clip(p, 0, 1) * 0.9)
    return lerp(rgb, TROUGH * 0.85, np.clip(-p, 0, 1) * 0.95)


def add_ledges(top: np.ndarray, rgb: np.ndarray, alpha: np.ndarray, tex: dict, rise: int = 7) -> None:
    """A higher terrace on a big cliff: an inner plateau raised by `rise` px with its own wall,
    casting a shadow down-right onto the lower level."""
    inner = (dist_inside(top) + 14 * (fbm(40, 20) - 0.5) * 2) > 26
    inner = cv2.morphologyEx(inner.astype(np.uint8), cv2.MORPH_OPEN, np.ones((7, 7), np.uint8)).astype(bool)
    if inner.sum() < 400:
        return
    upper = shift(inner, 0, -rise)
    lower_rgb = rgb.copy()
    foot = render_rock2(upper, rise, rgb, alpha, tex, soft=True)
    shade = cv2.GaussianBlur(shift(foot, 5, 4).astype(np.float32), (0, 0), 1.4) * 0.45
    on_lower = top & ~foot & (shade > 0.03)
    rgb[on_lower] = lower_rgb[on_lower] * (1 - shade[on_lower, None])


def make_rocks5(tex: dict) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)
    feet = np.zeros((H, W), bool)
    for parts, wall_h in CLIFFS:
        wall_h += 2
        top = blob(parts)
        jag = (noise(5) - 0.5) > 0.32
        top &= ~(jag & (dist_inside(top) < 3))
        feet |= render_rock2(top, wall_h, rgb, alpha, tex, soft=True)
        if wall_h >= 11:
            add_ledges(top, rgb, alpha, tex)
    cx, cy, rx, ry = ROCK_CORE
    top = blob([ROCK_CORE, (cx - 30, cy + 8, 26, 22), (cx + 28, cy - 6, 26, 24)], 0.45)
    rock = render_stepped_rock(top, rgb, alpha, tex, soft=True)
    place_crystals4(rgb, alpha, rock)
    feet |= rock
    rubble(rock, tex["rock"], rgb, alpha, 0.05)
    return rgb, alpha, feet


def make_test5() -> None:
    (OUT / "t5").mkdir(exist_ok=True)
    sand = make_sand4()
    save("t5/sand.png", sand)
    save("t5/sand_dunes.png", make_dunes5(sand))
    rock = match_colour(seamless(load_source("rock_top.png", SHRINK["rock_top.png"])), "rock") * 1.15
    rock_h = seamless(load_source("rock_top_height.png", SHRINK["rock_top.png"], gray=True))
    ox, oy = int(rng.integers(0, rock.shape[1])), int(rng.integers(0, rock.shape[0]))
    wall = match_colour(load_source("cliff_wall2.png", SHRINK["cliff_wall.png"]), "wall")
    cracks = rock_h < cv2.GaussianBlur(rock_h, (0, 0), 3) - 14
    tex = {"rock": tile(rock, ox, oy), "rock_h": tile(rock_h, ox, oy), "rock_cracks": tile(cracks, ox, oy), "wall": wall}
    rocks_rgb, rocks_a, feet = make_rocks5(tex)
    road_rgb, road_a = make_road2(feet)
    save("t5/road.png", road_rgb, road_a)
    save("t5/rocks.png", rocks_rgb, rocks_a)
    road = road_a > 0
    sc_rgb, sc_a = make_scatter4(feet | road, feet | road)
    save("t5/scatter.png", sc_rgb, sc_a)


# --- scene --------------------------------------------------------------------------------------

LAYERS = ["sand.png", "sand_dunes.png", "road.png", "rocks.png", "scatter.png"]


def write_scene() -> None:
    tex = LAYERS + [f"t{n}/{t}" for n in (2, 3, 4, 5) for t in LAYERS] + ["reference_half.png"]
    tex += sorted({u[0] for u in UNITS})
    lines = ["[gd_scene format=3]", "",
             '[ext_resource type="Script" path="res://scripts/rts/rts_style_test.gd" id="script"]']
    ids = {}
    for i, t in enumerate(tex):
        ids[t] = f"t{i}"
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/textures/rts/style_test/{t}" id="t{i}"]')
    lines += ["", '[node name="RtsStyleTest" type="Node2D"]', "texture_filter = 1", 'script = ExtResource("script")', ""]

    def sprite(name, t, parent=".", pos=None, centered=False, visible=True, z=None):
        lines.append(f'[node name="{name}" type="Sprite2D" parent="{parent}"]')
        if z is not None:
            lines.append(f"z_index = {z}")
        if not visible:
            lines.append("visible = false")
        lines.append(f'texture = ExtResource("{ids[t]}")')
        if not centered:
            lines.append("centered = false")
        if pos:
            lines.append(f"position = Vector2({pos[0]}, {pos[1]})")
        lines.append("")

    for group, prefix, visible in (("Test1", "", False), ("Test2", "t2/", False), ("Test3", "t3/", False),
                                   ("Test4", "t4/", False), ("Test5", "t5/", True)):
        lines += [f'[node name="{group}" type="Node2D" parent="."]'] + ([] if visible else ["visible = false"]) + [""]
        for node, t in zip(("Sand", "Dunes", "Road", "Rocks", "Scatter"), LAYERS):
            sprite(node, prefix + t, group)
    lines += ['[node name="Units" type="Node2D" parent="."]', "y_sort_enabled = true", ""]
    for i, (t, x, y) in enumerate(UNITS):
        sprite(f"Unit{i + 1}", t, "Units", (x, y), centered=True)
    sprite("Reference", "reference_half.png", visible=False, z=10)
    lines += ['[node name="Camera" type="Camera2D" parent="."]', f"position = Vector2({W // 2}, {H // 2})",
              "zoom = Vector2(1.3333, 1.3333)", "",
              '[node name="HUD" type="CanvasLayer" parent="."]', "",
              '[node name="Help" type="Label" parent="HUD"]',
              "offset_left = 10.0", "offset_top = 6.0", "offset_right = 1270.0", "offset_bottom = 30.0",
              "mouse_filter = 2", "theme_override_colors/font_outline_color = Color(0, 0, 0, 0.85)",
              "theme_override_constants/outline_size = 5", "theme_override_font_sizes/font_size = 14", ""]
    SCENE.write_text("\n".join(lines))


def main() -> None:
    global PALETTE
    PALETTE = rts_palette.load_palette()
    OUT.mkdir(parents=True, exist_ok=True)
    sand = make_sand()
    save("sand.png", sand)
    save("sand_dunes.png", make_dunes(sand))
    rocks_rgb, rocks_a, feet = make_rocks()
    road_rgb, road_a = make_road(feet)
    save("road.png", road_rgb, road_a)
    save("rocks.png", rocks_rgb, rocks_a)
    blocked = feet | (road_a > 0)
    sc_rgb, sc_a = make_scatter(blocked)
    save("scatter.png", sc_rgb, sc_a)
    make_units()
    make_test2()
    make_test3()
    make_test4()
    make_test5()
    ref = Image.open(ROOT / "docs" / "references" / "rts_mission1_desert_red.webp").convert("RGB")
    ref.resize((ref.width // 2, ref.height // 2), Image.BOX).save(OUT / "reference_half.png")
    write_scene()
    (OUT / "README.md").write_text(
        "Generated by tools/python/make_rts_style_test.py (procedural, palette-mapped). "
        "reference_half.png is docs/references/rts_mission1_desert_red.webp at art scale, for comparison only; "
        "do not ship it.\n")
    print("Wrote layers to", OUT, "and", SCENE)


PALETTE = None

if __name__ == "__main__":
    main()
