import os
import cv2
import numpy as np

ARTIFACT_JPG = r"C:\Users\PC\.gemini\antigravity\brain\25684232-7f72-4063-b959-1b79d32ac318\desert_canyon_ledges_diorama_v2_1794882244795.jpg"
RAW_PNG = r"d:\Games\Balance5\assets\textures\canyon_pbr\test_c2_ledges_raw.png"
OUT_DIR = r"d:\Games\Balance5\assets\textures\diorama_wings"


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
        base_edge = w * (0.88 - 0.08 * np.sin(yn * 2.8))
        dist_in = (base_edge + harmonic + lum_mod) - xx
        outer_fade = np.clip(xx / 18.0, 0.0, 1.0)
    else:
        base_edge = w * (0.12 + 0.08 * np.sin(yn * 2.8))
        dist_in = xx - (base_edge - harmonic - lum_mod)
        outer_fade = np.clip((w - 1 - xx) / 18.0, 0.0, 1.0)

    inner_alpha = np.clip(dist_in / 20.0, 0.0, 1.0)

    if side == "left":
        top_y = h * (0.06 + 0.18 * xn) + harmonic * 0.5 + lum_mod * 0.4
    else:
        top_y = h * (0.06 + 0.18 * (1.0 - xn)) + harmonic * 0.5 + lum_mod * 0.4
    top_alpha = np.clip((yy - top_y) / 22.0, 0.0, 1.0)

    bottom_fade = np.clip((h - 1 - yy) / 20.0, 0.0, 1.0)
    alpha = inner_alpha * top_alpha * bottom_fade * outer_fade
    alpha = cv2.GaussianBlur(alpha, (11, 11), sigmaX=1.9, sigmaY=1.9)
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
    if os.path.exists(ARTIFACT_JPG):
        img = cv2.imread(ARTIFACT_JPG, cv2.IMREAD_COLOR)
        if img is None:
            raise FileNotFoundError(f"Could not read {ARTIFACT_JPG}")
        cv2.imwrite(RAW_PNG, img)
        print(f"Copied C2 raw -> {RAW_PNG} ({img.shape[1]}x{img.shape[0]})")
    else:
        img = cv2.imread(RAW_PNG, cv2.IMREAD_COLOR)
        if img is None:
            raise FileNotFoundError(f"Missing {ARTIFACT_JPG} and {RAW_PNG}")

    h, w = img.shape[:2]
    save_ledge(img, 0, int(h * 0.42), int(w * 0.44), h, "c2_ledge_left_near.png", side="left")
    save_ledge(img, 0, 0, int(w * 0.44), int(h * 0.58), "c2_ledge_left_mid.png", side="left")
    save_ledge(img, int(w * 0.54), int(h * 0.42), w, h, "c2_ledge_right_near.png", side="right")
    save_ledge(img, int(w * 0.54), 0, w, int(h * 0.58), "c2_ledge_right_mid.png", side="right")


if __name__ == "__main__":
    main()
