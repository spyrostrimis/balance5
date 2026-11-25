"""Generate 1920x1080 (2x density, un-quantized smooth finish) painterly map layers
for the "hd_painted" profile of scenes/maps/rts_units_test.tscn.

    C:/Python312/python.exe tools/python/make_rts_hd_layers.py

Uses the existing 1024+ px source paintings in assets/source_inputs/rts/ at 2x resolution
(half the shrink factor of the 960x540 t5 pixel layers) on the exact same layout and
walk_mask.png footprint, adds the NE cliff oasis cue (spring pool + palm/scrub greenery
tucked inside the blocked NE cliff terrace), and writes to:
  assets/textures/rts/style_test/t5_hd/sand_dunes.png
  assets/textures/rts/style_test/t5_hd/road.png
  assets/textures/rts/style_test/t5_hd/rocks.png
  assets/textures/rts/style_test/t5_hd/scatter.png

The existing 960x540 48-colour layers in assets/textures/rts/style_test/t5/ remain untouched.
"""
from pathlib import Path
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from smooth_texture import cosine_wrap

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source_inputs" / "rts"
KITBASH = ROOT / "assets" / "textures" / "kitbash"
T5_DIR = ROOT / "assets" / "textures" / "rts" / "style_test" / "t5"
OUT = ROOT / "assets" / "textures" / "rts" / "style_test" / "t5_hd"

W, H = 1920, 1080
SEED = 11

LIGHT = np.array([-0.5, -0.7, 0.75], np.float32)
LIGHT = LIGHT / np.linalg.norm(LIGHT)

SAND = np.array([228, 135, 40], np.float32)
CREST_HI = np.array([255, 216, 112], np.float32)
TROUGH = np.array([169, 84, 22], np.float32)
ROAD_JOINT = np.array([150, 106, 74], np.float32)
ROCK_LIGHT = np.array([138, 112, 96], np.float32)
DEEP = np.array([22, 14, 10], np.float32)
SHADOW_DARK = np.array([70, 30, 8], np.float32)
MARKER = np.array([216, 208, 196], np.float32)
GOLD = np.array([255, 196, 70], np.float32)

TARGETS = {
    "sand": ((229, 136, 41), (16, 15, 7)),
    "road": ((205, 155, 113), (13, 12, 11)),
    "rock": ((84, 64, 56), (26, 21, 17)),
    "wall": ((108, 74, 50), (30, 22, 16)),
}
SAND_RIPPLED = ((229, 136, 41), (30, 30, 12))

# 2x density uses half the shrink factor so source paintings keep genuine 2x detail.
SHRINK_2X = {
    "sand.png": 1.6,
    "dunes2.png": 1.2,
    "rock_top.png": 2.75,
    "road.png": 5.0,
    "cliff_wall2.png": 4.5,
}

# Layout scaled by 2x (from 960x540 -> 1920x1080)
ROCK_CORE = (318 * 2, 222 * 2, 56 * 2, 36 * 2)
PLAZA = (312 * 2, 224 * 2, 94 * 2, 68 * 2)
ROAD_LINE = [(x * 2, y * 2) for x, y in [
    (-10, 116), (55, 124), (100, 146), (160, 164), (225, 196),
    (390, 262), (430, 300), (480, 335), (545, 372), (600, 398),
    (660, 414), (780, 442), (970, 474),
]]
WIND = -0.17

YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    t = np.asarray(t, np.float32)[..., None] if np.ndim(t) else t
    return a + (b - a) * t


def lambert(height: np.ndarray) -> np.ndarray:
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n @ LIGHT - LIGHT[2]


def shift(mask: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(mask)
    ys, yd = (slice(0, H - dy), slice(dy, H)) if dy >= 0 else (slice(-dy, H), slice(0, H + dy))
    xs, xd = (slice(0, W - dx), slice(dx, W)) if dx >= 0 else (slice(-dx, W), slice(0, W + dx))
    out[yd, xd] = mask[ys, xs]
    return out


def dist_inside(mask: np.ndarray) -> np.ndarray:
    return cv2.distanceTransform(mask.astype(np.uint8), cv2.DIST_L2, 5)


def load_source(name: str, factor: float, gray: bool = False) -> np.ndarray:
    im = Image.open(SRC / name).convert("L" if gray else "RGB")
    size = (max(1, round(im.width / factor)), max(1, round(im.height / factor)))
    return np.array(im.resize(size, Image.Resampling.LANCZOS)).astype(np.float32)


def seamless(tex: np.ndarray) -> np.ndarray:
    m = max(4, min(tex.shape[:2]) // 16)
    return cosine_wrap(cosine_wrap([tex], m, 0), m, 1)[0]


def match_colour(rgb: np.ndarray, material: str) -> np.ndarray:
    mean_t, std_t = (np.array(v, np.float32) for v in TARGETS[material])
    flat = rgb.reshape(-1, 3)
    ratio = np.clip(std_t / (flat.std(0) + 1e-3), 0.3, 3.0)
    return (rgb - flat.mean(0)) * ratio + mean_t


def tile(tex: np.ndarray, ox: int, oy: int) -> np.ndarray:
    th, tw = tex.shape[:2]
    ox, oy = ox % tw, oy % th
    reps = (H // th + 2, W // tw + 2) + ((1,) if tex.ndim == 3 else ())
    return np.tile(tex, reps)[oy:oy + H, ox:ox + W]


def noise_2x(rng: np.random.Generator, cx: int, cy: int | None = None) -> np.ndarray:
    cy = cy or cx
    gw, gh = W // cx + 3, H // cy + 3
    grid = rng.random((gh, gw)).astype(np.float32)
    return cv2.resize(grid, (gw * cx, gh * cy), interpolation=cv2.INTER_CUBIC)[:H, :W]


def fbm_2x(rng: np.random.Generator, *cells: int) -> np.ndarray:
    total, weight = np.zeros((H, W), np.float32), 0.0
    for i, c in enumerate(cells):
        w = 0.55 ** i
        total += noise_2x(rng, c) * w
        weight += w
    return total / weight


def stretched_noise_2x(rng: np.random.Generator, u: np.ndarray, v: np.ndarray, cell_u: float, cell_v: float) -> np.ndarray:
    big = cv2.resize(rng.random((64, 64)).astype(np.float32), (512, 512), interpolation=cv2.INTER_CUBIC)
    mx = (u / cell_u * 8).astype(np.float32)
    my = (v / cell_v * 8).astype(np.float32)
    return cv2.remap(big, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)


def distance_to_road_2x() -> np.ndarray:
    dist = np.full((H, W), 1e9, np.float32)
    pts = np.array(ROAD_LINE, np.float32)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((XX - a[0]) * ab[0] + (YY - a[1]) * ab[1]) / (ab @ ab), 0, 1)
        dist = np.minimum(dist, np.hypot(XX - a[0] - t * ab[0], YY - a[1] - t * ab[1]))
    cx, cy, rx, ry = PLAZA
    plaza = np.maximum(np.hypot((XX - cx) / rx, (YY - cy) / ry) - 1, 0) * min(rx, ry)
    return np.minimum(dist, plaza)


def make_sand_dunes_hd(rng: np.random.Generator) -> np.ndarray:
    # Start from the exact t5 low-frequency layout so dune fields & tones align 1:1 with pixel mode,
    # then layer genuine 2x high-resolution painted sand grain and wind-aligned dune ripples on top.
    t5_ground = np.array(
        Image.open(T5_DIR / "sand_dunes.png").convert("RGB").resize((W, H), Image.Resampling.BICUBIC),
        dtype=np.float32,
    )
    base_smooth = cv2.GaussianBlur(t5_ground, (0, 0), 3.2)

    sand_tex = match_colour(seamless(load_source("sand.png", SHRINK_2X["sand.png"])), "sand")
    sand_tiled = tile(sand_tex, 37, 53)
    sand_hi = sand_tiled - cv2.GaussianBlur(sand_tiled, (0, 0), 4.5)

    angle = WIND + 0.3 * (fbm_2x(rng, 800, 400) - 0.5)
    along = XX * np.cos(angle) + YY * np.sin(angle)
    across0 = YY * np.cos(angle) - XX * np.sin(angle)
    wave = (stretched_noise_2x(rng, along, across0, 84, 340) - 0.5) * 2 * 12.0
    across = across0 + 16.0 * (fbm_2x(rng, 640, 320) - 0.5) * 2 + wave

    flat = load_source("dunes2.png", SHRINK_2X["dunes2.png"])
    mu, sd = flat.reshape(-1, 3).mean(0), flat.reshape(-1, 3).std(0) + 1e-3
    mean_t, std_t = (np.array(v, np.float32) for v in SAND_RIPPLED)
    rip = seamless((flat - mu) * np.clip(std_t / sd, 0.3, 3) + mean_t)
    th, tw = rip.shape[:2]
    mx = np.mod(along + 113.0, tw).astype(np.float32)
    my = np.mod(across + 71.0, th).astype(np.float32)
    ripples = cv2.remap(rip.astype(np.float32), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    rip_hi = ripples - cv2.GaussianBlur(ripples, (0, 0), 5.0)

    calm = distance_to_road_2x()
    fields = smoothstep(76, 180, calm + 80 * (fbm_2x(rng, 240, 120) - 0.5))

    rgb = base_smooth + sand_hi * 0.65 + rip_hi * (0.18 + 0.38 * fields[..., None])
    return np.clip(rgb, 0, 255).astype(np.uint8)


def make_road_hd() -> np.ndarray:
    t5_road = np.array(
        Image.open(T5_DIR / "road.png").convert("RGBA").resize((W, H), Image.Resampling.BICUBIC),
        dtype=np.float32,
    )
    rgb = cv2.GaussianBlur(t5_road[..., :3], (0, 0), 2.0)
    alpha = t5_road[..., 3] / 255.0
    alpha = smoothstep(0.18, 0.82, alpha)

    tex = match_colour(seamless(load_source("road.png", SHRINK_2X["road.png"])), "road")
    hsrc = load_source("road_height.png", SHRINK_2X["road.png"], gray=True)
    hsrc_s = seamless(hsrc)
    cracks = np.clip((cv2.GaussianBlur(hsrc_s, (0, 0), 4.0) - hsrc_s - 6.0) / 22.0, 0, 1)

    tiled_road = tile(tex, 44, 88)
    road_detail = tiled_road - cv2.GaussianBlur(tiled_road, (0, 0), 6.0)
    tiled_cracks = tile(cracks, 44, 88)

    rgb = rgb + road_detail * 0.72
    rgb = lerp(rgb, ROAD_JOINT, tiled_cracks * 0.42)
    out = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), (alpha * 255).astype(np.uint8)])
    return out


def add_ne_oasis(rgb: np.ndarray, alpha: np.ndarray, solid_mask: np.ndarray, rng: np.random.Generator) -> None:
    """Paint a desert spring oasis pool and lush palm/reed cluster on the NE cliff terrace
    (as in docs/references/rts_mission1_desert_red.webp & RTS_ART_RULES.md §6c gap #4).
    Sits strictly inside the already-blocked NE cliff footprint so walk_mask.png is unchanged."""
    # NE cliff basin center in 1920x1080 space: around (1580, 152)
    cx, cy, rx, ry = 1585.0, 154.0, 88.0, 44.0
    dx = (XX - cx) / rx
    dy = (YY - cy) / ry
    wobble = (fbm_2x(rng, 48, 24) - 0.5) * 0.28
    dist = np.hypot(dx, dy) + wobble

    # Keep oasis strictly inside the solid NE cliff rock area
    inside_cliff = dist_inside(solid_mask) > 18.0
    basin = (dist < 1.18) & inside_cliff
    water = (dist < 0.78) & inside_cliff
    if water.sum() < 100:
        return

    # Damp dark rock rim around the spring
    rim_t = np.clip((1.18 - dist) / 0.40, 0, 1) * basin.astype(np.float32)
    rgb[:] = lerp(rgb, np.array([58, 52, 42], np.float32), rim_t * 0.55)

    # Turquoise/teal spring water with depth gradient and top-left sun reflection
    water_depth = np.clip((0.78 - dist) / 0.78, 0, 1)
    shallow_col = np.array([64, 148, 132], np.float32)
    deep_col = np.array([24, 78, 86], np.float32)
    water_col = lerp(shallow_col, deep_col, water_depth)
    # Sun shimmer near top-left of pool
    spec = np.exp(-(((XX - (cx - 22)) / 26.0) ** 2 + ((YY - (cy - 10)) / 14.0) ** 2))
    water_col = lerp(water_col, np.array([185, 235, 220], np.float32), spec * 0.55)
    water_feather = np.clip((0.78 - dist) / 0.12, 0, 1) * inside_cliff.astype(np.float32)
    rgb[:] = lerp(rgb, water_col, water_feather)

    # Oasis vegetation clusters (organic clumps along the NW and SE banks, leaving rocky shore gaps)
    clump_angles = [-2.65, -2.35, -2.05, -1.70, -1.42, -0.45, -0.18, 0.12, 0.42, 0.72, 1.85, 2.15]
    for idx, angle in enumerate(clump_angles):
        spr_im = Image.open(KITBASH / f"shrub_{idx % 6}.png").convert("RGBA")
        sc = 0.85 + 0.40 * ((idx * 37) % 5) / 4.0
        spr_im = spr_im.resize((max(4, round(spr_im.width * sc)), max(4, round(spr_im.height * sc))), Image.Resampling.LANCZOS)
        spr = np.array(spr_im, dtype=np.float32)
        sh, sw = spr.shape[:2]
        rad_mult = 0.74 + 0.10 * ((idx % 3) - 1)
        px = int(cx + np.cos(angle) * (rx * rad_mult) - sw // 2)
        py = int(cy + np.sin(angle) * (ry * rad_mult) - sh // 2)
        if 0 <= py and py + sh < H and 0 <= px and px + sw < W:
            if not inside_cliff[py + sh // 2, px + sw // 2]:
                continue
            sa = (spr[..., 3:4] / 255.0) * 0.90
            green_spr = spr[..., :3].copy()
            green_spr[..., 1] = np.clip(green_spr[..., 1] * 1.14 + 8, 0, 255)
            dst = rgb[py:py + sh, px:px + sw]
            rgb[py:py + sh, px:px + sw] = green_spr * sa + dst * (1.0 - sa)


def make_rocks_hd(rng: np.random.Generator) -> np.ndarray:
    t5_rocks = np.array(
        Image.open(T5_DIR / "rocks.png").convert("RGBA").resize((W, H), Image.Resampling.BICUBIC),
        dtype=np.float32,
    )
    rgb = cv2.GaussianBlur(t5_rocks[..., :3], (0, 0), 1.6)
    alpha = t5_rocks[..., 3] / 255.0
    solid = alpha > 0.88

    # High-res basalt top & height cracks
    rock_tex = match_colour(seamless(load_source("rock_top.png", SHRINK_2X["rock_top.png"])), "rock") * 1.15
    rock_h = seamless(load_source("rock_top_height.png", SHRINK_2X["rock_top.png"], gray=True))
    cracks = np.clip((cv2.GaussianBlur(rock_h, (0, 0), 3.5) - rock_h - 10.0) / 20.0, 0, 1)
    tiled_rock = tile(rock_tex, 62, 41)
    rock_detail = tiled_rock - cv2.GaussianBlur(tiled_rock, (0, 0), 7.0)
    tiled_cracks = tile(cracks, 62, 41)

    # High-res vertical cliff wall columns
    wall_tex = match_colour(seamless(load_source("cliff_wall2.png", SHRINK_2X["cliff_wall2.png"])), "wall")
    tiled_wall = tile(wall_tex, 19, 0)
    wall_detail = tiled_wall - cv2.GaussianBlur(tiled_wall, (0, 0), 6.0)

    # Detect warm south walls vs cooler slab tops vs bright gold Orichalcum crystals
    warm_wall = np.clip((rgb[..., 0] - rgb[..., 2] - 18.0) / 42.0, 0, 1)[..., None]
    amber_crystal = np.clip((rgb[..., 0] - 145.0) / 60.0, 0, 1)[..., None]
    top_weight = (1.0 - warm_wall) * (1.0 - amber_crystal)

    detail = rock_detail * top_weight + wall_detail * warm_wall * (1.0 - amber_crystal)
    rgb = rgb + detail * solid[..., None] * 0.70
    rgb = lerp(rgb, DEEP, tiled_cracks * top_weight[..., 0] * solid.astype(np.float32) * 0.55)

    # High-res Orichalcum crystal cluster at 2x resolution
    src_cryst = np.array(Image.open(SRC / "crystals2.png").convert("RGB"), dtype=np.float32)
    ca = np.clip((src_cryst.max(2) - 22.0) / 50.0, 0, 1)
    ys, xs = np.nonzero(ca > 0.05)
    src_cryst = src_cryst[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    c_width = 156
    c_size = (c_width, round(src_cryst.shape[0] * c_width / src_cryst.shape[1]))
    c_col = cv2.resize(src_cryst, c_size, interpolation=cv2.INTER_LANCZOS4)
    c_weight = np.clip((c_col.max(2) - 155.0) / 65.0, 0, 1)
    cx, cy = ROCK_CORE[0], ROCK_CORE[1] - 12
    x0, y0 = cx - c_size[0] // 2, cy - c_size[1] // 2
    reg = (slice(y0, y0 + c_size[1]), slice(x0, x0 + c_size[0]))
    c_keep = c_weight * solid[reg].astype(np.float32)
    glow = cv2.GaussianBlur(c_keep, (0, 0), 8.0) * 0.65
    rgb[reg] = lerp(rgb[reg], GOLD, np.clip(glow, 0, 0.52))
    rgb[reg] = lerp(rgb[reg], np.clip(c_col * 1.10, 0, 255), c_keep * 0.85)

    # Add NE cliff oasis cue inside the blocked NE cliff plateau
    add_ne_oasis(rgb, alpha, solid, rng)

    out = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), (np.clip(alpha, 0, 1) * 255).astype(np.uint8)])
    return out


def make_scatter_hd() -> np.ndarray:
    t5_scatter = np.array(
        Image.open(T5_DIR / "scatter.png").convert("RGBA").resize((W, H), Image.Resampling.LANCZOS),
        dtype=np.float32,
    )
    rgb = cv2.GaussianBlur(t5_scatter[..., :3], (0, 0), 0.75)
    alpha = t5_scatter[..., 3]
    return np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.clip(alpha, 0, 255).astype(np.uint8)])


def write_mipmap_import(png_path: Path) -> None:
    """Ensure Godot imports 2x HD textures with mipmaps enabled for TEXTURE_FILTER_LINEAR_WITH_MIPMAPS."""
    imp = Path(str(png_path) + ".import")
    if imp.exists():
        text = imp.read_text(encoding="utf-8")
        if "mipmaps/generate=false" in text:
            imp.write_text(text.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)

    sand_dunes = make_sand_dunes_hd(rng)
    Image.fromarray(sand_dunes).save(OUT / "sand_dunes.png")

    road = make_road_hd()
    Image.fromarray(road).save(OUT / "road.png")

    rocks = make_rocks_hd(rng)
    Image.fromarray(rocks).save(OUT / "rocks.png")

    scatter = make_scatter_hd()
    Image.fromarray(scatter).save(OUT / "scatter.png")

    for name in ("sand_dunes.png", "road.png", "rocks.png", "scatter.png"):
        write_mipmap_import(OUT / name)

    print(f"Wrote 1920x1080 2x HD layers to {OUT}")


if __name__ == "__main__":
    main()
