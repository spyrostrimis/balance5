"""Convert raw extracted Way 1B scan textures (tmp/way1b_raw_tex) into Godot-ready Albedo, Normal, and
Cavity-AO ORM maps under assets/textures/way1b_free_3d/.

For each photogrammetry asset:
  - <prefix>_albedo.jpg  (or _albedo_alpha.png for succulent)
  - <prefix>_normal.png  (linear 8-bit OpenGL tangent-space normal map)
  - <prefix>_orm.png     (R = multi-scale normal cavity AO, G = roughness, B = convex ridge rim mask / translucency)
"""
import os
import pathlib
import numpy as np
from PIL import Image, ImageFilter

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
TMP_TEX = REPO_ROOT / "tmp" / "way1b_raw_tex"
OUT_TEX = REPO_ROOT / "assets" / "textures" / "way1b_free_3d"
OUT_TEX.mkdir(parents=True, exist_ok=True)


def compute_cavity_and_ridge_from_normal(nor_rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Compute multi-scale crevice AO (cavity) and convex ridge highlight from an OpenGL tangent normal map."""
    # nor_rgb is in [0, 1], where (0.5, 0.5, 1.0) is flat.
    nx = nor_rgb[:, :, 0] * 2.0 - 1.0
    ny = nor_rgb[:, :, 1] * 2.0 - 1.0

    # In OpenGL normal maps (+X right, +Y up on texture, which is -V in image row space):
    # Divergence of normal vector measures local surface curvature (positive = convex ridge, negative = concave crevice)
    dnx_dx = np.roll(nx, -1, axis=1) - np.roll(nx, 1, axis=1)
    dny_dy = np.roll(ny, 1, axis=0) - np.roll(ny, -1, axis=0)
    curv = (dnx_dx + dny_dy) * 0.5

    # Multi-scale smoothing via PIL box/gaussian blur
    curv_img = Image.fromarray(np.clip((curv + 1.0) * 127.5, 0, 255).astype(np.uint8), mode="L")
    c_fine = (np.array(curv_img.filter(ImageFilter.GaussianBlur(radius=1.2)), dtype=np.float32) / 127.5) - 1.0
    c_mid = (np.array(curv_img.filter(ImageFilter.GaussianBlur(radius=4.0)), dtype=np.float32) / 127.5) - 1.0
    c_wide = (np.array(curv_img.filter(ImageFilter.GaussianBlur(radius=11.0)), dtype=np.float32) / 127.5) - 1.0

    combined = c_fine * 0.8 + c_mid * 1.4 + c_wide * 1.8
    # Cavity AO: 1.0 on flat/convex, drops toward 0.15 in deep cracks
    ao = np.clip(1.0 + np.minimum(combined * 1.65, 0.0), 0.12, 1.0)
    # Convex ridge mask: 0.0 on flat/concave, rises toward 1.0 on sharp rock edges
    ridge = np.clip(np.maximum(combined * 2.1, 0.0), 0.0, 1.0)
    return ao, ridge


def process_asset(prefix: str, res: int, has_alpha: bool = False):
    print(f"Processing textures for {prefix} ({res}x{res})...")
    # 1. Normal map
    nor_npy = TMP_TEX / f"{prefix}_nor.npy"
    if nor_npy.exists():
        nor_arr = np.load(nor_npy)[:, :, :3]
        # Renormalize vectors
        nvec = nor_arr * 2.0 - 1.0
        norm_len = np.linalg.norm(nvec, axis=2, keepdims=True) + 1e-6
        nvec = nvec / norm_len
        nor_rgb = np.clip(nvec * 0.5 + 0.5, 0.0, 1.0)
    else:
        nor_rgb = np.zeros((res, res, 3), dtype=np.float32)
        nor_rgb[:, :, 0] = 0.5
        nor_rgb[:, :, 1] = 0.5
        nor_rgb[:, :, 2] = 1.0

    nor_u8 = np.clip(nor_rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(nor_u8, mode="RGB").save(OUT_TEX / f"{prefix}_normal.png", optimize=False)

    # 2. Roughness + Cavity AO + Ridge/Translucency -> ORM
    ao, ridge = compute_cavity_and_ridge_from_normal(nor_rgb)
    for ao_ext in (".jpg", ".jpeg", ".png"):
        ao_raw_p = TMP_TEX / f"{prefix}_ao_raw{ao_ext}"
        if ao_raw_p.exists():
            ao_im = Image.open(ao_raw_p).convert("L").resize((res, res), Image.Resampling.LANCZOS)
            packed_ao = np.array(ao_im, dtype=np.float32) / 255.0
            ao = np.minimum(ao, packed_ao)

    rough_npy = TMP_TEX / f"{prefix}_rough.npy"
    if rough_npy.exists():
        r_arr = np.load(rough_npy)
        rough = np.clip(r_arr[:, :, 0], 0.15, 1.0)
    else:
        rough = np.full((res, res), 0.85, dtype=np.float32)

    blue_chan = ridge
    trans_p = TMP_TEX / f"{prefix}_trans_raw.png"
    if trans_p.exists():
        t_im = Image.open(trans_p).convert("L").resize((res, res), Image.Resampling.LANCZOS)
        blue_chan = np.array(t_im, dtype=np.float32) / 255.0

    orm_u8 = np.stack([
        np.clip(ao * 255.0 + 0.5, 0, 255).astype(np.uint8),
        np.clip(rough * 255.0 + 0.5, 0, 255).astype(np.uint8),
        np.clip(blue_chan * 255.0 + 0.5, 0, 255).astype(np.uint8),
    ], axis=2)
    Image.fromarray(orm_u8, mode="RGB").save(OUT_TEX / f"{prefix}_orm.png", optimize=False)

    # 3. Albedo (or Albedo + Alpha)
    diff_im = None
    for ext in (".jpg", ".jpeg", ".png"):
        dp = TMP_TEX / f"{prefix}_diff_raw{ext}"
        if dp.exists():
            diff_im = Image.open(dp).convert("RGB").resize((res, res), Image.Resampling.LANCZOS)
            break
    if diff_im is None and (TMP_TEX / f"{prefix}_col.npy").exists():
        col_arr = np.load(TMP_TEX / f"{prefix}_col.npy")[:, :, :3]
        # Convert linear EXR basecolor to sRGB
        col_srgb = np.power(np.clip(col_arr, 0.0, 1.0), 1.0 / 2.2)
        diff_im = Image.fromarray(np.clip(col_srgb * 255.0 + 0.5, 0, 255).astype(np.uint8), mode="RGB")

    if diff_im is not None:
        if has_alpha:
            ap = TMP_TEX / f"{prefix}_alpha_raw.png"
            if ap.exists():
                alpha_im = Image.open(ap).convert("L").resize((res, res), Image.Resampling.LANCZOS)
            else:
                alpha_im = Image.new("L", (res, res), 255)
            rgba = diff_im.convert("RGBA")
            rgba.putalpha(alpha_im)
            rgba.save(OUT_TEX / f"{prefix}_albedo.png", optimize=False)
        else:
            diff_im.save(OUT_TEX / f"{prefix}_albedo.jpg", quality=93, subsampling=0)


ASSETS = [
    ("namaqualand_cliff_02", 2048, False),
    ("namaqualand_cliff_01", 2048, False),
    ("rock_face_01", 2048, False),
    ("rock_face_02", 2048, False),
    ("cliff_scan_ledge", 2048, False),
    ("rock_07", 1024, False),
    ("namaqualand_boulder_03", 1024, False),
    ("namaqualand_boulder_02", 1024, False),
    ("namaqualand_boulder_05", 1024, False),
    ("namaqualand_stones_01", 1024, False),
    ("moon_rock_04", 1024, False),
    ("cheiridopsis_succulent", 1024, True),
    ("sand_rocks_small_01", 1024, False),
    ("namaqualand_rocks_01", 1024, False),
    ("canyon_river_terrain", 1024, False),
]

if __name__ == "__main__":
    for prefix, res, has_alpha in ASSETS:
        process_asset(prefix, res, has_alpha)
    print("=== ALL WAY 1B TEXTURES & ORM MAPS BUILT ===")
