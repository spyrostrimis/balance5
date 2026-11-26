"""Build all reusable art assets (Detailed Painted 2x HD + 960x540 Pixel 1x) for RTS Reusable 4.

Reads the 6 ChatGPT source sheets in assets/source_inputs/rts_reusable_4/ plus Carbon's
shared stone/sand inputs, and writes isolated runtime textures to:
    assets/textures/rts/reusable_4/

Usage:
    C:/Python312/python.exe tools/python/make_rts_reusable_4.py
"""
from __future__ import annotations

import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from make_rts_reusable_2_carbon import (
    OUT as CARBON_OUT,
    PALETTE as BASE_PALETTE,
    ROOT,
    SAND_REF_RGB,
    SRC_CARBON,
    SRC_RTS,
    add_sand_skirt,
    crop_tight_rgba,
    quantize_rgba,
    resize_premult,
    save_png,
)

SRC_R4 = ROOT / "assets" / "source_inputs" / "rts_reusable_4"
OUT = ROOT / "assets" / "textures" / "rts" / "reusable_4"
PREVIEW_DIR = ROOT / "render_captures" / "rts_reusable_4"

# Extend Carbon's 74-colour palette with richer cobalt, ivory, crimson-scarlet, and blue-grey HQ roof tones
EXTRA_R4_COLOURS = np.array([
    # Connected rich cobalt-blue infantry & banner tones
    [20, 62, 148], [30, 88, 198], [52, 118, 232], [88, 152, 248],
    # Crisp ivory-cream commander scarf
    [232, 222, 188], [248, 240, 212],
    # Deep crimson body + bright scarlet-red sunlit upper edge
    [104, 16, 30], [152, 20, 38], [198, 28, 48], [242, 54, 66],
    # Blue-grey HQ roof metal & sandstone highlights
    [66, 84, 102], [94, 114, 132], [128, 146, 162],
], dtype=np.uint8)

R4_PALETTE = np.vstack([BASE_PALETTE, EXTRA_R4_COLOURS])


def clean_alpha_cutout(
    raw_rgba: np.ndarray,
    bg_rgb: tuple[float, float, float] = (252.0, 250.0, 246.0),
    erode_rim: bool = True,
    alpha_floor: float = 18.0,
) -> np.ndarray:
    """Decontaminate subtle white anti-aliasing on transparent ChatGPT PNG cutouts."""
    f = raw_rgba.astype(np.float32)
    rgb = f[:, :, :3]
    a = f[:, :, 3]

    if erode_rim:
        solid = (a >= 210.0).astype(np.uint8)
        soft_mask = cv2.GaussianBlur(solid.astype(np.float32), (0, 0), 0.65)
        a_norm = np.where(solid > 0, a / 255.0, np.clip((a / 255.0) * soft_mask * 1.25, 0.0, 1.0))
        a_norm = np.where(a < alpha_floor, 0.0, a_norm)
    else:
        a_norm = np.where(a < alpha_floor, 0.0, np.clip(a / 255.0, 0.0, 1.0))

    bg = np.array(bg_rgb, dtype=np.float32)[None, None, :]
    clean_rgb = (rgb - (1.0 - a_norm[:, :, None]) * bg) / np.maximum(a_norm[:, :, None], 0.28)
    clean_rgb = np.where(a_norm[:, :, None] > 0.02, np.clip(clean_rgb, 0.0, 255.0), 0.0)
    out = np.concatenate([clean_rgb, a_norm[:, :, None] * 255.0], axis=2)
    return np.round(out).astype(np.uint8)


def save_r4_pair(
    name: str,
    src_rgba: np.ndarray,
    world_wh: tuple[int, int],
    skirt_hd: int = 0,
    sharp_hd: float = 0.16,
    sharp_pix: float = 0.32,
    alpha_cut: int = 86,
    outline_pix: bool = False,
) -> None:
    """Save matched 2x HD Painted (*_hd.png) and 1x Pixel (*_pixel.png) textures."""
    ww, wh = world_wh
    hd = resize_premult(src_rgba, (ww * 2, wh * 2), sharpen=sharp_hd)
    if skirt_hd > 0:
        hd = add_sand_skirt(hd, skirt_px=skirt_hd, strength=0.28)
    save_png(hd, OUT / f"{name}_hd.png")

    px_raw = resize_premult(src_rgba, (ww, wh), sharpen=sharp_pix)
    px = quantize_rgba(px_raw, R4_PALETTE, alpha_cutoff=alpha_cut, outline=outline_pix)
    save_png(px, OUT / f"{name}_pixel.png")


def rotate_rgba_premult(img_rgba: np.ndarray, angle_deg: float, scale_x: float = 1.0) -> np.ndarray:
    """Rotate and optionally foreshorten X in premultiplied alpha space without dark fringes."""
    h, w, _ = img_rgba.shape
    pad = max(16, int(max(h, w) * 0.22))
    canvas = np.zeros((h + pad * 2, w + pad * 2, 4), dtype=np.float32)
    f = img_rgba.astype(np.float32)
    a = f[:, :, 3:4] / 255.0
    canvas[pad:pad + h, pad:pad + w, :3] = f[:, :, :3] * a
    canvas[pad:pad + h, pad:pad + w, 3:4] = a * 255.0

    ch, cw = canvas.shape[:2]
    cx, cy = cw * 0.5, ch * 0.5
    rad = math.radians(angle_deg)
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    # Scale X around center, then rotate
    m_rot = np.array([
        [cos_a * scale_x, sin_a, cx - cos_a * scale_x * cx - sin_a * cy],
        [-sin_a * scale_x, cos_a, cy + sin_a * scale_x * cx - cos_a * cy],
    ], dtype=np.float32)
    warped = cv2.warpAffine(canvas, m_rot, (cw, ch), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    wa = warped[:, :, 3:4] / 255.0
    rgb = np.where(wa > 1e-3, warped[:, :, :3] / np.maximum(wa, 1e-3), 0.0)
    out = np.concatenate([np.clip(rgb, 0.0, 255.0), np.clip(warped[:, :, 3:4], 0.0, 255.0)], axis=2)
    out_u8 = np.round(out).astype(np.uint8)
    ys, xs = np.where(out_u8[:, :, 3] > 24)
    if len(xs) == 0:
        return img_rgba
    return out_u8[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def mirror_relight_topleft(img_rgba: np.ndarray) -> np.ndarray:
    """Mirror horizontally while keeping subtle upper-left sunlight emphasis."""
    mir = img_rgba[:, ::-1, :].copy().astype(np.float32)
    h, w, _ = mir.shape
    xx = np.linspace(-1.0, 1.0, w, dtype=np.float32)[None, :, None]
    yy = np.linspace(-1.0, 1.0, h, dtype=np.float32)[:, None, None]
    relight = 1.0 - 0.11 * xx - 0.04 * yy
    mir[:, :, :3] = np.clip(mir[:, :, :3] * relight, 0.0, 255.0)
    return np.round(mir).astype(np.uint8)


def tune_unit_readability_highres(cutout: np.ndarray, role_key: str) -> np.ndarray:
    """Reinforce cobalt, ivory scarf, or deep-crimson + bright-red upper edge at source resolution
    while preserving painted shading and dark metallic weapons."""
    out = cutout.copy().astype(np.float32)
    rgb = out[:, :, :3]
    a = out[:, :, 3]
    mask = a > 32.0
    if not np.any(mask):
        return cutout

    h, w, _ = out.shape
    yy = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    lum = rgb[:, :, 0] * 0.299 + rgb[:, :, 1] * 0.587 + rgb[:, :, 2] * 0.114
    max_c = rgb.max(axis=2)
    min_c = rgb.min(axis=2)
    chroma = max_c - min_c

    # Protect dark grey/black weapon pixels everywhere
    is_weapon = (chroma < 26.0) & (lum < 96.0)

    if role_key in ("blue_soldier", "blue_commander"):
        # Boost cobalt armour saturation & upper-shoulder clarity so it pops on both sand and pale stone
        is_blue = mask & (~is_weapon) & (rgb[:, :, 2] > rgb[:, :, 0] + 16.0)
        if np.any(is_blue):
            # Keep painted light/shadow ramp while deepening cobalt richness
            shade = np.clip(lum / 138.0, 0.42, 1.42)
            upper_boost = np.clip((0.55 - yy) / 0.40, 0.0, 1.0)
            target_r = 24.0 * shade + 14.0 * upper_boost
            target_g = 86.0 * shade + 28.0 * upper_boost
            target_b = np.clip(198.0 * shade + 34.0 * upper_boost, 0.0, 255.0)
            target = np.stack([target_r, target_g, target_b], axis=2)
            rgb[is_blue] = rgb[is_blue] * 0.28 + target[is_blue] * 0.72

        if role_key == "blue_commander":
            # Keep the commander's broad ivory scarf luminous and crisp
            is_scarf = mask & (lum > 148.0) & (rgb[:, :, 0] > rgb[:, :, 2] - 8.0) & (yy < 0.62)
            if np.any(is_scarf):
                s_shade = np.clip((lum - 140.0) / 95.0, 0.0, 1.0)
                scarf_rgb = np.stack([
                    226.0 + 26.0 * s_shade,
                    216.0 + 28.0 * s_shade,
                    182.0 + 34.0 * s_shade,
                ], axis=2)
                rgb[is_scarf] = rgb[is_scarf] * 0.25 + scarf_rgb[is_scarf] * 0.75

    elif role_key in ("red_soldier", "red_commander"):
        # Deep ruby-crimson body (cooler/deeper than #E48728 orange sand!) + brighter scarlet upper edge
        is_red = mask & (~is_weapon) & (rgb[:, :, 0] > rgb[:, :, 1] + 24.0) & (rgb[:, :, 0] > rgb[:, :, 2] + 18.0)
        if np.any(is_red):
            shade = np.clip(lum / 122.0, 0.38, 1.45)
            # Upper helmet crown & top shoulder rim get the brighter scarlet-red edge
            upper_rim = np.clip((0.36 - yy) / 0.24, 0.0, 1.0) * np.clip((lum - 72.0) / 70.0, 0.0, 1.0)
            target_r = np.clip(154.0 * shade + 76.0 * upper_rim, 0.0, 252.0)
            target_g = np.clip(18.0 * shade + 34.0 * upper_rim, 0.0, 96.0)
            target_b = np.clip(34.0 * shade + 24.0 * upper_rim, 0.0, 92.0)
            target = np.stack([target_r, target_g, target_b], axis=2)
            rgb[is_red] = rgb[is_red] * 0.24 + target[is_red] * 0.76

        if role_key == "red_soldier":
            # Suppress any overly warm orange/brass highlights so soldiers never merge into orange sand
            too_orange = mask & (~is_weapon) & (rgb[:, :, 0] > 150.0) & (rgb[:, :, 1] > 88.0) & (rgb[:, :, 2] < 90.0)
            if np.any(too_orange):
                rgb[too_orange, 1] *= 0.58
                rgb[too_orange, 2] = np.maximum(rgb[too_orange, 2], 36.0)

    out[:, :, :3] = np.clip(rgb, 0.0, 255.0)
    return np.round(out).astype(np.uint8)


def build_eight_facing_sheet(
    front_se_raw: np.ndarray,
    rear_ne_raw: np.ndarray,
    cell_hd: tuple[int, int],
    vis_h_hd: int,
    role_key: str,
) -> None:
    """Build true 8-direction (0:S, 1:SW, 2:W, 3:NW, 4:N, 5:NE, 6:E, 7:SE) x 4-walk-frame sheet
    using both painted front-SE and painted rear-NE poses."""
    front_se = tune_unit_readability_highres(clean_alpha_cutout(front_se_raw, erode_rim=True), role_key)
    rear_ne = tune_unit_readability_highres(clean_alpha_cutout(rear_ne_raw, erode_rim=True), role_key)

    # Derive all 8 cardinal + diagonal poses at high resolution before downsampling
    pose_se = front_se
    pose_sw = mirror_relight_topleft(front_se)
    pose_ne = rear_ne
    pose_nw = mirror_relight_topleft(rear_ne)

    # S (0): steeper downward rifle angle, compact frontal width, connected top shoulder mass
    pose_s = rotate_rgba_premult(front_se, angle_deg=-10.0, scale_x=0.93)
    # N (4): rear pose oriented straighter north, keeping full connected shoulder/back colour
    pose_n = rotate_rgba_premult(rear_ne, angle_deg=9.0, scale_x=0.93)
    # E (6) & W (2): horizontal rifle travel profile
    pose_e = rotate_rgba_premult(front_se, angle_deg=9.0, scale_x=0.96)
    pose_w = mirror_relight_topleft(pose_e)

    high_poses = [
        pose_s,   # 0: S
        pose_sw,  # 1: SW
        pose_w,   # 2: W
        pose_nw,  # 3: NW
        pose_n,   # 4: N
        pose_ne,  # 5: NE
        pose_e,   # 6: E
        pose_se,  # 7: SE
    ]

    cw, ch = cell_hd
    sheet_hd = np.zeros((ch * 4, cw * 8, 4), dtype=np.uint8)

    for col, hp in enumerate(high_poses):
        ys, xs = np.where(hp[:, :, 3] > 28)
        tight = hp[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        scale = vis_h_hd / max(tight.shape[0], 1)
        sw = min(cw - 4, max(6, int(round(tight.shape[1] * scale))))
        sh = min(ch - 4, max(8, int(round(tight.shape[0] * scale))))
        pose = resize_premult(tight, (sw, sh), sharpen=0.30)

        ph, pw, _ = pose.shape
        ox = (cw - pw) // 2
        oy_base = ch - ph - 2
        for row in range(4):
            frame = pose.copy()
            bob = -1 if row in (1, 3) else 0
            if row in (1, 3):
                # Smooth non-wrapping opposing stride shift in lower 35% of sprite (zero np.roll seam!)
                leg_y = int(ph * 0.65)
                mid_x = pw // 2
                shift = 1.0 if row == 1 else -1.0
                legs = frame[leg_y:, :, :].astype(np.float32)
                lh = legs.shape[0]
                yy_l = np.arange(lh, dtype=np.float32)[:, None]
                weight = np.clip(yy_l / max(lh - 1, 1), 0.0, 1.0)
                # Premultiply before vertical resampling so alpha edges stay clean
                la = legs[:, :, 3:4] / 255.0
                lpre = np.concatenate([legs[:, :, :3] * la, la * 255.0], axis=2)
                warped_pre = np.zeros_like(lpre)
                for half_slice, s_dir in [(slice(0, mid_x), shift), (slice(mid_x, pw), -shift)]:
                    sub_w = pw - mid_x if half_slice.start == mid_x else mid_x
                    if sub_w <= 0:
                        continue
                    map_x = np.broadcast_to(np.arange(sub_w, dtype=np.float32)[None, :], (lh, sub_w)).copy()
                    map_y = (yy_l - s_dir * weight * np.ones((1, sub_w), dtype=np.float32)).astype(np.float32)
                    warped_pre[:, half_slice, :] = cv2.remap(
                        lpre[:, half_slice, :], map_x, map_y,
                        interpolation=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0,
                    )
                wa = warped_pre[:, :, 3:4] / 255.0
                wrgb = np.where(wa > 1e-3, warped_pre[:, :, :3] / np.maximum(wa, 1e-3), 0.0)
                frame[leg_y:, :, :] = np.round(
                    np.concatenate([np.clip(wrgb, 0, 255), np.clip(warped_pre[:, :, 3:4], 0, 255)], axis=2)
                ).astype(np.uint8)
            oy = max(0, oy_base + bob)
            sheet_hd[row * ch + oy:row * ch + oy + ph, col * cw + ox:col * cw + ox + pw] = frame

    save_png(sheet_hd, OUT / f"{role_key}_hd.png")

    pcw, pch = cw // 2, ch // 2
    sheet_px = np.zeros((pch * 4, pcw * 8, 4), dtype=np.uint8)
    for row in range(4):
        for col in range(8):
            cell = sheet_hd[row * ch:(row + 1) * ch, col * cw:(col + 1) * cw]
            small = resize_premult(cell, (pcw, pch), sharpen=0.45)
            q = quantize_rgba(small, R4_PALETTE, alpha_cutoff=86, outline=True, outline_alpha=235)
            sheet_px[row * pch:(row + 1) * pch, col * pcw:(col + 1) * pcw] = q
    save_png(sheet_px, OUT / f"{role_key}_pixel.png")


def make_r4_portrait(cutout_rgba: np.ndarray, bg_top: tuple[int, int, int], bg_bot: tuple[int, int, int],
                     name: str) -> None:
    """Create 128x128 HD and 64x64 Pixel sidebar portrait cards in reusable_4/."""
    ys, xs = np.where(cutout_rgba[:, :, 3] > 32)
    sub = cutout_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    sz = 128
    yy = np.linspace(0.0, 1.0, sz, dtype=np.float32)[:, None, None]
    bg = np.array(bg_top, np.float32)[None, None, :] * (1.0 - yy) + np.array(bg_bot, np.float32)[None, None, :] * yy
    rng = np.random.default_rng(42)
    grain = cv2.GaussianBlur(rng.normal(0.0, 5.0, (sz, sz)).astype(np.float32), (0, 0), 0.9)
    gx, gy = np.meshgrid(np.linspace(-1, 1, sz), np.linspace(-1, 1, sz))
    vig = 1.0 - 0.26 * (gx * gx + gy * gy)
    canvas = np.clip((bg + grain[:, :, None]) * vig[:, :, None], 0, 255)

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
    px_rgba = quantize_rgba(px_raw, R4_PALETTE, alpha_cutoff=10, outline=False)
    save_png(px_rgba, OUT / f"portrait_{name}_pixel.png")


def make_squad_portrait_composite(single_rgba: np.ndarray) -> np.ndarray:
    """Compose a 4-soldier staggered diamond portrait from the clean single-soldier painting."""
    ys, xs = np.where(single_rgba[:, :, 3] > 28)
    s = single_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    sh, sw, _ = s.shape
    cw, ch = int(sw * 2.35), int(sh * 2.15)
    comp = np.zeros((ch, cw, 4), dtype=np.float32)
    offsets = [
        (int(cw * 0.50 - sw * 0.5), 0),
        (int(cw * 0.16 - sw * 0.5), int(sh * 0.48)),
        (int(cw * 0.84 - sw * 0.5), int(sh * 0.48)),
        (int(cw * 0.50 - sw * 0.5), int(sh * 0.96)),
    ]
    sf = s.astype(np.float32)
    sa = sf[:, :, 3:4] / 255.0
    for ox, oy in offsets:
        ox = max(0, min(cw - sw, ox))
        oy = max(0, min(ch - sh, oy))
        dst = comp[oy:oy + sh, ox:ox + sw]
        da = dst[:, :, 3:4] / 255.0
        out_a = sa + da * (1.0 - sa)
        out_rgb = np.where(out_a > 1e-3, (sf[:, :, :3] * sa + dst[:, :, :3] * da * (1.0 - sa)) / np.maximum(out_a, 1e-3), 0.0)
        comp[oy:oy + sh, ox:ox + sw, :3] = out_rgb
        comp[oy:oy + sh, ox:ox + sw, 3:4] = out_a * 255.0
    return np.round(np.clip(comp, 0, 255)).astype(np.uint8)


def build_units() -> None:
    u_src = np.array(Image.open(SRC_R4 / "01_units_readability.png").convert("RGBA"))
    uh, uw = u_src.shape[:2]
    cw, ch = uw // 4, uh // 2

    def cell_slice(r: int, c: int) -> np.ndarray:
        return crop_tight_rgba(u_src, (c * cw + 8, r * ch + 8, (c + 1) * cw - 8, (r + 1) * ch - 8), pad=8)

    b_sol_se, b_sol_ne = cell_slice(0, 0), cell_slice(0, 1)
    b_cmd_se, b_cmd_ne = cell_slice(0, 2), cell_slice(0, 3)
    r_sol_se, r_sol_ne = cell_slice(1, 0), cell_slice(1, 1)
    r_cmd_se, r_cmd_ne = cell_slice(1, 2), cell_slice(1, 3)

    # Identical frame cell & figure height to original Carbon!
    build_eight_facing_sheet(b_sol_se, b_sol_ne, (32, 36), 24, "blue_soldier")
    build_eight_facing_sheet(b_cmd_se, b_cmd_ne, (40, 46), 30, "blue_commander")
    build_eight_facing_sheet(r_sol_se, r_sol_ne, (32, 36), 24, "red_soldier")
    build_eight_facing_sheet(r_cmd_se, r_cmd_ne, (40, 46), 30, "red_commander")

    # Matching sidebar portraits
    b_sol_clean = tune_unit_readability_highres(clean_alpha_cutout(b_sol_se), "blue_soldier")
    r_sol_clean = tune_unit_readability_highres(clean_alpha_cutout(r_sol_se), "red_soldier")
    b_cmd_clean = tune_unit_readability_highres(clean_alpha_cutout(b_cmd_se), "blue_commander")
    r_cmd_clean = tune_unit_readability_highres(clean_alpha_cutout(r_cmd_se), "red_commander")

    make_r4_portrait(make_squad_portrait_composite(b_sol_clean), (226, 188, 134), (168, 122, 74), "blue_squad")
    make_r4_portrait(b_cmd_clean, (232, 196, 144), (162, 124, 82), "blue_commander")
    make_r4_portrait(make_squad_portrait_composite(r_sol_clean), (222, 178, 126), (158, 104, 64), "red_squad")
    make_r4_portrait(r_cmd_clean, (228, 182, 128), (162, 102, 62), "red_commander")


def build_dunes() -> None:
    """Extract signed-delta dune pieces from 02_dune_kit.png on flat #E48728 sand."""
    dunes_src = np.array(Image.open(SRC_R4 / "02_dune_kit.png").convert("RGB"), dtype=np.float32)
    bg = cv2.GaussianBlur(dunes_src, (0, 0), 92.0)
    delta = dunes_src - bg

    specs = [
        ("dune_fork", (12, 12, 754, 514), (296, 196), 1.18, 5.5, 21.0, False),
        ("dune_end", (762, 12, 1524, 514), (264, 168), 1.14, 5.2, 20.0, True),
        ("dune_shoulder", (12, 522, 754, 1012), (312, 188), 0.96, 4.5, 18.0, False),
        ("dune_ripples", (762, 522, 1524, 1012), (248, 152), 1.02, 3.8, 15.0, False),
    ]
    for cname, (x0, y0, x1, y1), (ww, wh), gain, e_floor, e_span, taper_east in specs:
        sub_d = delta[y0:y1, x0:x1].copy()
        ch, cw, _ = sub_d.shape
        cy_grid, cx_grid = np.mgrid[0:ch, 0:cw].astype(np.float32)
        ny = (cy_grid / max(ch - 1, 1)) * 2.0 - 1.0
        nx = (cx_grid / max(cw - 1, 1)) * 2.0 - 1.0
        r = np.sqrt(nx * nx + ny * ny)
        radial = np.clip((1.0 - r) / 0.28, 0.0, 1.0)
        radial = radial * radial * (3.0 - 2.0 * radial)

        if taper_east:
            # Ensure fading dune end dissolves smoothly toward its right/NE tip
            east_taper = np.clip((0.96 - (cx_grid / max(cw - 1, 1))) / 0.34, 0.0, 1.0)
            radial *= east_taper * (0.45 + 0.55 * east_taper)

        energy = cv2.GaussianBlur(np.linalg.norm(sub_d, axis=2), (0, 0), 28.0)
        env = np.clip((energy - e_floor) / e_span, 0.0, 1.0) * radial

        # HD (2x)
        d_hd = cv2.resize(sub_d, (ww * 2, wh * 2), interpolation=cv2.INTER_AREA)
        e_hd = cv2.resize(env, (ww * 2, wh * 2), interpolation=cv2.INTER_AREA)
        rgb_hd = np.clip(128.0 + d_hd * gain, 0.0, 255.0).astype(np.uint8)
        a_hd = np.clip(e_hd * 255.0, 0.0, 255.0).astype(np.uint8)[:, :, None]
        save_png(np.concatenate([rgb_hd, a_hd], axis=2), OUT / f"{cname}_hd.png")

        # Pixel (1x) stepped Dune II tonal bands
        d_px = cv2.resize(sub_d, (ww, wh), interpolation=cv2.INTER_AREA)
        e_px = cv2.resize(env, (ww, wh), interpolation=cv2.INTER_AREA)
        lum_d = d_px[:, :, 0] * 0.45 + d_px[:, :, 1] * 0.42 + d_px[:, :, 2] * 0.13
        stepped = np.round(np.clip(lum_d / 13.0, -4.0, 4.0)) * 13.0
        scale = np.where(np.abs(lum_d) > 1.8, stepped / np.where(np.abs(lum_d) > 1.8, lum_d, 1.0), 0.0)
        d_px_q = d_px * np.clip(scale[:, :, None], 0.0, 1.8)
        rgb_px = np.clip(128.0 + d_px_q * (gain * 1.04), 0.0, 255.0).astype(np.uint8)
        a_px = np.where(e_px > 0.11, np.clip(np.round(e_px * 6.0) / 6.0 * 255.0, 0, 255), 0).astype(np.uint8)[:, :, None]
        save_png(np.concatenate([rgb_px, a_px], axis=2), OUT / f"{cname}_pixel.png")


def build_oasis_and_hq() -> None:
    """Extract gap-verified modular oasis kit, freestanding tree, and adapted Blue Field HQ."""
    oasis_src = np.array(Image.open(SRC_R4 / "03_oasis_kit.png").convert("RGBA"))

    # 1. Water pool — preserve translucent shallow aqua rim, decontaminating white against warm shallow aqua
    w_raw = crop_tight_rgba(oasis_src, (36, 56, 594, 478), pad=6)
    w_clean = clean_alpha_cutout(w_raw, bg_rgb=(252.0, 252.0, 248.0), erode_rim=False, alpha_floor=10.0)
    save_r4_pair("oasis_water", w_clean, (156, 118), skirt_hd=0, sharp_hd=0.14, sharp_pix=0.25, alpha_cut=56)

    # 2. Sandy bank — decontaminate outer feathered edge toward desert sand so no pale rim ever shows!
    s_raw = crop_tight_rgba(oasis_src, (600, 56, 1022, 478), pad=6)
    s_clean = clean_alpha_cutout(s_raw, bg_rgb=(252.0, 250.0, 246.0), erode_rim=False, alpha_floor=12.0)
    # Blend very low-alpha outer pixels gently toward SAND_REF_RGB so it melts into Carbon's sand
    sf = s_clean.astype(np.float32)
    sa = sf[:, :, 3:4] / 255.0
    edge_blend = np.clip((0.68 - sa) / 0.55, 0.0, 1.0) * (sa > 0.02).astype(np.float32)
    sf[:, :, :3] = sf[:, :, :3] * (1.0 - edge_blend * 0.65) + SAND_REF_RGB[None, None, :] * (edge_blend * 0.65)
    save_r4_pair("oasis_bank_sand", np.round(sf).astype(np.uint8), (128, 96), skirt_hd=0, sharp_hd=0.12, sharp_pix=0.24, alpha_cut=52)

    # 3. Rocky bank
    rb_raw = crop_tight_rgba(oasis_src, (1028, 36, 1504, 478), pad=6)
    rb_clean = clean_alpha_cutout(rb_raw, erode_rim=True)
    save_r4_pair("oasis_bank_rock", rb_clean, (128, 114), skirt_hd=2, sharp_hd=0.18, sharp_pix=0.35, alpha_cut=82)

    # 4. Cliff ledge
    cl_raw = crop_tight_rgba(oasis_src, (16, 486, 616, 988), pad=6)
    cl_clean = clean_alpha_cutout(cl_raw, erode_rim=True)
    save_r4_pair("oasis_cliff_ledge", cl_clean, (192, 156), skirt_hd=4, sharp_hd=0.20, sharp_pix=0.36, alpha_cut=84)

    # 5. Cliff end / buttress
    ce_raw = crop_tight_rgba(oasis_src, (620, 486, 1032, 988), pad=6)
    ce_clean = clean_alpha_cutout(ce_raw, erode_rim=True)
    save_r4_pair("oasis_cliff_end", ce_clean, (118, 108), skirt_hd=4, sharp_hd=0.20, sharp_pix=0.36, alpha_cut=84)

    # 6. Oasis reeds
    rd_raw = crop_tight_rgba(oasis_src, (1040, 500, 1490, 920), pad=5)
    rd_clean = clean_alpha_cutout(rd_raw, erode_rim=False, alpha_floor=20.0)
    save_r4_pair("oasis_reeds", rd_clean, (34, 28), skirt_hd=0, sharp_hd=0.24, sharp_pix=0.40, alpha_cut=70)

    # 7. Freestanding oasis tree (with gentle vertical overhead foreshortening so crown matches Carbon's pitch)
    tree_src = np.array(Image.open(SRC_R4 / "04_oasis_tree.png").convert("RGBA"))
    t_raw = crop_tight_rgba(tree_src, (60, 12, 1480, 930), pad=8)
    t_clean = clean_alpha_cutout(t_raw, erode_rim=False, alpha_floor=22.0)
    save_r4_pair("oasis_tree", t_clean, (96, 62), skirt_hd=0, sharp_hd=0.22, sharp_pix=0.38, alpha_cut=76)

    # 8. Blue Field Headquarters (keep lamps warm & subdued so Orichalcum stays brightest gold landmark)
    hq_src = np.array(Image.open(SRC_R4 / "05_blue_headquarters.png").convert("RGBA"))
    hq_raw = crop_tight_rgba(hq_src, (250, 68, 1290, 960), pad=8)
    hq_clean = clean_alpha_cutout(hq_raw, erode_rim=True)
    hq_f = hq_clean.astype(np.float32)
    # Gently cap lamp peak brightness in lower front wall so Orichalcum remains the brightest gold highlight
    hh, hw, _ = hq_f.shape
    yy_hq = np.linspace(0.0, 1.0, hh, dtype=np.float32)[:, None]
    lamp_px = (yy_hq > 0.68) & (hq_f[:, :, 0] > 225.0) & (hq_f[:, :, 1] > 155.0) & (hq_f[:, :, 2] < 120.0)
    if np.any(lamp_px):
        hq_f[lamp_px, 0] = 208.0 + (hq_f[lamp_px, 0] - 208.0) * 0.35
        hq_f[lamp_px, 1] = 142.0 + (hq_f[lamp_px, 1] - 142.0) * 0.35
    hq_final = np.round(np.clip(hq_f, 0, 255)).astype(np.uint8)
    save_r4_pair("blue_field_hq", hq_final, (140, 118), skirt_hd=4, sharp_hd=0.20, sharp_pix=0.36, alpha_cut=84)
    make_r4_portrait(hq_final, (218, 184, 136), (138, 104, 68), "blue_hq")


def build_crystal_and_road_kit() -> None:
    """Extract modular Orichalcum crystal kit, gravel/pebble scatter, and seamless road fork/join/end pieces."""
    ori_kit = np.array(Image.open(SRC_R4 / "06_orichalcum_and_scatter.png").convert("RGBA"))
    oh, ow = ori_kit.shape[:2]

    cb_raw = crop_tight_rgba(ori_kit, (32, 20, ow // 2 - 8, oh // 2 + 8), pad=6)
    save_r4_pair("crystal_base", clean_alpha_cutout(cb_raw, erode_rim=True), (146, 100), skirt_hd=4, sharp_hd=0.20, sharp_pix=0.38, alpha_cut=82)

    cw_raw = crop_tight_rgba(ori_kit, (ow // 2 + 8, 140, ow - 20, oh // 2 - 20), pad=6)
    save_r4_pair("crystal_wide", clean_alpha_cutout(cw_raw, erode_rim=True), (98, 38), skirt_hd=0, sharp_hd=0.24, sharp_pix=0.42, alpha_cut=78)

    ct_raw = crop_tight_rgba(ori_kit, (180, oh // 2 + 20, ow // 2 - 60, oh - 20), pad=6)
    save_r4_pair("crystal_tall", clean_alpha_cutout(ct_raw, erode_rim=True), (64, 68), skirt_hd=0, sharp_hd=0.24, sharp_pix=0.42, alpha_cut=78)

    cg_raw = crop_tight_rgba(ori_kit, (ow // 2 + 12, oh // 2 + 80, 1100, oh - 40), pad=5)
    save_r4_pair("crystal_gravel", clean_alpha_cutout(cg_raw, erode_rim=True), (68, 50), skirt_hd=0, sharp_hd=0.20, sharp_pix=0.38, alpha_cut=74)

    pb_raw = crop_tight_rgba(ori_kit, (1100, oh // 2 + 80, ow - 40, oh - 40), pad=5)
    save_r4_pair("pebble_scatter", clean_alpha_cutout(pb_raw, erode_rim=True), (46, 38), skirt_hd=0, sharp_hd=0.22, sharp_pix=0.40, alpha_cut=74)

    # Road extensions built directly from Carbon's 05_road_and_outpost.png interior limestone plates
    # so stonework, joints, and colour match MainRoad and PlazaOval 1-to-1!
    plaza_full = np.array(Image.open(SRC_CARBON / "05_road_and_outpost.png").convert("RGB"), dtype=np.float32)
    stone_patch = plaza_full[290:600, 960:1540]  # pure interior cracked limestone plates

    # A. Seamless Y-Fork / Plaza-Join interior limestone bridge (erases crossing pebble rims!)
    jw, jh = 168, 112
    j_rgb = cv2.resize(stone_patch, (jw, jh), interpolation=cv2.INTER_AREA)
    j_blur = cv2.GaussianBlur(j_rgb, (0, 0), 1.0)
    j_rgb = np.clip(j_rgb + 0.38 * (j_rgb - j_blur), 0, 255)
    hgt = (j_rgb.mean(axis=2) / 255.0) - 0.5
    yy, xx = np.mgrid[0:jh, 0:jw].astype(np.float32)
    nx = (xx / (jw - 1)) * 2.0 - 1.0
    ny = (yy / (jh - 1)) * 2.0 - 1.0
    ell = np.sqrt(nx * nx + ny * ny) + 0.08 * hgt
    j_alpha = np.clip((0.94 - ell) / 0.24, 0.0, 1.0)
    join_hd = np.concatenate([j_rgb.astype(np.uint8), np.round(j_alpha[:, :, None] * 255.0).astype(np.uint8)], axis=2)
    save_png(join_hd, OUT / "road_join_patch_hd.png")
    join_px = quantize_rgba(resize_premult(join_hd, (jw // 2, jh // 2), sharpen=0.24), R4_PALETTE, alpha_cutoff=88)
    save_png(join_px, OUT / "road_join_patch_pixel.png")

    # B. Road End Cap — trailing flagstones breaking apart into windblown sand along +X
    ew, eh = 160, 104
    e_rgb = cv2.resize(stone_patch[30:270, 60:500], (ew, eh), interpolation=cv2.INTER_AREA)
    e_blur = cv2.GaussianBlur(e_rgb, (0, 0), 1.0)
    e_rgb = np.clip(e_rgb + 0.40 * (e_rgb - e_blur), 0, 255)
    ey, ex = np.mgrid[0:eh, 0:ew].astype(np.float32)
    u = ex / (ew - 1)  # 0 = attached road throat, 1 = sand tip
    v = np.abs((ey / (eh - 1)) * 2.0 - 1.0)
    plate_var = (cv2.GaussianBlur(e_rgb.mean(axis=2), (0, 0), 3.5) / 255.0 - 0.5) * 0.55
    half_w = 0.78 * (1.0 - 0.52 * u)
    across = np.clip((half_w - v + plate_var * 0.22) / 0.20, 0.0, 1.0)
    along = np.clip((1.02 - u + plate_var * 0.35) / 0.42, 0.0, 1.0) * np.clip(u / 0.14, 0.0, 1.0)
    e_alpha = across * along
    sand_mix = np.clip((u - 0.28) / 0.58, 0.0, 1.0)[:, :, None]
    e_rgb_sand = e_rgb * (1.0 - sand_mix * 0.72) + SAND_REF_RGB[None, None, :] * (sand_mix * 0.72)
    end_hd = np.concatenate([np.clip(e_rgb_sand, 0, 255).astype(np.uint8),
                             np.round(e_alpha[:, :, None] * 255.0).astype(np.uint8)], axis=2)
    save_png(end_hd, OUT / "road_end_cap_hd.png")
    end_px = quantize_rgba(resize_premult(end_hd, (ew // 2, eh // 2), sharpen=0.25), R4_PALETTE, alpha_cutoff=84)
    save_png(end_px, OUT / "road_end_cap_pixel.png")

    # C. Blown-sand spill decal for road edges (wind-drifted sand tongue)
    sand_tile = np.array(Image.open(CARBON_OUT / "sand_tile_hd.png").convert("RGB"), dtype=np.float32)
    sw, sh = 192, 96
    s_rgb = cv2.resize(sand_tile[:192, :384], (sw, sh), interpolation=cv2.INTER_AREA)
    sy, sx = np.mgrid[0:sh, 0:sw].astype(np.float32)
    s_nx = (sx / (sw - 1)) * 2.0 - 1.0
    s_ny = (sy / (sh - 1)) * 2.0 - 1.0
    wisp = 0.14 * np.sin(s_nx * 5.2 + s_ny * 2.5) + 0.08 * np.cos(s_nx * 9.0 - s_ny * 4.0)
    s_r = np.sqrt((s_nx * 0.95) ** 2 + (s_ny * 1.10 + 0.12 * s_nx) ** 2) + wisp
    s_alpha = np.clip((0.88 - s_r) / 0.42, 0.0, 1.0) ** 1.35
    # Slight sunlit warm crest along upper-left edge of drift
    crest = np.clip((-s_ny * 0.6 - s_nx * 0.3), -0.3, 0.4)[:, :, None]
    s_rgb = np.clip(s_rgb * (1.0 + crest * 0.12), 0, 255)
    spill_hd = np.concatenate([s_rgb.astype(np.uint8), np.round(s_alpha[:, :, None] * 255.0).astype(np.uint8)], axis=2)
    save_png(spill_hd, OUT / "road_sand_spill_hd.png")
    spill_sm = resize_premult(spill_hd, (sw // 2, sh // 2))
    spill_px = quantize_rgba(spill_sm, R4_PALETTE, alpha_cutoff=24)
    # Soften pixel alpha rim with 2x2 Bayer stipple so no hard oval shows on pixel flagstones
    ph_s, pw_s = spill_sm.shape[:2]
    bayer = (np.array([[0, 2], [3, 1]], dtype=np.float32) + 0.5) / 4.0
    thresh = np.tile(bayer, (ph_s // 2 + 1, pw_s // 2 + 1))[:ph_s, :pw_s]
    sa_norm = spill_sm[:, :, 3].astype(np.float32) / 255.0
    spill_px[:, :, 3] = np.where(sa_norm > thresh * 0.85 + 0.12, 220, 0).astype(np.uint8)
    save_png(spill_px, OUT / "road_sand_spill_pixel.png")


def build_diagnostic_sheet() -> None:
    """Render a quick visual audit sheet of extracted Reusable 4 pieces & 8-facing units."""
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    W, H = 1440, 900
    sand = np.array(Image.open(CARBON_OUT / "sand_tile_hd.png").convert("RGB"))
    canvas = np.tile(sand, (H // 512 + 2, W // 512 + 2, 1))[:H, :W].astype(np.float32)

    def blit(path: Path, cx: int, cy: int, scale: float = 1.0) -> None:
        im = np.array(Image.open(path).convert("RGBA"))
        if abs(scale - 1.0) > 1e-3:
            im = resize_premult(im, (max(1, int(im.shape[1] * scale)), max(1, int(im.shape[0] * scale))))
        ih, iw = im.shape[:2]
        x0, y0 = cx - iw // 2, cy - ih // 2
        x1, y1 = min(W, x0 + iw), min(H, y0 + ih)
        sx0, sy0 = max(0, -x0), max(0, -y0)
        x0, y0 = max(0, x0), max(0, y0)
        sub = im[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)].astype(np.float32)
        a = sub[:, :, 3:4] / 255.0
        canvas[y0:y1, x0:x1] = canvas[y0:y1, x0:x1] * (1.0 - a) + sub[:, :, :3] * a

    blit(OUT / "oasis_cliff_ledge_hd.png", 260, 210)
    blit(OUT / "oasis_cliff_end_hd.png", 560, 220)
    blit(OUT / "oasis_water_hd.png", 860, 210)
    blit(OUT / "oasis_bank_sand_hd.png", 920, 220)
    blit(OUT / "oasis_bank_rock_hd.png", 940, 235)
    blit(OUT / "oasis_tree_hd.png", 1210, 210)
    blit(OUT / "oasis_reeds_hd.png", 760, 260)

    blit(OUT / "blue_field_hq_hd.png", 240, 540)
    blit(OUT / "crystal_base_hd.png", 620, 540)
    blit(OUT / "crystal_wide_hd.png", 620, 530)
    blit(OUT / "crystal_base_hd.png", 960, 540)
    blit(OUT / "crystal_tall_hd.png", 960, 515)
    blit(OUT / "crystal_gravel_hd.png", 1220, 500)
    blit(OUT / "pebble_scatter_hd.png", 1220, 590)

    # Bottom strip: 8-facing HD sheets
    blit(OUT / "blue_soldier_hd.png", 220, 790)
    blit(OUT / "red_soldier_hd.png", 560, 790)
    blit(OUT / "blue_commander_hd.png", 930, 790)
    blit(OUT / "red_commander_hd.png", 1270, 790)

    save_png(np.clip(canvas, 0, 255).astype(np.uint8), PREVIEW_DIR / "kit_extraction_audit.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_units()
    build_dunes()
    build_oasis_and_hq()
    build_crystal_and_road_kit()
    build_diagnostic_sheet()
    print(f"Built {len(list(OUT.glob('*.png')))} textures in {OUT}")


if __name__ == "__main__":
    main()
