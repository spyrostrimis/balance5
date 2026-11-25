"""Extract the two Forest Claim ImageGen sheets into reusable game textures."""
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_inputs/forest_claim"
OUTPUT = ROOT / "assets/textures/rts/forest_claim"
SPRITES = (
    ("rooted_tree", "leaning_tree", "twin_tree"),
    ("boulder", "rocks", "fern"),
    ("ginger", "shrub", "orichalcum"),
)


def wrap_edges(image: Image.Image, axes: tuple[int, ...]) -> Image.Image:
    """Blend opposing painted edges over a short span before repeating."""
    pixels = np.array(image, dtype=np.float32)
    for axis in axes:
        across = np.moveaxis(pixels, axis, 0)
        margin = 40
        for step in range(margin):
            weight = 0.5 * (1.0 - step / margin) ** 2
            first = across[step].copy()
            last = across[-step - 1].copy()
            across[step] = first * (1.0 - weight) + last * weight
            across[-step - 1] = last * (1.0 - weight) + first * weight
    return Image.fromarray(np.rint(pixels).astype(np.uint8))


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    scenery = Image.open(SOURCE / "scenery.png").convert("RGBA")
    for y, row in enumerate(SPRITES):
        for x, name in enumerate(row):
            piece = scenery.crop((x * 418, y * 418, (x + 1) * 418, (y + 1) * 418))
            alpha = piece.getchannel("A")
            piece = piece.crop(alpha.point(lambda v: 255 if v >= 20 else 0).getbbox())
            piece.save(OUTPUT / f"{name}.png", optimize=True)

    surfaces = Image.open(SOURCE / "surfaces.png").convert("RGB")
    for name, bounds, axes in (
        ("earth", (4, 4, 647, 599), (0, 1)),
        ("forest_floor", (656, 4, 1299, 599), (0, 1)),
        ("cliff_cool", (4, 604, 647, 1203), (1,)),
        ("cliff_warm", (656, 604, 1299, 1203), (1,)),
    ):
        texture = surfaces.crop(bounds).resize((512, 512), Image.Resampling.LANCZOS)
        wrap_edges(texture, axes).save(OUTPUT / f"{name}.webp", quality=92, method=6)


if __name__ == "__main__":
    main()
