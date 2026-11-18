import cv2
import numpy as np

SRC_PATH = r"d:\Games\Balance5\assets\textures\maps\desert_approach_rpg_albedo.png"
OUT_PATH = r"d:\Games\Balance5\assets\textures\canyon_pbr\test_a_painted_ground_strip.png"


def main() -> None:
    img = cv2.imread(SRC_PATH, cv2.IMREAD_COLOR)
    if img is None:
        raise FileNotFoundError(f"Missing {SRC_PATH}")

    out_w, out_h = 1024, 2048
    # v in [0, 1]: v=0 is canyon exit (Z=-13.5), v=1 is foreground (Z=+11.5)
    v = np.linspace(0.0, 1.0, out_h, dtype=np.float32)
    z_world = -13.5 + v * 25.0
    cam_dz = 18.6 - z_world
    inv_z = (1.0 / cam_dz - 1.0 / 32.1) / (1.0 / 7.1 - 1.0 / 32.1)
    y_src = 285.0 + np.clip(inv_z, 0.0, 1.0) * (766.0 - 285.0)

    kp_y = np.array([285.0, 340.0, 430.0, 520.0, 620.0, 710.0, 766.0], dtype=np.float32)
    kp_cx = np.array([655.0, 642.0, 575.0, 588.0, 640.0, 678.0, 692.0], dtype=np.float32)
    kp_hw = np.array([175.0, 205.0, 255.0, 305.0, 350.0, 385.0, 410.0], dtype=np.float32)

    row_cx = np.interp(y_src, kp_y, kp_cx)
    row_hw = np.interp(y_src, kp_y, kp_hw)

    u = np.linspace(-1.0, 1.0, out_w, dtype=np.float32)[None, :]
    map_x = (row_cx[:, None] + u * row_hw[:, None]).astype(np.float32)
    map_y = np.broadcast_to(y_src[:, None], (out_h, out_w)).astype(np.float32)

    strip = cv2.remap(img, map_x, map_y, interpolation=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE)
    cv2.imwrite(OUT_PATH, strip)
    print(f"Saved {OUT_PATH} ({out_w}x{out_h})")


if __name__ == "__main__":
    main()
