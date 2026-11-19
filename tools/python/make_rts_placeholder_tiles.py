"""Draw the placeholder RTS tile strip: sand, road, rock, Orichalcum (32x32 px each).

    python tools/python/make_rts_placeholder_tiles.py

Writes assets/textures/rts/placeholder_tiles.png. Plain colours with a little noise so movement
reads; rock tiles get a lit top-left and dark bottom-right edge (light from the top-left).
These are stand-ins until the real Mission 1 tileset exists.
"""
from pathlib import Path
import random

from PIL import Image

TILE = 32
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "textures" / "rts" / "placeholder_tiles.png"

SAND = (214, 168, 98)
ROAD = (188, 164, 132)
ROCK = (92, 76, 64)
ORE_BASE = (78, 62, 52)
ORE = (246, 196, 72)


def jitter(color, amount, rng):
    d = rng.randint(-amount, amount)
    return tuple(max(0, min(255, c + d)) for c in color)


def main() -> None:
    rng = random.Random(7)
    img = Image.new("RGB", (TILE * 4, TILE), SAND)
    px = img.load()
    for i, base in enumerate([SAND, ROAD, ROCK, ORE_BASE]):
        ox = i * TILE
        for y in range(TILE):
            for x in range(TILE):
                px[ox + x, y] = jitter(base, 6, rng)
        if i == 0:  # a few darker sand specks
            for _ in range(10):
                px[ox + rng.randrange(TILE), rng.randrange(TILE)] = jitter((176, 132, 74), 8, rng)
        if i == 1:  # faint flagstone joints
            for y in range(TILE):
                for x in range(TILE):
                    if (x + 3 * (y // 8)) % 16 == 0 or y % 8 == 0:
                        px[ox + x, y] = jitter((160, 138, 108), 4, rng)
        if i in (2, 3):  # lit top-left edge, shaded bottom-right edge
            for k in range(TILE):
                for d in range(2):
                    px[ox + k, d] = jitter((128, 108, 92), 4, rng)
                    px[ox + d, k] = jitter((128, 108, 92), 4, rng)
                    px[ox + k, TILE - 1 - d] = jitter((58, 46, 40), 4, rng)
                    px[ox + TILE - 1 - d, k] = jitter((58, 46, 40), 4, rng)
        if i == 3:  # Orichalcum crystals
            for _ in range(7):
                cx, cy = rng.randrange(5, TILE - 5), rng.randrange(5, TILE - 5)
                for dy in range(-2, 3):
                    for dx in range(-1, 2):
                        if abs(dx) + abs(dy) <= 2:
                            px[ox + cx + dx, cy + dy] = jitter(ORE, 10, rng)
                px[ox + cx, cy - 2] = (255, 240, 180)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
