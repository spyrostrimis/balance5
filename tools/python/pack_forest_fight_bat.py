"""Pack the four painted bat poses around their shared chest point."""

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_inputs/rpg_2d/forest_fight/bat-poses.png"
OUTPUT = ROOT / "assets/textures/rpg_2d/forest_fight/bat.png"
CHESTS = [(353, 394), (895, 392), (1498, 394), (2011, 393)]
CELL = (850, 704)


def pack(source: Path, output: Path) -> None:
    image = np.asarray(Image.open(source).convert("RGBA"))
    alpha = image[:, :, 3]
    _, labels = cv2.connectedComponents((alpha > 75).astype(np.uint8))
    width, height = CELL
    atlas = Image.new("RGBA", (width * len(CHESTS) // 2, height // 2))
    kernel = np.ones((5, 5), dtype=np.uint8)
    for frame, (cx, cy) in enumerate(CHESTS):
        label = labels[cy, cx]
        if label == 0:
            raise ValueError(f"Chest {frame} must be within the painted pose")
        edge = cv2.dilate((labels == label).astype(np.uint8), kernel)
        cutout = image.copy()
        cutout[:, :, 3] *= edge
        cell = Image.fromarray(cutout).crop(
            (cx - width // 2, cy - height // 2, cx + width // 2, cy + height // 2)
        )
        atlas.paste(cell.resize((width // 2, height // 2), Image.Resampling.LANCZOS),
                    (frame * width // 2, 0))
    atlas.save(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    pack(args.source, args.output)
