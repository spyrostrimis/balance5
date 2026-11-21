#!/usr/bin/env python3
"""
Builds all 2D parallel-projection pixel-art assets for the RPG 2D Canyon study:
- Approach 1 (Continuous Uncut 2D Artwork):
  Stitches `approach1_plate_top.jpg` and `approach1_plate_bottom.jpg` across their
  exact 81-px overlap into a 1967-px tall uncut canyon, seamlessly extends the
  outer 139-px left/right cliff shelves for full 960x540 widescreen, and extracts
  in-place Y-sorted walk-behind boulder/bush overlays.
- Approach 2 (Modular Stitched & Kitbashed 2D Scene):
  Quilts a seamless 960x1967 desert floor and winding constant-width S-curve
  cobblestone road from `approach2_ground_road_sheet.jpg`, and slices all 6 modular
  stepped dry-stone/terracotta cliff formations (`approach2_cliffs_sheet.jpg`) and
  12 modular props (`approach2_props_sheet.jpg`) with exterior-flood-fill alpha
  cutouts and directional contact shadows.
- Shared 192-color master indexed palette (`palette_192.png`) and batch Laigter
  normal map generation (`C:/Laigter/laigter.exe -g -s -d`).
"""

import os
import subprocess
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT / "assets" / "source_inputs" / "rpg_2d"
OUT_DIR = ROOT / "assets" / "textures" / "rpg_2d"
MOD_DIR = OUT_DIR / "modular"
SPR_DIR = OUT_DIR / "sprites"
LAIGTER_EXE = Path(r"C:\Laigter\laigter.exe")

CANVAS_W = 960
CANVAS_H = 1967


def ensure_dirs() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    MOD_DIR.mkdir(parents=True, exist_ok=True)
    SPR_DIR.mkdir(parents=True, exist_ok=True)


def run_laigter_normal(diffuse_path: Path, out_normal_path: Path) -> None:
    if not LAIGTER_EXE.exists():
        raise FileNotFoundError(f"Laigter not found at {LAIGTER_EXE}")
    spec_old = diffuse_path.parent / f"{diffuse_path.stem}_s.png"
    if spec_old.exists():
        spec_old.unlink()
    cmd = [str(LAIGTER_EXE), "--no-gui", "--normal", "-d", str(diffuse_path)]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    generated = diffuse_path.parent / f"{diffuse_path.stem}_n.png"
    if not generated.exists():
        raise RuntimeError(f"Laigter did not produce {generated}")
    if generated != out_normal_path:
        if out_normal_path.exists():
            out_normal_path.unlink()
        generated.rename(out_normal_path)


def dp_horizontal_seam(top_patch: np.ndarray, bot_patch: np.ndarray) -> np.ndarray:
    """Minimum-error dynamic-programming horizontal seam cut between two (H, W, 3) float32 patches."""
    diff = np.abs(top_patch - bot_patch).sum(axis=2)
    H, W = diff.shape
    cost = np.zeros((H, W), dtype=np.float32)
    back = np.zeros((H, W), dtype=np.int32)
    cost[:, 0] = diff[:, 0]
    for x in range(1, W):
        for y in range(H):
            y0, y1 = max(0, y - 1), min(H, y + 2)
            bi = int(np.argmin(cost[y0:y1, x - 1])) + y0
            cost[y, x] = diff[y, x] + cost[bi, x - 1]
            back[y, x] = bi
    seam_y = np.zeros(W, dtype=np.int32)
    seam_y[W - 1] = int(np.argmin(cost[:, W - 1]))
    for x in range(W - 2, -1, -1):
        seam_y[x] = back[seam_y[x + 1], x + 1]
    out = np.zeros_like(top_patch)
    for x in range(W):
        sy = seam_y[x]
        for y in range(H):
            a = np.clip((y - (sy - 3.5)) / 7.0, 0.0, 1.0)
            out[y, x] = (1.0 - a) * top_patch[y, x] + a * bot_patch[y, x]
    return out


def dp_vertical_seam(left_patch: np.ndarray, right_patch: np.ndarray) -> np.ndarray:
    """Minimum-error dynamic-programming vertical seam cut between two (H, W, 3) float32 patches."""
    t_left = np.transpose(left_patch, (1, 0, 2))
    t_right = np.transpose(right_patch, (1, 0, 2))
    return np.transpose(dp_horizontal_seam(t_left, t_right), (1, 0, 2))


def build_master_192_palette() -> Image.Image:
    """Extracts a unified 192-color master palette across Approach 1, Approach 2, and the Blue Commander."""
    samples = []
    for name in [
        "img9_reference.jpg",
        "approach1_plate_bottom.jpg",
        "approach1_plate_top.jpg",
        "approach2_cliffs_sheet.jpg",
        "approach2_ground_road_sheet.jpg",
        "approach2_props_sheet.jpg",
    ]:
        im = Image.open(SRC_DIR / name).convert("RGB").resize((240, 240), Image.Resampling.BILINEAR)
        samples.append(np.array(im))

    hero_p = ROOT / "assets" / "textures" / "pixel_canyon" / "blue_commander.png"
    if hero_p.exists():
        him = Image.open(hero_p).convert("RGBA")
        harr = np.array(him)
        fg = harr[harr[:, :, 3] > 128][:, :3]
        if len(fg) > 0:
            idx = np.linspace(0, len(fg) - 1, 240 * 60, dtype=np.int32)
            samples.append(fg[idx].reshape((60, 240, 3)))

    comp = Image.fromarray(np.vstack(samples), "RGB")
    q = comp.quantize(colors=192, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal_raw = q.getpalette()[: 192 * 3]
    pal_arr = np.array(pal_raw, dtype=np.uint8).reshape((192, 3))

    swatch = Image.new("RGB", (16 * 16, 12 * 16))
    dr = ImageDraw.Draw(swatch)
    for idx, (r, g, b) in enumerate(pal_arr):
        cx = (idx % 16) * 16
        cy = (idx // 16) * 16
        dr.rectangle([cx, cy, cx + 15, cy + 15], fill=(int(r), int(g), int(b)))
    swatch.save(OUT_DIR / "palette_192.png")
    return q


def quantize_to_192(img_rgba: Image.Image, pal_img: Image.Image) -> Image.Image:
    rgba = img_rgba.convert("RGBA")
    arr = np.array(rgba)
    alpha = arr[:, :, 3]
    rgb = Image.fromarray(arr[:, :, :3], "RGB")
    q_rgb = rgb.quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.array(q_rgb), alpha])
    return Image.fromarray(out, "RGBA")


def clean_magenta_cutout(
    im_rgb: Image.Image,
    box: tuple[int, int, int, int],
    scale: float = 1.0,
    extra_bg_seeds: list[tuple[int, int]] | None = None,
) -> Image.Image:
    """Extracts an asset from the dark-magenta (#3A003A) background using exterior perimeter flood-fill."""
    x0, y0, x1, y1 = box
    sub = np.array(im_rgb.crop((x0, y0, x1, y1)), dtype=np.float32)
    H, W, _ = sub.shape
    r, g, b = sub[:, :, 0], sub[:, :, 1], sub[:, :, 2]
    cand_bg = (g < 28.0) & (b > g + 22.0) & (r < 115.0)

    is_ext_bg = np.zeros((H, W), dtype=bool)
    q = deque()
    for x in range(W):
        if cand_bg[0, x]:
            is_ext_bg[0, x] = True
            q.append((0, x))
        if cand_bg[H - 1, x]:
            is_ext_bg[H - 1, x] = True
            q.append((H - 1, x))
    for y in range(H):
        if cand_bg[y, 0]:
            is_ext_bg[y, 0] = True
            q.append((y, 0))
        if cand_bg[y, W - 1]:
            is_ext_bg[y, W - 1] = True
            q.append((y, W - 1))
    if extra_bg_seeds:
        for sx, sy in extra_bg_seeds:
            for dy in range(-5, 6):
                for dx in range(-5, 6):
                    ny, nx = sy + dy, sx + dx
                    if 0 <= ny < H and 0 <= nx < W and cand_bg[ny, nx] and not is_ext_bg[ny, nx]:
                        is_ext_bg[ny, nx] = True
                        q.append((ny, nx))
    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < H and 0 <= nx < W and not is_ext_bg[ny, nx] and cand_bg[ny, nx]:
                is_ext_bg[ny, nx] = True
                q.append((ny, nx))

    alpha = (~is_ext_bg).astype(np.int32)
    ext_pad = np.pad(is_ext_bg.astype(np.int32), 1)
    touches_ext = (
        ext_pad[:-2, :-2] + ext_pad[:-2, 1:-1] + ext_pad[:-2, 2:]
        + ext_pad[1:-1, :-2] + ext_pad[1:-1, 2:]
        + ext_pad[2:, :-2] + ext_pad[2:, 1:-1] + ext_pad[2:, 2:]
    ) > 0
    alpha = np.where(touches_ext & (b > g + 14.0) & (g < 38.0), 0, alpha)

    ys, xs = np.where(alpha > 0)
    y_min, y_max = int(ys.min()), int(ys.max()) + 1
    x_min, x_max = int(xs.min()), int(xs.max()) + 1
    sub = sub[y_min:y_max, x_min:x_max]
    alpha_f = alpha[y_min:y_max, x_min:x_max].astype(np.float32)

    ap2 = np.pad(alpha_f.astype(np.int32), 1)
    edge = (alpha_f > 0.5) & ((ap2[:-2, 1:-1] & ap2[2:, 1:-1] & ap2[1:-1, :-2] & ap2[1:-1, 2:]) == 0)
    sub[:, :, 2] = np.where(edge, np.minimum(sub[:, :, 2], sub[:, :, 1]), sub[:, :, 2])
    sub[:, :, 0] = np.where(
        edge & (sub[:, :, 0] > sub[:, :, 1] * 1.5),
        np.minimum(sub[:, :, 0], sub[:, :, 1] * 1.3 + 10.0),
        sub[:, :, 0],
    )

    if abs(scale - 1.0) > 1e-3:
        nw = max(8, int(round(sub.shape[1] * scale)))
        nh = max(8, int(round(sub.shape[0] * scale)))
        pre = sub * alpha_f[:, :, None]
        pre_im = Image.fromarray(np.clip(pre, 0, 255).astype(np.uint8), "RGB").resize(
            (nw, nh), Image.Resampling.LANCZOS
        )
        a_im = Image.fromarray((alpha_f * 255.0).astype(np.uint8), "L").resize(
            (nw, nh), Image.Resampling.LANCZOS
        )
        pre_s = np.array(pre_im, dtype=np.float32)
        a_s = np.array(a_im, dtype=np.float32) / 255.0
        mask = a_s >= 0.50
        rgb_s = np.zeros_like(pre_s)
        rgb_s[mask] = np.clip(pre_s[mask] / np.maximum(a_s[mask, None], 0.50), 0, 255)
        sub = rgb_s
        alpha_f = mask.astype(np.float32)

    ap3 = np.pad(alpha_f.astype(np.int32), 1)
    outline = (alpha_f > 0.5) & ((ap3[:-2, 1:-1] & ap3[2:, 1:-1] & ap3[1:-1, :-2] & ap3[1:-1, 2:]) == 0)
    sub[outline] = np.minimum(sub[outline], np.array([58.0, 28.0, 18.0]))

    rgba = np.dstack(
        [
            np.clip(sub[:, :, 0], 0, 255).astype(np.uint8),
            np.clip(sub[:, :, 1], 0, 255).astype(np.uint8),
            np.clip(sub[:, :, 2], 0, 255).astype(np.uint8),
            (alpha_f * 255).astype(np.uint8),
        ]
    )
    return Image.fromarray(rgba, "RGBA")


def build_approach1_assets(pal_img: Image.Image) -> None:
    """Builds the 960x1967 uncut Approach 1 canvas + Laigter normal map + Y-sorted in-place walk-behind cutouts."""
    p_bot = np.array(Image.open(SRC_DIR / "approach1_plate_bottom.jpg").convert("RGB"), dtype=np.float32)
    p_top = np.array(Image.open(SRC_DIR / "approach1_plate_top.jpg").convert("RGB"), dtype=np.float32)
    overlap = 81
    stitched = np.zeros((CANVAS_H, 682, 3), dtype=np.float32)
    stitched[: 1024 - overlap] = p_top[: 1024 - overlap]
    for r in range(overlap):
        a = np.clip((r - 52.0) / 24.0, 0.0, 1.0)
        stitched[1024 - overlap + r] = (1.0 - a) * p_top[1024 - overlap + r] + a * p_bot[r]
    stitched[1024:] = p_bot[overlap:]

    wing_w = 165
    ov_x = 26  # 165 - 26 = 139 px wing on each side -> 139 + 682 + 139 = 960 px total width

    def build_shifted_wing(src_strip: np.ndarray, offsets: list[int]) -> np.ndarray:
        ch = 520
        ov_y = 60
        step = ch - ov_y
        wing = np.zeros((len(offsets) * step + ov_y, wing_w, 3), dtype=np.float32)
        for i, y_off in enumerate(offsets):
            patch = src_strip[y_off : y_off + ch]
            if i == 0:
                wing[:ch] = patch
            else:
                y0 = i * step
                wing[y0 : y0 + ov_y] = dp_horizontal_seam(wing[y0 : y0 + ov_y], patch[:ov_y])
                wing[y0 + ov_y : y0 + ch] = patch[ov_y:]
        return wing[:CANVAS_H]

    left_wing = build_shifted_wing(stitched[:, :wing_w], [260, 740, 1180, 140, 920])
    right_wing = build_shifted_wing(stitched[:, 682 - wing_w :], [310, 820, 1260, 190, 1010])

    a1_wide = np.zeros((CANVAS_H, CANVAS_W, 3), dtype=np.float32)
    a1_wide[:, :139] = left_wing[:, :139]
    a1_wide[:, 139 : 139 + ov_x] = dp_vertical_seam(left_wing[:, 139 : 139 + ov_x], stitched[:, :ov_x])
    a1_wide[:, 139 + ov_x : 821 - ov_x] = stitched[:, ov_x : 682 - ov_x]
    a1_wide[:, 821 - ov_x : 821] = dp_vertical_seam(stitched[:, 682 - ov_x : 682], right_wing[:, :ov_x])
    a1_wide[:, 821:] = right_wing[:, ov_x:]

    a1_im = quantize_to_192(Image.fromarray(np.clip(a1_wide, 0, 255).astype(np.uint8), "RGB"), pal_img)
    a1_path = OUT_DIR / "approach1_uncut_canvas.png"
    a1_im.save(a1_path)
    run_laigter_normal(a1_path, OUT_DIR / "approach1_uncut_canvas_n.png")

    # Extract 8 in-place road-side boulder & bush cutouts from a1_im so the hero can walk behind their top crests
    # Each tuple is (name, x0_in_960, y0_in_1967, x1_in_960, y1_in_1967)
    a1_arr = np.array(a1_im)
    cutout_boxes = [
        ("a1_cutout_00", 365, 225, 458, 305),   # upper-right boulder & bush by road bend
        ("a1_cutout_01", 318, 495, 422, 578),   # upper-left large boulder next to road curb
        ("a1_cutout_02", 495, 765, 598, 845),   # mid-upper right faceted boulder by road
        ("a1_cutout_03", 555, 1095, 668, 1185), # mid-canyon right bush cluster by road
        ("a1_cutout_04", 365, 1275, 472, 1365), # lower-mid left large boulder by road bend
        ("a1_cutout_05", 520, 1525, 635, 1615), # lower-mid right boulder & bush by curb
        ("a1_cutout_06", 268, 1675, 385, 1765), # lower-left large boulder near entrance
        ("a1_cutout_07", 290, 1785, 405, 1882), # entrance left large olive sagebush
    ]
    for cname, x0, y0, x1, y1 in cutout_boxes:
        sub = a1_arr[y0:y1, x0:x1].copy()
        h, w, _ = sub.shape
        # Soft dome alpha mask: full opacity in center/bottom core, feathered 4px rim so it blends invisibly in-place
        yy, xx = np.mgrid[0:h, 0:w]
        nx = (xx - w * 0.5) / (w * 0.48)
        ny = (yy - h * 0.55) / (h * 0.50)
        dist = np.sqrt(nx * nx + ny * ny)
        mask = np.clip((1.02 - dist) * 4.5, 0.0, 1.0)
        sub[:, :, 3] = (mask * 255).astype(np.uint8)
        c_path = MOD_DIR / f"{cname}.png"
        Image.fromarray(sub, "RGBA").save(c_path)
        run_laigter_normal(c_path, MOD_DIR / f"{cname}_n.png")


def add_baked_drop_shadow(spr: Image.Image, sdx: int = -12, sdy: int = 8, sa: float = 0.38) -> tuple[Image.Image, int, int]:
    """Pads a cutout sprite with its own upper-right-to-lower-left warm umber drop shadow so Y-sorted Sprite2D nodes look grounded."""
    w, h = spr.size
    pad_l = max(0, -sdx) + 10
    pad_r = max(0, sdx) + 10
    pad_t = max(0, -sdy) + 6
    pad_b = max(0, sdy) + 10
    nw, nh = w + pad_l + pad_r, h + pad_t + pad_b

    arr = np.array(spr)
    a = arr[:, :, 3].astype(np.float32) / 255.0
    yy = np.linspace(0.15, 1.0, h)[:, None]
    sh_mask = np.clip(a * yy, 0.0, 1.0)
    sh_canvas = Image.new("L", (nw, nh), 0)
    sh_canvas.paste(Image.fromarray((sh_mask * 255).astype(np.uint8), "L"), (pad_l + sdx, pad_t + sdy))
    sh_blur = sh_canvas.filter(ImageFilter.GaussianBlur(radius=5))

    out = Image.new("RGBA", (nw, nh), (0, 0, 0, 0))
    sh_rgba = np.zeros((nh, nw, 4), dtype=np.uint8)
    sh_rgba[:, :, 0] = 48
    sh_rgba[:, :, 1] = 22
    sh_rgba[:, :, 2] = 28
    sh_rgba[:, :, 3] = (np.array(sh_blur, dtype=np.float32) * sa).astype(np.uint8)
    out.alpha_composite(Image.fromarray(sh_rgba, "RGBA"), (0, 0))
    out.alpha_composite(spr, (pad_l, pad_t))
    # Return padded sprite plus the bottom-center offset relative to the original visual base
    return out, pad_l + w // 2, pad_t + h


def build_approach2_assets(pal_img: Image.Image) -> None:
    """Builds the Approach 2 stitched ground+road canvas and extracts all 6 modular cliffs and 12 modular props."""
    im_g = Image.open(SRC_DIR / "approach2_ground_road_sheet.jpg").convert("RGB")
    im_c = Image.open(SRC_DIR / "approach2_cliffs_sheet.jpg").convert("RGB")
    im_p = Image.open(SRC_DIR / "approach2_props_sheet.jpg").convert("RGB")

    # 1. Scale ground & road sheet by 0.72x so road width (140px) matches Approach 1 and cliff masonry courses
    scale = 0.72
    im_gs = im_g.resize((int(round(im_g.width * scale)), int(round(im_g.height * scale))), Image.Resampling.LANCZOS)
    arr_g = np.array(im_gs, dtype=np.float32)
    b1_full = arr_g[8:482, 8:268]   # (474, 260, 3) seamless sand patch
    b3 = arr_g[7:483, 484:730]      # (476, 246, 3) S-curve road + curbs

    # Quilt 960x1967 desert sand floor using interior sub-crops and DP graph cuts (zero wrap seams)
    sh, sw = 410, 220
    ov = 46
    step_x, step_y = sw - ov, sh - ov
    grid_cols, grid_rows = 6, 6
    row_strips = []
    for r in range(grid_rows):
        strip = np.zeros((sh, grid_cols * step_x + ov, 3), dtype=np.float32)
        for c in range(grid_cols):
            y_off = (r * 23 + c * 17) % (474 - sh)
            x_off = (r * 13 + c * 11) % (260 - sw)
            patch = b1_full[y_off : y_off + sh, x_off : x_off + sw]
            if c == 0:
                strip[:, :sw] = patch
            else:
                x0 = c * step_x
                strip[:, x0 : x0 + ov] = dp_vertical_seam(strip[:, x0 : x0 + ov], patch[:, :ov])
                strip[:, x0 + ov : x0 + sw] = patch[:, ov:]
        row_strips.append(strip[:, :CANVAS_W])

    sand_canvas = np.zeros((grid_rows * step_y + ov, CANVAS_W, 3), dtype=np.float32)
    sand_canvas[:sh] = row_strips[0]
    for r in range(1, grid_rows):
        y0 = r * step_y
        sand_canvas[y0 : y0 + ov] = dp_horizontal_seam(sand_canvas[y0 : y0 + ov], row_strips[r][:ov])
        sand_canvas[y0 + ov : y0 + sh] = row_strips[r][ov:]
    sand_canvas = sand_canvas[:CANVAS_H, :CANVAS_W]

    # Stitch 1967-px tall S-curve cobblestone road across its exact 337-px period
    period = 337
    ov_r = 56
    cycle_patch = b3[50 : 50 + period + ov_r]
    n_cycles = 6
    road_strip = np.zeros((n_cycles * period + ov_r, b3.shape[1], 3), dtype=np.float32)
    road_strip[: period + ov_r] = cycle_patch
    for i in range(1, n_cycles):
        y_start = i * period
        road_strip[y_start : y_start + ov_r] = dp_horizontal_seam(
            road_strip[y_start : y_start + ov_r], cycle_patch[:ov_r]
        )
        road_strip[y_start + ov_r : y_start + period + ov_r] = cycle_patch[ov_r:]
    road_strip = road_strip[:CANVAS_H]

    x0 = (CANVAS_W - road_strip.shape[1]) // 2
    rw = road_strip.shape[1]
    margin = 16
    comp = sand_canvas.copy()
    comp[:, x0 + margin : x0 + rw - margin] = road_strip[:, margin : rw - margin]
    comp[:, x0 : x0 + margin] = dp_vertical_seam(sand_canvas[:, x0 : x0 + margin], road_strip[:, :margin])
    comp[:, x0 + rw - margin : x0 + rw] = dp_vertical_seam(
        road_strip[:, rw - margin : rw], sand_canvas[:, x0 + rw - margin : x0 + rw]
    )

    # 2. Extract the 6 modular cliffs and 12 props
    cliff_defs = {
        "cliff_left_large": ((10, 10, 330, 330), 0.94, -14, 10, 0.38),
        "cliff_corner_mid": ((360, 66, 663, 314), 0.92, -14, 10, 0.38),
        "cliff_right_large": ((693, 12, 1015, 338), 0.94, -28, 12, 0.44),
        "cliff_stair_ruin": ((12, 346, 312, 638), 0.92, -14, 10, 0.38),
        "cliff_outcrop_wide": ((325, 368, 727, 635), 0.88, -14, 10, 0.38),
        "cliff_buttress_right": ((754, 360, 1011, 651), 0.94, -28, 12, 0.44),
    }
    raw_cliffs = {}
    for cname, (box, sc, sdx, sdy, sa) in cliff_defs.items():
        cut = clean_magenta_cutout(im_c, box, scale=sc)
        raw_cliffs[cname] = cut
        padded, _, _ = add_baked_drop_shadow(cut, sdx, sdy, sa)
        q_cut = quantize_to_192(padded, pal_img)
        c_path = MOD_DIR / f"{cname}.png"
        q_cut.save(c_path)
        run_laigter_normal(c_path, MOD_DIR / f"{cname}_n.png")

    # Also bake the far-outer back-tier terracotta rim rock onto the outer 155px left & right edges of Approach 2's ground canvas
    # so the individual Y-sorted front-tier modular cliff nodes never have bare sand peeking out behind them at the screen borders!
    c_right_terra = clean_magenta_cutout(im_c, (815, 12, 1015, 338), 1.05)
    c_left_terra = raw_cliffs["cliff_left_large"]
    base_rgba = Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    for by in range(110, CANVAS_H + 180, 165):
        sh_l, _, _ = add_baked_drop_shadow(c_left_terra, -10, 8, 0.32)
        base_rgba.alpha_composite(sh_l, (45 - sh_l.width // 2, by - sh_l.height))
        sh_r, _, _ = add_baked_drop_shadow(c_right_terra, -18, 10, 0.35)
        base_rgba.alpha_composite(sh_r, (912 - sh_r.width // 2, by - sh_r.height))

    a2_base_q = quantize_to_192(base_rgba, pal_img)
    a2_base_path = OUT_DIR / "approach2_ground_road_canvas.png"
    a2_base_q.save(a2_base_path)
    run_laigter_normal(a2_base_path, OUT_DIR / "approach2_ground_road_canvas_n.png")

    prop_defs = {
        "bush_large_a": ((28, 38, 305, 258), 0.35, -10, 6, 0.38, None),
        "bush_large_b": ((338, 42, 592, 254), 0.35, -10, 6, 0.38, None),
        "ruined_archway": ((598, 22, 1004, 278), 0.56, -16, 8, 0.40, [(180, 140)]),
        "bush_med_a": ((44, 294, 222, 428), 0.38, -8, 5, 0.36, None),
        "bush_med_b": ((270, 292, 438, 424), 0.38, -8, 5, 0.36, None),
        "grass_tuft_large": ((494, 316, 653, 422), 0.35, -6, 4, 0.28, None),
        "grass_tuft_med": ((706, 272, 842, 422), 0.35, -6, 4, 0.28, None),
        "grass_tuft_small": ((844, 272, 992, 422), 0.35, -6, 4, 0.28, None),
        "boulder_large_a": ((24, 454, 288, 646), 0.36, -12, 7, 0.42, None),
        "boulder_large_b": ((330, 478, 584, 640), 0.36, -12, 7, 0.42, None),
        "boulder_med_a": ((624, 504, 790, 625), 0.38, -9, 5, 0.38, None),
        "boulder_med_b": ((836, 522, 998, 618), 0.38, -9, 5, 0.38, None),
    }
    for pname, (box, sc, sdx, sdy, sa, seeds) in prop_defs.items():
        cut = clean_magenta_cutout(im_p, box, scale=sc, extra_bg_seeds=seeds)
        padded, _, _ = add_baked_drop_shadow(cut, sdx, sdy, sa)
        q_cut = quantize_to_192(padded, pal_img)
        p_path = MOD_DIR / f"{pname}.png"
        q_cut.save(p_path)
        run_laigter_normal(p_path, MOD_DIR / f"{pname}_n.png")


def build_commander_sprites(pal_img: Image.Image) -> None:
    """Builds the 4x4 (104x120 cell, 416x480 sheet) Blue Commander sprite sheet from the genuine pixel_canyon sheet."""
    src_sheet = Image.open(ROOT / "assets" / "textures" / "pixel_canyon" / "blue_commander.png").convert("RGBA")
    src_back = Image.open(ROOT / "assets" / "textures" / "rpg_2d" / "session_b" / "commander_explore.png").convert("RGBA")

    cw, ch = 128, 144
    out_w, out_h = 104, 120  # 0.8125x scale -> ~102px tall character matching the 138px road width

    def get_cell(col: int, row: int) -> Image.Image:
        cell = src_sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
        arr = np.array(cell)
        # Repair the 4 missing cream-scarf tip pixels around x=20..30, y=54..66 if disconnected
        # by closing small 1-2px gaps in the scarf area
        scarf_zone = arr[48:72, 16:42]
        a_sz = scarf_zone[:, :, 3] > 80
        ap = np.pad(a_sz.astype(np.int32), 1)
        nb = ap[:-2, 1:-1] + ap[2:, 1:-1] + ap[1:-1, :-2] + ap[1:-1, 2:]
        fill_mask = (~a_sz) & (nb >= 3)
        scarf_zone[fill_mask] = np.array([238, 206, 122, 255], dtype=np.uint8)
        arr[48:72, 16:42] = scarf_zone
        return Image.fromarray(arr, "RGBA").resize((out_w, out_h), Image.Resampling.NEAREST)

    def get_back_cell(col: int, row: int) -> Image.Image:
        # Derive genuine high-craft North/Back view directly from pixel_canyon/blue_commander.png
        cell = src_sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)).transpose(
            Image.Transpose.FLIP_LEFT_RIGHT
        )
        arr = np.array(cell)
        # Cover only the interior face oval (center ~63, 27) using donor hair clusters from her own flowing hair
        donor_hair = arr[15:37, 71:91].copy()
        for y in range(15, 37):
            for x in range(53, 73):
                if arr[y, x, 3] > 128:
                    # Elliptical face mask so outer hair silhouette stays 100% organic
                    dx = (x - 63.0) / 9.5
                    dy = (y - 26.5) / 9.5
                    if dx * dx + dy * dy <= 1.05:
                        hy = y - 15
                        hx = (x - 53) % donor_hair.shape[1]
                        d_px = donor_hair[hy, hx]
                        if d_px[3] > 128 and d_px[0] < 175:
                            arr[y, x] = d_px
                        else:
                            arr[y, x] = np.array([96, 44, 24, 255], dtype=np.uint8)
        # Replace front chest highlights (y=44..60, x=53..77) with flat cobalt backplate + diagonal leather strap
        for y in range(44, 60):
            for x in range(53, 77):
                if arr[y, x, 3] > 128:
                    r_v, g_v, b_v = int(arr[y, x, 0]), int(arr[y, x, 1]), int(arr[y, x, 2])
                    # Only replace blue breastplate / central torso pixels (keep golden scarf & outer arm outline)
                    if b_v > r_v - 15 and y >= 45 and 55 <= x <= 74:
                        if abs((x - 55) - (y - 45) * 1.15) < 2.1:
                            arr[y, x] = np.array([108, 64, 34, 255], dtype=np.uint8)
                        else:
                            shade_b = 115 if x > 64 else 86
                            arr[y, x] = np.array([34, int(shade_b * 0.58), shade_b, 255], dtype=np.uint8)
        return Image.fromarray(arr, "RGBA").resize((out_w, out_h), Image.Resampling.NEAREST)

    sheet = Image.new("RGBA", (out_w * 4, out_h * 4), (0, 0, 0, 0))
    # Row 0: South / Forward walk
    south_frames = [get_cell(0, 3), get_cell(2, 1), get_cell(3, 3), get_cell(6, 1)]
    # Row 1: North / Back walk
    north_frames = [get_back_cell(0, 3), get_back_cell(2, 1), get_back_cell(3, 3), get_back_cell(6, 1)]
    # Row 2: East / West / Diagonal explore walk
    side_frames = [get_cell(0, 0), get_cell(1, 0), get_cell(3, 0), get_cell(2, 2)]
    # Row 3: Combat profile walk & aim
    combat_frames = [get_cell(3, 4), get_cell(1, 2), get_cell(3, 4), get_cell(4, 4)]

    for r_idx, row_list in enumerate([south_frames, north_frames, side_frames, combat_frames]):
        for c_idx, frame in enumerate(row_list):
            sheet.alpha_composite(frame, (c_idx * out_w, r_idx * out_h))

    q_sheet = quantize_to_192(sheet, pal_img)
    sh_path = SPR_DIR / "blue_commander_sheet.png"
    q_sheet.save(sh_path)
    run_laigter_normal(sh_path, SPR_DIR / "blue_commander_sheet_n.png")

    # Contact shadow oval (56x22)
    sh_im = Image.new("RGBA", (56, 22), (0, 0, 0, 0))
    yy, xx = np.mgrid[0:22, 0:56]
    d = np.sqrt(((xx - 28.0) / 25.0) ** 2 + ((yy - 11.0) / 9.0) ** 2)
    a = np.clip((1.0 - d) * 1.6, 0.0, 1.0) * 0.58
    sh_arr = np.zeros((22, 56, 4), dtype=np.uint8)
    sh_arr[:, :, 0] = 36
    sh_arr[:, :, 1] = 16
    sh_arr[:, :, 2] = 22
    sh_arr[:, :, 3] = (a * 255).astype(np.uint8)
    Image.fromarray(sh_arr, "RGBA").save(SPR_DIR / "contact_shadow.png")


def main() -> None:
    ensure_dirs()
    print("[1/4] Building 192-color master palette...")
    pal_img = build_master_192_palette()
    print("[2/4] Building Approach 1 (Uncut 2D Canyon Canvas + In-Place Walk-Behind Cutouts + Laigter Normals)...")
    build_approach1_assets(pal_img)
    print("[3/4] Building Approach 2 (Modular Stitched Ground/Road + 6 Cliffs + 12 Props + Laigter Normals)...")
    build_approach2_assets(pal_img)
    print("[4/4] Building 8-Directional Blue Commander Sheet + Laigter Normals...")
    build_commander_sprites(pal_img)
    print("Done! All Approach 1 & Approach 2 textures and normal maps generated.")


if __name__ == "__main__":
    main()
