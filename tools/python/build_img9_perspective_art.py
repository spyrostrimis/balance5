"""Extract real Image-9 2.5D perspective layers directly from img9_reference.jpg.

Strict rules:
- No procedural brick/noise textures. Every road cobble, sand verge, curb stone,
  stepped dry-stone wall wing, terracotta cliff, boulder, sagebush, and canyon-mouth
  horizon is sliced/quilted directly from assets/source_inputs/rpg_2d/img9_reference.jpg.
- Quantized cleanly (dither=NONE) to a 192-colour palette sampled from Image 9.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = ROOT / "assets/source_inputs/rpg_2d/img9_reference.jpg"
OUTPUT_DIR = ROOT / "assets/textures/rpg_2d/img9_perspective"
TMP_DIR = ROOT / "tmp"

ART_W, ART_H = 960, 540
NEAREST = Image.Resampling.NEAREST
LANCZOS = Image.Resampling.LANCZOS

# Projection constants shared with scripts/rpg_2d/img9_perspective_follow.gd
BOOTS = (486.0, 320.0)
HORIZON = 88.0
DEPTH = 260.0

# S-curve route calibration marks: (distance_uphill, road_center_x, road_half_width)
# Calibrated directly to Image 9's cobble road from foreground (-140) through spawn (0)
# up to the upper canyon bend (+520) and beyond into the sunlit gap.
ROUTE_MARKS = [
    (-260.0, 38.0, 62.0),
    (-120.0, 34.0, 62.0),
    (-75.0, 82.0, 63.0),
    (-35.0, 64.0, 68.0),
    (0.0, 0.0, 74.0),
    (55.0, -56.0, 82.0),
    (138.0, -64.0, 94.0),
    (275.0, 60.0, 108.0),
    (455.0, 152.0, 118.0),
    (760.0, 48.0, 130.0),
    (1350.0, 18.0, 145.0),
    (2600.0, 115.0, 155.0),
]


def build_palette_image(src_rgb: Image.Image, colors: int = 192) -> Image.Image:
    """Create a 192-colour median-cut palette image directly from Image 9."""
    return src_rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def quantize_rgb(img: Image.Image, palette_img: Image.Image) -> Image.Image:
    return img.convert("RGB").quantize(palette=palette_img, dither=Image.Dither.NONE).convert("RGB")


def quantize_rgba(img: Image.Image, palette_img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    rgb_q = quantize_rgb(rgba.convert("RGB"), palette_img)
    out = rgb_q.convert("RGBA")
    out.putalpha(rgba.getchannel("A"))
    return out


def seam(cost: np.ndarray) -> np.ndarray:
    """Minimum-energy vertical seam through an overlapping cost strip."""
    h, w = cost.shape
    totals = cost[0].copy()
    parents = np.zeros((h, w), dtype=int)
    cols = np.arange(w)
    for row in range(1, h):
        neighbours = np.stack((np.r_[np.inf, totals[:-1]], totals, np.r_[totals[1:], np.inf]))
        moves = np.argmin(neighbours, axis=0)
        parents[row] = cols + moves - 1
        totals = cost[row] + neighbours[moves, cols]
    path = np.zeros(h, dtype=int)
    path[-1] = int(np.argmin(totals))
    for row in range(h - 1, 0, -1):
        path[row - 1] = parents[row, path[row]]
    return cols[None, :] < path[:, None]


def wrap_tile_h(surface: np.ndarray, overlap: int) -> np.ndarray:
    repeated = surface[:, -overlap:]
    first = surface[:, :overlap]
    mask = seam(np.square(first - repeated).sum(axis=2))
    out = surface.copy()
    out[:, :overlap][mask] = repeated[mask]
    return out[:, :-overlap]


def wrap_tile_v(surface: np.ndarray, overlap: int) -> np.ndarray:
    return wrap_tile_h(surface.transpose(1, 0, 2), overlap).transpose(1, 0, 2)


def quilt_seamless(
    patches: list[np.ndarray],
    patch_size: int,
    overlap: int,
    count_x: int,
    count_y: int,
    seed: int,
) -> np.ndarray:
    """Texture synthesis purely by quilting real Image-9 donor patches."""
    rng = random.Random(seed)
    step = patch_size - overlap
    w = step * count_x + overlap
    h = step * count_y + overlap
    canvas = np.zeros((h, w, 3), dtype=np.float32)

    for y in range(0, step * count_y, step):
        for x in range(0, step * count_x, step):
            target = canvas[y : y + patch_size, x : x + patch_size]
            best_score = float("inf")
            selected = None
            best_cost = None
            for _ in range(40):
                src = rng.choice(patches)
                max_x = src.shape[1] - patch_size
                max_y = src.shape[0] - patch_size
                if max_x < 0 or max_y < 0:
                    continue
                lx = rng.randint(0, max_x)
                ty = rng.randint(0, max_y)
                cand = src[ty : ty + patch_size, lx : lx + patch_size]
                diff = np.square(cand - target).sum(axis=2)
                score = 0.0
                if x > 0:
                    score += float(diff[:, :overlap].mean())
                if y > 0:
                    score += float(diff[:overlap, :].mean())
                if score < best_score:
                    best_score = score
                    selected = cand
                    best_cost = diff
            keep = np.zeros((patch_size, patch_size), dtype=bool)
            if x > 0:
                keep[:, :overlap] |= seam(best_cost[:, :overlap])
            if y > 0:
                keep[:overlap, :] |= seam(best_cost[:overlap, :].T).T
            target[~keep] = selected[~keep]

    wrapped = wrap_tile_h(canvas, overlap)
    wrapped = wrap_tile_v(wrapped, overlap)
    return np.clip(wrapped, 0, 255).astype(np.uint8)


def repair_hero_from_road(img9: Image.Image, palette_img: Image.Image) -> Image.Image:
    """Remove the central Blue Commander and her cast shadow using donor cobbles/sand
    from neighboring Image-9 road rows, blended cleanly along pixel masks."""
    repaired = img9.copy()
    arr = np.asarray(repaired, dtype=np.uint8).copy()

    # Hero + shadow bounding mask in 960x540 coordinates (measured from img9_hero_zoom.png):
    # - Head/torso/scarf/rifle: x=468..536, y=190..315
    # - Cast shadow under boots: x=446..540, y=300..328
    # We patch in 4 horizontal bands with scale-matched neighboring donor rows from the road!
    # Format: (target_polygon, dx_donor, dy_donor)
    bands = [
        # 1. Head & upper torso (y=188..230): donor road cobbles slightly to the upper-left/right
        (
            [(486, 189), (528, 189), (534, 232), (470, 232)],
            -64,
            18,
        ),
        # 2. Mid torso, scarf & rifle (y=228..296) on cobble side (x=466..522): donor cobbles left
        (
            [(466, 226), (524, 226), (526, 298), (468, 298)],
            -68,
            6,
        ),
        # 3. Right arm/hip over right curb-sand margin (x=518..540, y=225..295): donor sand/curb just right
        (
            [(520, 224), (538, 224), (538, 298), (520, 298)],
            -72,
            24,
        ),
        # 4. Lower legs, boots & dark cast shadow (x=444..544, y=294..330): donor cobbles directly below
        (
            [(446, 296), (542, 296), (544, 330), (444, 330)],
            18,
            40,
        ),
    ]

    # Build a combined soft-feathered repair cleanly using real donor pixels
    # First create a clean donor composite for the hero+shadow region
    donor_canvas = arr.copy()
    for poly, dx, dy in bands:
        mask = Image.new("L", (ART_W, ART_H), 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        m = np.asarray(mask) > 0
        ys, xs = np.where(m)
        sy = np.clip(ys + dy, 0, ART_H - 1)
        sx = np.clip(xs + dx, 0, ART_W - 1)
        donor_canvas[ys, xs] = arr[sy, sx]

    # Exact silhouette polygon covering hero + fluttering scarf + rifle + cast shadow
    hero_poly = [
        (498, 190), (520, 190), (526, 206), (526, 218), (536, 226), (538, 256),
        (532, 286), (536, 304), (542, 314), (536, 326), (484, 328), (448, 322),
        (448, 310), (468, 302), (486, 296), (482, 284), (470, 286), (470, 268),
        (478, 246), (466, 246), (468, 232), (484, 218), (492, 202),
    ]
    hero_mask = Image.new("L", (ART_W, ART_H), 0)
    ImageDraw.Draw(hero_mask).polygon(hero_poly, fill=255)
    # 2px soft seam blend at edge, then snap back to 192-color palette for crisp pixel look
    soft_mask = np.asarray(hero_mask.filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32) / 255.0
    blended = arr.astype(np.float32) * (1.0 - soft_mask[:, :, None]) + donor_canvas.astype(np.float32) * soft_mask[:, :, None]

    # Patch the subtle diagonal right-curb shadow corner at (520..536, 296..312) so the stone
    # edge beside the right boot looks uninterrupted
    out_img = Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8))
    return quantize_rgb(out_img, palette_img)


def build_horizon_backdrop(img9_q: Image.Image, palette_img: Image.Image) -> Image.Image:
    """Extract distant sunlit canyon-mouth horizon & upper light-shaft sky backdrop (y=0..155)
    with mirrored horizontal wings (width 1152) for safe parallax and seamless horizon ground join."""
    pad = 96
    bw, bh = ART_W + pad * 2, 180
    backdrop = Image.new("RGB", (bw, bh))

    # Extract y=0..155 directly from Image 9
    top_strip = img9_q.crop((0, 0, ART_W, 155))
    backdrop.paste(top_strip, (pad, 0))

    # Mirror outer cliff edges smoothly into the 96px left/right parallax margins
    left_wing = top_strip.crop((0, 0, pad, 155)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    right_wing = top_strip.crop((ART_W - pad, 0, ART_W, 155)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    backdrop.paste(left_wing, (0, 0))
    backdrop.paste(right_wing, (pad + ART_W, 0))

    # Fill y=155..180 with warm distant sandstone haze (sits behind ground shader)
    b_arr = np.asarray(backdrop, dtype=np.float32).copy()
    haze_color = np.array([175.0, 124.0, 92.0], dtype=np.float32)
    for y in range(155, bh):
        t = (y - 155) / float(bh - 155)
        b_arr[y] = b_arr[154] * (1.0 - t) + haze_color * t

    return quantize_rgb(Image.fromarray(np.clip(b_arr, 0, 255).astype(np.uint8)), palette_img)


def build_ground_textures(repaired: Image.Image, palette_img: Image.Image) -> None:
    """Build cobble tile, sand verge tile, and dressed curb strip purely from Image-9 donors."""
    # 1. Cobble paving tile (384x384 seamless) from clean interior Image-9 road patches
    cobble_patches = []
    for box, scale_x, scale_y in [
        ((504, 428, 636, 526), 1.00, 1.78),  # foreground cobbles (pure interior)
        ((494, 346, 616, 424), 1.15, 2.02),  # lower-mid cobbles (pure interior)
        ((418, 240, 504, 308), 1.50, 2.65),  # mid-bend cobbles scaled to match fg stone size
    ]:
        crop = repaired.crop(box)
        deskewed = crop.resize(
            (round(crop.width * scale_x), round(crop.height * scale_y)),
            NEAREST,
        )
        cobble_patches.append(np.asarray(deskewed, dtype=np.float32))

    # step = 80 - 16 = 64 -> 6 * 64 = 384x384 seamless cobble tile!
    cobble_arr = quilt_seamless(cobble_patches, patch_size=80, overlap=16, count_x=6, count_y=6, seed=901)
    cobble_img = quantize_rgb(Image.fromarray(cobble_arr), palette_img)
    cobble_img.save(OUTPUT_DIR / "cobble_tile.png")

    # 2. Sand verge tile (256x256 seamless) strictly from pure sunlit bush-free Image-9 sand patches
    sand_patches = []
    for box, scale_x, scale_y in [
        ((346, 480, 404, 534), 1.25, 1.65),  # pure warm sunlit lower-left sand
        ((364, 424, 412, 464), 1.30, 1.85),  # pure sunlit left-mid sand
        ((326, 236, 366, 282), 1.50, 1.90),  # pure sunlit mid-left sand verge
    ]:
        crop = repaired.crop(box)
        deskewed = crop.resize(
            (round(crop.width * scale_x), round(crop.height * scale_y)),
            NEAREST,
        )
        sand_patches.append(np.asarray(deskewed, dtype=np.float32))

    # step = 42 - 10 = 32 -> 8 * 32 = 256x256 seamless pure sand tile!
    sand_arr = quilt_seamless(sand_patches, patch_size=42, overlap=10, count_x=8, count_y=8, seed=902)
    sand_img = quantize_rgb(Image.fromarray(sand_arr), palette_img)
    sand_img.save(OUTPUT_DIR / "sand_verge_tile.png")

    # 3. Dressed curb strip (32x256 seamless vertical strip) sliced directly from Image 9's curbs!
    curb_samples = [
        repaired.crop((474, 410, 504, 440)),  # left foreground stone A
        repaired.crop((438, 462, 472, 492)),  # left foreground stone B
        repaired.crop((654, 404, 686, 438)),  # right foreground stone A
        repaired.crop((654, 462, 684, 496)),  # right foreground stone B
        repaired.crop((454, 364, 486, 390)),  # left mid-fg stone
        repaired.crop((634, 368, 666, 394)),  # right mid-fg stone
    ]
    strip = Image.new("RGB", (32, 256))
    y_cursor = 0
    for idx in range(8):
        stone = curb_samples[idx % len(curb_samples)].resize((32, 32), NEAREST)
        strip.paste(stone, (0, y_cursor))
        y_cursor += 32
    strip_img = quantize_rgb(strip, palette_img)
    strip_img.save(OUTPUT_DIR / "curb_strip.png")


def _extend_plate(img: Image.Image, pad_left: int = 0, pad_right: int = 0, pad_bottom: int = 0) -> Image.Image:
    """Pad an Image-9 plate with mirrored rock courses on screen edges so large wall wings
    never reveal straight crop borders as the camera shifts laterally."""
    w, h = img.size
    out = Image.new("RGB", (w + pad_left + pad_right, h + pad_bottom))
    out.paste(img, (pad_left, 0))
    if pad_left > 0:
        lw = img.crop((0, 0, pad_left, h)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        out.paste(lw, (0, 0))
    if pad_right > 0:
        rw = img.crop((w - pad_right, 0, w, h)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        out.paste(rw, (pad_left + w, 0))
    if pad_bottom > 0:
        bw = out.crop((0, h - pad_bottom, out.width, h)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        out.paste(bw, (0, h))
    return out


def _extract_poly(plate: Image.Image, poly: list[tuple[int, int]], shift_x: int = 0) -> tuple[Image.Image, tuple[int, int, int, int]]:
    shifted = [(x + shift_x, y) for (x, y) in poly]
    mask = Image.new("L", plate.size, 0)
    ImageDraw.Draw(mask).polygon(shifted, fill=255)
    bounds = mask.getbbox()
    sprite = plate.crop(bounds).convert("RGBA")
    sprite.putalpha(mask.crop(bounds))
    return sprite, bounds


def _clean_bush_alpha(sprite: Image.Image) -> Image.Image:
    """Trim outer orange sand pixels around a polygon-cropped sagebush so foliage tufts stay crisp."""
    arr = np.asarray(sprite, dtype=np.uint8).copy()
    r = arr[:, :, 0].astype(np.float32)
    g = arr[:, :, 1].astype(np.float32)
    b = arr[:, :, 2].astype(np.float32)
    a = arr[:, :, 3]

    # Warm desert sand in Image 9 is distinctly reddish-orange (R - G > 44, G - B > 32, R > 165, B < 115)
    # whereas sagebush leaves & sunlit yellow-cream tips have much smaller R - G (< 38) or dark outlines.
    is_sand = (a > 0) & ((r - g) > 44.0) & ((g - b) > 28.0) & (r > 160.0) & (b < 115.0)

    # Only remove sand pixels connected to the outside border (flood fill from transparent border)
    h, w = a.shape
    visited = np.zeros((h, w), dtype=bool)
    queue: list[tuple[int, int]] = []

    # Seed from pixels adjacent to alpha==0 or image boundary
    for y in range(h):
        for x in range(w):
            if not is_sand[y, x]:
                continue
            on_edge = (
                y == 0 or y == h - 1 or x == 0 or x == w - 1
                or a[y - 1, x] == 0 or a[y + 1, x] == 0
                or a[y, x - 1] == 0 or a[y, x + 1] == 0
            )
            if on_edge:
                visited[y, x] = True
                queue.append((y, x))

    head = 0
    while head < len(queue):
        cy, cx = queue[head]
        head += 1
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_sand[ny, nx]:
                visited[ny, nx] = True
                queue.append((ny, nx))

    arr[visited, 3] = 0
    return Image.fromarray(arr)


def build_props_atlas(repaired: Image.Image, palette_img: Image.Image) -> dict:
    """Slice 6 large contoured 2.5D wall wings, 2 boulders, 2 sagebushes, and dressed curb stones."""
    # Padded plate: 120px mirrored left, 120px mirrored right, 48px bottom
    pad_l, pad_r, pad_b = 120, 120, 48
    plate = _extend_plate(repaired, pad_l, pad_r, pad_b)

    # All polygons and anchors are in 960x540 Image-9 coordinates (negative x or x > 960
    # uses the mirrored edge padding so side walls stay cleanly buried past screen edges).
    specs = {
        # --- 6 LARGE CONTOURED 2.5D WALL WINGS ---
        # 1. Left Foreground Terraced Ledge (sunlit lower-left pillar + foreground rock base)
        "left_fg_terraced_ledge": {
            "anchor": (165, 495),
            "poly": [
                (-96, 286), (0, 278), (38, 276), (78, 282), (118, 304),
                (142, 336), (146, 362), (186, 382), (200, 434), (218, 452),
                (252, 430), (288, 444), (314, 480), (338, 524), (344, 578),
                (-96, 578),
            ],
        },
        # 2. Left Mid Stepped Dry-Stone Wall (multi-tier curved dry-stone amphitheater & upper cliff)
        # Clean rounded stepped base so no narrow hanging spike shows as the camera scrolls uphill!
        "left_mid_drystone_wall": {
            "anchor": (248, 362),
            "poly": [
                (-110, 0), (198, 0), (222, 32), (242, 56), (344, 56),
                (372, 68), (386, 98), (384, 134), (350, 152), (312, 168),
                (288, 198), (288, 266), (274, 314), (254, 356), (228, 374),
                (188, 368), (150, 344), (118, 304), (72, 282), (-110, 286),
            ],
        },
        # 3. Left Upper Terracotta Cliff (stepped upper-left canyon wall strictly inside cliff contour; zero sky leak)
        "left_upper_terracotta_cliff": {
            "anchor": (420, 146),
            "poly": [
                (296, 0), (478, 0), (484, 24), (496, 52), (494, 76),
                (476, 92), (452, 108), (440, 138), (408, 146), (368, 146),
                (334, 158), (296, 156),
            ],
        },
        # 4. Right Foreground Shaded Step (lower-right shaded terracotta step + corner masonry)
        "right_fg_shaded_step": {
            "anchor": (812, 492),
            "poly": [
                (960 + 96, 290), (916, 294), (882, 312), (876, 360),
                (838, 376), (812, 418), (790, 474), (762, 514),
                (758, 578), (960 + 96, 578),
            ],
        },
        # 5. Right Mid Shaded Dry-Stone Wall (curved multi-tier shaded dry-stone wall & sunlit cap)
        "right_mid_drystone_wall": {
            "anchor": (700, 318),
            "poly": [
                (960 + 110, 26), (924, 30), (884, 44), (854, 62), (846, 108),
                (782, 118), (726, 132), (668, 142), (648, 174), (640, 224),
                (648, 266), (682, 294), (736, 326), (802, 358), (878, 386),
                (960 + 110, 396),
            ],
        },
        # 6. Right Upper Sunlit Cliff with God Rays (upper-right canyon cliff bathed in warm light shafts)
        "right_upper_sunlit_cliff": {
            "anchor": (642, 144),
            "poly": [
                (554, 0), (960 + 110, 0), (960 + 110, 128), (912, 128),
                (854, 122), (792, 138), (722, 154), (656, 156), (596, 140),
                (582, 112), (566, 86), (534, 68), (528, 44), (546, 18),
            ],
        },
        # --- 2 BOULDER CUTOUTS ---
        "boulder_left_sunlit": {
            "anchor": (288, 356),
            "poly": [
                (238, 326), (254, 300), (278, 286), (304, 290), (328, 314),
                (342, 344), (336, 360), (296, 366), (254, 362), (236, 348),
            ],
        },
        "boulder_bend_left": {
            "anchor": (392, 194),
            "poly": [
                (348, 168), (358, 142), (378, 128), (404, 134), (422, 156),
                (442, 174), (438, 194), (404, 200), (368, 198), (348, 186),
            ],
        },
        # --- 2 SAGEBUSH CUTOUTS (chroma-trimmed for crisp leaf silhouettes) ---
        "bush_left_fg": {
            "anchor": (304, 420),
            "bush": True,
            "poly": [
                (252, 392), (262, 358), (288, 346), (316, 344), (344, 358),
                (358, 386), (352, 418), (324, 432), (282, 430), (256, 416),
            ],
        },
        "bush_right_mid": {
            "anchor": (642, 314),
            "bush": True,
            "poly": [
                (600, 286), (610, 260), (636, 250), (664, 256), (684, 278),
                (684, 306), (668, 322), (634, 324), (608, 314),
            ],
        },
        # --- DRESSED CURB-STONE CUTOUTS ---
        "curb_left_a": {
            "anchor": (490, 434),
            "poly": [
                (476, 408), (504, 408), (510, 426), (506, 442), (474, 442), (468, 422),
            ],
        },
        "curb_left_b": {
            "anchor": (456, 488),
            "poly": [
                (446, 456), (476, 458), (478, 476), (466, 498), (432, 496), (428, 476),
            ],
        },
        "curb_right_a": {
            "anchor": (670, 432),
            "poly": [
                (652, 398), (684, 402), (692, 424), (686, 444), (654, 440), (648, 418),
            ],
        },
        "curb_mid_a": {
            "anchor": (404, 326),
            "poly": [
                (384, 308), (414, 304), (424, 320), (416, 336), (388, 336), (380, 322),
            ],
        },
    }

    # Shelf-pack into a clean atlas with 4px transparent gutters
    extracted: list[tuple[str, Image.Image, tuple[int, int]]] = []
    for name, info in specs.items():
        sprite, bounds = _extract_poly(plate, info["poly"], shift_x=pad_l)
        if info.get("bush"):
            sprite = _clean_bush_alpha(sprite)
        sprite = quantize_rgba(sprite, palette_img)
        # Recompute tight bbox after bush trim
        tight = sprite.getbbox()
        if tight is not None:
            sprite = sprite.crop(tight)
            bx = bounds[0] + tight[0] - pad_l
            by = bounds[1] + tight[1]
        else:
            bx = bounds[0] - pad_l
            by = bounds[1]
        ax, ay = info["anchor"]
        pivot = (ax - bx, ay - by)
        extracted.append((name, sprite, pivot))

    # Sort tallest-first for compact shelf packing
    extracted.sort(key=lambda item: item[1].height, reverse=True)
    atlas_w = 2048
    x, y, row_h = 4, 4, 0
    placements = []
    for name, sprite, pivot in extracted:
        if x + sprite.width + 4 > atlas_w:
            x = 4
            y += row_h + 6
            row_h = 0
        placements.append((name, sprite, pivot, x, y))
        x += sprite.width + 6
        row_h = max(row_h, sprite.height)

    atlas_h = y + row_h + 4
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    meta: dict[str, dict] = {}
    for name, sprite, pivot, px, py in placements:
        atlas.paste(sprite, (px, py))
        meta[name] = {
            "rect": [px, py, sprite.width, sprite.height],
            "pivot": [pivot[0], pivot[1]],
            "anchor_img9": list(specs[name]["anchor"]),
        }
        print(
            f"  {name:28s}: Rect2({px}, {py}, {sprite.width}, {sprite.height}), "
            f"pivot=Vector2({pivot[0]}, {pivot[1]}), anchor_img9={specs[name]['anchor']}"
        )

    atlas.save(OUTPUT_DIR / "props_atlas.png")
    with open(OUTPUT_DIR / "props_meta.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    return meta


def _road_at(distance: float) -> tuple[float, float]:
    for i in range(1, len(ROUTE_MARKS)):
        d1, cx1, hw1 = ROUTE_MARKS[i]
        if distance <= d1:
            d0, cx0, hw0 = ROUTE_MARKS[i - 1]
            t = max(0.0, min(1.0, (distance - d0) / (d1 - d0)))
            s = t * t * (3.0 - 2.0 * t)
            return (cx0 + (cx1 - cx0) * s, hw0 + (hw1 - hw0) * s)
    return (ROUTE_MARKS[-1][1], ROUTE_MARKS[-1][2])


def write_curve_check(img9_q: Image.Image) -> None:
    """Draw the calibrated S-curve onto Image 9 so we can visually inspect road alignment."""
    vis = img9_q.copy()
    draw = ImageDraw.Draw(vis)
    draw.line([(0, int(HORIZON)), (ART_W, int(HORIZON))], fill=(255, 255, 0), width=1)
    for y in range(int(HORIZON) + 12, ART_H, 2):
        apparent = (y - HORIZON) / (BOOTS[1] - HORIZON)
        dist = DEPTH * (1.0 / apparent - 1.0)
        cx, hw = _road_at(dist)
        sx = BOOTS[0] + cx * apparent
        shw = hw * apparent
        draw.point((int(sx), y), fill=(0, 255, 255))
        draw.point((int(sx - shw), y), fill=(0, 255, 0))
        draw.point((int(sx + shw), y), fill=(0, 255, 0))
    vis.save(TMP_DIR / "img9_curve_check.png")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    raw = Image.open(SOURCE_PATH).convert("RGB")
    ref_960 = raw.resize((ART_W, ART_H), LANCZOS)
    # Untouched 960x540 reference for F2 overlay and side-by-side comparison
    ref_960.save(OUTPUT_DIR / "img9_ref_960x540.png")

    # 192-colour palette sampled directly from Image 9
    palette_img = build_palette_image(ref_960, colors=192)
    img9_q = quantize_rgb(ref_960, palette_img)

    # Save 192-colour palette JSON for traceability
    pal_raw = palette_img.getpalette()[: 192 * 3]
    colors = [[pal_raw[i], pal_raw[i + 1], pal_raw[i + 2]] for i in range(0, len(pal_raw), 3)]
    with open(OUTPUT_DIR / "palette_192.json", "w", encoding="utf-8") as f:
        json.dump({"source": "img9_reference.jpg", "count": len(colors), "colors": colors}, f, indent=2)

    print("1) Repairing hero & shadow from cobblestone road...")
    repaired = repair_hero_from_road(img9_q, palette_img)
    repaired.save(OUTPUT_DIR / "road_repaired_960x540.png")

    print("2) Extracting sunlit canyon-mouth horizon backdrop...")
    backdrop = build_horizon_backdrop(img9_q, palette_img)
    backdrop.save(OUTPUT_DIR / "horizon_backdrop.png")

    print("3) Building Image-9 donor cobble, sand verge, and curb strip textures...")
    build_ground_textures(repaired, palette_img)

    print("4) Slicing 6 contoured wall wings + 2 boulders + 2 sagebushes + curb stones...")
    build_props_atlas(repaired, palette_img)

    write_curve_check(img9_q)
    print(f"Done! Wrote Image-9 perspective layers to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
