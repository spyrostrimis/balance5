import os
import cv2
import numpy as np

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


SRC_IMG = (
    os.path.join(PROJECT_ROOT, "assets/source_inputs", r"media_1794834895605_af15c30b.jpg")
)
OUT_IMG = os.path.join(PROJECT_ROOT, r"assets/textures/units/blue_tank.png")


def rounded_rect_mask(h: int, w: int, x0: int, y0: int, x1: int, y1: int, radius: float) -> np.ndarray:
    """Return a boolean mask for an inclusive pixel box [x0..x1, y0..y1] with rounded corners."""
    yy, xx = np.mgrid[0:h, 0:w]
    in_rect = (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
    cx0, cx1 = x0 + radius, x1 - radius
    cy0, cy1 = y0 + radius, y1 - radius
    dx = np.maximum(0.0, np.maximum(cx0 - xx, xx - cx1))
    dy = np.maximum(0.0, np.maximum(cy0 - yy, yy - cy1))
    return in_rect & ((dx * dx + dy * dy) <= (radius * radius + 0.25))


def main() -> None:
    orig = cv2.imread(SRC_IMG)
    if orig is None:
        raise FileNotFoundError(f"Could not read source image: {SRC_IMG}")

    # Center the hull pivot at (174, 224) inside a 59x39 sprite so rotation orbits the chassis/turret.
    cx, cy = 174, 224
    half_w, half_h = 29, 19
    x_start, y_start = cx - half_w, cy - half_h
    w, h = half_w * 2 + 1, half_h * 2 + 1

    crop = orig[y_start:y_start + h, x_start:x_start + w].copy()

    # Hull mask in crop coordinates (original x=157..191, y=211..238)
    hull = rounded_rect_mask(
        h, w,
        157 - x_start, 211 - y_start,
        191 - x_start, 238 - y_start,
        radius=3.0,
    )

    # Gun barrel pointing right (+X in Godot 2D space): original x=191..201, y=220..224
    yy, xx = np.mgrid[0:h, 0:w]
    barrel = (
        (xx >= (191 - x_start))
        & (xx <= (201 - x_start))
        & (yy >= (220 - y_start))
        & (yy <= (224 - y_start))
    )
    # Taper very tip pixel slightly
    barrel &= ~((xx == (201 - x_start)) & ((yy == (220 - y_start)) | (yy == (224 - y_start))))

    solid_mask = (hull | barrel).astype(np.float32)

    # Subtle 1px outer anti-aliased feather while keeping 100% of interior pixels opaque.
    eroded = cv2.erode(solid_mask, np.ones((3, 3), np.uint8), iterations=1)
    blurred = cv2.GaussianBlur(solid_mask, (3, 3), 0.75)
    alpha = np.where(eroded > 0.5, 1.0, np.clip(blurred * 1.15, 0.0, 1.0))
    alpha = np.where(solid_mask > 0.5, np.maximum(alpha, 0.78), alpha * 0.45)
    alpha[alpha < 0.08] = 0.0

    b, g, r = cv2.split(crop)
    rgba = np.stack([b, g, r, np.clip(alpha * 255.0, 0, 255).astype(np.uint8)], axis=-1)

    os.makedirs(os.path.dirname(OUT_IMG), exist_ok=True)
    cv2.imwrite(OUT_IMG, rgba)
    print(f"Saved clean blue tank sprite: {OUT_IMG} ({w}x{h})")


if __name__ == "__main__":
    main()
