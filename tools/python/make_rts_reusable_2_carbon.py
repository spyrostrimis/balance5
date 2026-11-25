"""Build all reusable art assets (Detailed Painted 2x HD + 960x540 Pixel 1x) for RTS Reusable 2 Carbon.

Reads the 6 ChatGPT source sheets in assets/source_inputs/rts_carbon/ plus continuous
sand/road inputs in assets/source_inputs/rts/, and writes isolated runtime textures to:
    assets/textures/rts/carbon/

Usage:
    C:/Python312/python.exe tools/python/make_rts_reusable_2_carbon.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC_CARBON = ROOT / "assets" / "source_inputs" / "rts_carbon"
SRC_RTS = ROOT / "assets" / "source_inputs" / "rts"
OUT = ROOT / "assets" / "textures" / "rts" / "carbon"
PREVIEW_DIR = ROOT / "render_captures" / "rts_carbon"

OUTLINE_RGB = np.array([34, 24, 20], dtype=np.uint8)
SAND_REF_RGB = np.array([228.0, 135.0, 40.0], dtype=np.float32)

# Top-left directional light matching docs/RTS_ART_RULES.md §3
LIGHT_DIR = np.array([-0.50, -0.70, 0.78], dtype=np.float32)
LIGHT_DIR /= np.linalg.norm(LIGHT_DIR)


def build_curated_palette() -> np.ndarray:
    """48-colour desert palette + oasis turquoise/greens + Blue/Red faction accents (74 colours total)."""
    pal_path = ROOT / "assets" / "textures" / "rts" / "palette_desert.json"
    raw_hex = json.loads(pal_path.read_text(encoding="utf-8"))["colors"]
    base = [[int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)] for h in raw_hex]
    extras = [
        # Oasis turquoise & deep teal water
        [24, 108, 114], [34, 146, 148], [52, 184, 178], [92, 216, 204], [168, 242, 232],
        # Oasis lush desert shrubs
        [38, 68, 24], [62, 104, 32], [94, 142, 42], [138, 176, 56],
        # Blue Coalition cobalt armour, ivory scarf & cyan Mend emblem
        [28, 52, 104], [46, 86, 162], [74, 126, 212], [122, 168, 236],
        [218, 204, 166], [244, 234, 202], [76, 228, 242],
        # Red Command crimson armour, dark cloak & brass-gold trim
        [92, 22, 20], [146, 32, 28], [198, 48, 38], [232, 84, 62],
        [168, 126, 52], [222, 178, 78],
        # Steel outpost & glowing Orichalcum highlights
        [74, 80, 92], [112, 120, 134], [156, 164, 178], [255, 226, 112],
    ]
    all_cols = np.array(base + extras, dtype=np.uint8)
    return all_cols


PALETTE = build_curated_palette()


def quantize_rgba(img_rgba: np.ndarray, palette: np.ndarray = PALETTE, alpha_cutoff: int = 96,
                  outline: bool = False, outline_alpha: int = 235) -> np.ndarray:
    """Snap an RGBA array onto the curated pixel-art palette with optional crisp 1px dark silhouette."""
    h, w, _ = img_rgba.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    mask = img_rgba[:, :, 3] >= alpha_cutoff
    if not np.any(mask):
        return out

    rgb = img_rgba[:, :, :3].astype(np.float32)
    # De-multiply any semi-transparent edge darkening slightly before palette snap
    a_norm = np.clip(img_rgba[:, :, 3].astype(np.float32) / 255.0, 0.25, 1.0)
    pts = rgb[mask]
    pal_f = palette.astype(np.float32)
    # Perceptual-weighted RGB distance (2, 4, 3)
    weights = np.array([2.0, 4.0, 3.0], dtype=np.float32)
    diff = pts[:, None, :] - pal_f[None, :, :]
    dist2 = np.sum((diff * diff) * weights[None, None, :], axis=2)
    idx = np.argmin(dist2, axis=1)
    out_rgb = np.zeros((h, w, 3), dtype=np.uint8)
    out_rgb[mask] = palette[idx]
    out[:, :, :3] = out_rgb
    out[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)

    if outline:
        k = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], dtype=np.uint8)
        dil = cv2.dilate(mask.astype(np.uint8), k, iterations=1).astype(bool)
        ring = dil & (~mask)
        out[ring, :3] = OUTLINE_RGB
        out[ring, 3] = outline_alpha
    else:
        # Keep soft sub-alpha pebbles/skirts where 28 <= alpha < alpha_cutoff
        soft = (img_rgba[:, :, 3] >= 28) & (~mask)
        if np.any(soft):
            pts_s = rgb[soft] / a_norm[soft, None]
            pts_s = np.clip(pts_s, 0, 255)
            diff_s = pts_s[:, None, :] - pal_f[None, :, :]
            idx_s = np.argmin(np.sum((diff_s * diff_s) * weights[None, None, :], axis=2), axis=1)
            out[soft, :3] = palette[idx_s]
            out[soft, 3] = (img_rgba[soft, 3].astype(np.float32) * 0.9).astype(np.uint8)
    return out


def save_png(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(path, optimize=True)


def resize_premult(img_rgba: np.ndarray, size_wh: tuple[int, int], sharpen: float = 0.0) -> np.ndarray:
    """Area-average resize in premultiplied alpha space so transparent edges never bleed dark/white halos."""
    w, h = size_wh
    f = img_rgba.astype(np.float32)
    a = f[:, :, 3:4] / 255.0
    pre = np.concatenate([f[:, :, :3] * a, a * 255.0], axis=2)
    interp = cv2.INTER_AREA if (w < img_rgba.shape[1] or h < img_rgba.shape[0]) else cv2.INTER_CUBIC
    rs = cv2.resize(pre, (w, h), interpolation=interp)
    ra = rs[:, :, 3:4] / 255.0
    rgb = np.where(ra > 1e-3, rs[:, :, :3] / np.maximum(ra, 1e-3), 0.0)
    rgb = np.clip(rgb, 0.0, 255.0)
    if sharpen > 0.0:
        blur = cv2.GaussianBlur(rgb, (0, 0), 0.85)
        rgb = np.clip(rgb + sharpen * (rgb - blur), 0.0, 255.0)
    out = np.concatenate([rgb, np.clip(rs[:, :, 3:4], 0.0, 255.0)], axis=2)
    return np.round(out).astype(np.uint8)


def crop_tight_rgba(img_rgba: np.ndarray, box: tuple[int, int, int, int], pad: int = 4) -> np.ndarray:
    x0, y0, x1, y1 = box
    sub = img_rgba[y0:y1, x0:x1].copy()
    ys, xs = np.where(sub[:, :, 3] > 14)
    if len(xs) == 0:
        return sub
    bx0 = max(0, int(xs.min()) - pad)
    by0 = max(0, int(ys.min()) - pad)
    bx1 = min(sub.shape[1], int(xs.max()) + 1 + pad)
    by1 = min(sub.shape[0], int(ys.max()) + 1 + pad)
    return sub[by0:by1, bx0:bx1]


def add_sand_skirt(img_rgba: np.ndarray, skirt_px: int = 3, strength: float = 0.32) -> np.ndarray:
    """Add a subtle blown-sand contact dusting around lower rock/pad bases so pieces melt into sand."""
    if skirt_px <= 0:
        return img_rgba
    out = img_rgba.copy().astype(np.float32)
    solid = (out[:, :, 3] > 140).astype(np.uint8)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (skirt_px * 2 + 1, skirt_px * 2 + 1))
    dil = cv2.dilate(solid, k, iterations=1).astype(np.float32)
    blur_d = cv2.GaussianBlur(dil, (0, 0), skirt_px * 0.7)
    # Bias toward bottom half (south foot of cliffs/rocks)
    h, w, _ = out.shape
    yy = np.linspace(0.35, 1.0, h, dtype=np.float32)[:, None]
    fringe = np.clip(blur_d - out[:, :, 3] / 255.0, 0.0, 1.0) * yy * strength
    sand_col = np.array([212.0, 124.0, 44.0], dtype=np.float32)
    base_a = out[:, :, 3] / 255.0
    new_a = base_a + fringe * (1.0 - base_a)
    safe_a = np.maximum(new_a, 1e-4)
    out[:, :, :3] = (out[:, :, :3] * base_a[:, :, None] + sand_col[None, None, :] * fringe[:, :, None] * (1.0 - base_a[:, :, None])) / safe_a[:, :, None]
    out[:, :, 3] = np.clip(new_a * 255.0, 0.0, 255.0)
    return np.round(out).astype(np.uint8)


def save_piece_pair(name: str, src_rgba: np.ndarray, world_wh: tuple[int, int],
                    skirt_hd: int = 4, sharp_pix: float = 0.35, alpha_cut: int = 84) -> None:
    """Save both *_hd.png (2x = 64px/cell) and *_pixel.png (1x = 32px/cell) for a placed scene piece."""
    ww, wh = world_wh
    hd = resize_premult(src_rgba, (ww * 2, wh * 2), sharpen=0.18)
    if skirt_hd > 0:
        hd = add_sand_skirt(hd, skirt_px=skirt_hd, strength=0.26)
    save_png(hd, OUT / f"{name}_hd.png")

    px_raw = resize_premult(src_rgba, (ww, wh), sharpen=sharp_pix)
    px = quantize_rgba(px_raw, PALETTE, alpha_cutoff=alpha_cut, outline=False)
    save_png(px, OUT / f"{name}_pixel.png")


def build_ground_and_road() -> None:
    """Build seamless sand tiles and tileable flagstone road strips with feathered sand shoulders."""
    sand_src = np.array(Image.open(SRC_RTS / "sand.png").convert("RGB"), dtype=np.float32)
    # Make 512x512 seamless via cross-blended offset quilting
    s512 = cv2.resize(sand_src, (512, 512), interpolation=cv2.INTER_AREA)
    shift = np.roll(np.roll(s512, 256, axis=0), 256, axis=1)
    yy, xx = np.mgrid[0:512, 0:512].astype(np.float32)
    wx = 0.5 - 0.5 * np.cos(2.0 * math.pi * xx / 512.0)
    wy = 0.5 - 0.5 * np.cos(2.0 * math.pi * yy / 512.0)
    w_seam = np.clip(wx * wy * 1.35, 0.0, 1.0)[:, :, None]
    seamless = s512 * w_seam + shift * (1.0 - w_seam)
    # Match mean colour to reference desert sand while keeping rich grain
    mean_rgb = seamless.mean(axis=(0, 1), keepdims=True)
    seamless = np.clip((seamless - mean_rgb) * 1.12 + SAND_REF_RGB[None, None, :], 0, 255).astype(np.uint8)
    save_png(seamless, OUT / "sand_tile_hd.png")

    s256 = cv2.resize(seamless, (256, 256), interpolation=cv2.INTER_AREA)
    s256_rgba = np.concatenate([s256, np.full((256, 256, 1), 255, dtype=np.uint8)], axis=2)
    s256_px = quantize_rgba(s256_rgba, PALETTE, alpha_cutoff=10)[:, :, :3]
    save_png(s256_px, OUT / "sand_tile_pixel.png")

    # Road strip (horizontally seamless for Line2D texture_mode = LINE_TEXTURE_TILE)
    # Sample directly from the crisp cracked limestone plates of 05_road_and_outpost.png's plaza_oval
    # so the road's stonework, joints, and colour match PlazaOval 1-to-1!
    plaza_full = np.array(Image.open(SRC_CARBON / "05_road_and_outpost.png").convert("RGB"), dtype=np.float32)
    stone_patch = plaza_full[290:600, 960:1540]  # pure interior cracked limestone plates
    rw, rh = 256, 96
    r_rgb = cv2.resize(stone_patch, (rw, rh), interpolation=cv2.INTER_AREA)
    # Make horizontally seamless across X via cosine cross-fade
    r_roll = np.roll(r_rgb, rw // 2, axis=1)
    ux = (0.5 - 0.5 * np.cos(2.0 * math.pi * np.arange(rw, dtype=np.float32) / rw))[None, :, None]
    r_rgb = r_rgb * ux + r_roll * (1.0 - ux)
    # Subtle sharpen so hairline plate cracks read just like PlazaOval
    r_blur = cv2.GaussianBlur(r_rgb, (0, 0), 1.0)
    r_rgb = np.clip(r_rgb + 0.42 * (r_rgb - r_blur), 0, 255)
    r_hgt = r_rgb.mean(axis=2) / 255.0

    # Organic stone-edge alpha profile across Y (0..rh-1) + periodic dark border marker stones
    vy = np.abs(np.linspace(-1.0, 1.0, rh, dtype=np.float32))[:, None]
    edge_wobble = 0.08 * np.sin(np.linspace(0, 4.0 * math.pi, rw, dtype=np.float32))[None, :] + 0.05 * (r_hgt - 0.5)
    dist_edge = vy + edge_wobble
    alpha = np.clip((0.86 - dist_edge) / 0.18, 0.0, 1.0)
    # Warm blown-sand tint near outer shoulder
    shoulder = np.clip((dist_edge - 0.58) / 0.24, 0.0, 1.0)[:, :, None]
    r_rgb = r_rgb * (1.0 - shoulder * 0.48) + SAND_REF_RGB[None, None, :] * (shoulder * 0.48)

    # Small marker stones dotted along both road rims (matching reference!)
    for sx in range(16, rw, 32):
        for sy_center in (13, rh - 14):
            jitter_x = int((sx * 7) % 5) - 2
            cx, cy = (sx + jitter_x) % rw, sy_center
            yy_s, xx_s = np.ogrid[0:rh, 0:rw]
            dx = np.minimum(np.abs(xx_s - cx), rw - np.abs(xx_s - cx))
            dy = yy_s - cy
            stone = (dx * dx) / 11.0 + (dy * dy) / 7.5 <= 1.0
            stone_lit = ((dx - 1.2) ** 2) / 6.0 + ((dy + 1.2) ** 2) / 4.5 <= 1.0
            r_rgb[stone] = np.array([112.0, 86.0, 68.0])
            r_rgb[stone_lit] = np.array([164.0, 134.0, 108.0])
            alpha[stone] = np.maximum(alpha[stone], 0.96)

    road_hd = np.concatenate([np.clip(r_rgb, 0, 255).astype(np.uint8),
                              np.clip(alpha[:, :, None] * 255.0, 0, 255).astype(np.uint8)], axis=2)
    save_png(road_hd, OUT / "road_strip_hd.png")

    road_px_raw = resize_premult(road_hd, (rw // 2, rh // 2), sharpen=0.25)
    road_px = quantize_rgba(road_px_raw, PALETTE, alpha_cutoff=90, outline=False)
    save_png(road_px, OUT / "road_strip_pixel.png")


def build_terrain_pieces() -> None:
    """Extract and build HD + Pixel reusable landmarks, rock kit, stone works, shrubs, and dune clusters."""
    # 1. Central Orichalcum Outcrop
    ori_src = np.array(Image.open(SRC_CARBON / "01_orichalcum_outcrop.png").convert("RGBA"))
    ori_crop = crop_tight_rgba(ori_src, (24, 188, 1230, 1064), pad=6)
    save_piece_pair("orichalcum_outcrop", ori_crop, (184, 132), skirt_hd=5, sharp_pix=0.40, alpha_cut=80)

    # 2. Northeast Cliff & Turquoise Oasis Landmark
    oasis_src = np.array(Image.open(SRC_CARBON / "02_cliff_oasis.png").convert("RGBA"))
    oasis_crop = crop_tight_rgba(oasis_src, (8, 8, 1244, 1164), pad=6)
    save_piece_pair("cliff_oasis", oasis_crop, (336, 312), skirt_hd=5, sharp_pix=0.35, alpha_cut=80)

    # 3. Reusable Rock Kit (4 rock pieces + 2 desert shrubs)
    rk_src = np.array(Image.open(SRC_CARBON / "03_rock_kit.png").convert("RGBA"))
    mesa_crop = crop_tight_rgba(rk_src, (60, 48, 710, 514), pad=6)
    save_piece_pair("rock_mesa", mesa_crop, (196, 140), skirt_hd=4, sharp_pix=0.35)

    ridge_crop = crop_tight_rgba(rk_src, (746, 28, 1488, 602), pad=6)
    save_piece_pair("rock_ridge", ridge_crop, (232, 180), skirt_hd=4, sharp_pix=0.35)

    boulders_crop = crop_tight_rgba(rk_src, (98, 562, 630, 1002), pad=6)
    save_piece_pair("rock_boulders", boulders_crop, (132, 110), skirt_hd=4, sharp_pix=0.38)

    # Mask out the two shrubs on the right before cropping rock_outcrop_low
    rk_no_shrubs = rk_src.copy()
    rk_no_shrubs[664:790, 1190:1332, 3] = 0
    rk_no_shrubs[868:952, 1210:1310, 3] = 0
    low_crop = crop_tight_rgba(rk_no_shrubs, (832, 684, 1304, 942), pad=5)
    save_piece_pair("rock_outcrop_low", low_crop, (116, 64), skirt_hd=3, sharp_pix=0.38)

    scrub_lg = crop_tight_rgba(rk_src, (1192, 668, 1328, 788), pad=3)
    save_piece_pair("scrub_large", scrub_lg, (26, 23), skirt_hd=0, sharp_pix=0.45, alpha_cut=72)

    scrub_sm = crop_tight_rgba(rk_src, (1212, 870, 1308, 950), pad=3)
    save_piece_pair("scrub_small", scrub_sm, (18, 15), skirt_hd=0, sharp_pix=0.45, alpha_cut=72)

    # 4. Outpost on Stone Pad + Oval Flagstone Plaza
    rp_src = np.array(Image.open(SRC_CARBON / "05_road_and_outpost.png").convert("RGBA"))
    outpost_crop = crop_tight_rgba(rp_src, (54, 128, 682, 750), pad=6)
    save_piece_pair("outpost_pad", outpost_crop, (136, 134), skirt_hd=4, sharp_pix=0.38)

    plaza_crop = crop_tight_rgba(rp_src, (746, 114, 1740, 778), pad=6)
    save_piece_pair("plaza_oval", plaza_crop, (288, 192), skirt_hd=0, sharp_pix=0.30, alpha_cut=60)

    # 5. Soft directional shadow blob texture (shared by cliffs, boulders, outpost, Orichalcum)
    sh_sz = 128
    yy, xx = np.mgrid[0:sh_sz, 0:sh_sz].astype(np.float32)
    d = np.sqrt(((xx - 63.5) / 58.0) ** 2 + ((yy - 63.5) / 58.0) ** 2)
    sh_a = np.clip(1.0 - d, 0.0, 1.0) ** 1.65
    sh_rgba = np.zeros((sh_sz, sh_sz, 4), dtype=np.uint8)
    sh_rgba[:, :, 0] = 68
    sh_rgba[:, :, 1] = 28
    sh_rgba[:, :, 2] = 6
    sh_rgba[:, :, 3] = np.round(sh_a * 255.0).astype(np.uint8)
    save_png(sh_rgba, OUT / "soft_shadow.png")

    # 6. Reusable Dune Clusters (signed delta relief in RGB around 128 + smooth feather envelope in A)
    dunes_src = np.array(Image.open(SRC_CARBON / "04_dune_clusters.png").convert("RGB"), dtype=np.float32)
    # Local background sand via wide Gaussian blur removes lighting gradients cleanly
    bg = cv2.GaussianBlur(dunes_src, (0, 0), 92.0)
    delta = dunes_src - bg  # signed crest (+) / trough (-) delta

    clusters = [
        ("dune_cluster_a", (8, 180, 728, 820), (264, 232)),
        ("dune_cluster_b", (820, 12, 1514, 440), (256, 160)),
        ("dune_cluster_c", (620, 490, 1474, 1010), (304, 188)),
    ]
    for cname, (x0, y0, x1, y1), (ww, wh) in clusters:
        sub_d = delta[y0:y1, x0:x1].copy()
        ch, cw, _ = sub_d.shape
        # Smooth elliptical cosine window + local ripple energy envelope so edges hit exact 0
        cy_grid, cx_grid = np.mgrid[0:ch, 0:cw].astype(np.float32)
        ny = (cy_grid / max(ch - 1, 1)) * 2.0 - 1.0
        nx = (cx_grid / max(cw - 1, 1)) * 2.0 - 1.0
        r = np.sqrt(nx * nx + ny * ny)
        radial = np.clip((1.0 - r) / 0.28, 0.0, 1.0)
        radial = radial * radial * (3.0 - 2.0 * radial)

        energy = cv2.GaussianBlur(np.linalg.norm(sub_d, axis=2), (0, 0), 30.0)
        env = np.clip((energy - 6.0) / 22.0, 0.0, 1.0) * radial

        # Encode HD (2x)
        d_hd = cv2.resize(sub_d, (ww * 2, wh * 2), interpolation=cv2.INTER_AREA)
        e_hd = cv2.resize(env, (ww * 2, wh * 2), interpolation=cv2.INTER_AREA)
        rgb_hd = np.clip(128.0 + d_hd * 1.18, 0.0, 255.0).astype(np.uint8)
        a_hd = np.clip(e_hd * 255.0, 0.0, 255.0).astype(np.uint8)[:, :, None]
        save_png(np.concatenate([rgb_hd, a_hd], axis=2), OUT / f"{cname}_hd.png")

        # Encode Pixel (1x): stepped crisp Dune II crest/lee bands!
        d_px = cv2.resize(sub_d, (ww, wh), interpolation=cv2.INTER_AREA)
        e_px = cv2.resize(env, (ww, wh), interpolation=cv2.INTER_AREA)
        # Quantize signed delta into 7 crisp tonal steps so ripples read with classic pixel clarity
        lum_d = (d_px[:, :, 0] * 0.45 + d_px[:, :, 1] * 0.42 + d_px[:, :, 2] * 0.13)
        stepped = np.round(np.clip(lum_d / 14.0, -4.0, 4.0)) * 14.0
        scale = np.where(np.abs(lum_d) > 2.0, stepped / np.where(np.abs(lum_d) > 2.0, lum_d, 1.0), 0.0)
        d_px_q = d_px * np.clip(scale[:, :, None], 0.0, 1.8)
        rgb_px = np.clip(128.0 + d_px_q * 1.22, 0.0, 255.0).astype(np.uint8)
        a_px = np.where(e_px > 0.12, np.clip(np.round(e_px * 6.0) / 6.0 * 255.0, 0, 255), 0).astype(np.uint8)[:, :, None]
        save_png(np.concatenate([rgb_px, a_px], axis=2), OUT / f"{cname}_pixel.png")


def clean_unit_cutout(raw_rgba: np.ndarray) -> np.ndarray:
    """Extract razor-clean sprites from 06_units_sheet.png (where background alpha is ~154..222 and sprites are >=240)."""
    f = raw_rgba.astype(np.float32)
    rgb = f[:, :, :3]
    a = f[:, :, 3]
    max_c = rgb.max(axis=2)
    min_c = rgb.min(axis=2)
    chroma = max_c - min_c

    # ChatGPT's alpha channel jumps sharply from <=222 on the backdrop to >=242 on every painted subject!
    fg_from_a = np.clip((a - 226.0) / 18.0, 0.0, 1.0)
    # Also suppress any bright low-chroma white glow right at the silhouette rim
    white_rim = np.clip((min_c - 226.0) / 22.0, 0.0, 1.0) * np.clip(1.0 - chroma / 34.0, 0.0, 1.0)
    fg = fg_from_a * (1.0 - 0.88 * white_rim)

    # Keep interior highlights solid via exterior flood-fill
    sure_bg = (fg < 0.35).astype(np.uint8)
    h, w = sure_bg.shape
    ff = sure_bg.copy()
    mask_ff = np.zeros((h + 2, w + 2), dtype=np.uint8)
    for x in range(w):
        if ff[0, x] == 1:
            cv2.floodFill(ff, mask_ff, (x, 0), 2)
        if ff[h - 1, x] == 1:
            cv2.floodFill(ff, mask_ff, (x, h - 1), 2)
    for y in range(h):
        if ff[y, 0] == 1:
            cv2.floodFill(ff, mask_ff, (0, y), 2)
        if ff[y, w - 1] == 1:
            cv2.floodFill(ff, mask_ff, (w - 1, y), 2)
    ext_bg = (ff == 2) | ((a < 232.0) & (min_c > 236.0) & (chroma < 16.0))
    # Erode 1px of residual white anti-aliasing and feather smoothly
    solid = (~ext_bg).astype(np.uint8)
    eroded = cv2.erode(solid, np.ones((3, 3), np.uint8), iterations=1).astype(np.float32)
    soft_edge = cv2.GaussianBlur(solid.astype(np.float32), (0, 0), 0.7)
    final_a = np.where(eroded > 0.5, 1.0, np.where(ext_bg, 0.0, np.clip(fg * soft_edge * 1.15, 0.0, 1.0)))

    # Decontaminate any white blend on semi-transparent silhouette pixels
    bg_col = np.array([251.0, 247.0, 240.0], dtype=np.float32)
    clean_rgb = (rgb - (1.0 - final_a[:, :, None]) * bg_col[None, None, :]) / np.maximum(final_a[:, :, None], 0.30)
    clean_rgb = np.where(final_a[:, :, None] > 0.03, np.clip(clean_rgb, 0.0, 255.0), 0.0)

    out = np.concatenate([clean_rgb, final_a[:, :, None] * 255.0], axis=2)
    return np.round(out).astype(np.uint8)


def make_portrait(cutout_rgba: np.ndarray, bg_top: tuple[int, int, int], bg_bot: tuple[int, int, int],
                  name: str) -> None:
    """Create 128x128 HD and 64x64 Pixel Dune II unit/landmark portrait cards."""
    ys, xs = np.where(cutout_rgba[:, :, 3] > 32)
    sub = cutout_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    sz = 128
    yy = np.linspace(0.0, 1.0, sz, dtype=np.float32)[:, None, None]
    bg = np.array(bg_top, np.float32)[None, None, :] * (1.0 - yy) + np.array(bg_bot, np.float32)[None, None, :] * yy
    # Subtle parchment grain + vignette
    rng = np.random.default_rng(42)
    grain = cv2.GaussianBlur(rng.normal(0.0, 5.0, (sz, sz)).astype(np.float32), (0, 0), 0.9)
    gx, gy = np.meshgrid(np.linspace(-1, 1, sz), np.linspace(-1, 1, sz))
    vig = 1.0 - 0.26 * (gx * gx + gy * gy)
    canvas = np.clip((bg + grain[:, :, None]) * vig[:, :, None], 0, 255)

    # Fit subject nicely inside 112x112
    sh, sw, _ = sub.shape
    scale = min(110.0 / max(sw, 1), 110.0 / max(sh, 1))
    nw, nh = max(1, int(round(sw * scale))), max(1, int(round(sh * scale)))
    fitted = resize_premult(sub, (nw, nh), sharpen=0.20).astype(np.float32)
    ox, oy = (sz - nw) // 2, (sz - nh) // 2 + 2
    fa = fitted[:, :, 3:4] / 255.0
    roi = canvas[oy:oy + nh, ox:ox + nw]
    canvas[oy:oy + nh, ox:ox + nw] = roi * (1.0 - fa) + fitted[:, :, :3] * fa

    hd_rgba = np.concatenate([np.clip(canvas, 0, 255).astype(np.uint8),
                              np.full((sz, sz, 1), 255, dtype=np.uint8)], axis=2)
    save_png(hd_rgba, OUT / f"portrait_{name}_hd.png")

    px_raw = resize_premult(hd_rgba, (64, 64), sharpen=0.30)
    px_rgba = quantize_rgba(px_raw, PALETTE, alpha_cutoff=10, outline=False)
    save_png(px_rgba, OUT / f"portrait_{name}_pixel.png")


def make_infantry_sheet(base_cutout: np.ndarray, cell_hd: tuple[int, int], vis_h_hd: int,
                        back_cloak_rgb: tuple[int, int, int], name: str) -> None:
    """Build an 8-direction (S, SW, W, NW, N, NE, E, SE) x 4-walk-frame sprite sheet in HD (2x) and Pixel (1x)."""
    ys, xs = np.where(base_cutout[:, :, 3] > 32)
    tight = base_cutout[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    cw, ch = cell_hd
    scale = vis_h_hd / max(tight.shape[0], 1)
    sw = min(cw - 4, max(6, int(round(tight.shape[1] * scale))))
    sh = min(ch - 4, max(8, int(round(tight.shape[0] * scale))))
    se_pose = resize_premult(tight, (sw, sh), sharpen=0.28)

    # Mirrored SW pose with gentle top-left re-lighting so lit shoulder stays upper-left
    sw_pose = se_pose[:, ::-1, :].copy().astype(np.float32)
    xx_rel = np.linspace(-1.0, 1.0, sw, dtype=np.float32)[None, :, None]
    yy_rel = np.linspace(-1.0, 1.0, sh, dtype=np.float32)[:, None, None]
    relight = 1.0 - 0.14 * xx_rel - 0.06 * yy_rel
    sw_pose[:, :, :3] = np.clip(sw_pose[:, :, :3] * relight, 0.0, 255.0)
    sw_pose = np.round(sw_pose).astype(np.uint8)

    # Rear-view synthesis (for NW, N, NE): drape backpack/cloak tone over upper-middle chest/face visor
    def make_rear(front_img: np.ndarray) -> np.ndarray:
        rear = front_img.copy().astype(np.float32)
        rh, rw, _ = rear.shape
        yg, xg = np.mgrid[0:rh, 0:rw].astype(np.float32)
        ny = yg / max(rh - 1, 1)
        nx = xg / max(rw - 1, 1)
        # Cover front face/chest plate (0.16..0.56 height, 0.25..0.75 width) with shaded cloak/pack
        cape = np.exp(-(((nx - 0.48) / 0.26) ** 2 + ((ny - 0.36) / 0.20) ** 2))
        cape = np.clip(cape, 0.0, 0.82) * (rear[:, :, 3] > 80).astype(np.float32)
        shade = 1.0 - 0.22 * nx - 0.18 * ny
        cloak = np.array(back_cloak_rgb, dtype=np.float32)[None, None, :] * shade[:, :, None]
        rear[:, :, :3] = rear[:, :, :3] * (1.0 - cape[:, :, None]) + cloak * cape[:, :, None]
        return np.clip(np.round(rear), 0, 255).astype(np.uint8)

    ne_pose = make_rear(se_pose)
    nw_pose = make_rear(sw_pose)

    # 8 columns: 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE
    col_poses = [
        se_pose,   # S
        sw_pose,   # SW
        sw_pose,   # W
        nw_pose,   # NW
        ne_pose,   # N
        ne_pose,   # NE
        se_pose,   # E
        se_pose,   # SE
    ]

    sheet_hd = np.zeros((ch * 4, cw * 8, 4), dtype=np.uint8)
    for col, pose in enumerate(col_poses):
        ph, pw, _ = pose.shape
        ox = (cw - pw) // 2
        oy_base = ch - ph - 2
        for row in range(4):
            frame = pose.copy()
            # Row 0 = idle, Row 1 = left step + bob, Row 2 = planted pass, Row 3 = right step + bob
            bob = -1 if row in (1, 3) else 0
            if row in (1, 3):
                # Subtle opposing boot stride shift in lower 35% of sprite
                leg_y = int(ph * 0.65)
                mid_x = pw // 2
                shift = 1 if row == 1 else -1
                legs = frame[leg_y:, :, :].copy()
                frame[leg_y:, :mid_x, :] = np.roll(legs[:, :mid_x, :], shift, axis=0)
                frame[leg_y:, mid_x:, :] = np.roll(legs[:, mid_x:, :], -shift, axis=0)
            oy = max(0, oy_base + bob)
            sheet_hd[row * ch + oy:row * ch + oy + ph, col * cw + ox:col * cw + ox + pw] = frame

    save_png(sheet_hd, OUT / f"{name}_hd.png")

    # Purposeful 1x Pixel sheet (cw//2 x ch//2 per cell, crisp 1px dark silhouette outline)
    pcw, pch = cw // 2, ch // 2
    sheet_px = np.zeros((pch * 4, pcw * 8, 4), dtype=np.uint8)
    for row in range(4):
        for col in range(8):
            cell = sheet_hd[row * ch:(row + 1) * ch, col * cw:(col + 1) * cw]
            small = resize_premult(cell, (pcw, pch), sharpen=0.48)
            q = quantize_rgba(small, PALETTE, alpha_cutoff=88, outline=True, outline_alpha=235)
            sheet_px[row * pch:(row + 1) * pch, col * pcw:(col + 1) * pcw] = q
    save_png(sheet_px, OUT / f"{name}_pixel.png")


def render_tank_sheets(faction: str) -> None:
    """Render 8-facing steep-overhead orthographic Tank Hull (8x2 tread frames) + Turret (8x1) sheets
    matched directly to the ChatGPT 06_units_sheet.png Blue & Red tanks."""
    is_blue = faction == "blue"
    hull_base = np.array([58.0, 106.0, 186.0] if is_blue else [182.0, 44.0, 36.0], np.float32)
    hull_hi = np.array([118.0, 164.0, 232.0] if is_blue else [228.0, 88.0, 62.0], np.float32)
    trim_col = np.array([204.0, 178.0, 132.0] if is_blue else [216.0, 170.0, 74.0], np.float32)
    deck_col = np.array([124.0, 102.0, 76.0] if is_blue else [116.0, 92.0, 68.0], np.float32)
    tread_col = np.array([62.0, 54.0, 48.0], np.float32)
    barrel_col = np.array([78.0, 82.0, 90.0], np.float32)
    lamp_col = np.array([82.0, 232.0, 255.0] if is_blue else [255.0, 192.0, 56.0], np.float32)

    # Supersampled 144x144 -> 72x72 HD (36x36 world units) -> 36x36 Pixel
    ss = 144
    hd_sz = 72
    px_sz = 36

    # Steep overhead camera pitch = 55 deg from horizontal (orthonormal basis!)
    # World: +X = East (right), +Y = South (down-screen), +Z = Up (skyward)
    # Camera looks from South-Above (0, +cos(pitch), +sin(pitch)) toward origin:
    pitch = math.radians(55.0)
    cp, sp = math.cos(pitch), math.sin(pitch)
    cam_right = np.array([1.0, 0.0, 0.0], np.float32)
    screen_down = np.array([0.0, sp, -cp], np.float32)  # orthogonal to view_dir! +Y world -> down, +Z world -> up
    view_dir = np.array([0.0, cp, sp], np.float32)      # unit vector from surface toward camera

    # Prebuild pixel ray origins on screen plane [-21..21] world units
    span = 21.0
    u_vals = np.linspace(-span, span, ss, dtype=np.float32)
    v_vals = np.linspace(-span, span, ss, dtype=np.float32)
    vv, uu = np.meshgrid(v_vals, u_vals, indexing="ij")
    ray_o = (uu[:, :, None] * cam_right[None, None, :] +
             vv[:, :, None] * screen_down[None, None, :])

    def raycast_boxes(yaw: float, boxes: list[tuple], cyls: list[tuple], tread_phase: float = 0.0) -> np.ndarray:
        cy, sy = math.cos(yaw), math.sin(yaw)
        # Tank local: +Y = forward, +X = right, +Z = up.
        # yaw = 0 => tank faces South (+Y world); yaw = +pi/4 => SW (-X, +Y world); yaw = -pi/4 (7*pi/4) => SE (+X, +Y world)
        # Forward world vector F = (-sin(yaw), cos(yaw), 0), Right world vector R = (cos(yaw), sin(yaw), 0)
        def to_local(vec: np.ndarray) -> np.ndarray:
            wx, wy, wz = vec[..., 0], vec[..., 1], vec[..., 2]
            lx = wx * cy + wy * sy
            ly = -wx * sy + wy * cy
            return np.stack([lx, ly, wz], axis=-1)

        def to_world_n(n_loc: np.ndarray) -> np.ndarray:
            lx, ly, lz = n_loc[..., 0], n_loc[..., 1], n_loc[..., 2]
            wx = lx * cy - ly * sy
            wy = lx * sy + ly * cy
            return np.stack([wx, wy, lz], axis=-1)

        ro = to_local(ray_o)
        rd = to_local(view_dir)
        inv_rd = np.zeros(3, np.float32)
        for k in range(3):
            inv_rd[k] = 1.0 / rd[k] if abs(float(rd[k])) > 1e-6 else 1e6

        best_t = np.full((ss, ss), -1e9, np.float32)  # largest t = closest to camera!
        hit_col = np.zeros((ss, ss, 3), np.float32)
        hit_n = np.zeros((ss, ss, 3), np.float32)
        hit_emit = np.zeros((ss, ss), np.float32)
        hit_mask = np.zeros((ss, ss), dtype=bool)

        # Evaluate each oriented box in local coords: (center, half_extents, rgb, slope_front, mat_kind)
        for center, half, col_rgb, bevel_top, mat_kind in boxes:
            c = np.array(center, np.float32)
            h = np.array(half, np.float32)
            # Ray-AABB intersection for P(t) = ro + t * rd (t can be any real; larger t is closer to camera)
            t1 = (c - h - ro) * inv_rd
            t2 = (c + h - ro) * inv_rd
            tmin = np.maximum.reduce(np.minimum(t1, t2), axis=-1)
            tmax = np.minimum.reduce(np.maximum(t1, t2), axis=-1)
            valid = tmax >= np.maximum(tmin, -50.0)
            # Camera sits at +infinity along +rd, so the visible entry point is tmax!
            t_hit = tmax
            closer = valid & (t_hit > best_t)
            if not np.any(closer):
                continue
            p = ro + t_hit[:, :, None] * rd[None, None, :]
            rel = (p - c) / np.maximum(h, 1e-4)
            # Outward normal + soft bevel near box edges so painted facets catch light!
            abs_r = np.abs(rel)
            dom = np.argmax(abs_r, axis=-1)
            n_loc = np.zeros_like(rel)
            for axis in range(3):
                m_ax = dom == axis
                n_loc[m_ax, axis] = np.sign(rel[m_ax, axis])
            if bevel_top > 0.0:
                n_loc += rel * bevel_top
                n_loc /= np.maximum(np.linalg.norm(n_loc, axis=-1, keepdims=True), 1e-4)

            c_tex = np.broadcast_to(col_rgb[None, None, :], (ss, ss, 3)).copy()
            emit = np.zeros((ss, ss), np.float32)

            if mat_kind == "tread":
                # Articulated track cleats along local Y + roadwheel side detail
                cleat = np.sin((p[:, :, 1] + p[:, :, 2] * 0.6 + tread_phase * 2.1) * 1.65)
                dark_band = np.where(cleat > 0.15, 1.14, 0.78)[:, :, None]
                side_wheel = (np.abs(rel[:, :, 0]) > 0.92) & (p[:, :, 2] < 3.4)
                wheel_ring = np.sin(p[:, :, 1] * 0.85) > 0.1
                c_tex *= dark_band
                c_tex[side_wheel & wheel_ring] *= 1.22
            elif mat_kind == "hull":
                # Painted armour seams, weathered highlights on front glacis & trim stripe
                seam = (np.abs(np.sin(p[:, :, 1] * 0.55)) > 0.96) | (np.abs(np.abs(p[:, :, 0]) - 4.8) < 0.35)
                c_tex[seam] *= 0.78
                # Trim stripe on front fender shoulders
                stripe = (p[:, :, 1] > 2.5) & (np.abs(p[:, :, 0]) > 5.2) & (p[:, :, 2] > 4.2)
                c_tex[stripe] = trim_col
                # Front twin glowing headlights on glacis
                lamp = (p[:, :, 1] > c[1] + h[1] - 0.9) & (np.abs(np.abs(p[:, :, 0]) - 3.3) < 1.35) & (np.abs(p[:, :, 2] - 4.3) < 0.75)
                c_tex[lamp] = lamp_col
                emit[lamp] = 0.85
            elif mat_kind == "deck":
                louvre = np.sin(p[:, :, 1] * 2.2) > 0.25
                c_tex[louvre & (np.abs(p[:, :, 0]) < 4.5)] *= 0.72

            best_t = np.where(closer, t_hit, best_t)
            hit_mask |= closer
            hit_col[closer] = c_tex[closer]
            hit_n[closer] = to_world_n(n_loc)[closer]
            hit_emit[closer] = emit[closer]

        # Evaluate cylinders: (kind="z"|"y", center, radius, half_len, col_rgb)
        for ckind, center, rad, hlen, col_rgb in cyls:
            c = np.array(center, np.float32)
            oc = ro - c
            if ckind == "z":
                # Vertical cylinder (round turret / cupola): x^2 + y^2 <= rad^2, |z| <= hlen
                a_c = rd[0] * rd[0] + rd[1] * rd[1]
                b_c = 2.0 * (oc[:, :, 0] * rd[0] + oc[:, :, 1] * rd[1])
                c_c = oc[:, :, 0] ** 2 + oc[:, :, 1] ** 2 - rad * rad
                disc = b_c * b_c - 4.0 * a_c * c_c
                valid_side = disc >= 0.0
                sq = np.sqrt(np.maximum(disc, 0.0))
                t_side = (-b_c + sq) / max(2.0 * a_c, 1e-6)
                z_at = oc[:, :, 2] + t_side * rd[2]
                valid_side &= np.abs(z_at) <= hlen

                # Top cap at z = c[2] + hlen
                t_cap = (hlen - oc[:, :, 2]) / (rd[2] if abs(rd[2]) > 1e-6 else 1e-6)
                px_cap = oc[:, :, 0] + t_cap * rd[0]
                py_cap = oc[:, :, 1] + t_cap * rd[1]
                valid_cap = (px_cap * px_cap + py_cap * py_cap) <= rad * rad

                t_hit = np.where(valid_cap & ((~valid_side) | (t_cap > t_side)), t_cap, t_side)
                use_cap = valid_cap & ((~valid_side) | (t_cap > t_side))
                valid = valid_cap | valid_side
                closer = valid & (t_hit > best_t)
                if not np.any(closer):
                    continue
                p = ro + t_hit[:, :, None] * rd[None, None, :]
                rel_xy = (p[:, :, :2] - c[:2]) / rad
                n_side = np.concatenate([rel_xy, np.full((ss, ss, 1), 0.28, np.float32)], axis=-1)
                n_side /= np.maximum(np.linalg.norm(n_side, axis=-1, keepdims=True), 1e-4)
                n_cap = np.concatenate([rel_xy * 0.22, np.ones((ss, ss, 1), np.float32)], axis=-1)
                n_cap /= np.maximum(np.linalg.norm(n_cap, axis=-1, keepdims=True), 1e-4)
                n_loc = np.where(use_cap[:, :, None], n_cap, n_side)

                c_tex = np.broadcast_to(col_rgb[None, None, :], (ss, ss, 3)).copy()
                # Turret cheek trim & hatch ring
                r_cap = np.sqrt(px_cap * px_cap + py_cap * py_cap)
                ring = use_cap & (np.abs(r_cap - rad * 0.56) < 0.42)
                c_tex[ring] *= 0.76
                cheek = (~use_cap) & (np.abs(p[:, :, 0]) > rad * 0.68) & (p[:, :, 1] > 0.0)
                c_tex[cheek] = trim_col

                best_t = np.where(closer, t_hit, best_t)
                hit_mask |= closer
                hit_col[closer] = c_tex[closer]
                hit_n[closer] = to_world_n(n_loc)[closer]
                hit_emit[closer] = 0.0

            elif ckind == "y":
                # Forward gun barrel cylinder along local +Y: x^2 + z^2 <= rad^2, |y| <= hlen
                a_c = rd[0] * rd[0] + rd[2] * rd[2]
                b_c = 2.0 * (oc[:, :, 0] * rd[0] + oc[:, :, 2] * rd[2])
                c_c = oc[:, :, 0] ** 2 + oc[:, :, 2] ** 2 - rad * rad
                disc = b_c * b_c - 4.0 * a_c * c_c
                valid_side = disc >= 0.0
                sq = np.sqrt(np.maximum(disc, 0.0))
                t_side = (-b_c + sq) / max(2.0 * a_c, 1e-6)
                y_at = oc[:, :, 1] + t_side * rd[1]
                valid_side &= np.abs(y_at) <= hlen

                # Muzzle cap at y = +hlen
                t_cap = (hlen - oc[:, :, 1]) / (rd[1] if abs(rd[1]) > 1e-6 else 1e-6)
                px_c = oc[:, :, 0] + t_cap * rd[0]
                pz_c = oc[:, :, 2] + t_cap * rd[2]
                r2 = px_c * px_c + pz_c * pz_c
                valid_cap = (r2 <= rad * rad) & (rd[1] > 0.0)

                t_hit = np.where(valid_cap & ((~valid_side) | (t_cap > t_side)), t_cap, t_side)
                use_cap = valid_cap & ((~valid_side) | (t_cap > t_side))
                valid = valid_cap | valid_side
                closer = valid & (t_hit > best_t)
                if not np.any(closer):
                    continue
                p = ro + t_hit[:, :, None] * rd[None, None, :]
                n_side = np.stack([(p[:, :, 0] - c[0]) / rad, np.zeros((ss, ss), np.float32), (p[:, :, 2] - c[2]) / rad], axis=-1)
                n_side /= np.maximum(np.linalg.norm(n_side, axis=-1, keepdims=True), 1e-4)
                n_cap = np.broadcast_to(np.array([0.0, 1.0, 0.0], np.float32)[None, None, :], (ss, ss, 3))
                n_loc = np.where(use_cap[:, :, None], n_cap, n_side)

                c_tex = np.broadcast_to(col_rgb[None, None, :], (ss, ss, 3)).copy()
                bore = use_cap & (r2 < (rad * 0.52) ** 2)
                c_tex[bore] *= 0.25

                best_t = np.where(closer, t_hit, best_t)
                hit_mask |= closer
                hit_col[closer] = c_tex[closer]
                hit_n[closer] = to_world_n(n_loc)[closer]
                hit_emit[closer] = 0.0

        # Warm top-left sunlight + warm desert sand bounce + specular rim glint
        out = np.zeros((ss, ss, 4), np.uint8)
        if not np.any(hit_mask):
            return out
        ndotl = np.sum(hit_n * LIGHT_DIR[None, None, :], axis=-1)
        up_ao = np.clip(0.75 + 0.25 * hit_n[:, :, 2], 0.55, 1.05)
        diff = np.clip(0.58 + 0.56 * ndotl, 0.30, 1.24) * up_ao
        half_v = LIGHT_DIR + view_dir
        half_v /= np.linalg.norm(half_v)
        spec = np.clip(np.sum(hit_n * half_v[None, None, :], axis=-1), 0.0, 1.0) ** 14.0

        shaded = hit_col * diff[:, :, None] + hull_hi[None, None, :] * (spec[:, :, None] * 0.26)
        shaded = shaded * (1.0 - hit_emit[:, :, None]) + hit_col * hit_emit[:, :, None] * 1.18
        out[:, :, :3] = np.clip(np.round(shaded), 0, 255).astype(np.uint8)
        out[hit_mask, 3] = 255
        return out

    hull_boxes = [
        # Left & right exposed twin tracks
        ((-7.6, 0.0, 2.7), (2.7, 11.4, 2.7), tread_col, 0.18, "tread"),
        ((7.6, 0.0, 2.7), (2.7, 11.4, 2.7), tread_col, 0.18, "tread"),
        # Rear engine deck
        ((0.0, -6.2, 4.4), (5.8, 4.4, 2.3), deck_col, 0.22, "deck"),
        # Main armoured hull & front glacis
        ((0.0, 1.8, 4.5), (6.2, 7.6, 2.4), hull_base, 0.32, "hull"),
        # Fender shoulder plates over front tracks
        ((-7.4, 4.2, 5.2), (2.4, 4.8, 0.8), hull_base * 0.94, 0.28, "hull"),
        ((7.4, 4.2, 5.2), (2.4, 4.8, 0.8), hull_base * 0.94, 0.28, "hull"),
    ]
    turret_boxes = [
        # Gun mantlet block
        ((0.0, 5.0, 8.3), (2.2, 2.0, 1.5), trim_col * 0.88, 0.25, "plain"),
    ]
    turret_cyls = [
        ("z", (0.0, -0.4, 8.2), 5.4, 2.1, hull_base * 1.04),
        ("z", (-0.8, -0.8, 10.5), 2.5, 0.55, hull_base * 0.92),
        # Main cannon barrel + muzzle collar
        ("y", (0.0, 10.6, 8.3), 1.05, 5.8, barrel_col),
        ("y", (0.0, 15.6, 8.3), 1.38, 1.15, barrel_col * 0.86),
    ]

    # Columns 0..7 match Godot's col = posmod(roundi(atan2(-facing.x, facing.y) / (PI/4)), 8):
    # 0: S (0,1), 1: SW (-1,1), 2: W (-1,0), 3: NW (-1,-1), 4: N (0,-1), 5: NE (1,-1), 6: E (1,0), 7: SE (1,1)
    yaws = [col * (math.pi / 4.0) for col in range(8)]

    hull_hd = np.zeros((hd_sz * 2, hd_sz * 8, 4), np.uint8)
    hull_px = np.zeros((px_sz * 2, px_sz * 8, 4), np.uint8)
    turret_hd = np.zeros((hd_sz, hd_sz * 8, 4), np.uint8)
    turret_px = np.zeros((px_sz, px_sz * 8, 4), np.uint8)

    for col, yaw in enumerate(yaws):
        for row in range(2):
            raw_h = raycast_boxes(yaw, hull_boxes, [], tread_phase=float(row) * 1.5)
            h72 = resize_premult(raw_h, (hd_sz, hd_sz), sharpen=0.22)
            hull_hd[row * hd_sz:(row + 1) * hd_sz, col * hd_sz:(col + 1) * hd_sz] = h72
            h36 = resize_premult(raw_h, (px_sz, px_sz), sharpen=0.42)
            hull_px[row * px_sz:(row + 1) * px_sz, col * px_sz:(col + 1) * px_sz] = quantize_rgba(
                h36, PALETTE, alpha_cutoff=92, outline=True, outline_alpha=235
            )

        raw_t = raycast_boxes(yaw, turret_boxes, turret_cyls, tread_phase=0.0)
        t72 = resize_premult(raw_t, (hd_sz, hd_sz), sharpen=0.25)
        turret_hd[:, col * hd_sz:(col + 1) * hd_sz] = t72
        t36 = resize_premult(raw_t, (px_sz, px_sz), sharpen=0.45)
        turret_px[:, col * px_sz:(col + 1) * px_sz] = quantize_rgba(
            t36, PALETTE, alpha_cutoff=84, outline=True, outline_alpha=235
        )

    save_png(hull_hd, OUT / f"{faction}_tank_hull_hd.png")
    save_png(hull_px, OUT / f"{faction}_tank_hull_pixel.png")
    save_png(turret_hd, OUT / f"{faction}_tank_turret_hd.png")
    save_png(turret_px, OUT / f"{faction}_tank_turret_pixel.png")


def build_units_and_portraits() -> None:
    u_src = np.array(Image.open(SRC_CARBON / "06_units_sheet.png").convert("RGBA"))

    # Clean cutouts of all 6 subjects for portraits & infantry sheets
    blue_squad_full = clean_unit_cutout(u_src[18:498, 46:524])
    blue_soldier_single = clean_unit_cutout(u_src[146:352, 62:226])  # isolated left Blue trooper
    blue_commander = clean_unit_cutout(u_src[72:472, 586:910])
    blue_tank_paint = clean_unit_cutout(u_src[50:494, 1006:1474])

    red_squad_full = clean_unit_cutout(u_src[508:1000, 38:534])
    red_soldier_single = clean_unit_cutout(u_src[522:728, 194:360])  # isolated top Red Legionary
    red_commander = clean_unit_cutout(u_src[558:978, 576:930])
    red_tank_paint = clean_unit_cutout(u_src[546:994, 1002:1476])

    # Dune II sidebar portraits (warm parchment for Blue/Desert, warm bronze-crimson tint for Red)
    make_portrait(blue_squad_full, (226, 188, 134), (168, 122, 74), "blue_squad")
    make_portrait(blue_commander, (232, 196, 144), (162, 124, 82), "blue_commander")
    make_portrait(blue_tank_paint, (222, 184, 132), (156, 114, 70), "blue_tank")
    make_portrait(red_squad_full, (222, 178, 126), (158, 104, 64), "red_squad")
    make_portrait(red_commander, (228, 182, 128), (162, 102, 62), "red_commander")
    make_portrait(red_tank_paint, (220, 176, 124), (154, 100, 62), "red_tank")

    # Landmark portraits for empty selection / objective inspection
    ori_src = np.array(Image.open(SRC_CARBON / "01_orichalcum_outcrop.png").convert("RGBA"))
    make_portrait(ori_src[188:1064, 24:1230], (218, 168, 104), (132, 86, 46), "orichalcum")

    # 8-direction x 4-frame Infantry & Commander sheets
    # Individual soldier = 32x36 HD (16x18 world units, visible height ~24 HD px = 12 art px)
    # Commander = 40x46 HD (20x23 world units, visible height ~30 HD px = 15 art px)
    make_infantry_sheet(blue_soldier_single, (32, 36), 24, (196, 182, 146), "blue_soldier")
    make_infantry_sheet(blue_commander, (40, 46), 30, (214, 200, 164), "blue_commander")
    make_infantry_sheet(red_soldier_single, (32, 36), 24, (92, 58, 44), "red_soldier")
    make_infantry_sheet(red_commander, (40, 46), 30, (86, 54, 42), "red_commander")

    # 8-direction Tank Hull + independent Turret sheets (Blue & Red)
    render_tank_sheets("blue")
    render_tank_sheets("red")


def build_contact_preview() -> None:
    """Create a diagnostic contact sheet in render_captures/rts_carbon/kit_contact_sheet.png."""
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    W, H = 1440, 920
    sand = np.array(Image.open(OUT / "sand_tile_hd.png").convert("RGB"))
    canvas = np.tile(sand, (H // 512 + 2, W // 512 + 2, 1))[:H, :W].astype(np.float32)

    def blit(img_path: Path, x: int, y: int, scale: int = 1) -> None:
        im = np.array(Image.open(img_path).convert("RGBA"))
        if scale > 1:
            im = cv2.resize(im, (im.shape[1] * scale, im.shape[0] * scale), interpolation=cv2.INTER_NEAREST)
        ih, iw, _ = im.shape
        x2, y2 = min(W, x + iw), min(H, y + ih)
        if x2 <= x or y2 <= y:
            return
        sub = im[:y2 - y, :x2 - x].astype(np.float32)
        a = sub[:, :, 3:4] / 255.0
        canvas[y:y2, x:x2] = canvas[y:y2, x:x2] * (1.0 - a) + sub[:, :, :3] * a

    blit(OUT / "plaza_oval_hd.png", 20, 20)
    blit(OUT / "orichalcum_outcrop_hd.png", 124, 80)
    blit(OUT / "cliff_oasis_hd.png", 620, 10)
    blit(OUT / "outpost_pad_hd.png", 350, 430)
    blit(OUT / "rock_mesa_hd.png", 20, 430)
    blit(OUT / "rock_boulders_hd.png", 20, 720)
    blit(OUT / "rock_outcrop_low_hd.png", 330, 730)

    # Show HD vs 2x-nearest Pixel units side by side
    blit(OUT / "blue_commander_hd.png", 660, 640)
    blit(OUT / "blue_commander_pixel.png", 660, 700, scale=2)
    blit(OUT / "blue_soldier_hd.png", 660, 760)
    blit(OUT / "blue_soldier_pixel.png", 660, 810, scale=2)
    blit(OUT / "blue_tank_hull_hd.png", 20, 850)
    blit(OUT / "blue_tank_turret_hd.png", 20, 850)
    blit(OUT / "red_tank_hull_pixel.png", 660, 855, scale=2)
    blit(OUT / "red_tank_turret_pixel.png", 660, 855, scale=2)

    save_png(np.clip(canvas, 0, 255).astype(np.uint8), PREVIEW_DIR / "kit_contact_sheet.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # Prevent Godot from scanning render_captures
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "render_captures" / ".gdignore").write_text("", encoding="utf-8")

    print("1/4 Building seamless ground sand & stone road strips...")
    build_ground_and_road()
    print("2/4 Extracting & building HD + Pixel reusable terrain pieces & dune clusters...")
    build_terrain_pieces()
    print("3/4 Building 8-direction HD + Pixel unit sprite sheets & Dune II portraits...")
    build_units_and_portraits()
    print("4/4 Rendering kit verification contact sheet...")
    build_contact_preview()
    print("Done ->", OUT)


if __name__ == "__main__":
    main()
