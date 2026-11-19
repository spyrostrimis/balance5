import os
import glob
import cv2
import numpy as np

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

SRC = os.path.join(PROJECT_ROOT, r'assets\textures\maps\desert_approach_rpg_albedo.png')
OUT_DIR = os.path.join(PROJECT_ROOT, r'assets\textures\canyon_pbr')
os.makedirs(OUT_DIR, exist_ok=True)

# Clean up any temporary debug/check images
for p in glob.glob(os.path.join(OUT_DIR, "debug_*.png")) + glob.glob(os.path.join(OUT_DIR, "chk_*.png")):
    os.remove(p)

img = cv2.imread(SRC)
if img is None:
    raise FileNotFoundError(f"Missing source image: {SRC}")

def make_seamless_mirror_blend(tile: np.ndarray, size: int = 512, overlap: int = 72) -> np.ndarray:
    res = cv2.resize(tile, (size, size), interpolation=cv2.INTER_CUBIC).astype(np.float32)
    out_x = res.copy()
    for x in range(overlap):
        t = 0.5 * (1.0 - np.cos(np.pi * (x / float(overlap))))
        out_x[:, x] = (1.0 - t) * res[:, size - overlap + x] + t * res[:, x]
    out_xy = out_x.copy()
    for y in range(overlap):
        t = 0.5 * (1.0 - np.cos(np.pi * (y / float(overlap))))
        out_xy[y, :] = (1.0 - t) * out_x[size - overlap + y, :] + t * out_x[y, :]
    return np.clip(out_xy, 0.0, 255.0).astype(np.uint8)

def make_seamless_tile_mirror(tile: np.ndarray, size: int = 512) -> np.ndarray:
    # 2x2 symmetric mirror tiling eliminates wrap seams on small organic textures cleanly
    h_half = size // 2
    q = cv2.resize(tile, (h_half, h_half), interpolation=cv2.INTER_CUBIC)
    qx = cv2.flip(q, 1)
    top = np.hstack([q, qx])
    bot = cv2.flip(top, 0)
    return np.vstack([top, bot])

def make_normal_map(albedo: np.ndarray, strength: float = 2.8) -> np.ndarray:
    gray = cv2.cvtColor(albedo, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
    pad = cv2.copyMakeBorder(gray, 2, 2, 2, 2, cv2.BORDER_WRAP)
    gx = cv2.Sobel(pad, cv2.CV_32F, 1, 0, ksize=3)[2:-2, 2:-2] * strength
    gy = cv2.Sobel(pad, cv2.CV_32F, 0, 1, ksize=3)[2:-2, 2:-2] * strength
    gz = np.ones_like(gx)
    norm = np.sqrt(gx * gx + gy * gy + gz * gz)
    # Godot expects tangent-space normal map in RGB (BGR in OpenCV: [B=nz, G=ny, R=nx])
    nx = (gx / norm * 0.5 + 0.5) * 255.0
    ny = (-gy / norm * 0.5 + 0.5) * 255.0
    nz = (gz / norm * 0.5 + 0.5) * 255.0
    return np.clip(np.stack([nz, ny, nx], axis=2), 0.0, 255.0).astype(np.uint8)

def save_pbr_pair(name: str, crop: np.ndarray, strength: float = 2.8, enhance_strata: bool = False, use_mirror: bool = False):
    albedo = make_seamless_tile_mirror(crop, 512) if use_mirror else make_seamless_mirror_blend(crop, 512, 72)
    if enhance_strata:
        f = albedo.astype(np.float32)
        blur_h = cv2.GaussianBlur(f, (1, 13), 0)
        albedo = np.clip(f + (f - blur_h) * 0.55, 0.0, 255.0).astype(np.uint8)
    normal = make_normal_map(albedo, strength=strength)
    cv2.imwrite(os.path.join(OUT_DIR, f"{name}_albedo.png"), albedo)
    cv2.imwrite(os.path.join(OUT_DIR, f"{name}_normal.png"), normal)

# 1. Pure Terracotta Stratified Cliff Face (y=135..225, x=355..432: pure red-terracotta horizontal strata!)
save_pbr_pair("hd2d_red_cliff", img[135:225, 355:432], strength=3.0, enhance_strata=True)

# 2. Dark Basalt Terrace Top (y=376..408, x=222..268: dark charcoal stone-slab surface, darkened slightly for crisp two-tone contrast)
dark_crop = img[376:408, 222:268].astype(np.float32)
dark_crop[:, :, 0] *= 0.85  # B
dark_crop[:, :, 1] *= 0.72  # G
dark_crop[:, :, 2] *= 0.65  # R -> cool charcoal basalt stone
save_pbr_pair("hd2d_dark_ledge", np.clip(dark_crop, 0, 255).astype(np.uint8), strength=3.0, use_mirror=False)

# 3. Pure Cobblestone Path (y=600..755, x=675..765: pure cobblestones, non-mirrored for natural stone stagger)
save_pbr_pair("hd2d_cobble", img[600:755, 675:765], strength=3.2, use_mirror=False)

# 4. Warm Canyon Sand/Dirt: find cleanest sunlit sandy patch without dark twig specks
best_score, best_box = -1.0, (612, 640, 528, 556)
for yy in range(540, 690, 4):
    for xx in range(510, 650, 4):
        p_sub = img[yy:yy + 28, xx:xx + 28].astype(np.float32)
        b_m, g_m, r_m = p_sub[:, :, 0], p_sub[:, :, 1], p_sub[:, :, 2]
        # Score high warm orange sand min brightness (excludes twigs/shadows & gray cobbles)
        sc = float(np.percentile(r_m, 10)) + float(np.mean(r_m - b_m)) * 0.5 - float(np.std(r_m))
        if float(np.mean(r_m - g_m)) > 28.0 and sc > best_score:
            best_score = sc
            best_box = (yy, yy + 28, xx, xx + 28)

sand_base = make_seamless_mirror_blend(img[best_box[0]:best_box[1], best_box[2]:best_box[3]], 512, 72).astype(np.float32)
rng = np.random.default_rng(77)
fine_grit = rng.normal(0.0, 5.0, (512, 512, 1)).astype(np.float32)
sand_clean = np.clip(sand_base + fine_grit, 0.0, 255.0).astype(np.uint8)
cv2.imwrite(os.path.join(OUT_DIR, "hd2d_sand_albedo.png"), sand_clean)
cv2.imwrite(os.path.join(OUT_DIR, "hd2d_sand_normal.png"), make_normal_map(sand_clean, strength=1.8))

# 5. Clean Desert Sage Bush Cutouts (key out bright warm orange sand & upper dark background corners, feather cleanly)
def extract_bush(crop: np.ndarray, out_name: str):
    h, w, _ = crop.shape
    b, g, r = cv2.split(crop.astype(np.float32))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # Key out bright orange sand (R-G high, R-B high) AND dark shadow/cliff in upper-left/right corners
    sand_score = np.clip(((r - g) - 14.0) / 26.0, 0.0, 1.0) * np.clip(((r - b) - 40.0) / 48.0, 0.0, 1.0)
    upper_dark = np.clip((58.0 - g) / 25.0, 0.0, 1.0) * np.clip((h * 0.55 - yy) / (h * 0.25), 0.0, 1.0)
    foliage_mask = 1.0 - np.clip(sand_score + upper_dark, 0.0, 1.0)

    nx = (xx - w * 0.5) / (w * 0.45)
    ny = (yy - h * 0.52) / (h * 0.44)
    dist = np.sqrt(nx * nx + ny * ny)
    ellip = 1.0 - np.clip((dist - 0.58) / 0.42, 0.0, 1.0)

    raw_alpha = foliage_mask * ellip
    alpha = cv2.GaussianBlur(raw_alpha, (3, 3), 0) * ellip
    crop_up = cv2.resize(crop, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
    alpha_up = cv2.resize(alpha, (w * 2, h * 2), interpolation=cv2.INTER_LINEAR)
    rgba = np.dstack([crop_up, np.clip(alpha_up * 255.0, 0, 255).astype(np.uint8)])
    cv2.imwrite(os.path.join(OUT_DIR, out_name), rgba)

# 6. Clean Sandstone Boulder Cutout (y=458..518, x=385..455)
def extract_boulder(crop: np.ndarray, out_name: str):
    h, w, _ = crop.shape
    b, g, r = cv2.split(crop.astype(np.float32))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - w * 0.50) / (w * 0.42)
    ny = (yy - h * 0.50) / (h * 0.38)
    dist = np.sqrt(nx * nx + ny * ny)
    ellip = 1.0 - np.clip((dist - 0.55) / 0.40, 0.0, 1.0)
    # Feather out dark deep crevices in top-left/top-right corners outside rock mass
    dark_bg = np.clip((52.0 - r) / 22.0, 0.0, 1.0) * np.clip((h * 0.48 - yy) / (h * 0.2), 0.0, 1.0)
    alpha = cv2.GaussianBlur(ellip * (1.0 - dark_bg), (3, 3), 0) * ellip
    crop_up = cv2.resize(crop, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
    alpha_up = cv2.resize(alpha, (w * 2, h * 2), interpolation=cv2.INTER_LINEAR)
    rgba = np.dstack([crop_up, np.clip(alpha_up * 255.0, 0, 255).astype(np.uint8)])
    cv2.imwrite(os.path.join(OUT_DIR, out_name), rgba)

# Left foreground sage bush (x=405..492, y=525..600)
extract_bush(img[525:600, 405:492], "hd2d_bush_1.png")
# Mid right isolated sage bush (x=796..882, y=428..506)
extract_bush(img[428:506, 796:882], "hd2d_bush_2.png")
# Left foreground golden sandstone boulder (x=385..455, y=458..518)
extract_boulder(img[458:518, 385:455], "hd2d_boulder_1.png")

print("Successfully built crisp grid-aligned HD-2D PBR textures and props!")
