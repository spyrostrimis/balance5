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


def generate_normal_map(albedo_bgr: np.ndarray, strength: float = 2.8) -> np.ndarray:
    """Computes a wrapped tangent-space normal map from luminance Sobel gradients."""
    gray = cv2.cvtColor(albedo_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
    gray = cv2.GaussianBlur(gray, (3, 3), sigmaX=0.6)
    padded = cv2.copyMakeBorder(gray, 2, 2, 2, 2, cv2.BORDER_WRAP)
    dx = cv2.Sobel(padded, cv2.CV_32F, 1, 0, ksize=3)[2:-2, 2:-2]
    dy = cv2.Sobel(padded, cv2.CV_32F, 0, 1, ksize=3)[2:-2, 2:-2]

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


def enhance_basalt_mortar(tile: np.ndarray) -> np.ndarray:
    """Keeps basalt cap charcoal-slate while darkening mortar crevices without pure-black holes."""
    f = tile.astype(np.float32) / 255.0
    # Clamp crushed blacks slightly up to warm dark basalt so Godot lights & shadows still read
    f = np.maximum(f, 0.09)
    gray = 0.299 * f[:, :, 2] + 0.587 * f[:, :, 1] + 0.114 * f[:, :, 0]
    crevice = np.clip((0.26 - gray) / 0.14, 0.0, 1.0)
    f *= (1.0 - crevice[:, :, None] * 0.28)
    return np.clip(f * 255.0, 0, 255).astype(np.uint8)


def enhance_sandstone_strata(tile: np.ndarray, ref_bgr: np.ndarray) -> np.ndarray:
    """Warm-grades sandstone strata toward Picture 1's terracotta tone and deepens strata grooves."""
    f = tile.astype(np.float32)
    h, w = f.shape[:2]
    ref_cliff = ref_bgr[80:320, 40:300].astype(np.float32)
    ref_mean = ref_cliff.mean(axis=(0, 1))
    cur_mean = f.mean(axis=(0, 1))
    ratio = np.clip(ref_mean / (cur_mean + 1e-4), 0.80, 1.25)
    f = f * (0.50 + 0.50 * ratio[None, None, :])

    yy = np.linspace(0.0, 2.0 * np.pi, h, dtype=np.float32)[:, None]
    strata = 1.0 + 0.07 * np.sin(yy * 7.0) + 0.04 * np.cos(yy * 15.0 + 0.4)
    f *= strata[:, :, None]
    return np.clip(f, 0, 255).astype(np.uint8)


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
    strata_nrm = generate_normal_map(strata_alb, strength=3.2)
    cv2.imwrite(os.path.join(OUT_DIR, "d_sandstone_strata_albedo.png"), strata_alb)
    cv2.imwrite(os.path.join(OUT_DIR, "d_sandstone_strata_normal.png"), strata_nrm)

    # 3. Warm golden-ochre fractured Boulder surface (recolored clean basalt-grain + warm sandstone warmth)
    b_f = basalt_alb.astype(np.float32) / 255.0
    # Transform grey-slate basalt fracture facets into warm sunlit golden-ochre desert sandstone boulders
    boulder_warm = np.zeros_like(b_f)
    gray_b = 0.299 * b_f[:, :, 2] + 0.587 * b_f[:, :, 1] + 0.114 * b_f[:, :, 0]
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
