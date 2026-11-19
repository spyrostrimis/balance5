import os
import cv2
import numpy as np

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

ARTIFACT_JPG = os.path.join(PROJECT_ROOT, "assets/source_inputs", r"test_b_hd2d_ground_raw_1794880450271.jpg")
RAW_PNG = os.path.join(PROJECT_ROOT, r"assets\textures\canyon_pbr\test_b_hd2d_ground_raw.png")
OUT_STRIP = os.path.join(PROJECT_ROOT, r"assets\textures\canyon_pbr\test_b_hd2d_ground_strip.png")


def main() -> None:
    if os.path.exists(ARTIFACT_JPG):
        raw = cv2.imread(ARTIFACT_JPG, cv2.IMREAD_COLOR)
        if raw is None:
            raise FileNotFoundError(f"Could not read {ARTIFACT_JPG}")
        cv2.imwrite(RAW_PNG, raw)
        print(f"Copied generated texture -> {RAW_PNG} ({raw.shape[1]}x{raw.shape[0]})")
    else:
        raw = cv2.imread(RAW_PNG, cv2.IMREAD_COLOR)
        if raw is None:
            raise FileNotFoundError(f"Missing both {ARTIFACT_JPG} and {RAW_PNG}")

    # Normalize to 1024px wide and prepare 160px cosine cross-fade wrap along vertical axis (1184 - 160 = 1024)
    overlap = 160
    out_w, out_h = 1024, 1024
    resized = cv2.resize(raw, (out_w, out_h + overlap), interpolation=cv2.INTER_LANCZOS4).astype(np.float32)

    top_strip = resized[:overlap]
    core = resized[overlap:out_h]
    bot_strip = resized[out_h:]

    w = (0.5 - 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, overlap, dtype=np.float32)))[:, None, None]
    seam_strip = bot_strip * (1.0 - w) + top_strip * w

    seamless = np.vstack([seam_strip, core])
    seamless_u8 = np.clip(seamless, 0.0, 255.0).astype(np.uint8)
    cv2.imwrite(OUT_STRIP, seamless_u8)
    print(f"Saved seamless strip {OUT_STRIP} ({seamless_u8.shape[1]}x{seamless_u8.shape[0]})")


if __name__ == "__main__":
    main()
