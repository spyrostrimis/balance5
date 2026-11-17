import os
import cv2
import numpy as np

SRC_PATH = r"d:\Games\Balance5\assets\textures\maps\desert_approach_rpg_albedo.png"
WING_DIR = r"d:\Games\Balance5\assets\textures\diorama_wings"
BUSH_OUT = r"d:\Games\Balance5\assets\textures\canyon_pbr\hd2d_bush_cluster.png"
CRATER_SRC = r"d:\Games\Balance5\assets\textures\maps\desert_mission_1_clean_albedo.png"
CRATER_OUT = r"d:\Games\Balance5\assets\textures\canyon_pbr\orichalcum_crater.png"
VISTA_SRC = r"d:\Games\Balance5\assets\textures\canyon_pbr\canyon_exit_battlefield_vista.png"
VISTA_OUT = r"d:\Games\Balance5\assets\textures\canyon_pbr\canyon_vista_seamless.png"


def make_rock_wing_alpha(crop_bgr: np.ndarray, side: str, is_gate: bool = False, is_fg: bool = False) -> np.ndarray:
    """Builds a pure-rock stratified cliff alpha mask extending solidly to the bottom edge."""
    h, w = crop_bgr.shape[:2]
    b, g, r = cv2.split(crop_bgr.astype(np.float32))
    rn, gn, bn = r / 255.0, g / 255.0, b / 255.0
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    yn = yy / max(h - 1, 1)
    xn = xx / max(w - 1, 1)

    harmonic = (
        np.sin(yn * 13.0 + (0.4 if side == "left" else 2.1)) * 20.0
        + np.sin(yn * 31.0 + 1.3) * 10.0
        + np.cos(yn * 63.0 + 0.7) * 5.0
    )
    lum_mod = (0.52 - lum) * 42.0

    if side == "left":
        if is_fg:
            base_edge = w * (0.48 + 0.24 * np.clip((yn - 0.12) / 0.78, 0.0, 1.0))
        elif is_gate:
            step_clear = np.clip((yn - 0.40) / 0.35, 0.0, 1.0)
            base_edge = w * (0.72 - 0.22 * step_clear)
        else:
            bottom_pullback = 0.22 * np.clip((yn - 0.52) / 0.44, 0.0, 1.0)
            base_edge = w * (0.68 + 0.06 * np.sin(yn * 3.1) - bottom_pullback)
        edge_x = base_edge + harmonic + lum_mod
        dist_inside = edge_x - xx
        inner_zone = np.clip((xn - 0.42) / 0.15, 0.0, 1.0)
    else:
        if is_fg:
            base_edge = w * (0.52 - 0.24 * np.clip((yn - 0.12) / 0.78, 0.0, 1.0))
        elif is_gate:
            step_clear = np.clip((yn - 0.40) / 0.35, 0.0, 1.0)
            base_edge = w * (0.28 + 0.22 * step_clear)
        else:
            buttress = 0.07 * np.exp(-((yn - 0.48) ** 2) / 0.035)
            bottom_pullback = 0.22 * np.clip((yn - 0.52) / 0.44, 0.0, 1.0)
            base_edge = w * (0.32 - buttress + bottom_pullback)
        edge_x = base_edge - harmonic - lum_mod
        dist_inside = xx - edge_x
        inner_zone = np.clip((0.58 - xn) / 0.15, 0.0, 1.0)

    alpha = np.clip(dist_inside / 18.0, 0.0, 1.0)

    # Suppress bush green or bright flat sand near the inner edge so only jagged sandstone cliff silhouettes remain
    is_bush_or_sand = ((gn > rn * 0.86) & (lum > 0.25)) | ((lum > 0.65) & ((rn - bn) > 0.28))
    reject_inner = np.where(is_bush_or_sand, 1.0, 0.0).astype(np.float32) * inner_zone
    alpha *= (1.0 - reject_inner)

    # Remove upper-inner bright sky corner on gate & main wings
    if is_gate:
        sky_likeness = np.clip((lum - 0.72) / 0.16, 0.0, 1.0)
        gap_region = np.clip(1.0 - yn / 0.44, 0.0, 1.0)
        alpha *= (1.0 - sky_likeness * gap_region * inner_zone)
    elif not is_fg:
        sky_corner = np.clip((lum - 0.75) / 0.16, 0.0, 1.0) * np.clip(1.0 - yn / 0.30, 0.0, 1.0) * inner_zone
        alpha *= (1.0 - sky_corner)

    # Soft natural top feather on foreground outcrops
    if is_fg:
        organic_top = 18.0 + 16.0 * (np.sin(xn * 9.0 + 0.6) * 0.5 + 0.5) + lum_mod * 0.3
        alpha *= np.clip((yy - organic_top) / 26.0, 0.0, 1.0)
    elif is_gate:
        alpha *= np.clip(yy / 10.0, 0.0, 1.0)

    bottom_fade = np.clip((h - 1 - yy) / 24.0, 0.0, 1.0)
    outer_fade = np.clip(xx / 12.0, 0.0, 1.0) if side == "left" else np.clip((w - 1 - xx) / 12.0, 0.0, 1.0)
    alpha *= bottom_fade * outer_fade
    alpha_blur = cv2.GaussianBlur(alpha, (13, 13), sigmaX=2.2, sigmaY=2.2)
    return np.clip(alpha_blur * 255.0, 0.0, 255.0).astype(np.uint8)


def save_resized_rgba_crop(
    img_bgr: np.ndarray,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    out_w: int,
    out_h: int,
    out_path: str,
    side: str,
    is_gate: bool = False,
    is_fg: bool = False,
) -> None:
    sub = img_bgr[y0:y1, x0:x1]
    crop = cv2.resize(sub, (out_w, out_h), interpolation=cv2.INTER_LANCZOS4)
    alpha = make_rock_wing_alpha(crop, side=side, is_gate=is_gate, is_fg=is_fg)
    rgba = cv2.cvtColor(crop, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = alpha
    cv2.imwrite(out_path, rgba)
    print(f"Saved {out_path} ({out_w}x{out_h}), non-zero alpha px={(alpha > 20).sum()}")


def extract_bush_cluster(img_bgr: np.ndarray, out_path: str) -> None:
    x0, y0, x1, y1 = 385, 525, 615, 655
    crop = img_bgr[y0:y1, x0:x1]
    b, g, r = cv2.split(crop.astype(np.float32))

    warmth = r - g
    green_lift = g - b
    lum = (r + g + b) / 3.0

    sage_mask = ((warmth < 21.0) & (green_lift > 4.0) & (lum < 220.0) & (lum > 30.0)).astype(np.float32)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    near_sage = cv2.dilate(sage_mask, kernel, iterations=1)
    inner_fill = (((lum < 105.0) | ((lum < 215.0) & (warmth < 28.0))) & (near_sage > 0.5)).astype(np.float32)
    mask = np.clip(np.maximum(sage_mask, inner_fill), 0.0, 1.0)
    mask = cv2.morphologyEx((mask > 0.5).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)).astype(np.float32)

    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats((mask > 0.5).astype(np.uint8))
    clean = np.zeros_like(mask)
    for lbl in range(1, num_labels):
        if stats[lbl, cv2.CC_STAT_AREA] >= 120:
            clean[labels == lbl] = 1.0

    h, w = crop.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    border = (
        np.clip(xx / 6.0, 0.0, 1.0)
        * np.clip((w - 1 - xx) / 6.0, 0.0, 1.0)
        * np.clip(yy / 6.0, 0.0, 1.0)
        * np.clip((h - 1 - yy) / 8.0, 0.0, 1.0)
    )
    alpha = cv2.GaussianBlur(clean * border, (5, 5), sigmaX=1.1, sigmaY=1.1)
    alpha_u8 = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)

    rgba = cv2.cvtColor(crop, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = alpha_u8
    cv2.imwrite(out_path, rgba)
    print(f"Saved {out_path} ({w}x{h}), non-zero alpha px={(alpha_u8 > 25).sum()}")


def extract_crater(src_path: str, out_path: str) -> None:
    img = cv2.imread(src_path, cv2.IMREAD_COLOR)
    if img is None:
        raise FileNotFoundError(f"Missing crater source: {src_path}")
    h, w = img.shape[:2]
    x0, x1 = int(w * 0.39), int(w * 0.60)
    y0, y1 = int(h * 0.405), int(h * 0.605)
    crop = img[y0:y1, x0:x1]
    ch, cw = crop.shape[:2]

    yy, xx = np.mgrid[0:ch, 0:cw].astype(np.float32)
    nx = (xx - cw * 0.50) / (cw * 0.46)
    ny = (yy - ch * 0.50) / (ch * 0.44)
    rad = np.sqrt(nx * nx + ny * ny)
    theta = np.arctan2(ny, nx)
    wobble = 0.08 * np.sin(theta * 5.0 + 0.4) + 0.05 * np.cos(theta * 9.0)
    mask = np.clip((0.92 + wobble - rad) / 0.22, 0.0, 1.0)
    alpha = cv2.GaussianBlur(mask, (9, 9), sigmaX=2.2, sigmaY=2.2)

    rgba = cv2.cvtColor(crop, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    cv2.imwrite(out_path, rgba)
    print(f"Saved {out_path} ({cw}x{ch})")


def build_clean_vista(src_path: str, out_path: str) -> None:
    """Blends a golden atmospheric haze band across y=36%..52% to erase the baked horizon seam."""
    img = cv2.imread(src_path, cv2.IMREAD_COLOR)
    if img is None:
        raise FileNotFoundError(f"Missing vista source: {src_path}")
    h, w = img.shape[:2]
    out = img.astype(np.float32)

    y_vals = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    # Smooth mist weight peaking across the horizon line (42.5%) between 36% and 52%
    band_up = np.clip((y_vals - 0.36) / (0.425 - 0.36), 0.0, 1.0)
    band_dn = np.clip((0.52 - y_vals) / (0.52 - 0.425), 0.0, 1.0)
    raw_tri = np.where(y_vals <= 0.425, band_up, band_dn)
    mist_alpha = (raw_tri * raw_tri * (3.0 - 2.0 * raw_tri)) * 0.92  # cubic smoothstep bell

    # Gradient from pale golden desert mist at y=36% BGR(138,198,242) to warmer amber BGR(115,178,232) at y=52%
    t_grad = np.clip((y_vals - 0.36) / 0.16, 0.0, 1.0)
    top_col = np.array([138.0, 198.0, 242.0], dtype=np.float32)[None, None, :]
    bot_col = np.array([115.0, 178.0, 232.0], dtype=np.float32)[None, None, :]
    mist_col = top_col * (1.0 - t_grad[:, :, None]) + bot_col * t_grad[:, :, None]

    out = out * (1.0 - mist_alpha[:, :, None]) + mist_col * mist_alpha[:, :, None]
    cv2.imwrite(out_path, np.clip(out, 0.0, 255.0).astype(np.uint8))
    print(f"Saved clean vista {out_path} ({w}x{h})")


def main() -> None:
    os.makedirs(WING_DIR, exist_ok=True)
    img = cv2.imread(SRC_PATH, cv2.IMREAD_COLOR)
    if img is None:
        raise FileNotFoundError(f"Could not read source concept image: {SRC_PATH}")

    # Pure-rock cliff crops excluding lower floor bushes and sand
    save_resized_rgba_crop(img, 0, 0, 450, 510, 600, 768, os.path.join(WING_DIR, "wing_left_main.png"), side="left")
    save_resized_rgba_crop(img, 900, 0, 1376, 540, 600, 768, os.path.join(WING_DIR, "wing_right_main.png"), side="right")
    save_resized_rgba_crop(img, 0, 268, 340, 768, 420, 500, os.path.join(WING_DIR, "wing_fg_left.png"), side="left", is_fg=True)
    save_resized_rgba_crop(img, 1000, 218, 1376, 768, 420, 550, os.path.join(WING_DIR, "wing_fg_right.png"), side="right", is_fg=True)
    save_resized_rgba_crop(img, 0, 0, 470, 440, 600, 768, os.path.join(WING_DIR, "wing_gate_left.png"), side="left", is_gate=True)
    save_resized_rgba_crop(img, 890, 0, 1376, 460, 600, 768, os.path.join(WING_DIR, "wing_gate_right.png"), side="right", is_gate=True)

    extract_bush_cluster(img, BUSH_OUT)
    extract_crater(CRATER_SRC, CRATER_OUT)
    build_clean_vista(VISTA_SRC, VISTA_OUT)


if __name__ == "__main__":
    main()
