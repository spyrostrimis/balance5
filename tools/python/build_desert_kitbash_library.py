from pathlib import Path
import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
SRC_ALBEDO = ROOT / "assets/textures/maps/desert_mission_1_clean_albedo.png"
KIT_DIR = ROOT / "assets/textures/kitbash"
TILED_DIR = ROOT / "assets/textures/source/tiled"

# Exact mean BGR of the uploaded 185x102 reference image's flat sand (RGB 222, 138, 42)
TARGET_SAND_BGR = np.array([44.0, 138.0, 222.0], dtype=np.float32)


def flatten_sand_tone(patch_bgr: np.ndarray, target_bgr: np.ndarray, sigma: float = 24.0) -> np.ndarray:
    """Remove macro illumination drift while keeping crisp stippled sand grain."""
    f = patch_bgr.astype(np.float32)
    low = cv2.GaussianBlur(f, (0, 0), sigmaX=sigma, sigmaY=sigma, borderType=cv2.BORDER_REFLECT_101)
    return np.clip(f - low + target_bgr[None, None, :], 0, 255).astype(np.uint8)


def build_sand_macro_grid(clean: np.ndarray) -> tuple[np.ndarray, list[np.ndarray]]:
    """Build a seamless 128x128 (4x4 grid of 32x32) stippled sand texture and its 16 tiles."""
    raw_patches = [
        clean[500:548, 292:340],  # mid-lower left flat sand
        clean[490:538, 368:416],  # mid-lower center sand
        clean[410:458, 830:878],  # eastern sand flat
        clean[145:193, 520:568],  # upper-mid sand flat
    ]
    patches = [flatten_sand_tone(p, TARGET_SAND_BGR, sigma=18.0).astype(np.float32) for p in raw_patches]

    buf = np.zeros((168, 168, 3), dtype=np.float32)
    w_sum = np.zeros((168, 168, 1), dtype=np.float32)
    t1d = np.sin(np.pi * np.linspace(0.0, 1.0, 48, dtype=np.float32)) ** 2
    wt = (t1d[:, None] * t1d[None, :])[..., None]

    for r in range(6):
        for c in range(6):
            idx = (r * 3 + c * 2 + (r ^ c)) % 4
            p = patches[idx]
            y0, x0 = r * 24, c * 24
            buf[y0:y0 + 48, x0:x0 + 48] += p * wt
            w_sum[y0:y0 + 48, x0:x0 + 48] += wt

    canvas = buf / np.maximum(w_sum, 1e-6)
    canvas = flatten_sand_tone(np.clip(canvas, 0, 255).astype(np.uint8), TARGET_SAND_BGR, sigma=24.0).astype(np.float32)

    ramp = 0.5 - 0.5 * np.cos(np.pi * (np.arange(16, dtype=np.float32) / 16.0))
    horiz = canvas[20:164, 20:148].copy()
    horiz[:, :16, :] = (
        canvas[20:164, 148:164, :] * (1.0 - ramp[None, :, None])
        + canvas[20:164, 20:36, :] * ramp[None, :, None]
    )
    seamless = horiz[:128, :, :].copy()
    seamless[:16, :, :] = (
        horiz[128:144, :, :] * (1.0 - ramp[:, None, None])
        + horiz[:16, :, :] * ramp[:, None, None]
    )
    seamless_128 = np.clip(seamless, 0, 255).astype(np.uint8)

    cv2.imwrite(str(KIT_DIR / "sand_macro_tileset.png"), seamless_128)
    tiles: list[np.ndarray] = []
    for tr in range(4):
        for tc in range(4):
            tile = seamless_128[tr * 32:(tr + 1) * 32, tc * 32:(tc + 1) * 32]
            idx = tr * 4 + tc
            cv2.imwrite(str(KIT_DIR / f"sand_base_{idx}.png"), tile)
            tiles.append(tile)
    return seamless_128, tiles


def build_cobble_road_tileset(clean: np.ndarray) -> Path:
    """Build a 128x128 (4x4 of 32x32) 4-bit orthogonal autotile cobblestone road atlas.

    Tile index = mask (0..15) where bits are N=1, E=2, S=4, W=8, at (col=mask%4, row=mask//4).
    """
    # Clean sandstone flagstone patches from the central roundabout apron
    c1 = clean[256:288, 488:552].copy()  # 32x64 clean flagstones
    c2 = clean[420:452, 464:528].copy()  # 32x64 lower apron flagstones
    target_cobble = np.array([124.0, 162.0, 200.0], dtype=np.float32)
    p1 = flatten_sand_tone(c1, target_cobble, sigma=16.0).astype(np.float32)
    p2 = flatten_sand_tone(c2, target_cobble, sigma=16.0).astype(np.float32)

    # Assemble a 64x64 seamless flagstone canvas
    buf = np.zeros((96, 96, 3), dtype=np.float32)
    wsum = np.zeros((96, 96, 1), dtype=np.float32)
    tx = np.sin(np.pi * np.linspace(0.0, 1.0, 64, dtype=np.float32)) ** 2
    ty = np.sin(np.pi * np.linspace(0.0, 1.0, 32, dtype=np.float32)) ** 2
    wt = (ty[:, None] * tx[None, :])[..., None]
    for r in range(5):
        for c in range(2):
            p = p1 if (r + c) % 2 == 0 else p2
            y0, x0 = r * 16, c * 32
            buf[y0:y0 + 32, x0:x0 + 64] += p * wt
            wsum[y0:y0 + 32, x0:x0 + 64] += wt
    cob = buf / np.maximum(wsum, 1e-6)
    cob_32 = np.clip(cob[32:64, 16:48], 0, 255).astype(np.float32)

    # Smooth wrap cob_32 across 32x32 so connecting roads show zero seam across tile borders
    ramp = 0.5 - 0.5 * np.cos(np.pi * (np.arange(8, dtype=np.float32) / 8.0))
    cob_h = cob[24:64, 16:48].copy()
    cob_h[:, :8, :] = cob[24:64, 48:56, :] * (1.0 - ramp[None, :, None]) + cob[24:64, 16:24, :] * ramp[None, :, None]
    cob_tile = cob_h[:32, :, :].copy()
    cob_tile[:8, :, :] = cob_h[32:40, :, :] * (1.0 - ramp[:, None, None]) + cob_h[:8, :, :] * ramp[:, None, None]

    # Precompute deterministic subtle stone-curb wobble field (periodic on 32x32)
    yy, xx = np.mgrid[0:32, 0:32].astype(np.float32)
    wobble = (
        0.95 * np.sin(2.0 * np.pi * xx / 16.0 + 0.7) * np.cos(2.0 * np.pi * yy / 16.0 - 0.4)
        + 0.55 * np.sin(2.0 * np.pi * (xx + yy) / 10.6667)
    )

    atlas = np.zeros((128, 128, 4), dtype=np.uint8)
    cx, cy = 15.5, 15.5
    half_w = 11.2

    for mask in range(16):
        has_n = bool(mask & 1)
        has_e = bool(mask & 2)
        has_s = bool(mask & 4)
        has_w = bool(mask & 8)

        # Signed distance to union of rounded central hub + connected arms
        dist = np.hypot(xx - cx, yy - cy) - half_w
        if has_n:
            d_n = np.where(yy <= cy, np.abs(xx - cx) - half_w, np.hypot(xx - cx, yy - cy) - half_w)
            dist = np.minimum(dist, d_n)
        if has_s:
            d_s = np.where(yy >= cy, np.abs(xx - cx) - half_w, np.hypot(xx - cx, yy - cy) - half_w)
            dist = np.minimum(dist, d_s)
        if has_w:
            d_w = np.where(xx <= cx, np.abs(yy - cy) - half_w, np.hypot(xx - cx, yy - cy) - half_w)
            dist = np.minimum(dist, d_w)
        if has_e:
            d_e = np.where(xx >= cx, np.abs(yy - cy) - half_w, np.hypot(xx - cx, yy - cy) - half_w)
            dist = np.minimum(dist, d_e)

        # Keep boundary arms exact on tile edges so adjacent tiles connect cleanly
        edge_fade = np.minimum(np.minimum(xx, 31.0 - xx), np.minimum(yy, 31.0 - yy))
        wob_weight = np.clip(edge_fade / 4.0, 0.0, 1.0)
        sdf = dist + wobble * wob_weight

        # Subtle dark stone curb shadow along outer rim (sdf in [-1.8..+1.5])
        curb_darken = np.exp(-((sdf - 0.2) ** 2) / 1.8) * 0.28
        tile_rgb = cob_tile * (1.0 - curb_darken[..., None])
        # Warm sandy dust blend right at the outer 1.5px fringe
        sand_fringe = np.clip((sdf + 1.0) / 2.2, 0.0, 1.0)[..., None] * 0.45
        tile_rgb = tile_rgb * (1.0 - sand_fringe) + TARGET_SAND_BGR[None, None, :] * sand_fringe

        alpha = np.clip((1.6 - sdf) / 2.4, 0.0, 1.0)
        alpha = 0.5 - 0.5 * np.cos(np.pi * alpha)
        alpha[alpha < 0.04] = 0.0

        rgba = np.dstack([
            np.clip(tile_rgb, 0, 255).astype(np.uint8),
            np.clip(alpha * 255.0, 0, 255).astype(np.uint8),
        ])
        col, row = mask % 4, mask // 4
        atlas[row * 32:(row + 1) * 32, col * 32:(col + 1) * 32] = rgba

    out_path = KIT_DIR / "road_tileset.png"
    cv2.imwrite(str(out_path), atlas)
    return out_path


def heal_spot(img: np.ndarray, cx: int, cy: int, r: int, _dx: int = 0, _dy: int = 0) -> None:
    """Inpaint a small stray speck at (cx, cy) smoothly from surrounding pixels."""
    mask = np.zeros(img.shape[:2], dtype=np.uint8)
    cv2.circle(mask, (cx, cy), max(1, r), 255, -1)
    healed = cv2.inpaint(img, mask, inpaintRadius=max(2, r + 1), flags=cv2.INPAINT_TELEA)
    img[:] = healed


def extract_dune_stamp(
    clean: np.ndarray,
    name: str,
    x: int,
    y: int,
    w: int,
    h: int,
    margin: tuple[int, int, int, int] = (10, 10, 10, 10),
    heals: list[tuple[int, ...]] | None = None,
) -> Path:
    """Extract a dune wave bank with wide macro tone leveling and relief-gated feathered alpha."""
    crop = clean[y:y + h, x:x + w].copy()
    if heals:
        for item in heals:
            heal_spot(crop, item[0] - x, item[1] - y, item[2])

    f_crop = crop.astype(np.float32)
    low_freq_bg = cv2.GaussianBlur(f_crop, (0, 0), sigmaX=26.0, sigmaY=26.0, borderType=cv2.BORDER_REFLECT_101)
    norm_bgr = np.clip(f_crop - low_freq_bg + TARGET_SAND_BGR[None, None, :], 0, 255).astype(np.uint8)

    gray = cv2.cvtColor(norm_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    gray_low = cv2.GaussianBlur(gray, (0, 0), sigmaX=18.0, sigmaY=18.0, borderType=cv2.BORDER_REFLECT_101)
    relief = cv2.GaussianBlur(np.abs(gray - gray_low), (0, 0), sigmaX=9.0, sigmaY=9.0, borderType=cv2.BORDER_REFLECT_101)
    wave_mask = np.clip((relief - 2.2) / 4.5, 0.0, 1.0)
    wave_mask = cv2.GaussianBlur(wave_mask, (0, 0), sigmaX=5.0, sigmaY=5.0, borderType=cv2.BORDER_CONSTANT)

    ml, mt, mr, mb = margin
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ax_l = np.clip(xx / max(ml, 1), 0.0, 1.0) if ml > 0 else np.ones_like(xx)
    ax_r = np.clip((w - 1.0 - xx) / max(mr, 1), 0.0, 1.0) if mr > 0 else np.ones_like(xx)
    ay_t = np.clip(yy / max(mt, 1), 0.0, 1.0) if mt > 0 else np.ones_like(yy)
    ay_b = np.clip((h - 1.0 - yy) / max(mb, 1), 0.0, 1.0) if mb > 0 else np.ones_like(yy)

    rect_feather = np.minimum(np.minimum(ax_l, ax_r), np.minimum(ay_t, ay_b))
    rect_feather = 0.5 - 0.5 * np.cos(np.pi * rect_feather)
    alpha = np.clip(rect_feather * wave_mask, 0.0, 1.0)
    alpha[alpha < 0.02] = 0.0
    alpha_u8 = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)

    rgba = np.dstack([norm_bgr, alpha_u8])
    out_path = KIT_DIR / f"{name}.png"
    cv2.imwrite(str(out_path), rgba)
    return out_path


def extract_prop_stamp(
    clean: np.ndarray,
    name: str,
    cx: int,
    cy: int,
    w: int,
    h: int,
    core_radius: float,
    shadow_shift: tuple[float, float] = (2.0, 2.0),
    diff_thresh: float = 28.0,
) -> Path:
    """Extract an alpha-cut shrub, pebble, or speck with neutral sand-matched fringe."""
    x0 = cx - w // 2
    y0 = cy - h // 2
    crop = clean[y0:y0 + h, x0:x0 + w].copy()

    border = np.concatenate([crop[0, :], crop[-1, :], crop[:, 0], crop[:, -1]], axis=0)
    bg_bgr = np.median(border, axis=0).astype(np.float32)
    diff = np.linalg.norm(crop.astype(np.float32) - bg_bgr[None, None, :], axis=2)

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ox, oy = (w - 1) * 0.5, (h - 1) * 0.5
    d_core = np.hypot(xx - ox, yy - oy)
    d_shadow = np.hypot(xx - (ox + shadow_shift[0]), yy - (oy + shadow_shift[1]))
    radial_gate = np.maximum(
        np.clip(1.0 - (d_core - core_radius) / 2.2, 0.0, 1.0),
        0.72 * np.clip(1.0 - (d_shadow - (core_radius + 0.5)) / 2.5, 0.0, 1.0),
    )

    color_alpha = np.clip((diff - diff_thresh * 0.45) / (diff_thresh * 0.85), 0.0, 1.0)
    alpha = np.clip(color_alpha * radial_gate, 0.0, 1.0)

    solid = (d_core <= core_radius * 0.65) & (diff > diff_thresh * 0.7)
    alpha = np.where(solid, 1.0, alpha)
    alpha = cv2.GaussianBlur(alpha.astype(np.float32), (3, 3), 0.55)
    alpha[alpha < 0.05] = 0.0

    bgr_out = crop.astype(np.float32)
    fringe = (alpha > 0.0) & (alpha < 0.6)
    if np.any(fringe):
        shift_w = np.clip((0.6 - alpha[fringe]) / 0.6, 0.0, 1.0)[:, None] * 0.65
        bgr_out[fringe] = bgr_out[fringe] * (1.0 - shift_w) + TARGET_SAND_BGR[None, :] * shift_w

    rgba = np.dstack([np.clip(bgr_out, 0, 255).astype(np.uint8), np.clip(alpha * 255.0, 0, 255).astype(np.uint8)])
    out_path = KIT_DIR / f"{name}.png"
    cv2.imwrite(str(out_path), rgba)
    return out_path


def extract_landmark_stamps(clean: np.ndarray) -> list[Path]:
    """Extract reusable obstacle landmarks: Orichalcum crystal mound, basalt mesa, and oasis spring."""
    out: list[Path] = []

    def fill_holes(bin_mask: np.ndarray) -> np.ndarray:
        h, w = bin_mask.shape
        inv = (bin_mask == 0).astype(np.uint8)
        ff = inv.copy()
        ff_mask = np.zeros((h + 2, w + 2), dtype=np.uint8)
        for sx in range(w):
            if ff[0, sx] == 1:
                cv2.floodFill(ff, ff_mask, (sx, 0), 2)
            if ff[h - 1, sx] == 1:
                cv2.floodFill(ff, ff_mask, (sx, h - 1), 2)
        for sy in range(h):
            if ff[sy, 0] == 1:
                cv2.floodFill(ff, ff_mask, (0, sy), 2)
            if ff[sy, w - 1] == 1:
                cv2.floodFill(ff, ff_mask, (w - 1, sy), 2)
        return (ff != 2).astype(np.uint8)

    # 1. Orichalcum crystal mound (398..596, 282..428): dark basalt ring + interior glowing crystals
    cryst = clean[282:428, 398:596].copy()
    ch, cw = cryst.shape[:2]
    gray_c = cv2.cvtColor(cryst, cv2.COLOR_BGR2GRAY)
    b, g, r = cv2.split(cryst)
    # Dark basalt & rubble skirt is significantly darker than the surrounding tan cobblestones (~145..200)
    dark_ring = ((gray_c < 108) & (r < 140)).astype(np.uint8)
    dark_ring = cv2.morphologyEx(dark_ring, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    fg = fill_holes(dark_ring)
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    num, labels, stats, _ = cv2.connectedComponentsWithStats(fg)
    if num > 1:
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        fg = (labels == largest).astype(np.uint8)
    alpha_c = cv2.GaussianBlur(fg.astype(np.float32), (3, 3), 0.75)
    alpha_c = np.where(cv2.erode(fg, np.ones((3, 3), np.uint8)) > 0, 1.0, alpha_c)
    alpha_c[alpha_c < 0.06] = 0.0
    p_cryst = KIT_DIR / "rock_crystal_outcrop.png"
    cv2.imwrite(str(p_cryst), np.dstack([cryst, np.clip(alpha_c * 255, 0, 255).astype(np.uint8)]))
    out.append(p_cryst)

    # 2. Standalone basalt rock mesa from top-left outcrop (52..204, 12..98) with clean right margin
    mesa = clean[12:98, 52:204].copy()
    mh, mw = mesa.shape[:2]
    b, g, r = cv2.split(mesa)
    hsv_m = cv2.cvtColor(mesa, cv2.COLOR_BGR2HSV)
    is_green_m = (hsv_m[:, :, 0] >= 24) & (hsv_m[:, :, 0] <= 80) & (hsv_m[:, :, 1] > 80)
    is_sand = (((r.astype(int) - b.astype(int)) > 72) & (r > 145)) | is_green_m
    yy, xx = np.mgrid[0:mh, 0:mw]
    fg_m = (~is_sand).astype(np.uint8)
    fg_m[(xx + yy * 1.1) < 32] = 0
    fg_m[(xx > mw - 34) & (yy > mh - 24)] = 0
    fg_m[:, -6:] = 0
    top_curve = 7.0 + 10.0 * ((xx - mw * 0.48) / (mw * 0.46)) ** 2
    fg_m[yy < top_curve] = 0
    fg_m = cv2.morphologyEx(fg_m, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    fg_m = fill_holes(fg_m)
    fg_m = cv2.morphologyEx(fg_m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    num, labels, stats, _ = cv2.connectedComponentsWithStats(fg_m)
    if num > 1:
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        fg_m = (labels == largest).astype(np.uint8)
    alpha_m = cv2.GaussianBlur(fg_m.astype(np.float32), (5, 5), 1.0)
    alpha_m = np.where(cv2.erode(fg_m, np.ones((5, 5), np.uint8)) > 0, 1.0, alpha_m)
    alpha_m[alpha_m < 0.05] = 0.0
    p_mesa = KIT_DIR / "rock_basalt_mesa.png"
    cv2.imwrite(str(p_mesa), np.dstack([mesa, np.clip(alpha_m * 255, 0, 255).astype(np.uint8)]))
    out.append(p_mesa)

    # 3. Full oval oasis spring pool + lush green reed rim from clean[96:194, 746:874]
    oasis = clean[96:194, 746:874].copy()
    b, g, r = cv2.split(oasis)
    hsv = cv2.cvtColor(oasis, cv2.COLOR_BGR2HSV)
    is_water = (b.astype(int) > r.astype(int) + 12) & (b > 90)
    is_green = (hsv[:, :, 0] >= 24) & (hsv[:, :, 0] <= 85) & (hsv[:, :, 1] > 75) & (hsv[:, :, 2] > 35)
    fg_o = (is_water | is_green).astype(np.uint8)
    fg_o = cv2.morphologyEx(fg_o, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    fg_o = fill_holes(fg_o)
    fg_o = cv2.dilate(fg_o, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)), iterations=1)
    num, labels, stats, _ = cv2.connectedComponentsWithStats(fg_o)
    keep_o = np.zeros_like(fg_o)
    for idx in range(1, num):
        if stats[idx, cv2.CC_STAT_AREA] >= 50:
            keep_o[labels == idx] = 1
    alpha_o = cv2.GaussianBlur(keep_o.astype(np.float32), (5, 5), 1.2)
    alpha_o = np.where(cv2.erode(keep_o, np.ones((3, 3), np.uint8)) > 0, 1.0, alpha_o)
    alpha_o[alpha_o < 0.05] = 0.0
    p_oasis = KIT_DIR / "oasis_spring.png"
    cv2.imwrite(str(p_oasis), np.dstack([oasis, np.clip(alpha_o * 255, 0, 255).astype(np.uint8)]))
    out.append(p_oasis)

    return out


def export_tiled_kitbash(seamless_128: np.ndarray, road_path: Path, stamp_paths: list[Path]) -> None:
    """Create desert_kitbash_tileset.png, .tsx files, and desert_kitbash_examples.tmx."""
    TILED_DIR.mkdir(parents=True, exist_ok=True)

    atlas = np.zeros((256, 256, 4), dtype=np.uint8)
    atlas[0:128, 0:128, :3] = seamless_128
    atlas[0:128, 0:128, 3] = 255
    road_img = cv2.imread(str(road_path), cv2.IMREAD_UNCHANGED)
    if road_img is not None:
        atlas[0:128, 128:256] = road_img

    cur_x, cur_y = 0, 132
    row_h = 0
    for sp in stamp_paths:
        im = cv2.imread(str(sp), cv2.IMREAD_UNCHANGED)
        if im is None:
            continue
        sh, sw = im.shape[:2]
        if sw > 96 or sh > 56:
            scale = min(96.0 / sw, 56.0 / sh)
            im = cv2.resize(im, (max(1, int(sw * scale)), max(1, int(sh * scale))), interpolation=cv2.INTER_AREA)
            sh, sw = im.shape[:2]
        if cur_x + sw > 256:
            cur_x = 0
            cur_y += row_h + 2
            row_h = 0
        if cur_y + sh <= 256:
            atlas[cur_y:cur_y + sh, cur_x:cur_x + sw] = im
            cur_x += sw + 2
            row_h = max(row_h, sh)

    atlas_path = TILED_DIR / "desert_kitbash_tileset.png"
    cv2.imwrite(str(atlas_path), atlas)

    tsx_grid = TILED_DIR / "desert_kitbash_tileset.tsx"
    tsx_grid.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.0" name="desert_kitbash_tileset" tilewidth="32" tileheight="32" tilecount="64" columns="8">
 <image source="desert_kitbash_tileset.png" width="256" height="256"/>
</tileset>
""",
        encoding="utf-8",
    )

    stamp_entries = []
    max_w, max_h = 1, 1
    for tid, sp in enumerate(stamp_paths):
        im = cv2.imread(str(sp), cv2.IMREAD_UNCHANGED)
        sh, sw = im.shape[:2]
        max_w = max(max_w, sw)
        max_h = max(max_h, sh)
        rel = f"../../kitbash/{sp.name}"
        stamp_entries.append(
            f' <tile id="{tid}">\n  <image source="{rel}" width="{sw}" height="{sh}"/>\n </tile>'
        )

    tsx_stamps = TILED_DIR / "desert_kitbash_stamps.tsx"
    tsx_stamps.write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.0" name="desert_kitbash_stamps" tilewidth="{max_w}" tileheight="{max_h}" tilecount="{len(stamp_paths)}" columns="0">
 <grid orientation="orthogonal" width="1" height="1"/>
{chr(10).join(stamp_entries)}
</tileset>
""",
        encoding="utf-8",
    )

    cols, rows = 20, 11
    csv_lines = []
    for r in range(rows):
        line = [str(1 + (r % 4) * 8 + (c % 4)) for c in range(cols)]
        csv_lines.append(",".join(line))

    first_stamp_gid = 65
    name_to_gid = {sp.stem: first_stamp_gid + i for i, sp in enumerate(stamp_paths)}

    tmx_path = TILED_DIR / "desert_kitbash_examples.tmx"
    tmx_path.write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.11.0" orientation="orthogonal" renderorder="right-down" width="{cols}" height="{rows}" tilewidth="32" tileheight="32" infinite="0" nextlayerid="4" nextobjectid="12">
 <tileset firstgid="1" source="desert_kitbash_tileset.tsx"/>
 <tileset firstgid="{first_stamp_gid}" source="desert_kitbash_stamps.tsx"/>
 <layer id="1" name="SandBase" width="{cols}" height="{rows}">
  <data encoding="csv">
{",\n".join(csv_lines)}
</data>
 </layer>
 <objectgroup id="2" name="DuneRidges">
  <object id="1" gid="{name_to_gid['dune_bank_ml']}" x="0" y="106" width="130" height="100"/>
  <object id="2" gid="{name_to_gid['dune_bank_ul']}" x="470" y="70" width="145" height="64"/>
  <object id="3" gid="{name_to_gid['dune_bank_mr']}" x="498" y="346" width="138" height="106"/>
 </objectgroup>
 <objectgroup id="3" name="LandmarksAndProps">
  <object id="4" gid="{name_to_gid['rock_crystal_outcrop']}" x="246" y="218" width="124" height="92"/>
  <object id="5" gid="{name_to_gid['oasis_spring']}" x="404" y="136" width="104" height="90"/>
  <object id="6" gid="{name_to_gid['rock_basalt_mesa']}" x="32" y="318" width="112" height="68"/>
  <object id="7" gid="{name_to_gid['shrub_0']}" x="150" y="112" width="22" height="20"/>
  <object id="8" gid="{name_to_gid['shrub_4']}" x="378" y="274" width="24" height="22"/>
  <object id="9" gid="{name_to_gid['pebble_0']}" x="192" y="244" width="14" height="14"/>
 </objectgroup>
</map>
""",
        encoding="utf-8",
    )


def main() -> None:
    KIT_DIR.mkdir(parents=True, exist_ok=True)
    clean = cv2.imread(str(SRC_ALBEDO))
    if clean is None:
        raise FileNotFoundError(f"Missing clean albedo: {SRC_ALBEDO}")

    seamless_128, _ = build_sand_macro_grid(clean)
    road_path = build_cobble_road_tileset(clean)

    stamps: list[Path] = [
        extract_dune_stamp(
            clean,
            "dune_bank_ul",
            275,
            16,
            145,
            64,
            margin=(12, 10, 10, 12),
            heals=[(352, 36, 3)],
        ),
        extract_dune_stamp(
            clean,
            "dune_bank_ml",
            220,
            368,
            130,
            100,
            margin=(10, 12, 14, 10),
            heals=[(304, 444, 4), (311, 440, 3), (324, 412, 2)],
        ),
        extract_dune_stamp(clean, "dune_bank_lm_taper", 554, 520, 102, 86, margin=(14, 10, 10, 10)),
        extract_dune_stamp(
            clean,
            "dune_bank_mr",
            870,
            394,
            138,
            106,
            margin=(14, 8, 8, 8),
            heals=[(956, 442, 3), (969, 469, 3)],
        ),
        extract_dune_stamp(
            clean,
            "dune_bank_lm_wide",
            500,
            614,
            160,
            78,
            margin=(12, 10, 12, 10),
            heals=[(564, 667, 3)],
        ),
    ]

    stamps.extend(extract_landmark_stamps(clean))

    shrub_specs = [
        (278, 325, 22, 20, 6.2),
        (581, 464, 22, 20, 6.2),
        (686, 427, 22, 20, 6.5),
        (904, 507, 22, 20, 6.0),
        (926, 536, 24, 22, 7.2),
        (210, 602, 22, 20, 6.0),
    ]
    for i, (cx, cy, sw, sh, rad) in enumerate(shrub_specs):
        stamps.append(extract_prop_stamp(clean, f"shrub_{i}", cx, cy, sw, sh, core_radius=rad, diff_thresh=24.0))

    pebble_specs = [
        (622, 169, 14, 14, 4.0),
        (538, 583, 14, 14, 4.0),
        (881, 489, 14, 14, 4.2),
        (411, 568, 12, 12, 3.2),
        (368, 563, 12, 12, 3.2),
        (389, 535, 12, 12, 3.4),
    ]
    for i, (cx, cy, pw, ph, rad) in enumerate(pebble_specs):
        stamps.append(extract_prop_stamp(clean, f"pebble_{i}", cx, cy, pw, ph, core_radius=rad, diff_thresh=22.0))

    speck_specs = [
        (535, 213, 10, 10, 2.5),
        (433, 495, 10, 10, 2.5),
        (586, 216, 10, 10, 2.4),
        (375, 543, 10, 10, 2.4),
        (357, 578, 10, 10, 2.5),
        (538, 614, 10, 10, 2.5),
    ]
    for i, (cx, cy, kw, kh, rad) in enumerate(speck_specs):
        stamps.append(extract_prop_stamp(clean, f"speck_{i}", cx, cy, kw, kh, core_radius=rad, diff_thresh=20.0))

    export_tiled_kitbash(seamless_128, road_path, stamps)
    print(f"Built sand macro-grid + 16 cobble road tiles + {len(stamps)} kitbash stamps + Tiled pack.")


if __name__ == "__main__":
    main()
