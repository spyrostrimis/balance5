import os
import cv2
import numpy as np

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

SRC_PATH = os.path.join(PROJECT_ROOT, r"assets\textures\maps\desert_approach_rpg_albedo.png")
OUT_DIR = os.path.join(PROJECT_ROOT, r"assets\textures\diorama_wings")


def make_ledge_alpha(crop_bgr: np.ndarray, side: str) -> np.ndarray:
    h, w = crop_bgr.shape[:2]
    b, g, r = cv2.split(crop_bgr.astype(np.float32))
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    yn = yy / max(h - 1, 1)
    xn = xx / max(w - 1, 1)

    harmonic = (
        np.sin(yn * 11.0 + (0.5 if side == "left" else 1.8)) * 18.0
        + np.sin(yn * 27.0 + 0.9) * 9.0
    )
    lum_mod = (0.55 - lum) * 36.0

    if side == "left":
        base_edge = w * (0.86 - 0.10 * np.sin(yn * 2.8))
        dist_in = (base_edge + harmonic + lum_mod) - xx
        outer_fade = np.clip(xx / 18.0, 0.0, 1.0)
    else:
        base_edge = w * (0.14 + 0.10 * np.sin(yn * 2.8))
        dist_in = xx - (base_edge - harmonic - lum_mod)
        outer_fade = np.clip((w - 1 - xx) / 18.0, 0.0, 1.0)

    inner_alpha = np.clip(dist_in / 20.0, 0.0, 1.0)

    if side == "left":
        top_y = h * (0.06 + 0.18 * xn) + harmonic * 0.5 + lum_mod * 0.4
    else:
        top_y = h * (0.06 + 0.18 * (1.0 - xn)) + harmonic * 0.5 + lum_mod * 0.4
    top_alpha = np.clip((yy - top_y) / 22.0, 0.0, 1.0)

    bottom_fade = np.clip((h - 1 - yy) / 22.0, 0.0, 1.0)
    alpha = inner_alpha * top_alpha * bottom_fade * outer_fade
    alpha = cv2.GaussianBlur(alpha, (13, 13), sigmaX=2.2, sigmaY=2.2)
    return np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)


def save_ledge(img: np.ndarray, x0: int, y0: int, x1: int, y1: int, out_name: str, side: str) -> None:
    sub = img[y0:y1, x0:x1]
    crop = cv2.resize(sub, (480, 380), interpolation=cv2.INTER_LANCZOS4)
    alpha = make_ledge_alpha(crop, side=side)
    rgba = cv2.cvtColor(crop, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = alpha
    out_path = os.path.join(OUT_DIR, out_name)
    cv2.imwrite(out_path, rgba)
    print(f"Saved {out_path} (480x380), opaque_px={(alpha > 20).sum()}")


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    img = cv2.imread(SRC_PATH, cv2.IMREAD_COLOR)
    if img is None:
        raise FileNotFoundError(f"Missing {SRC_PATH}")

    save_ledge(img, 110, 350, 590, 730, "ledge_left_near.png", side="left")
    save_ledge(img, 220, 230, 640, 550, "ledge_left_mid.png", side="left")
    save_ledge(img, 760, 340, 1240, 720, "ledge_right_near.png", side="right")
    save_ledge(img, 750, 230, 1170, 550, "ledge_right_mid.png", side="right")


if __name__ == "__main__":
    main()
