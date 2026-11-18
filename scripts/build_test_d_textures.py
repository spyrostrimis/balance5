import os
import cv2
import numpy as np

RAW_PATH = r"d:\Games\Balance5\assets\textures\canyon_pbr\test_c2_ledges_raw.png"
SHEET_PATH = r"C:\Users\PC\.gemini\antigravity\brain\25684232-7f72-4063-b959-1b79d32ac318\desert_stone_sandstone_albedo_sheet_1794942452330.jpg"
REF_PATH = r"d:\Games\Balance5\assets\textures\maps\desert_approach_rpg_albedo.png"
OUT_DIR = r"d:\Games\Balance5\assets\textures\canyon_pbr"


def make_seamless_512(patch_bgr: np.ndarray, pad: int = 64) -> np.ndarray:
    """Resizes a clean rock patch and makes it 4-way seamlessly tileable using a cosine wrap."""
    out_size = 512
    work = cv2.resize(patch_bgr, (out_size + pad, out_size + pad), interpolation=cv2.INTER_LANCZOS4).astype(np.float32)

    top = work[:pad, :]
    bot = work[out_size:, :]
    wy = (0.5 - 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, pad, dtype=np.float32)))[:, None, None]
    work_y = np.vstack([bot * (1.0 - wy) + top * wy, work[pad:out_size, :]])

    left = work_y[:, :pad]
    right = work_y[:, out_size:]
    wx = (0.5 - 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, pad, dtype=np.float32)))[None, :, None]
    seamless = np.hstack([right * (1.0 - wx) + left * wx, work_y[:, pad:out_size]])
    return np.clip(seamless, 0.0, 255.0).astype(np.uint8)


def generate_normal_map(albedo_bgr: np.ndarray, strength: float = 2.8, dy_boost: float = 1.0) -> np.ndarray:
    """Computes a wrapped tangent-space normal map from luminance Sobel gradients."""
    gray = cv2.cvtColor(albedo_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
    gray = cv2.GaussianBlur(gray, (3, 3), sigmaX=0.6)
    padded = cv2.copyMakeBorder(gray, 2, 2, 2, 2, cv2.BORDER_WRAP)
    dx = cv2.Sobel(padded, cv2.CV_32F, 1, 0, ksize=3)[2:-2, 2:-2]
    dy = cv2.Sobel(padded, cv2.CV_32F, 0, 1, ksize=3)[2:-2, 2:-2] * dy_boost

    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(nx)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-6)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len

    norm_b = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    norm_g = np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    norm_r = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    return cv2.merge([norm_b, norm_g, norm_r])


def _tile_seamless_2x(tile: np.ndarray) -> np.ndarray:
    """Halves feature scale cleanly (2x2 seamless repeat at 512x512) without introducing seams."""
    half = cv2.resize(tile, (256, 256), interpolation=cv2.INTER_AREA)
    return np.tile(half, (2, 2, 1))


def enhance_basalt_mortar(tile: np.ndarray) -> np.ndarray:
    """
    Re-grades dark stone cap texture into rough, weathered grey-brown desert shelf stone
    with softer joints and granular rock grit (avoiding harsh black spiderweb paving cracks).
    """
    finer = _tile_seamless_2x(tile)
    f = finer.astype(np.float32) / 255.0
    gray = 0.299 * f[:, :, 2] + 0.587 * f[:, :, 1] + 0.114 * f[:, :, 0]
    p5, p95 = np.percentile(gray, [5.0, 95.0])
    t = np.clip((gray - p5) / max(p95 - p5, 1e-4), 0.0, 1.0)
    # Compress deep paving cracks upward and mix fine rock grit so ledges read like natural weathered rock
    t = np.power(t, 0.72)
    rng = np.random.default_rng(42)
    grit = rng.normal(0.0, 0.055, size=t.shape).astype(np.float32)
    grit = cv2.GaussianBlur(grit, (3, 3), sigmaX=0.7)
    t = np.clip(t * 0.88 + 0.08 + grit, 0.0, 1.0)

    # BGR: soft warm crevice RGB(48,38,30) -> midtone RGB(94,72,56) -> sunlit highlight RGB(150,116,90)
    c_dark = np.array([30.0, 38.0, 48.0], dtype=np.float32)
    c_mid = np.array([56.0, 72.0, 94.0], dtype=np.float32)
    c_hi = np.array([90.0, 116.0, 150.0], dtype=np.float32)

    low_t = np.clip(t * 2.0, 0.0, 1.0)[:, :, None]
    hi_t = np.clip((t - 0.5) * 2.0, 0.0, 1.0)[:, :, None]
    graded = np.where(
        t[:, :, None] < 0.5,
        c_dark[None, None, :] * (1.0 - low_t) + c_mid[None, None, :] * low_t,
        c_mid[None, None, :] * (1.0 - hi_t) + c_hi[None, None, :] * hi_t,
    )
    return np.clip(graded, 0.0, 255.0).astype(np.uint8)


def enhance_sandstone_strata(tile: np.ndarray, ref_bgr: np.ndarray) -> np.ndarray:
    """
    Produces natural, horizontally varied sedimentary sandstone with subtle broken strata
    seams and blocky rock texture (no uniform zebra stripes) matching Img 1's left_wall_upper.
    """
    finer = _tile_seamless_2x(tile).astype(np.float32)
    h, w = finer.shape[:2]

    # Preserve rich fractured rock grit while keeping gentle horizontal sedimentary alignment
    padded = cv2.copyMakeBorder(finer, 16, 16, 32, 32, cv2.BORDER_WRAP)
    horiz_bed = cv2.GaussianBlur(padded, (35, 3), sigmaX=9.0, sigmaY=0.7)[16:-16, 32:-32]
    wide_blur = cv2.GaussianBlur(padded, (29, 29), sigmaX=9.0, sigmaY=9.0)[16:-16, 32:-32]
    grain = finer - wide_blur
    flat_rock = np.clip(horiz_bed * 0.35 + finer * 0.65 + grain * 0.55, 0.0, 255.0)

    gray = (0.299 * flat_rock[:, :, 2] + 0.587 * flat_rock[:, :, 1] + 0.114 * flat_rock[:, :, 0]) / 255.0
    yy = np.linspace(0.0, 2.0 * np.pi, h, dtype=np.float32)[:, None]
    xx = np.linspace(0.0, 2.0 * np.pi, w, dtype=np.float32)[None, :]
    # Pinching horizontal modulation so strata bands vary naturally across X instead of ruler stripes
    horiz_mod = 0.58 + 0.42 * np.sin(xx * 2.0 + 0.6 * np.sin(yy * 2.0))
    patch_var = 0.045 * np.sin(xx * 1.0 + yy * 2.0) * np.cos(xx * 3.0 - yy * 1.0)
    phase = yy + 0.018 * np.sin(xx * 2.0 + yy * 2.0) + 0.010 * np.cos(xx * 5.0)

    strata_wave = (
        0.036 * np.tanh(1.5 * np.sin(phase * 11.0 + 0.4 * np.sin(phase * 3.0))) * horiz_mod
        + 0.024 * np.sin(phase * 25.0 + 1.1) * (1.1 - 0.35 * horiz_mod)
        + 0.018 * np.tanh(1.8 * np.cos(phase * 43.0))
    )
    bed_val = np.clip(gray * 0.90 + 0.05 + strata_wave + patch_var, 0.0, 1.0)
    p4, p96 = np.percentile(bed_val, [4.0, 96.0])
    t = np.clip((bed_val - p4) / max(p96 - p4, 1e-4), 0.0, 1.0)

    # Map cleanly to Img 1 left_wall_upper BGR (~[22,36,68] -> [46,74,134] -> [88,134,202])
    c_dark = np.array([22.0, 36.0, 68.0], dtype=np.float32)
    c_mid = np.array([46.0, 74.0, 134.0], dtype=np.float32)
    c_hi = np.array([88.0, 134.0, 202.0], dtype=np.float32)
    low_t = np.clip(t * 2.0, 0.0, 1.0)[:, :, None]
    hi_t = np.clip((t - 0.5) * 2.0, 0.0, 1.0)[:, :, None]
    graded = np.where(
        t[:, :, None] < 0.5,
        c_dark[None, None, :] * (1.0 - low_t) + c_mid[None, None, :] * low_t,
        c_mid[None, None, :] * (1.0 - hi_t) + c_hi[None, None, :] * hi_t,
    )
    return np.clip(graded, 0.0, 255.0).astype(np.uint8)


def extract_clean_bush(ref_bgr: np.ndarray, x0: int, y0: int, x1: int, y1: int, out_path: str) -> None:
    """Extracts an individual crisp sage bush from Picture 1 with zero sand background halo."""
    crop = ref_bgr[y0:y1, x0:x1]
    crop = cv2.resize(crop, (crop.shape[1] * 2, crop.shape[0] * 2), interpolation=cv2.INTER_LANCZOS4)
    b, g, r = cv2.split(crop.astype(np.float32))
    warmth = r - g
    green_lift = g - b
    lum = (r + g + b) / 3.0

    sage_mask = ((warmth < 21.0) & (green_lift > 4.0) & (lum < 220.0) & (lum > 30.0)).astype(np.float32)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    near_sage = cv2.dilate(sage_mask, kernel, iterations=1)
    inner_fill = (((lum < 100.0) | ((lum < 215.0) & (warmth < 26.0))) & (near_sage > 0.5)).astype(np.float32)
    mask = np.clip(np.maximum(sage_mask, inner_fill), 0.0, 1.0)
    mask = cv2.morphologyEx((mask > 0.5).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)).astype(np.float32)

    n_lbl, labels, stats, _ = cv2.connectedComponentsWithStats((mask > 0.5).astype(np.uint8))
    clean = np.zeros_like(mask)
    for lbl in range(1, n_lbl):
        if stats[lbl, cv2.CC_STAT_AREA] >= 250:
            clean[labels == lbl] = 1.0

    ch, cw = crop.shape[:2]
    yy, xx = np.mgrid[0:ch, 0:cw].astype(np.float32)
    border = (
        np.clip(xx / 6.0, 0.0, 1.0)
        * np.clip((cw - 1 - xx) / 6.0, 0.0, 1.0)
        * np.clip(yy / 6.0, 0.0, 1.0)
        * np.clip((ch - 1 - yy) / 8.0, 0.0, 1.0)
    )
    alpha = cv2.GaussianBlur(clean * border, (5, 5), sigmaX=1.0)
    rgba = cv2.cvtColor(crop, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    cv2.imwrite(out_path, rgba)
    print(f"Saved bush sprite {out_path} ({cw}x{ch}), opaque px={(rgba[:, :, 3] > 30).sum()}")


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet = cv2.imread(SHEET_PATH, cv2.IMREAD_COLOR)
    ref = cv2.imread(REF_PATH, cv2.IMREAD_COLOR)
    if sheet is None or ref is None:
        raise FileNotFoundError(f"Missing sheet={SHEET_PATH} or ref={REF_PATH}")

    sh, sw = sheet.shape[:2]
    # 1. Pure dark charcoal Basalt Cap blocks from clean top half (avoiding center divider line around 50%)
    basalt_patch = sheet[0:int(sh * 0.48), :]
    basalt_alb = enhance_basalt_mortar(make_seamless_512(basalt_patch))
    basalt_nrm = generate_normal_map(basalt_alb, strength=3.0)
    cv2.imwrite(os.path.join(OUT_DIR, "d_basalt_cap_albedo.png"), basalt_alb)
    cv2.imwrite(os.path.join(OUT_DIR, "d_basalt_cap_normal.png"), basalt_nrm)

    # 2. Pure terracotta Sandstone Strata from clean bottom half
    strata_patch = sheet[int(sh * 0.52):sh, :]
    strata_alb = enhance_sandstone_strata(make_seamless_512(strata_patch), ref)
    strata_nrm = generate_normal_map(strata_alb, strength=3.6, dy_boost=1.45)
    cv2.imwrite(os.path.join(OUT_DIR, "d_sandstone_strata_albedo.png"), strata_alb)
    cv2.imwrite(os.path.join(OUT_DIR, "d_sandstone_strata_normal.png"), strata_nrm)

    # 3. Warm golden-ochre fractured Boulder surface derived from clean fractured stone facets
    b_raw = make_seamless_512(basalt_patch).astype(np.float32) / 255.0
    boulder_warm = np.zeros_like(b_raw)
    gray_b = 0.299 * b_raw[:, :, 2] + 0.587 * b_raw[:, :, 1] + 0.114 * b_raw[:, :, 0]
    gray_b = np.maximum(gray_b, 0.09)
    boulder_warm[:, :, 2] = np.clip(gray_b * 2.15 + 0.16, 0.0, 0.96)  # R
    boulder_warm[:, :, 1] = np.clip(gray_b * 1.62 + 0.08, 0.0, 0.82)  # G
    boulder_warm[:, :, 0] = np.clip(gray_b * 1.05 + 0.03, 0.0, 0.58)  # B
    boulder_alb = np.clip(boulder_warm * 255.0, 0, 255).astype(np.uint8)
    boulder_nrm = generate_normal_map(boulder_alb, strength=2.6)
    cv2.imwrite(os.path.join(OUT_DIR, "d_boulder_rock_albedo.png"), boulder_alb)
    cv2.imwrite(os.path.join(OUT_DIR, "d_boulder_rock_normal.png"), boulder_nrm)

    # 4. Crisp un-haloed 2.5D desert sagebrush cutout sprites
    extract_clean_bush(ref, 382, 540, 484, 645, os.path.join(OUT_DIR, "d_sage_bush_1.png"))
    extract_clean_bush(ref, 515, 535, 610, 625, os.path.join(OUT_DIR, "d_sage_bush_2.png"))
    print("Generated all Small Test D albedo, normal, and sagebush textures.")


if __name__ == "__main__":
    main()
