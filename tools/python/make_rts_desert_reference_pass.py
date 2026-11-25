"""Prepare the reusable Painted HD assets from the saved reference-pass originals."""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/source_inputs/rts/desert_reference_pass"
OUT = ROOT / "assets/textures/rts/desert_reference_pass"


def isolate(image: Image.Image, threshold: int = 20) -> Image.Image:
    """Keep each sprite's largest connected subject and its antialiased edge."""
    array = np.asarray(image.convert("RGBA")).copy()
    alpha = array[..., 3]
    _, labels, stats, _ = cv2.connectedComponentsWithStats((alpha >= threshold).astype(np.uint8))
    component = labels == (int(np.argmax(stats[1:, cv2.CC_STAT_AREA])) + 1)
    edge = cv2.dilate(component.astype(np.uint8), np.ones((9, 9), np.uint8))
    alpha *= edge
    alpha[alpha < 5] = 0
    sprite = Image.fromarray(array)
    return sprite.crop(sprite.getbbox())


def save_sprite(name: str, image: Image.Image, max_size: tuple[int, int]) -> None:
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    image.save(OUT / f"{name}.png", optimize=True)


def dune(image: Image.Image) -> Image.Image:
    array = np.asarray(isolate(image, 40)).astype(np.float32)
    alpha = array[..., 3] / 255.0
    # Taper the edges into the shared sand. The solid centre keeps its painted highlights.
    alpha = np.clip((alpha - 0.065) / 0.935, 0.0, 1.0)
    array[..., 3] = 255.0 * (alpha * alpha * (3.0 - 2.0 * alpha))
    array[..., :3] *= [1.015, 0.985, 0.94]
    return Image.fromarray(np.clip(array, 0, 255).astype(np.uint8))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cliff = isolate(Image.open(SRC / "terraces.png"))
    save_sprite("terraces", cliff, (1200, 800))

    dunes = Image.open(SRC / "dunes.png")
    half = dunes.height // 2
    save_sprite("ripple_field", dune(dunes.crop((0, 0, dunes.width, half))), (1000, 320))
    save_sprite("dune_swells", dune(dunes.crop((0, half, dunes.width, dunes.height))), (900, 300))

    landmarks = Image.open(SRC / "landmarks.png")
    # Use the transparent gutters on the authored sheet.
    spans = [(0, 850), (850, 1550), (1550, landmarks.width)]
    for (name, size), (left, right) in zip(
        [("orichalcum", (480, 400)), ("oasis", (380, 340)), ("verge_scrub", (270, 150))], spans
    ):
        cut = isolate(landmarks.crop((left, 0, right, landmarks.height)))
        save_sprite(name, cut, size)

    ground = Image.open(ROOT / "assets/textures/rts/desert_proof/sand_hd.png").convert("RGB")
    rgb = np.asarray(ground, np.float32)
    median = np.median(rgb.reshape(-1, 3), axis=0)
    rgb = (rgb - median) * [1.05, 1.10, 1.02] + [223, 151, 82]
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(OUT / "sand.png", optimize=True)


if __name__ == "__main__":
    main()
