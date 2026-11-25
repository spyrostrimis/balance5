"""Build cliff-foot shadows and rubble from the reusable cutouts and existing pebble sprites."""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/textures/rts/desert_reference_pass"
KIT = ROOT / "assets/textures/kitbash"
DENSITY = 3


def projected(mask, x: float, y: float, blur: float):
    transform = np.array([[1, 0, x * DENSITY], [0, 1, y * DENSITY]], dtype=np.float32)
    shifted = cv2.warpAffine(mask, transform, mask.shape[::-1], flags=cv2.INTER_LINEAR)
    return cv2.GaussianBlur(shifted, (0, 0), blur * DENSITY, borderType=cv2.BORDER_CONSTANT)


def build(name: str, source: Path, size: tuple[int, int], padding: tuple[int, int, int, int], seed: int) -> None:
    left, top, right, bottom = padding
    width, height = size
    sprite = Image.open(source).convert("RGBA").resize(
        (width * DENSITY, height * DENSITY), Image.Resampling.LANCZOS
    )
    alpha = np.asarray(sprite.getchannel("A"), dtype=np.float32) / 255.0
    mask = np.pad(alpha, ((top * DENSITY, bottom * DENSITY), (left * DENSITY, right * DENSITY)))
    # Contact starts at the cutout. Each further projection is softer and less opaque.
    opacity = np.maximum(
        projected(mask, 2, 3, 1.2) * 0.68,
        projected(mask, 6, 11, 2.8) * 0.44,
    )
    opacity = np.maximum(opacity, projected(mask, 12, 24, 5.5) * 0.28)
    rgba = np.empty((*mask.shape, 4), dtype=np.uint8)
    rgba[..., :3] = (66, 40, 35)
    rgba[..., 3] = np.rint(opacity * 255.0).astype(np.uint8)
    Image.fromarray(rgba).save(ART / f"{name}_shade.png", optimize=True)

    pebbles = []
    for index in range(5):
        pebble = Image.open(KIT / f"pebble_{index}.png").convert("RGBA")
        pebbles.append(pebble.crop(pebble.getbbox()))
    rubble = Image.new("RGBA", mask.shape[::-1])
    rng = np.random.default_rng(seed)
    for anchor in range(7, width - 3, 11):
        # Sit the denser chips at the foot, with a few smaller pieces further out.
        for stone_index in range(int(rng.integers(2, 5))):
            x = int(np.clip(anchor + rng.uniform(-6, 6), 0, width - 1))
            ys = np.flatnonzero(alpha[:, x * DENSITY] > 0.62)
            if not len(ys):
                continue
            distance = rng.uniform(0.4, 4.0) if stone_index == 0 else rng.uniform(2.0, 10.0)
            stone_width = rng.uniform(3.0, 6.5) if stone_index == 0 else rng.uniform(0.8, 3.1)
            stone = pebbles[int(rng.integers(len(pebbles)))].copy()
            stone.thumbnail((round(stone_width * DENSITY), round(stone_width * DENSITY)))
            center_x = round((left + x + distance * 0.24) * DENSITY)
            center_y = ys[-1] + round((top + distance) * DENSITY)
            rubble.alpha_composite(stone, (center_x - stone.width // 2, center_y - stone.height // 2))
    rubble.save(ART / f"{name}_scree.png", optimize=True)


if __name__ == "__main__":
    pad = (24, 12, 40, 42)
    build("terraces_foot", ART / "terraces.png", (364, 238), pad, seed=25)
    build("mesa_foot", ROOT / "assets/textures/rts/carbon/rock_mesa_hd.png", (140, 108),
          pad, seed=47)
