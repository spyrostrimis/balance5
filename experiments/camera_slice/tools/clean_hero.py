#!/usr/bin/env python3
"""Remove greenscreen fringe and transparent green-bleed from the RPG hero sprite.

Reads res://assets/textures/units/blue_commander_rpg.png (without modifying it)
and writes experiments/camera_slice/assets/hero_clean.png.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def _distance_from_transparent(alpha: np.ndarray, max_dist: int = 8) -> np.ndarray:
    """4-neighbor Manhattan distance of opaque pixels from transparent (a == 0) pixels."""
    dist = np.full(alpha.shape, max_dist + 1, dtype=np.int32)
    dist[alpha == 0] = 0
    for d in range(1, max_dist + 1):
        prev = dist == (d - 1)
        p = np.pad(prev, 1, constant_values=False)
        nb = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
        dist[(dist > max_dist) & nb] = d
    return dist


def _bleed_rgb_into_transparent(rgb: np.ndarray, alpha: np.ndarray, iterations: int = 12) -> np.ndarray:
    """Replace neon-green RGB stored in a==0 pixels with dilated opaque border colors."""
    out = rgb.copy()
    valid = alpha > 0
    # First zero out all transparent pixels so nothing neon green can survive if unreachable.
    out[~valid] = 0.0
    for _ in range(iterations):
        if valid.all():
            break
        acc = np.zeros_like(out)
        cnt = np.zeros(alpha.shape, dtype=np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            v_shift = np.zeros_like(valid)
            c_shift = np.zeros_like(out)
            ys_src = slice(max(0, -dy), out.shape[0] - max(0, dy))
            ys_dst = slice(max(0, dy), out.shape[0] - max(0, -dy))
            xs_src = slice(max(0, -dx), out.shape[1] - max(0, dx))
            xs_dst = slice(max(0, dx), out.shape[1] - max(0, -dx))
            v_shift[ys_dst, xs_dst] = valid[ys_src, xs_src]
            c_shift[ys_dst, xs_dst] = out[ys_src, xs_src]
            m = v_shift & (~valid)
            acc[m] += c_shift[m]
            cnt[m] += 1.0
        fill = (~valid) & (cnt > 0)
        if not fill.any():
            break
        out[fill] = acc[fill] / cnt[fill, None]
        valid[fill] = True
    return out


def clean_hero(src_path: Path, dst_path: Path) -> None:
    im = Image.open(src_path).convert("RGBA")
    arr = np.array(im)
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]

    # Despill green excess on the outer 4-pixel silhouette rim (where greenscreen bleed lives),
    # leaving interior green eyes and cyan medic emblem (dist >= 5) untouched.
    dist = _distance_from_transparent(alpha, max_dist=6)
    rim = (dist >= 1) & (dist <= 4)
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]
    max_rb = np.maximum(r, b)
    rgb[:, :, 1] = np.where(rim & (g > max_rb), max_rb, g)

    # Replace transparent pixels' [12, 247, 5] neon green RGB with bled border RGB
    # so linear filtering and mipmaps never produce a green halo.
    rgb = _bleed_rgb_into_transparent(rgb, alpha, iterations=12)

    out = np.empty_like(arr)
    out[:, :, :3] = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
    out[:, :, 3] = alpha

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, mode="RGBA").save(dst_path)
    print(f"Wrote cleaned hero sprite: {dst_path} ({out.shape[1]}x{out.shape[0]})")


def main() -> None:
    slice_dir = Path(__file__).resolve().parent.parent
    repo_root = slice_dir.parent.parent
    parser = argparse.ArgumentParser(description="Despill greenscreen fringe from RPG hero sprite.")
    parser.add_argument(
        "--src",
        type=Path,
        default=repo_root / "assets/textures/units/blue_commander_rpg.png",
    )
    parser.add_argument(
        "--dst",
        type=Path,
        default=slice_dir / "assets/hero_clean.png",
    )
    args = parser.parse_args()
    clean_hero(args.src, args.dst)


if __name__ == "__main__":
    main()
