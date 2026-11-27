"""Art for the forest kit of RTS Mission 1 – Forest (scenes/rts/forest_kit/).

Writes assets/textures/rts/forest_kit/<piece>_hd.png (2x, Detailed) and <piece>_pixel.png (1x, Pixel)
for every forest piece, plus the forest's ground and road (sand_tile_*, road_strip_*; the battlefield
loads its ground and road under those names from the kit's art folder).

Two sources, per piece:
  1. The owner's ChatGPT paintings in assets/source_inputs/forest_kit/ (see PROMPTS.md there). When a
     sheet is present, it is cut into its pieces (by transparency), fitted to the piece's size and used.
  2. Otherwise a procedural STAND-IN drawn here at Carbon's camera (near-overhead, light from the
     upper left), so the map and mechanics can be built before the paintings exist.

Idempotent; rerun after saving a painting:
    C:/Python312/python.exe tools/python/make_forest_kit.py
    C:/Python312/python.exe tools/python/make_forest_kit.py --stand-ins   (ignore paintings)
"""

from __future__ import annotations

import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/textures/rts/forest_kit"
SRC = ROOT / "assets/source_inputs/forest_kit"
LIGHT = np.array([-0.5, -0.7, 0.75]) / np.linalg.norm([-0.5, -0.7, 0.75])

# piece_id -> world size (the HD painting is twice this many pixels)
SIZES = {
    "dirt_clearing_plaza": (400, 288),
    "dirt_patch_round": (112, 96),
    "dirt_patch_long": (176, 80),
    "gravel_pad_base": (288, 224),
    "gravel_field": (288, 208),
    "grass_flowers": (40, 30),
    "grass_stones": (40, 30),
    "fern_patch": (48, 36),
    "tree_cluster_large": (288, 224),
    "tree_cluster_medium": (192, 156),
    "tree_cluster_small": (128, 108),
    "conifer_tree": (64, 64),
    "broadleaf_tree": (72, 66),
    "broadleaf_tree_tall": (84, 78),
    "forest_verge": (192, 56),
    "river": (256, 112),  # one tile of the river strip; the Line2D course repeats it
    "river_ford": (176, 136),
    "river_bridge": (104, 144),
    "mossy_boulder": (44, 38),
    "mossy_boulder_pair": (76, 52),
    "mossy_slab": (88, 48),
    "fallen_log": (112, 36),
    "tree_stump": (28, 24),
}

# Reference palette (sampled from docs/references/rts_mission1_forest_blue.webp, brightened for sun)
GRASS = [(0.0, (70, 92, 24)), (0.45, (120, 128, 36)), (0.8, (156, 152, 48)), (1.0, (190, 178, 70))]
DIRT = [(0.0, (112, 72, 34)), (0.5, (168, 116, 56)), (0.85, (204, 148, 82)), (1.0, (226, 178, 112))]
GRAVEL = [(0.0, (58, 54, 50)), (0.45, (98, 90, 82)), (0.8, (134, 126, 116)), (1.0, (170, 162, 150))]
CONIFER = [(0.0, (6, 26, 22)), (0.35, (18, 58, 46)), (0.7, (40, 92, 62)), (1.0, (96, 140, 82))]
BROADLEAF = [(0.0, (14, 40, 14)), (0.35, (48, 92, 24)), (0.7, (112, 146, 36)), (1.0, (196, 204, 82))]
EMERALD = [(0.0, (8, 36, 22)), (0.35, (26, 86, 44)), (0.7, (64, 140, 64)), (1.0, (150, 200, 108))]
ROCK = [(0.0, (46, 44, 42)), (0.45, (96, 92, 86)), (0.8, (146, 140, 128)), (1.0, (186, 180, 166))]
MOSS = [(0.0, (34, 58, 16)), (0.5, (88, 120, 30)), (1.0, (170, 186, 64))]
BARK = [(0.0, (42, 26, 14)), (0.5, (92, 60, 32)), (1.0, (156, 112, 64))]
WATER = [(0.0, (18, 58, 92)), (0.5, (34, 104, 148)), (0.85, (70, 156, 186)), (1.0, (186, 228, 236))]
WOOD = [(0.0, (60, 36, 18)), (0.5, (124, 84, 44)), (1.0, (196, 150, 92))]


# --- helpers -------------------------------------------------------------------------------------

def ramp(t: np.ndarray, stops) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0)
    xs = [s[0] for s in stops]
    out = np.zeros(t.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(t, xs, [s[1][c] for s in stops])
    return out


def pnoise(h: int, w: int, beta: float, rng, lo_cut: float = 0.0) -> np.ndarray:
    """Periodic 1/f^beta noise (tiles in both axes), zero mean, unit std."""
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta)
    amp[f < lo_cut] = 0.0
    amp[0, 0] = 0.0
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    return (n - n.mean()) / (n.std() + 1e-6)


def lambert(height: np.ndarray, relief: float) -> np.ndarray:
    gy, gx = np.gradient(height * relief)
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return np.clip((n * LIGHT[None, None, :]).sum(axis=2), 0.0, 1.0)


def over(dst: np.ndarray, src: np.ndarray, x: int, y: int) -> None:
    """Alpha-composite float RGBA src (0..1 alpha) onto dst at (x, y), clipped."""
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x0 >= x1 or y0 >= y1:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = dst[y0:y1, x0:x1]
    a = s[..., 3:4]
    out_a = a + d[..., 3:4] * (1 - a)
    rgb = (s[..., :3] * a + d[..., :3] * d[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-6)
    d[..., :3] = rgb
    d[..., 3:4] = out_a


def darken_under(dst: np.ndarray, mask: np.ndarray, x: int, y: int, strength: float) -> None:
    h, w = mask.shape
    H, W = dst.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x0 >= x1 or y0 >= y1:
        return
    m = mask[y0 - y:y1 - y, x0 - x:x1 - x]
    dst[y0:y1, x0:x1, :3] *= (1.0 - strength * m)[..., None]


def soft_blob_mask(h: int, w: int, rng, rough: float = 0.12, scale: float = 0.42) -> np.ndarray:
    """An irregular oval mask with ragged edges, 1 inside, soft 0..1 at the rim."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - w / 2) / (w * scale)
    ny = (yy - h / 2) / (h * scale)
    d = np.sqrt(nx * nx + ny * ny)
    n = pnoise(h, w, 2.2, rng) * rough + pnoise(h, w, 1.3, rng) * rough * 0.18
    return np.clip((1.0 - d + n) / 0.10, 0.0, 1.0)


def to_u8(rgba: np.ndarray) -> np.ndarray:
    out = rgba.copy()
    out[..., :3] = np.clip(out[..., :3], 0, 255)
    out[..., 3] = np.clip(out[..., 3] * 255.0, 0, 255)
    return out.round().astype(np.uint8)


def pixel_version(hd: np.ndarray, opaque: bool = False) -> np.ndarray:
    img = Image.fromarray(hd).resize((hd.shape[1] // 2, hd.shape[0] // 2), Image.LANCZOS)
    arr = np.asarray(img).copy()
    rgb = Image.fromarray(arr[..., :3]).quantize(colors=40, method=Image.Quantize.MEDIANCUT,
                                                 dither=Image.Dither.NONE).convert("RGB")
    arr[..., :3] = np.asarray(rgb)
    if opaque:
        arr[..., 3] = 255
    else:
        arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
    return arr


# --- crowns, rocks and ground stand-ins ----------------------------------------------------------

def crown(r: float, kind: str, rng) -> np.ndarray:
    """One tree crown seen from above, lit from the upper left. Float RGBA, alpha 0..1."""
    size = int(r * 2.4) + 4
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    dx, dy = xx - c, yy - c
    d = np.sqrt(dx * dx + dy * dy)
    th = np.arctan2(dy, dx)
    leaf = pnoise(size, size, 0.6, rng)
    if kind == "conifer":
        n = rng.integers(7, 10)
        ph = rng.uniform(0, np.pi)
        rad = r * (0.80 + 0.20 * np.abs(np.cos(n * th / 2 + ph)) ** 0.6 + 0.04 * np.sin(3 * th + ph))
        h = np.clip(1.0 - d / rad, 0.0, 1.0) ** 0.85
        h = h + 0.05 * np.sin(n * 2 * th) * (h > 0) + 0.04 * leaf * (h > 0)
        stops, relief = CONIFER, r * 0.9
    else:
        h = np.zeros_like(d)
        lobes = [(0.0, 0.0, 0.62)]
        k = rng.integers(6, 9)
        for i in range(k):
            a = i * 2 * np.pi / k + rng.uniform(-0.3, 0.3)
            lobes.append((np.cos(a) * r * 0.48, np.sin(a) * r * 0.48, rng.uniform(0.44, 0.56)))
        for lx, ly, lr in lobes:
            rl = lr * r
            q = 1.0 - ((dx - lx) ** 2 + (dy - ly) ** 2) / (rl * rl)
            h = np.maximum(h, np.sqrt(np.clip(q, 0, 1)) * (0.75 + (0.25 if lx == 0 else 0.0)))
        h = h + 0.07 * leaf * (h > 0)
        stops = EMERALD if kind == "emerald" else BROADLEAF
        relief = r * 0.7
    h = np.clip(h, 0, 1.2)
    lit = lambert(h, relief)
    t = 0.30 * np.clip(h, 0, 1) + 0.75 * lit - 0.12 + 0.06 * leaf
    rgba = np.zeros((size, size, 4), np.float32)
    rgba[..., :3] = ramp(t, stops)
    rgba[..., 3] = np.clip(h * 12.0, 0, 1)
    return rgba


def cluster(w: int, h: int, n: int, rng, conifer_share: float, r_range: tuple[float, float]) -> np.ndarray:
    canvas = np.zeros((h, w, 4), np.float32)
    pts = []
    tries = 0
    while len(pts) < n and tries < 6000:
        tries += 1
        r = rng.uniform(*r_range)
        x = rng.uniform(r * 0.9, w - r * 0.9)
        y = rng.uniform(r * 0.9, h - r * 0.9)
        nx, ny = (x - w / 2) / (w / 2 - r), (y - h / 2) / (h / 2 - r)
        if nx * nx + ny * ny > 1.0:
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < (0.50 * (r + pr)) ** 2 for px, py, pr in pts):
            continue
        pts.append((x, y, r))
    pts.sort(key=lambda p: p[1])
    for x, y, r in pts:
        roll = rng.uniform()
        kind = "conifer" if roll < conifer_share else ("emerald" if roll < conifer_share + 0.25 else "broad")
        cr = crown(r, kind, rng)
        s = cr.shape[0]
        # The new crown shades the crowns behind it, down and to the right of its silhouette.
        darken_under(canvas, cv2.GaussianBlur(cr[..., 3], (0, 0), r * 0.18), int(x - s / 2 + r * 0.10),
                     int(y - s / 2 + r * 0.14), 0.42)
        over(canvas, cr, int(x - s / 2), int(y - s / 2))
    return canvas


def single_tree(w: int, h: int, kind: str, rng) -> np.ndarray:
    canvas = np.zeros((h, w, 4), np.float32)
    r = min(w, h) * 0.46
    cr = crown(r, kind, rng)
    s = cr.shape[0]
    over(canvas, cr, int(w / 2 - s / 2), int(h / 2 - s / 2))
    return canvas


def verge(w: int, h: int, rng) -> np.ndarray:
    canvas = np.zeros((h, w, 4), np.float32)
    xs = np.linspace(h * 0.35, w - h * 0.35, 13) + rng.uniform(-6, 6, 13)
    for x in sorted(xs, key=lambda _: rng.uniform()):
        r = rng.uniform(h * 0.22, h * 0.36)
        y = h / 2 + rng.uniform(-h * 0.12, h * 0.12)
        cr = crown(r, rng.choice(["broad", "emerald", "conifer"], p=[0.5, 0.35, 0.15]), rng)
        s = cr.shape[0]
        over(canvas, cr, int(x - s / 2), int(y - s / 2))
    return canvas


def ground_patch(w: int, h: int, stops, rng, speckle: float, scale: float = 0.44, rough: float = 0.12,
                 stones: int = 0) -> np.ndarray:
    tone = pnoise(h, w, 1.4, rng) * 0.10 + pnoise(h, w, 0.4, rng) * speckle
    lit = lambert(pnoise(h, w, 1.2, rng), 6.0)
    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., :3] = ramp(0.55 + tone + (lit - 0.6) * 0.5, stops)
    rgba[..., 3] = soft_blob_mask(h, w, rng, rough, scale)
    for _ in range(stones):
        sr = rng.uniform(2.5, 6.0)
        st = rock(int(sr * 2.6) + 2, int(sr * 2.2) + 2, rng, moss=0.0, light=0.6)
        sx, sy = rng.uniform(0.15, 0.85) * w, rng.uniform(0.15, 0.85) * h
        if rgba[int(sy), int(sx), 3] > 0.8:
            over(rgba, st, int(sx), int(sy))
    return rgba


def rock(w: int, h: int, rng, moss: float = 0.5, light: float = 1.0, lumps: int = 1) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    hgt = np.zeros((h, w), np.float32)
    for i in range(lumps):
        cx = w * (0.5 if lumps == 1 else (0.32 + 0.36 * i / max(1, lumps - 1)))
        cy = h * (0.5 if lumps == 1 else rng.uniform(0.42, 0.58))
        rx = w * (0.44 if lumps == 1 else 0.28) * rng.uniform(0.9, 1.05)
        ry = h * 0.44 * rng.uniform(0.9, 1.05)
        q = 1.0 - ((xx - cx) / rx) ** 2 - ((yy - cy) / ry) ** 2
        hgt = np.maximum(hgt, np.sqrt(np.clip(q, 0, 1)))
    facet = pnoise(h, w, 1.0, rng) * 0.10
    hgt2 = np.clip(hgt + facet * (hgt > 0), 0, 1.2)
    lit = lambert(hgt2, min(w, h) * 0.5)
    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., :3] = ramp(0.05 + 0.95 * lit * light, ROCK)
    if moss > 0:
        mm = np.clip((lit - 0.55) * 3.0 + pnoise(h, w, 1.3, rng) * 0.4, 0, 1) * moss * np.clip(hgt * 2, 0, 1)
        rgba[..., :3] = rgba[..., :3] * (1 - mm[..., None]) + ramp(lit, MOSS) * mm[..., None]
    rgba[..., 3] = np.clip(hgt * 10.0, 0, 1)
    return rgba


def log(w: int, h: int, rng) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = (xx - w * 0.5) / (w * 0.47)  # -1 .. 1 along the trunk
    bend = np.sin(u * 1.7 + 0.4) * h * 0.06
    half = h * 0.36 * (1.0 - 0.18 * (u + 1) / 2) * (1 + 0.06 * np.sin(u * 9.0))
    ny = (yy - h / 2 - bend) / half
    cap = np.clip((np.abs(u) - 0.86) / 0.14, 0, 1)
    q = 1 - ny * ny - cap * cap
    hgt = np.sqrt(np.clip(q, 0, 1))
    bark = np.sin(u * 40.0 + pnoise(h, w, 1.0, rng) * 2.5) * 0.07 + np.sin(ny * 6.0) * 0.04
    lit = lambert(hgt, h * 0.45)
    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., :3] = ramp(0.15 + 0.85 * lit + bark, BARK)
    mm = np.clip((lit - 0.6) * 3.0 + pnoise(h, w, 1.4, rng) * 0.6, 0, 1) * 0.85 * (u < 0.8)
    rgba[..., :3] = rgba[..., :3] * (1 - mm[..., None]) + ramp(lit, MOSS) * mm[..., None]
    face = (u > 0.86) & (q > 0.05)
    rings = 0.6 + 0.2 * np.sin(np.sqrt(((u - 0.86) * w * 0.47) ** 2 + (ny * half) ** 2) * 1.6)
    rgba[..., :3][face] = ramp(rings[face], WOOD)
    rgba[..., 3] = np.clip(hgt * 10.0, 0, 1)
    return rgba


def stump(w: int, h: int, rng) -> np.ndarray:
    rgba = rock(w, h, rng, moss=0.3)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w * 0.47) / (w * 0.30)) ** 2 + ((yy - h * 0.45) / (h * 0.30)) ** 2)
    top = d < 1.0
    rings = 0.55 + 0.25 * np.sin(d * 14.0)
    rgba[..., :3][top] = ramp(rings[top], WOOD)
    return rgba


def flowers(w: int, h: int, rng, kind: str) -> np.ndarray:
    canvas = np.zeros((h, w, 4), np.float32)
    base = ground_patch(w, h, GRASS, rng, 0.08, scale=0.42, rough=0.2)
    base[..., 3] *= 0.0
    n = 26 if kind == "flowers" else 9
    for _ in range(n):
        x, y = rng.uniform(0.18, 0.82) * w, rng.uniform(0.2, 0.8) * h
        if kind == "flowers":
            col = (240, 236, 220) if rng.uniform() < 0.55 else (246, 206, 64)
            r = rng.uniform(1.4, 2.4)
            dot = np.zeros((7, 7, 4), np.float32)
            yy, xx = np.mgrid[0:7, 0:7].astype(np.float32)
            m = np.clip((r - np.sqrt((xx - 3) ** 2 + (yy - 3) ** 2)) * 1.5, 0, 1)
            dot[..., :3] = col
            dot[..., 3] = m
            over(canvas, dot, int(x - 3), int(y - 3))
        elif kind == "stones":
            sr = rng.uniform(2.2, 5.0)
            over(canvas, rock(int(sr * 2.6) + 2, int(sr * 2.2) + 2, rng, moss=0.2), int(x), int(y))
    if kind == "ferns":
        for _ in range(5):
            x, y = rng.uniform(0.25, 0.75) * w, rng.uniform(0.3, 0.7) * h
            fr = verge_leaf(rng)
            over(canvas, fr, int(x - fr.shape[1] / 2), int(y - fr.shape[0] / 2))
    return canvas


def verge_leaf(rng) -> np.ndarray:
    s = 30
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32) - s / 2
    th = np.arctan2(yy, xx)
    d = np.sqrt(xx * xx + yy * yy)
    rad = 12 * (0.55 + 0.45 * np.abs(np.cos(3 * th + rng.uniform(0, 3))))
    h = np.clip(1 - d / rad, 0, 1)
    lit = lambert(h + 0.15 * np.sin(th * 18) * (h > 0), 8)
    rgba = np.zeros((s, s, 4), np.float32)
    rgba[..., :3] = ramp(0.2 + 0.8 * lit, EMERALD)
    rgba[..., 3] = np.clip(h * 8, 0, 1)
    return rgba


def grass_tile(n: int, rng) -> np.ndarray:
    big = pnoise(n, n, 2.2, rng)
    mid = pnoise(n, n, 1.4, rng)
    fine = pnoise(n, n, 0.3, rng)
    blades = lambert(pnoise(n, n, 0.8, rng), 4.0)
    t = 0.52 + big * 0.06 + mid * 0.05 + fine * 0.07 + (blades - 0.6) * 0.35
    rgba = np.zeros((n, n, 4), np.float32)
    rgba[..., :3] = ramp(t, GRASS)
    rgba[..., 3] = 1.0
    return rgba


def strip(w: int, h: int, rng, kind: str) -> np.ndarray:
    """Horizontal strip that tiles left-right: 'road' (dirt) or 'river' (water with muddy banks)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = yy / (h - 1)  # 0 top .. 1 bottom
    edge = pnoise(h, w, 1.8, rng) * 0.03
    rgba = np.zeros((h, w, 4), np.float32)
    if kind == "road":
        dist = np.abs(v - 0.5) + edge
        tone = pnoise(h, w, 1.2, rng) * 0.09 + pnoise(h, w, 0.3, rng) * 0.08
        ruts = -0.10 * np.exp(-((np.abs(v - 0.5) - 0.16) / 0.035) ** 2)
        lit = lambert(pnoise(h, w, 1.0, rng), 4.0)
        rgba[..., :3] = ramp(0.58 + tone + ruts + (lit - 0.6) * 0.4, DIRT)
        rgba[..., 3] = np.clip((0.40 - dist) / 0.10, 0, 1)
        fringe = np.clip(1 - np.abs(dist - 0.34) / 0.06, 0, 1) * np.clip(pnoise(h, w, 0.6, rng), 0, 1)
        rgba[..., :3] = rgba[..., :3] * (1 - fringe[..., None]) + ramp(np.full_like(v, 0.6), GRASS) * fringe[..., None]
        return rgba
    dist = np.abs(v - 0.5) + edge
    depth = np.clip(1.0 - dist / 0.285, 0, 1)
    ripple = np.sin(yy * 0.55 + pnoise(h, w, 1.8, rng) * 3.0)
    ripple = (np.clip(ripple, 0.93, 1.0) - 0.93) * np.clip(pnoise(h, w, 1.4, rng), 0, 1)
    water = ramp(0.25 + 0.35 * (1 - depth) + ripple * 6.0 + pnoise(h, w, 1.0, rng) * 0.05, WATER)
    water = water * (0.80 + 0.20 * (1 - depth[..., None]))
    bank_t = np.clip((dist - 0.285) / 0.11, 0, 1)
    mud = ramp(0.40 + pnoise(h, w, 0.8, rng) * 0.10 + bank_t * 0.2, DIRT) * 0.82
    grass = ramp(0.55 + pnoise(h, w, 0.5, rng) * 0.12, GRASS)
    is_water = (dist < 0.285).astype(np.float32)
    soft = np.clip((0.285 - dist) / 0.012, 0, 1)
    rgb = water * soft[..., None] + mud * (1 - soft[..., None])
    g = np.clip((bank_t - 0.55) / 0.3, 0, 1) * np.clip(0.6 + pnoise(h, w, 0.7, rng) * 0.5, 0, 1)
    rgb = rgb * (1 - g[..., None]) + grass * g[..., None]
    rgba[..., :3] = rgb
    rgba[..., 3] = np.clip((0.46 - dist) / 0.07, 0, 1)
    del is_water
    return rgba


def ford(w: int, h: int, rng) -> np.ndarray:
    canvas = np.zeros((h, w, 4), np.float32)
    bar = ground_patch(int(w * 0.84), int(h * 0.94), GRAVEL, rng, 0.18, scale=0.47, rough=0.08)
    bar[..., :3] = bar[..., :3] * 0.85 + np.array([170, 160, 140]) * 0.15
    # shallow water glints over the bar
    yy, xx = np.mgrid[0:bar.shape[0], 0:bar.shape[1]].astype(np.float32)
    glint = np.clip(np.sin(yy * 0.35 + pnoise(*bar.shape[:2], 1.5, rng) * 2.0), 0.9, 1) - 0.9
    bar[..., :3] += glint[..., None] * 900 * np.array([0.45, 0.6, 0.65])
    bar[..., 3] *= 0.96
    over(canvas, bar, int(w * 0.08), int(h * 0.03))
    for i in range(12):
        st = rock(int(rng.uniform(16, 24)), int(rng.uniform(13, 18)), rng, moss=0.25)
        over(canvas, st, int(w * rng.uniform(0.2, 0.7)), int(h * (0.04 + (i % 8) * 0.11)))
    return canvas


def bridge(w: int, h: int, rng) -> np.ndarray:
    canvas = np.zeros((h, w, 4), np.float32)
    deck_x0, deck_x1 = int(w * 0.12), int(w * 0.88)
    plank_h = 11
    for y in range(int(h * 0.04), int(h * 0.96), plank_h):
        pw = deck_x1 - deck_x0
        pl = np.zeros((plank_h - 1, pw, 4), np.float32)
        yy, xx = np.mgrid[0:plank_h - 1, 0:pw].astype(np.float32)
        grain = np.sin(xx * 0.5 + pnoise(plank_h - 1, pw, 1.0, rng) * 3.0) * 0.06
        lit = 0.62 + 0.25 * (1 - yy / (plank_h - 1)) - 0.18 * (yy > plank_h - 4)
        pl[..., :3] = ramp(lit + grain + rng.uniform(-0.08, 0.08), WOOD)
        pl[..., 3] = 1.0
        over(canvas, pl, deck_x0 + int(rng.uniform(-2, 2)), y)
    for rx in (int(w * 0.06), int(w * 0.84)):
        rail = np.zeros((int(h * 0.94), int(w * 0.10), 4), np.float32)
        lit = np.linspace(0.85, 0.45, rail.shape[1])[None, :].repeat(rail.shape[0], 0)
        rail[..., :3] = ramp(lit, WOOD)
        rail[..., 3] = 1.0
        over(canvas, rail, rx, int(h * 0.03))
        for py in np.linspace(h * 0.05, h * 0.9, 5):
            post = np.zeros((10, int(w * 0.13), 4), np.float32)
            post[..., :3] = ramp(np.full(post.shape[:2], 0.35), WOOD)
            post[..., 3] = 1.0
            over(canvas, post, rx - 1, int(py))
    return canvas


# --- the owner's paintings ------------------------------------------------------------------------

def components(sheet: Path) -> list[tuple[np.ndarray, tuple[int, int, int, int]]]:
    """Cut a sheet into its separate pieces by transparency (or by keying out a flat background)."""
    rgba = np.asarray(Image.open(sheet).convert("RGBA")).copy()
    alpha = rgba[..., 3]
    if alpha.min() > 250:  # no transparency: key out the corner colour
        corners = np.concatenate([rgba[:8, :8, :3].reshape(-1, 3), rgba[-8:, -8:, :3].reshape(-1, 3)])
        bg = np.median(corners, axis=0)
        dist = np.linalg.norm(rgba[..., :3].astype(np.float32) - bg, axis=2)
        alpha = np.clip((dist - 18) * 8, 0, 255).astype(np.uint8)
        rgba[..., 3] = alpha
    mask = cv2.dilate((alpha > 40).astype(np.uint8), np.ones((9, 9), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
    total = mask.shape[0] * mask.shape[1]
    out = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if area < total * 0.004:
            continue
        crop = rgba[y:y + h, x:x + w].copy()
        crop[..., 3] = np.where(labels[y:y + h, x:x + w] == i, crop[..., 3], 0)
        out.append((crop, (x, y, w, h)))
    return out


def fit(crop: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    W, H = size
    h, w = crop.shape[:2]
    k = min(W / w, H / h)
    img = Image.fromarray(crop).resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((W - img.width) // 2, (H - img.height) // 2))
    return np.asarray(canvas)


SHEETS = {
    # sheet file -> how to name its components
    "dirt_clearings.png": ("area_then_y", ["dirt_clearing_plaza", "dirt_patch_round", "dirt_patch_long"]),
    "gravel_pads.png": ("x", ["gravel_pad_base", "gravel_field"]),
    "tree_clusters.png": ("area", ["tree_cluster_large", "tree_cluster_medium", "tree_cluster_small"]),
    "trees_single_and_verge.png": ("verge_then_x", ["forest_verge", "conifer_tree", "broadleaf_tree", "broadleaf_tree_tall"]),
    "river_crossings.png": ("x", ["river_ford", "river_bridge"]),
    "rocks_logs_details.png": ("rows_3_2_3", ["mossy_boulder", "mossy_boulder_pair", "mossy_slab", "fallen_log",
                                              "tree_stump", "grass_flowers", "grass_stones", "fern_patch"]),
}


def cut_sheet(name: str, rule: str, ids: list[str]) -> dict[str, np.ndarray]:
    comps = components(SRC / name)
    if len(comps) < len(ids):
        print(f"  ! {name}: found {len(comps)} pieces, expected {len(ids)}; keeping stand-ins")
        return {}
    comps.sort(key=lambda c: -c[1][2] * c[1][3])
    comps = comps[:len(ids)]
    if rule == "area":
        ordered = comps
    elif rule == "x":
        ordered = sorted(comps, key=lambda c: c[1][0])
    elif rule == "area_then_y":
        ordered = comps[:1] + sorted(comps[1:], key=lambda c: c[1][1])
    elif rule == "verge_then_x":
        widest = max(comps, key=lambda c: c[1][2] / max(1, c[1][3]))
        rest = sorted([c for c in comps if c is not widest], key=lambda c: c[1][0])
        ordered = [widest] + rest
    elif rule == "rows_3_2_3":
        by_y = sorted(comps, key=lambda c: c[1][1] + c[1][3] / 2)
        ordered = (sorted(by_y[:3], key=lambda c: c[1][0]) + sorted(by_y[3:5], key=lambda c: c[1][0])
                   + sorted(by_y[5:], key=lambda c: c[1][0]))
    else:
        raise ValueError(rule)
    return {pid: fit(c[0], (SIZES[pid][0] * 2, SIZES[pid][1] * 2)) for pid, c in zip(ids, ordered)}


def strip_from_painting(path: Path, height: int) -> np.ndarray:
    img = Image.open(path).convert("RGBA")
    w = round(img.width * height / img.height)
    return np.asarray(img.resize((w, height), Image.LANCZOS))


# --- main -----------------------------------------------------------------------------------------

def stand_ins() -> dict[str, np.ndarray]:
    rng = np.random.default_rng(20261127)
    hd = lambda pid: (SIZES[pid][0] * 2, SIZES[pid][1] * 2)  # noqa: E731
    art: dict[str, np.ndarray] = {}
    w, h = hd("dirt_clearing_plaza"); art["dirt_clearing_plaza"] = ground_patch(w, h, DIRT, rng, 0.10, 0.46, 0.10, stones=26)
    w, h = hd("dirt_patch_round"); art["dirt_patch_round"] = ground_patch(w, h, DIRT, rng, 0.10, 0.44, 0.16, stones=5)
    w, h = hd("dirt_patch_long"); art["dirt_patch_long"] = ground_patch(w, h, DIRT, rng, 0.10, 0.44, 0.16, stones=6)
    w, h = hd("gravel_pad_base"); art["gravel_pad_base"] = ground_patch(w, h, GRAVEL, rng, 0.22, 0.47, 0.06, stones=30)
    w, h = hd("gravel_field"); art["gravel_field"] = ground_patch(w, h, GRAVEL, rng, 0.22, 0.45, 0.14, stones=40)
    for pid, kind in (("grass_flowers", "flowers"), ("grass_stones", "stones"), ("fern_patch", "ferns")):
        art[pid] = flowers(*hd(pid), rng, kind)
    w, h = hd("tree_cluster_large"); art["tree_cluster_large"] = cluster(w, h, 40, rng, 0.45, (40, 58))
    w, h = hd("tree_cluster_medium"); art["tree_cluster_medium"] = cluster(w, h, 20, rng, 0.40, (36, 52))
    w, h = hd("tree_cluster_small"); art["tree_cluster_small"] = cluster(w, h, 10, rng, 0.35, (32, 46))
    art["conifer_tree"] = single_tree(*hd("conifer_tree"), "conifer", rng)
    art["broadleaf_tree"] = single_tree(*hd("broadleaf_tree"), "broad", rng)
    art["broadleaf_tree_tall"] = single_tree(*hd("broadleaf_tree_tall"), "emerald", rng)
    art["forest_verge"] = verge(*hd("forest_verge"), rng)
    art["river"] = strip(*hd("river"), rng, "river")
    art["river_ford"] = ford(*hd("river_ford"), rng)
    art["river_bridge"] = bridge(*hd("river_bridge"), rng)
    art["mossy_boulder"] = rock(*hd("mossy_boulder"), rng, moss=0.6)
    art["mossy_boulder_pair"] = rock(*hd("mossy_boulder_pair"), rng, moss=0.55, lumps=2)
    art["mossy_slab"] = rock(*hd("mossy_slab"), rng, moss=0.7, lumps=3)
    art["fallen_log"] = log(*hd("fallen_log"), rng)
    art["tree_stump"] = stump(*hd("tree_stump"), rng)
    art["sand_tile"] = grass_tile(512, rng)
    art["road_strip"] = strip(256, 96, rng, "road")
    return {k: to_u8(v) for k, v in art.items()}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    art = stand_ins()
    source = {k: "stand-in" for k in art}
    if "--stand-ins" not in sys.argv:
        for name, (rule, ids) in SHEETS.items():
            if (SRC / name).exists():
                for pid, img in cut_sheet(name, rule, ids).items():
                    art[pid] = img
                    source[pid] = name
        if (SRC / "grass_tile.png").exists():
            art["sand_tile"] = np.asarray(Image.open(SRC / "grass_tile.png").convert("RGBA").resize((512, 512), Image.LANCZOS))
            source["sand_tile"] = "grass_tile.png"
        if (SRC / "dirt_road_strip.png").exists():
            art["road_strip"] = strip_from_painting(SRC / "dirt_road_strip.png", 96)
            source["road_strip"] = "dirt_road_strip.png"
        if (SRC / "river_strip.png").exists():
            art["river"] = strip_from_painting(SRC / "river_strip.png", SIZES["river"][1] * 2)
            source["river"] = "river_strip.png"
    for pid, img in sorted(art.items()):
        opaque = pid == "sand_tile"
        hd = img.copy()
        if opaque:
            hd[..., 3] = 255
            Image.fromarray(hd[..., :3]).save(OUT / f"{pid}_hd.png")
            Image.fromarray(pixel_version(hd, True)[..., :3]).save(OUT / f"{pid}_pixel.png")
        else:
            Image.fromarray(hd).save(OUT / f"{pid}_hd.png")
            Image.fromarray(pixel_version(hd)).save(OUT / f"{pid}_pixel.png")
        print(f"{pid:22s} {hd.shape[1]}x{hd.shape[0]}  {source[pid]}")
    sheet_preview(art)


def sheet_preview(art: dict[str, np.ndarray]) -> None:
    """Contact sheet of every piece over the grass, for a quick look (render_captures/rts_forest_kit/)."""
    dst = ROOT / "render_captures/rts_mission_1_forest"
    dst.mkdir(parents=True, exist_ok=True)
    grass = Image.fromarray(art["sand_tile"][..., :3]).convert("RGBA")
    W, H = 1800, 1900
    sheet = Image.new("RGBA", (W, H))
    for y in range(0, H, 512):
        for x in range(0, W, 512):
            sheet.alpha_composite(grass, (x, y))
    x = y = 10
    row_h = 0
    for pid, img in sorted(art.items()):
        if pid == "sand_tile":
            continue
        im = Image.fromarray(img)
        if x + im.width > W:
            x = 10
            y += row_h + 10
            row_h = 0
        sheet.alpha_composite(im, (x, y))
        x += im.width + 10
        row_h = max(row_h, im.height)
    sheet.save(dst / "forest_kit_sheet.png")


if __name__ == "__main__":
    main()
