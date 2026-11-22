"""Build all uniform-density (64 texels/m), <=32-color, seamless textures and sprites for 3D Kit Canyon v2.

Outputs (assets/textures/kit_v2/):
  cobble_albedo.png (+ _normal, _orm)           from kit_v2_cobble_img1.jpg (img1), 160x160 (2.50x2.50 m)
  sand_albedo.png (+ _normal)                   from art_gemini/hd2d_sand_albedo.png, min-cut wrapped seamless
  dune_albedo.png (+ _normal)                   from art_gemini/pure_dune_sand_albedo.png, min-cut wrapped seamless
  cliff_strata_albedo.png (+ _normal)           from d64/d_sandstone_strata_albedo.png (art_road_goal)
  cliff_ledge_albedo.png (+ _normal)            from cliffs/cliff_paving_goal.png (art_road_goal)
  cliff_rock_side_albedo.png (+ _normal)        128x128 (2.0x2.0 m) seamless banded terracotta from cliff_blocks_gpt
  cliff_rock_top_albedo.png (+ _normal)         128x128 (2.0x2.0 m) seamless warm cracked sandstone cap
  road_boulder_albedo.png (+ _normal, _orm)     from d64/chatgpt_sandstone (106x106, 1.65625x1.65625 m)
  curb_stone_albedo.png (+ _normal)             128x128 (2.0x2.0 m) seamless weathered sandstone curb stone
  bush_*_v2.png, grass_*_v2.png                 from kit_sprites/*_goal.png with 2-px RGB edge bleed
  blue_commander_v2.png                         40x82 px (0.625x1.28125 m at 64/m), <=30 colors, edge bleed
  orichalcum_crater_v2.png                      384x256 px (6.0x4.0 m at 64/m), pixel-art basalt + crystals, <=28 colors
  manifest.json                                 exact pixel dims, tile_m, color counts, seam ratios

Run:
  C:/Python312/python.exe tools/python/build_kit_v2_assets.py
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_road_tiles import min_cut_wrap  # noqa: E402
from pixel_snap import GOAL_PALETTE, IMPORT_STUB, normal_map, seam_ratio  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source_inputs"
TEX = ROOT / "assets" / "textures"
OUT = TEX / "kit_v2"
DENSITY = 64.0
MAX_COLORS = 32
MAX_SEAM = 1.25

SPRITE_IMPORT_STUB = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
detect_3d/compress_to=0
"""


def lum(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., :3].astype(float) @ np.array([0.299, 0.587, 0.114]) / 255.0


def count_colors(arr: np.ndarray) -> int:
    if arr.shape[2] == 4:
        opaque = arr[arr[:, :, 3] >= 128][:, :3]
    else:
        opaque = arr[:, :, :3].reshape(-1, 3)
    return int(len(np.unique(opaque.reshape(-1, 3), axis=0))) if len(opaque) else 0


def quantize_cap(rgb: np.ndarray, colors: int, use_goal_palette: bool = False) -> np.ndarray:
    assert colors <= MAX_COLORS
    img = Image.fromarray(rgb, "RGB")
    if use_goal_palette:
        # First quantize softly to own colors, map onto goal palette, then cap to <= colors.
        own = img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE)
        goal = Image.open(GOAL_PALETTE).convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT)
        mapped = own.convert("RGB").quantize(palette=goal, dither=Image.Dither.NONE).convert("RGB")
        if count_colors(np.asarray(mapped)) > colors:
            mapped = mapped.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE).convert("RGB")
        return np.asarray(mapped)
    q = img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE).convert("RGB")
    return np.asarray(q)


def edge_bleed_rgba(rgba: np.ndarray, radius: int = 2) -> np.ndarray:
    """Fill transparent pixels near opaque edges with nearest opaque RGB so linear AA never pulls black fringes."""
    out = rgba.copy()
    mask = (out[:, :, 3] >= 128)
    out[:, :, 3] = np.where(mask, 255, 0)
    rgb = out[:, :, :3].copy()
    valid = mask.copy()
    for _ in range(radius):
        # 4-neighbor average of valid pixels into invalid pixels
        acc = np.zeros_like(rgb, dtype=np.float32)
        cnt = np.zeros(valid.shape, dtype=np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            sr_y0, sr_y1 = max(0, -dy), rgb.shape[0] - max(0, dy)
            ds_y0, ds_y1 = max(0, dy), rgb.shape[0] - max(0, -dy)
            sr_x0, sr_x1 = max(0, -dx), rgb.shape[1] - max(0, dx)
            ds_x0, ds_x1 = max(0, dx), rgb.shape[1] - max(0, -dx)
            v = valid[sr_y0:sr_y1, sr_x0:sr_x1]
            acc[ds_y0:ds_y1, ds_x0:ds_x1][v] += rgb[sr_y0:sr_y1, sr_x0:sr_x1][v]
            cnt[ds_y0:ds_y1, ds_x0:ds_x1][v] += 1.0
        fill = (~valid) & (cnt > 0)
        rgb[fill] = np.round(acc[fill] / cnt[fill, None]).astype(np.uint8)
        valid[fill] = True
    out[:, :, :3] = rgb
    return out


def save_png(arr: np.ndarray, path: Path, sprite: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = "RGBA" if arr.shape[2] == 4 else "RGB"
    Image.fromarray(arr, mode).save(path)
    stub = path.with_name(path.name + ".import")
    stub.write_text(SPRITE_IMPORT_STUB if sprite else IMPORT_STUB, encoding="utf-8", newline="\n")


def min_cut_band(img: np.ndarray, axis: int, band_frac: float) -> np.ndarray:
    """Join end of `axis` to start along a closed (cyclic) minimum-difference seam inside `band_frac`."""
    a = np.moveaxis(img, axis, 1).astype(np.float32)  # shape (R, N, 3)
    R, n, _ = a.shape
    w = max(8, min(n // 2 - 2, int(round(n * band_frac))))
    tail, head = a[:, n - w:], a[:, :w]
    err = np.abs(tail - head).sum(axis=2)  # (R, w)

    # Enforce cyclic seam closure (|path[-1] - path[0]| <= 1) so cutting one axis never breaks the other.
    # Evaluate top candidate start columns c0 where boundary error is lowest.
    boundary_score = err[0] + err[-1]
    candidates = np.argsort(boundary_score)[:min(16, w)]
    best_total = float("inf")
    best_path = None
    for c0 in candidates:
        cost = np.full((R, w), np.inf, dtype=np.float32)
        cost[0, c0] = err[0, c0]
        for r in range(1, R):
            prev = cost[r - 1]
            best_prev = np.minimum(prev, np.minimum(np.r_[np.inf, prev[:-1]], np.r_[prev[1:], np.inf]))
            cost[r] = err[r] + best_prev
        lo_end, hi_end = max(0, int(c0) - 1), min(w, int(c0) + 2)
        c_end = lo_end + int(np.argmin(cost[-1, lo_end:hi_end]))
        total = float(cost[-1, c_end])
        if total < best_total:
            best_total = total
            path = np.zeros(R, int)
            path[-1] = c_end
            for r in range(R - 2, -1, -1):
                c = path[r + 1]
                lo, hi = max(0, c - 1), min(w, c + 2)
                path[r] = lo + int(np.argmin(cost[r, lo:hi]))
            best_path = path

    joined = head.copy()
    for r, c in enumerate(best_path):
        joined[r, :c] = tail[r, :c]
    out = np.concatenate([joined, a[:, w:n - w]], axis=1)
    return np.moveaxis(out, 1, axis).astype(np.uint8)


def wrap_if_needed(arr: np.ndarray, limit: float = MAX_SEAM) -> np.ndarray:
    out = arr.copy()
    for axis in (1, 0):
        if seam_ratio(out, axis) <= limit:
            continue
        best_arr = out
        best_r = seam_ratio(out, axis)
        for frac in (0.08, 0.14, 0.22, 0.30, 0.38):
            cand = min_cut_band(out, axis, frac)
            r = seam_ratio(cand, axis)
            if r < best_r:
                best_r, best_arr = r, cand
            if r <= 1.15:
                break
        out = best_arr
    return out


def extract_components(sheet: np.ndarray, min_area: int):
    bg = np.median(sheet[:30, :30].reshape(-1, 3), axis=0)
    mask = (np.abs(sheet.astype(int) - bg).sum(axis=2) > 60).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    return [tuple(stats[i][:4]) for i in range(1, n) if stats[i][4] > min_area]


def build_cobble() -> dict:
    src = np.asarray(Image.open(SRC / "kit_v2_cobble_img1.jpg").convert("RGB"))
    # Seamless cut on both axes at high resolution before downsampling
    cut = min_cut_band(min_cut_band(src, 1, 0.08), 0, 0.08)

    # Stone-vs-mortar heightmap at full resolution using luminance + morphological black-hat crevices
    gray = cv2.cvtColor(cut, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (21, 21))
    blackhat = cv2.morphologyEx((gray * 255).astype(np.uint8), cv2.MORPH_BLACKHAT, kernel).astype(np.float32) / 255.0
    # Combine bright stone tops and penalized mortar cracks
    raw_h = np.clip(gray * 0.80 + 0.25 - blackhat * 1.45, 0.0, 1.0)
    raw_h = (raw_h - raw_h.min()) / max(raw_h.max() - raw_h.min(), 1e-5)

    # Target: 160x160 px = 2.50 x 2.50 m at 64.0 texels/m (stone width ~0.28-0.45 m, realistic cobble masonry)
    px = 160
    small = np.asarray(Image.fromarray(cut).resize((px, px), Image.BOX))
    small = wrap_if_needed(small, 1.20)
    h_small = np.asarray(Image.fromarray((raw_h * 255).round().astype(np.uint8)).resize((small.shape[1], small.shape[0]), Image.BOX)).astype(float) / 255.0
    h_small = (h_small - h_small.min()) / max(h_small.max() - h_small.min(), 1e-5)

    albedo = quantize_cap(small, 28, use_goal_palette=False)
    # Check if quantization opened a seam; normally min_cut_wrap remains seamless
    sx, sy = seam_ratio(albedo, 1), seam_ratio(albedo, 0)
    nrm = normal_map(h_small, 2.3)

    # ORM: R = cavity AO, G = roughness (0.78 crowns .. 0.95 mortar), B = crisp crown rim
    ao = np.clip(0.42 + 0.58 * np.power(h_small, 0.85), 0.35, 1.0)
    rough = np.clip(0.95 - 0.18 * h_small, 0.75, 0.96)
    rim = np.clip((h_small - 0.55) / 0.45, 0.0, 1.0) * 0.55
    orm = (np.dstack([ao, rough, rim]) * 255.0).round().astype(np.uint8)

    save_png(albedo, OUT / "cobble_albedo.png")
    save_png(nrm, OUT / "cobble_normal.png")
    save_png(orm, OUT / "cobble_orm.png")
    return {"albedo": "cobble_albedo.png", "normal": "cobble_normal.png", "orm": "cobble_orm.png",
            "cells": [albedo.shape[1], albedo.shape[0]],
            "tile_m": [round(albedo.shape[1] / DENSITY, 6), round(albedo.shape[0] / DENSITY, 6)],
            "colors": count_colors(albedo), "seam_x": round(sx, 3), "seam_y": round(sy, 3)}


def build_art_gemini_sand() -> tuple[dict, dict]:
    results = []
    for name, src_name, nrm_strength in (
        ("sand", "hd2d_sand_albedo.png", 1.4),
        ("dune", "pure_dune_sand_albedo.png", 1.3),
    ):
        src = np.asarray(Image.open(TEX / "pixel_ab" / "art_gemini" / src_name).convert("RGB"))
        wrapped = wrap_if_needed(src, 1.20)
        # Keep original art_gemini palette (<= 24 colors) without re-quantizing or scaling
        cols = count_colors(wrapped)
        assert cols <= MAX_COLORS, f"{name} exceeded color cap: {cols}"
        sx, sy = seam_ratio(wrapped, 1), seam_ratio(wrapped, 0)
        nrm = normal_map(lum(wrapped), nrm_strength)
        save_png(wrapped, OUT / f"{name}_albedo.png")
        save_png(nrm, OUT / f"{name}_normal.png")
        results.append({
            "albedo": f"{name}_albedo.png", "normal": f"{name}_normal.png",
            "cells": [wrapped.shape[1], wrapped.shape[0]],
            "tile_m": [round(wrapped.shape[1] / DENSITY, 6), round(wrapped.shape[0] / DENSITY, 6)],
            "colors": cols, "seam_x": round(sx, 3), "seam_y": round(sy, 3),
        })
    return results[0], results[1]


def build_cliff_surfaces() -> dict:
    # Cliff strata: exact art_road_goal strata (d64/d_sandstone_strata_albedo.png)
    strata = np.asarray(Image.open(TEX / "pixel_ab" / "d64" / "d_sandstone_strata_albedo.png").convert("RGB"))
    strata = wrap_if_needed(strata, 1.25)
    strata_nrm = np.asarray(Image.open(TEX / "pixel_ab" / "d64" / "d_sandstone_strata_normal.png").convert("RGB"))
    if strata_nrm.shape[:2] != strata.shape[:2]:
        strata_nrm = normal_map(lum(strata), 2.0)

    # Organic weathered sandstone shelf surface (replaces concrete-like paving tiles):
    # Built from natural stone tops of cliff_blocks_gpt + subtle dusty weathered grain in art_road_goal palette
    sheet = np.asarray(Image.open(SRC / "cliff_blocks_gpt.webp").convert("RGB"))
    boxes = extract_components(sheet, 3000)
    centres = [y + h / 2 for _, y, _, h in boxes]
    split = (min(centres) + max(centres)) / 2
    tops = sorted((b for b, c in zip(boxes, centres) if c < split), key=lambda b: b[0])
    # Extract interior stone grain from top faces 0, 2, 4, 5 (warm cracked sandstone, rotated for variety)
    crops = []
    for idx, rot in ((0, 1), (2, 0), (4, 2), (5, 1)):
        bx, by, bw, bh = tops[idx]
        c = sheet[by + int(bh * 0.18):by + int(bh * 0.82), bx + int(bw * 0.18):bx + int(bw * 0.82)]
        if rot:
            c = np.rot90(c, rot)
        crops.append(np.asarray(Image.fromarray(c).resize((80, 80), Image.BOX)))
    mosaic = np.vstack([np.hstack([crops[0], crops[1]]), np.hstack([crops[2], crops[3]])])
    cut = min_cut_band(min_cut_band(mosaic, 1, 0.14), 0, 0.14)
    ledge_128 = np.asarray(Image.fromarray(cut).resize((128, 128), Image.BOX)).astype(np.float32)
    # Slightly weathered earthy sandstone shelf tone (subtle warm umber modulation so rocks pop on top)
    ledge_128 *= np.array([0.84, 0.78, 0.75], dtype=np.float32)
    ledge_128 = np.clip(ledge_128, 0, 255).astype(np.uint8)
    # Map onto cliff_paving_goal + cliff_blocks_goal weathered sandstone palette (14 colors)
    paving_pal_img = np.asarray(Image.open(TEX / "cliffs" / "cliff_paving_goal.png").convert("RGB"))
    blocks_pal_img = np.asarray(Image.open(TEX / "cliffs" / "cliff_blocks_goal.png").convert("RGB"))
    comb_pal = Image.fromarray(np.vstack([paving_pal_img[:64, :128], blocks_pal_img[:64, :128]]), "RGB").quantize(colors=16, method=Image.Quantize.MEDIANCUT)
    ledge_q = np.asarray(Image.fromarray(ledge_128).quantize(palette=comb_pal, dither=Image.Dither.NONE).convert("RGB"))
    ledge = wrap_if_needed(ledge_q, 1.20)
    ledge_nrm = normal_map(lum(ledge), 1.6)

    save_png(strata, OUT / "cliff_strata_albedo.png")
    save_png(strata_nrm, OUT / "cliff_strata_normal.png")
    save_png(ledge, OUT / "cliff_ledge_albedo.png")
    save_png(ledge_nrm, OUT / "cliff_ledge_normal.png")

    return {
        "cliff_strata": {
            "albedo": "cliff_strata_albedo.png", "normal": "cliff_strata_normal.png",
            "cells": [strata.shape[1], strata.shape[0]],
            "tile_m": [round(strata.shape[1] / DENSITY, 6), round(strata.shape[0] / DENSITY, 6)],
            "colors": count_colors(strata),
            "seam_x": round(seam_ratio(strata, 1), 3), "seam_y": round(seam_ratio(strata, 0), 3),
        },
        "cliff_ledge": {
            "albedo": "cliff_ledge_albedo.png", "normal": "cliff_ledge_normal.png",
            "cells": [ledge.shape[1], ledge.shape[0]],
            "tile_m": [round(ledge.shape[1] / DENSITY, 6), round(ledge.shape[0] / DENSITY, 6)],
            "colors": count_colors(ledge),
            "seam_x": round(seam_ratio(ledge, 1), 3), "seam_y": round(seam_ratio(ledge, 0), 3),
        },
    }


def build_cliff_rock_and_curb_tiles() -> dict:
    # 1. Cliff rock side & top from cliff_blocks_gpt.webp mapped onto GOAL_PALETTE (art_road_goal look)
    sheet = np.asarray(Image.open(SRC / "cliff_blocks_gpt.webp").convert("RGB"))
    boxes = extract_components(sheet, 3000)
    centres = [y + h / 2 for _, y, _, h in boxes]
    split = (min(centres) + max(centres)) / 2
    tops = sorted((b for b, c in zip(boxes, centres) if c < split), key=lambda b: b[0])
    fronts = sorted((b for b, c in zip(boxes, centres) if c >= split), key=lambda b: b[0])

    # Side tile: stack interior bands of wide front faces (indices 1, 3, 5) horizontally tiled -> min-cut wrap
    side_strips = []
    for idx in (3, 1, 5):
        bx, by, bw, bh = fronts[idx]
        # Skip the top lit cap rim (top 32%) and rounded outer sides (left/right 12%) + bottom shadow fringe (bottom 6%)
        crop = sheet[by + int(bh * 0.34):by + int(bh * 0.94), bx + int(bw * 0.12):bx + int(bw * 0.88)]
        crop_resized = np.asarray(Image.fromarray(crop).resize((160, 56), Image.BOX))
        side_strips.append(crop_resized)
    stacked = np.vstack(side_strips)  # 168 x 160
    side_cut = min_cut_band(min_cut_band(stacked, 1, 0.08), 0, 0.08)
    side_128 = np.asarray(Image.fromarray(side_cut).resize((128, 128), Image.BOX))
    blocks_goal_pal = Image.open(TEX / "cliffs" / "cliff_blocks_goal.png").convert("RGB").quantize(colors=16, method=Image.Quantize.MEDIANCUT)
    side_q = np.asarray(Image.fromarray(side_128).quantize(palette=blocks_goal_pal, dither=Image.Dither.NONE).convert("RGB"))
    side_q = wrap_if_needed(side_q, 1.20)

    # Top tile: clean central stone plates from the widest top views (1 and 3) without repeating 2x2 mirror blobs
    bx3, by3, bw3, bh3 = tops[3]
    top_crop_a = sheet[by3 + int(bh3 * 0.20):by3 + int(bh3 * 0.82), bx3 + int(bw3 * 0.18):bx3 + int(bw3 * 0.82)]
    bx1, by1, bw1, bh1 = tops[1]
    top_crop_b = sheet[by1 + int(bh1 * 0.20):by1 + int(bh1 * 0.82), bx1 + int(bw1 * 0.18):bx1 + int(bw1 * 0.82)]
    top_mosaic = np.vstack([
        np.asarray(Image.fromarray(top_crop_a).resize((160, 84), Image.BOX)),
        np.asarray(Image.fromarray(top_crop_b).resize((160, 84), Image.BOX)),
    ])
    top_cut = min_cut_band(min_cut_band(top_mosaic, 1, 0.16), 0, 0.16)
    top_128 = np.asarray(Image.fromarray(top_cut).resize((128, 128), Image.BOX))
    top_q = np.asarray(Image.fromarray(top_128).quantize(palette=blocks_goal_pal, dither=Image.Dither.NONE).convert("RGB"))
    top_q = wrap_if_needed(top_q, 1.20)

    # 2. Curb stone tile from curb_faces_gpt.webp top faces mapped onto curb_atlas_goal palette
    curb_sheet = np.asarray(Image.open(SRC / "curb_faces_gpt.webp").convert("RGB"))
    cboxes = extract_components(curb_sheet, 2000)
    ccentres = [y + h / 2 for _, y, _, h in cboxes]
    csplit = (min(ccentres) + max(ccentres)) / 2
    ctops = sorted((b for b, c in zip(cboxes, ccentres) if c < csplit), key=lambda b: b[0])
    # Take two 90-deg rotated + unrotated wide center crops so grain runs evenly without narrow vertical repeats
    curb_tiles = []
    for idx, rot in ((0, 0), (2, 1), (3, 0), (4, 3)):
        bx, by, bw, bh = ctops[idx]
        crop = curb_sheet[by + int(bh * 0.13):by + int(bh * 0.87), bx + int(bw * 0.15):bx + int(bw * 0.85)]
        if rot:
            crop = np.rot90(crop, rot)
        curb_tiles.append(np.asarray(Image.fromarray(crop).resize((80, 80), Image.BOX)))
    curb_mosaic = np.vstack([np.hstack([curb_tiles[0], curb_tiles[1]]), np.hstack([curb_tiles[2], curb_tiles[3]])])
    curb_cut = min_cut_band(min_cut_band(curb_mosaic, 1, 0.14), 0, 0.14)
    curb_128 = np.asarray(Image.fromarray(curb_cut).resize((128, 128), Image.BOX))
    curb_goal_pal = Image.open(TEX / "curbs" / "curb_atlas_goal.png").convert("RGB").quantize(colors=16, method=Image.Quantize.MEDIANCUT)
    curb_q = np.asarray(Image.fromarray(curb_128).quantize(palette=curb_goal_pal, dither=Image.Dither.NONE).convert("RGB"))
    curb_q = wrap_if_needed(curb_q, 1.20)

    out = {}
    for key, arr, strength in (
        ("cliff_rock_side", side_q, 2.0),
        ("cliff_rock_top", top_q, 1.8),
        ("curb_stone", curb_q, 1.8),
    ):
        nrm = normal_map(lum(arr), strength)
        save_png(arr, OUT / f"{key}_albedo.png")
        save_png(nrm, OUT / f"{key}_normal.png")
        out[key] = {
            "albedo": f"{key}_albedo.png", "normal": f"{key}_normal.png",
            "cells": [arr.shape[1], arr.shape[0]],
            "tile_m": [round(arr.shape[1] / DENSITY, 6), round(arr.shape[0] / DENSITY, 6)],
            "colors": count_colors(arr),
            "seam_x": round(seam_ratio(arr, 1), 3), "seam_y": round(seam_ratio(arr, 0), 3),
        }
    return out


def build_road_boulder() -> dict:
    alb = np.asarray(Image.open(TEX / "pixel_ab" / "d64" / "chatgpt_sandstone_albedo.png").convert("RGB"))
    nrm = np.asarray(Image.open(TEX / "pixel_ab" / "d64" / "chatgpt_sandstone_normal.png").convert("RGB"))
    orm = np.asarray(Image.open(TEX / "pixel_ab" / "d64" / "chatgpt_sandstone_orm.png").convert("RGB"))
    save_png(alb, OUT / "road_boulder_albedo.png")
    save_png(nrm, OUT / "road_boulder_normal.png")
    save_png(orm, OUT / "road_boulder_orm.png")
    return {
        "albedo": "road_boulder_albedo.png", "normal": "road_boulder_normal.png", "orm": "road_boulder_orm.png",
        "cells": [alb.shape[1], alb.shape[0]],
        "tile_m": [round(alb.shape[1] / DENSITY, 6), round(alb.shape[0] / DENSITY, 6)],
        "colors": count_colors(alb),
        "seam_x": round(seam_ratio(alb, 1), 3), "seam_y": round(seam_ratio(alb, 0), 3),
    }


def build_kit_sprites() -> dict:
    meta = json.loads((TEX / "kit_sprites" / "kit_sprites.json").read_text(encoding="utf-8"))
    out = {}
    for entry in meta["sprites"]:
        name = entry["name"]
        src = np.asarray(Image.open(TEX / "kit_sprites" / f"{name}_goal.png").convert("RGBA"))
        bled = edge_bleed_rgba(src, radius=2)
        cols = count_colors(bled)
        assert cols <= MAX_COLORS, f"{name} exceeded color cap: {cols}"
        save_png(bled, OUT / f"{name}_v2.png", sprite=True)
        out[name] = {
            "albedo": f"{name}_v2.png",
            "kind": entry["kind"],
            "cells": [bled.shape[1], bled.shape[0]],
            "metres": [round(bled.shape[1] / DENSITY, 6), round(bled.shape[0] / DENSITY, 6)],
            "colors": cols,
        }
    return out


def build_commander() -> dict:
    # Source: 555x1126 -> native grid ~148x300. Target: 40x82 px (0.625 x 1.28125 m at 64 texels/m).
    src = Image.open(TEX / "units" / "blue_commander_rpg.png").convert("RGBA")
    arr = np.asarray(src)
    # Trim transparent border first so boots touch bottom pixel row and head touches top row cleanly
    ys, xs = np.nonzero(arr[:, :, 3] >= 128)
    cropped = Image.fromarray(arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")
    w, h = 40, 82
    resized = np.asarray(cropped.resize((w, h), Image.BOX))

    # Crisp 1-bit alpha silhouette (protect slightly thin rifle barrel & boots)
    alpha = resized[:, :, 3] >= 112
    rgb = resized[:, :, :3].copy()

    # Preserve/boost cyan med-cross pixel on gauntlet (approx x=75-85%, y=38-46% of body) if softened by BOX
    # Quantize opaque pixels to 28 colors cleanly
    opaque_idx = np.where(alpha)
    opaque_rgb = rgb[opaque_idx]
    # Build tiny image of opaque pixels to run clean median-cut without transparent black skewing palette
    strip = Image.fromarray(opaque_rgb[None, :, :], "RGB")
    pal = strip.quantize(colors=28, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE)
    q_opaque = np.asarray(strip.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB"))[0]
    rgb[opaque_idx] = q_opaque

    # Check if bright cyan med-cross accent is visible in opaque pixels; if muted, restore brightest cyan pixel
    cyan_mask = (resized[:, :, 2].astype(int) - resized[:, :, 0].astype(int) > 45) & (resized[:, :, 1] > 140) & alpha
    if cyan_mask.any():
        rgb[cyan_mask] = np.array([72, 232, 224], dtype=np.uint8)

    out_rgba = np.dstack([rgb, np.where(alpha, 255, 0).astype(np.uint8)])
    bled = edge_bleed_rgba(out_rgba, radius=2)
    cols = count_colors(bled)
    assert cols <= MAX_COLORS, f"commander exceeded color cap: {cols}"
    save_png(bled, OUT / "blue_commander_v2.png", sprite=True)
    return {
        "albedo": "blue_commander_v2.png",
        "cells": [w, h],
        "metres": [round(w / DENSITY, 6), round(h / DENSITY, 6)],
        "pixel_size": 1.0 / DENSITY,
        "colors": cols,
    }


def build_orichalcum_crater() -> dict:
    # Crisp 384x256 px (6.00 x 4.00 m at 64 texels/m) pixel-art basalt crater + glowing golden Orichalcum crystals.
    w, h = 384, 256
    src = Image.open(TEX / "canyon_pbr" / "orichalcum_crater.png").convert("RGBA")
    src_resized = np.asarray(src.resize((w, h), Image.BICUBIC))
    alpha_mask = src_resized[:, :, 3] >= 120

    # Extract dark basalt plate palette from d64/d_basalt_cap_albedo.png (~11 colors) + crisp golden crystal palette (7 colors)
    basalt = np.asarray(Image.open(TEX / "pixel_ab" / "d64" / "d_basalt_cap_albedo.png").convert("RGB"))
    # Tile basalt seamlessly at exact 64 texels/m (61x61 -> natural 1:1 basalt pixel texture!)
    bh, bw = basalt.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    rock_base = basalt[yy % bh, xx % bw].astype(np.float32)

    # Procedural cracked plate seams & concentric crater rim depression
    rng = np.random.default_rng(42)
    cx, cy = w * 0.50, h * 0.52
    nx = (xx - cx) / (w * 0.42)
    ny = (yy - cy) / (h * 0.42)
    r = np.hypot(nx, ny)
    # Voronoi cell cracks over integer pixel grid (~18-24 px plates)
    sites_x = rng.uniform(18, w - 18, 52)
    sites_y = rng.uniform(18, h - 18, 52)
    d2 = (xx[:, :, None] - sites_x[None, None, :]) ** 2 + (yy[:, :, None] - sites_y[None, None, :]) ** 2
    d_sorted = np.sort(np.sqrt(d2), axis=2)
    crack = (d_sorted[:, :, 1] - d_sorted[:, :, 0]) < 2.2

    # Darken center basin & cracks cleanly
    basin_shade = np.clip(0.55 + 0.45 * np.clip((r - 0.15) / 0.85, 0.0, 1.0), 0.55, 1.0)
    rock = rock_base * basin_shade[:, :, None]
    rock[crack] = np.array([28.0, 17.0, 14.0])

    # Identify crystal spots from source image (bright warm orange/gold pixels), clean specks into chunky pixel clusters
    sr, sg, sb = src_resized[:, :, 0].astype(float), src_resized[:, :, 1].astype(float), src_resized[:, :, 2].astype(float)
    crystal_score = (sr - sb) * 0.65 + sg * 0.35
    crystals_raw = (alpha_mask & (crystal_score > 125) & (sr > 170)).astype(np.uint8)
    crystals_clean = cv2.morphologyEx(crystals_raw, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    crystals_clean = cv2.morphologyEx(crystals_clean, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    crystals = crystals_clean > 0

    # Quantize rock part to 16 basalt/umber colors, and draw crisp faceted 8-color golden Orichalcum crystals on top
    rock_q = quantize_cap(np.clip(rock, 0, 255).astype(np.uint8), 16, use_goal_palette=False)

    crystal_palette = np.array([
        [92, 42, 8],     # dark amber rim
        [156, 84, 14],   # deep gold shadow
        [214, 134, 24],  # rich amber midtone
        [248, 186, 46],  # warm gold facet
        [255, 226, 98],  # bright glint
        [255, 248, 178], # specular tip
    ], dtype=np.uint8)

    out_rgb = rock_q.copy()
    # Outline crystals with 1px dark rim where crystal touches non-crystal
    dilated = cv2.dilate(crystals.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    rim_px = dilated & (~crystals) & alpha_mask
    out_rgb[rim_px] = crystal_palette[0]

    # Shade each crystal pixel by normalized source brightness + local top-left facet light
    bright = np.clip((sr + sg * 0.7) / 400.0, 0.0, 1.0)
    # Top-left facet highlight
    gx = np.gradient(crystals.astype(float), axis=1)
    gy = np.gradient(crystals.astype(float), axis=0)
    facet = np.clip(bright + (-gx - gy) * 0.35 + (0.35 - r) * 0.35, 0.0, 1.0)
    idx = np.clip((facet * 4.99).astype(int) + 1, 1, 5)
    out_rgb[crystals] = crystal_palette[idx[crystals]]

    # Subtle 1px dark rocky border around outer crater silhouette
    eroded = cv2.erode(alpha_mask.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    outer_border = alpha_mask & (~eroded)
    out_rgb[outer_border] = np.array([32, 20, 16], dtype=np.uint8)

    # Ensure total palette <= 28 colors
    final_rgb = quantize_cap(out_rgb, 26, use_goal_palette=False)
    out_rgba = np.dstack([final_rgb, np.where(alpha_mask, 255, 0).astype(np.uint8)])
    bled = edge_bleed_rgba(out_rgba, radius=2)
    cols = count_colors(bled)
    assert cols <= MAX_COLORS, f"crater exceeded color cap: {cols}"
    save_png(bled, OUT / "orichalcum_crater_v2.png", sprite=True)
    return {
        "albedo": "orichalcum_crater_v2.png",
        "cells": [w, h],
        "metres": [round(w / DENSITY, 6), round(h / DENSITY, 6)],
        "colors": cols,
    }


def write_preview(manifest: dict) -> None:
    # Build a 2x2 tiled diagnostic sheet for tiling surfaces + commander & crater crops
    tiles = []
    for key in ("cobble", "sand", "dune", "cliff_strata", "cliff_ledge", "cliff_rock_side", "cliff_rock_top", "curb_stone", "road_boulder"):
        info = manifest[key]
        arr = np.asarray(Image.open(OUT / info["albedo"]).convert("RGB"))
        tiled = np.tile(arr, (2, 2, 1))
        thumb = np.asarray(Image.fromarray(tiled).resize((256, 256), Image.NEAREST)).copy()
        cv2.putText(thumb, f"{key} ({info['colors']}c, {info['seam_x']}/{info['seam_y']})", (6, 20),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 0), 3, cv2.LINE_AA)
        cv2.putText(thumb, f"{key} ({info['colors']}c, {info['seam_x']}/{info['seam_y']})", (6, 20),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_AA)
        tiles.append(thumb)

    # Panel 10: Commander zoomed 3x + bushes + crater
    cmd = np.asarray(Image.open(OUT / "blue_commander_v2.png").convert("RGBA"))
    cmd_vis = np.where(cmd[:, :, 3:4] > 0, cmd[:, :, :3], np.array([75, 45, 75], dtype=np.uint8))
    cmd_big = np.asarray(Image.fromarray(cmd_vis).resize((cmd.shape[1] * 3, cmd.shape[0] * 3), Image.NEAREST))
    panel_sprites = np.full((256, 256, 3), (75, 45, 75), dtype=np.uint8)
    panel_sprites[4:4 + cmd_big.shape[0], 8:8 + cmd_big.shape[1]] = cmd_big
    bush = np.asarray(Image.open(OUT / "bush_large_a_v2.png").convert("RGBA"))
    bush_vis = np.where(bush[:, :, 3:4] > 0, bush[:, :, :3], np.array([75, 45, 75], dtype=np.uint8))
    bush_big = np.asarray(Image.fromarray(bush_vis).resize((bush.shape[1] * 2, bush.shape[0] * 2), Image.NEAREST))
    panel_sprites[12:12 + bush_big.shape[0], 122:122 + bush_big.shape[1]] = bush_big
    cv2.putText(panel_sprites, f"cmd ({manifest['blue_commander']['colors']}c) + bush", (6, 248),
                cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_AA)
    tiles.append(panel_sprites)

    crater = np.asarray(Image.open(OUT / "orichalcum_crater_v2.png").convert("RGBA"))
    crater_vis = np.where(crater[:, :, 3:4] > 0, crater[:, :, :3], np.array([196, 138, 72], dtype=np.uint8))
    crater_thumb = np.asarray(Image.fromarray(crater_vis).resize((256, 256), Image.NEAREST)).copy()
    cv2.putText(crater_thumb, f"crater ({manifest['orichalcum_crater']['colors']}c)", (6, 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 2, cv2.LINE_AA)
    cv2.putText(crater_thumb, f"crater ({manifest['orichalcum_crater']['colors']}c)", (6, 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.45, (10, 10, 10), 1, cv2.LINE_AA)
    tiles.append(crater_thumb)

    # Pad to 12 tiles (4x3 grid)
    tiles.append(np.full((256, 256, 3), 36, dtype=np.uint8))
    rows = [np.hstack(tiles[i:i + 4]) for i in range(0, 12, 4)]
    sheet = np.vstack(rows)
    preview = ROOT / "tmp" / "kit_v2_textures_preview.png"
    preview.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet, "RGB").save(preview)
    print(f"Preview saved: {preview}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"density": DENSITY, "updated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")}
    manifest["cobble"] = build_cobble()
    manifest["sand"], manifest["dune"] = build_art_gemini_sand()
    manifest.update(build_cliff_surfaces())
    manifest.update(build_cliff_rock_and_curb_tiles())
    manifest["road_boulder"] = build_road_boulder()
    manifest["sprites"] = build_kit_sprites()
    manifest["blue_commander"] = build_commander()
    manifest["orichalcum_crater"] = build_orichalcum_crater()

    # Strict audit of every generated asset
    tiling_keys = ("cobble", "sand", "dune", "cliff_strata", "cliff_ledge", "cliff_rock_side", "cliff_rock_top", "curb_stone", "road_boulder")
    for k in tiling_keys:
        info = manifest[k]
        assert info["colors"] <= MAX_COLORS, f"{k} colors {info['colors']} > {MAX_COLORS}"
        assert info["seam_x"] <= MAX_SEAM and info["seam_y"] <= MAX_SEAM, f"{k} seam {info['seam_x']}, {info['seam_y']} > {MAX_SEAM}"
        print(f"  {k:18s}: {info['cells'][0]:3d}x{info['cells'][1]:<3d} px ({info['tile_m'][0]:.4f}x{info['tile_m'][1]:.4f} m) "
              f"colors={info['colors']:2d} seam=({info['seam_x']:.2f}, {info['seam_y']:.2f})")

    for sname, sinfo in manifest["sprites"].items():
        assert sinfo["colors"] <= MAX_COLORS
        print(f"  sprite {sname:13s}: {sinfo['cells'][0]:3d}x{sinfo['cells'][1]:<3d} px ({sinfo['metres'][0]:.4f}x{sinfo['metres'][1]:.4f} m) colors={sinfo['colors']:2d}")

    for k in ("blue_commander", "orichalcum_crater"):
        info = manifest[k]
        assert info["colors"] <= MAX_COLORS
        print(f"  {k:18s}: {info['cells'][0]:3d}x{info['cells'][1]:<3d} px ({info['metres'][0]:.4f}x{info['metres'][1]:.4f} m) colors={info['colors']:2d}")

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    write_preview(manifest)
    print("PASS: All kit_v2 textures generated and verified <= 32 colors, 64 texels/m, seamless tiling.")


if __name__ == "__main__":
    main()
