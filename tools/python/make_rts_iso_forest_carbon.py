"""Build normalized modular isometric kit textures and 8-direction unit sheets
for 'RTS Isometric 2— Forest Claim Carbon' from ChatGPT source sheets."""

from __future__ import annotations

import json
from math import cos, pi, sin
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/source_inputs/rts_forest_carbon"
OUT = ROOT / "assets/textures/rts/forest_carbon"
PREVIEW_DIR = ROOT / "render_captures/rts_iso_forest_carbon"


def smoothstep(low: float, high: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - low) / max(high - low, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def load_rgba(name: str) -> np.ndarray:
    with Image.open(SRC / name) as im:
        return np.array(im.convert("RGBA"), dtype=np.float32)


def save_rgba(name: str, arr: np.ndarray) -> tuple[int, int]:
    OUT.mkdir(parents=True, exist_ok=True)
    u8 = np.clip(np.rint(arr), 0, 255).astype(np.uint8)
    Image.fromarray(u8, mode="RGBA").save(OUT / f"{name}.png", optimize=True)
    return u8.shape[1], u8.shape[0]


def clean_alpha(arr: np.ndarray, low: float = 18.0, high: float = 224.0, unpremult_white: bool = True) -> np.ndarray:
    out = arr.copy()
    raw_a = out[:, :, 3]
    a = smoothstep(low, high, raw_a)
    if unpremult_white:
        # Remove faint pale halo on semi-transparent antialiased edge pixels
        edge = (a > 0.02) & (a < 0.94)
        frac = np.clip(raw_a / 255.0, 0.12, 1.0)[..., None]
        matte = np.array([245.0, 246.0, 244.0], dtype=np.float32)
        dehalo = (out[:, :, :3] - matte * (1.0 - frac)) / frac
        out[:, :, :3] = np.where(edge[..., None], np.clip(dehalo, 0.0, 255.0), out[:, :, :3])
    out[:, :, 3] = a * 255.0
    out[out[:, :, 3] < 2.0] = 0.0
    return out


def tile_axis(rgb: np.ndarray, axis: int) -> np.ndarray:
    n = rgb.shape[axis]
    w = (np.sin(np.pi * np.arange(n, dtype=np.float32) / n) ** 2)
    weights = w[None, :, None] if axis == 1 else w[:, None, None]
    rolled = np.roll(rgb, n // 2, axis=axis)
    return rolled + (rgb - rolled) * weights


def build_ground_textures() -> None:
    # 1. Ochre clearing earth: calm warm peach-ochre tuned to forest.png path
    ochre_src = load_rgba("01_ochre_earth.png")[:, :, :3]
    ochre_512 = cv2.resize(ochre_src, (512, 512), interpolation=cv2.INTER_AREA)
    ochre_seamless = tile_axis(tile_axis(ochre_512, 0), 1)
    mean_o = ochre_seamless.mean(axis=(0, 1), keepdims=True)
    # Gently calm contrast so 4-soldier squads pop effortlessly
    target_ochre = np.array([[[214.0, 146.0, 86.0]]], dtype=np.float32)
    ochre_final = np.clip(target_ochre + (ochre_seamless - mean_o) * 0.72, 0.0, 255.0)
    rgba_o = np.dstack([ochre_final, np.full((512, 512), 255.0, dtype=np.float32)])
    save_rgba("ground_ochre_earth", rgba_o)

    # 2. Mossy forest turf: rich Fight-4 yellow-green & cool emerald moss
    moss_src = load_rgba("02_forest_moss_turf.png")[:, :, :3]
    moss_512 = cv2.resize(moss_src, (512, 512), interpolation=cv2.INTER_AREA)
    moss_seamless = tile_axis(tile_axis(moss_512, 0), 1)
    mean_m = moss_seamless.mean(axis=(0, 1), keepdims=True)
    target_moss = np.array([[[102.0, 134.0, 62.0]]], dtype=np.float32)
    moss_final = np.clip(target_moss + (moss_seamless - mean_m) * 0.78, 0.0, 255.0)
    rgba_m = np.dstack([moss_final, np.full((512, 512), 255.0, dtype=np.float32)])
    save_rgba("ground_forest_moss", rgba_m)

    # 3. Organic splat transition noise + tuft detail texture (R=tuft height, G=dapple leaf clusters, B=mist wisps)
    rng = np.random.default_rng(4207)
    detail = np.zeros((512, 512, 4), dtype=np.float32)
    # Channel R: moss clump luminance from moss texture for natural tuft-edge transitions
    lum_m = (moss_seamless[:, :, 0] * 0.32 + moss_seamless[:, :, 1] * 0.58 + moss_seamless[:, :, 2] * 0.10)
    lum_m = (lum_m - lum_m.min()) / max(lum_m.max() - lum_m.min(), 1.0)
    detail[:, :, 0] = lum_m * 255.0

    # Channel G: seamless painterly leaf-canopy dapple pattern
    leaf = np.zeros((512, 512), dtype=np.float32)
    for _ in range(260):
        cx = float(rng.uniform(0, 512))
        cy = float(rng.uniform(0, 512))
        rx = float(rng.uniform(10.0, 28.0))
        ry = rx * 0.62
        val = float(rng.uniform(0.35, 1.0))
        for ox in (-512.0, 0.0, 512.0):
            for oy in (-512.0, 0.0, 512.0):
                y_idx, x_idx = np.ogrid[:512, :512]
                d2 = ((x_idx - (cx + ox)) / rx) ** 2 + ((y_idx - (cy + oy)) / ry) ** 2
                leaf = np.maximum(leaf, val * np.clip(1.0 - d2, 0.0, 1.0))
    leaf = cv2.GaussianBlur(leaf, (15, 15), 4.2)
    detail[:, :, 1] = np.clip(leaf * 255.0, 0.0, 255.0)

    # Channel B: soft valley mist cloud billows
    noise_small = rng.uniform(0.0, 1.0, (32, 32)).astype(np.float32)
    mist = cv2.resize(noise_small, (512, 512), interpolation=cv2.INTER_CUBIC)
    mist = tile_axis(tile_axis(mist[:, :, None], 0), 1)[:, :, 0]
    detail[:, :, 2] = np.clip(mist * 255.0, 0.0, 255.0)
    detail[:, :, 3] = 255.0
    save_rgba("ground_detail_masks", detail)


def extract_islands(sheet: np.ndarray, min_area: int = 1200, alpha_thresh: int = 28) -> list[dict]:
    mask = (sheet[:, :, 3] > alpha_thresh).astype(np.uint8)
    n, labels, stats, cents = cv2.connectedComponentsWithStats(mask, connectivity=8)
    islands = []
    for idx in range(1, n):
        x, y, w, h, area = [int(v) for v in stats[idx]]
        if area < min_area:
            continue
        pad = 3
        x0 = max(0, x - pad)
        y0 = max(0, y - pad)
        x1 = min(sheet.shape[1], x + w + pad)
        y1 = min(sheet.shape[0], y + h + pad)
        crop = sheet[y0:y1, x0:x1].copy()
        sub_labels = labels[y0:y1, x0:x1]
        # Keep main island + tiny nearby leaf/stone flecks inside bbox that aren't another major island
        other_major = np.zeros_like(sub_labels, dtype=bool)
        for other_id in range(1, n):
            if other_id != idx and stats[other_id, 4] >= min_area:
                other_major |= (sub_labels == other_id)
        crop[other_major] = 0.0
        islands.append({
            "bbox": (x0, y0, x1, y1),
            "center": (float(cents[idx][0]), float(cents[idx][1])),
            "crop": crop,
            "area": area,
        })
    return islands


def resize_scale(arr: np.ndarray, scale: float) -> np.ndarray:
    h, w = arr.shape[:2]
    nw = max(4, int(round(w * scale)))
    nh = max(4, int(round(h * scale)))
    return cv2.resize(arr, (nw, nh), interpolation=cv2.INTER_AREA)


def split_tree_trunk_and_crown(tree_rgba: np.ndarray, split_y0_frac: float, split_y1_frac: float) -> tuple[np.ndarray, np.ndarray]:
    """Decompose a single RGBA tree into exact Porter-Duff complementary Trunk + Crown layers:
    crown OVER trunk == original tree pixel-for-pixel when crown opacity == 1.0."""
    h, w = tree_rgba.shape[:2]
    y = np.arange(h, dtype=np.float32)[:, None]
    # Also keep central lower trunk solid slightly higher up than wide side boughs
    x_norm = np.abs((np.arange(w, dtype=np.float32)[None, :] / max(w - 1, 1)) - 0.5) * 2.0
    y0 = h * split_y0_frac - h * 0.08 * np.clip(1.0 - x_norm * 1.8, 0.0, 1.0)
    y1 = h * split_y1_frac - h * 0.05 * np.clip(1.0 - x_norm * 1.8, 0.0, 1.0)
    trunk_weight = smoothstep(0.0, 1.0, (y - y0) / np.maximum(y1 - y0, 4.0))

    a = np.clip(tree_rgba[:, :, 3] / 255.0, 0.0, 1.0)
    a_trunk = a * trunk_weight
    a_crown = np.where(a > a_trunk + 1e-4, (a - a_trunk) / np.maximum(1.0 - a_trunk, 1e-4), 0.0)
    a_crown = np.clip(a_crown, 0.0, 1.0)

    trunk = tree_rgba.copy()
    trunk[:, :, 3] = a_trunk * 255.0
    trunk[trunk[:, :, 3] < 1.5] = 0.0

    crown = tree_rgba.copy()
    crown[:, :, 3] = a_crown * 255.0
    crown[crown[:, :, 3] < 1.5] = 0.0
    return trunk, crown


def build_environment_kit() -> dict[str, dict]:
    catalog: dict[str, dict] = {}

    def register(piece_id: str, rgba: np.ndarray, scale: float, anchor_uv: tuple[float, float],
                 role: str, blocked_cells: list[list[int]], shade_radius: tuple[float, float] = (0.0, 0.0),
                 shade_offset: tuple[float, float] = (18.0, 12.0), shade_strength: float = 0.0,
                 canopy_split: tuple[float, float] | None = None, is_orichalcum: bool = False,
                 tall_occluder: bool = False) -> None:
        scaled = resize_scale(rgba, scale)
        w, h = save_rgba(piece_id, scaled)
        entry = {
            "piece_id": piece_id,
            "size": [w, h],
            "anchor_px": [round(w * anchor_uv[0], 1), round(h * anchor_uv[1], 1)],
            "role": role,
            "blocked_cells": blocked_cells,
            "shade_radius": list(shade_radius),
            "shade_offset": list(shade_offset),
            "shade_strength": shade_strength,
            "has_canopy": canopy_split is not None,
            "is_orichalcum": is_orichalcum,
            "tall_occluder": tall_occluder,
        }
        if canopy_split is not None:
            trunk, crown = split_tree_trunk_and_crown(scaled, canopy_split[0], canopy_split[1])
            save_rgba(f"{piece_id}_trunk", trunk)
            save_rgba(f"{piece_id}_crown", crown)
        catalog[piece_id] = entry

    # --- Sheet 03: Raised Cliff Bluff Kit (6 pieces) ---
    # Scale 0.42 -> ~190px wide (~3x2 or 2x2 isometric cells at 45.25px/cell width, stored 2x crisp!)
    s03 = clean_alpha(load_rgba("03_cliff_bluff_kit.png"))
    isl03 = sorted(extract_islands(s03), key=lambda d: (0 if d["center"][1] < 512 else 1, d["center"][0]))
    assert len(isl03) == 6, f"Expected 6 bluff pieces, got {len(isl03)}"

    # Row 0: [0]=bluff_sw (+u axis), [1]=bluff_se (-v axis), [2]=bluff_outer_corner
    register("cliff_bluff_u", isl03[0]["crop"], 0.42, (0.50, 0.62), "cliff",
             [[-2, 0], [-1, 0], [0, 0], [1, 0], [2, 0], [-2, 1], [-1, 1], [0, 1], [1, 1], [2, 1]],
             shade_radius=(92.0, 56.0), shade_offset=(22.0, 16.0), shade_strength=0.38, tall_occluder=True)
    register("cliff_bluff_v", isl03[1]["crop"], 0.42, (0.50, 0.62), "cliff",
             [[0, -2], [0, -1], [0, 0], [0, 1], [0, 2], [1, -2], [1, -1], [1, 0], [1, 1], [1, 2]],
             shade_radius=(92.0, 56.0), shade_offset=(24.0, 16.0), shade_strength=0.40, tall_occluder=True)
    register("cliff_outer_corner", isl03[2]["crop"], 0.42, (0.50, 0.64), "cliff",
             [[-1, 0], [0, 0], [0, -1], [-1, 1], [0, 1], [1, 0], [1, -1]],
             shade_radius=(84.0, 52.0), shade_offset=(22.0, 15.0), shade_strength=0.38, tall_occluder=True)
    # Row 1: [3]=bluff_inner_corner, [4]=bluff_end_u (tapers +u), [5]=bluff_end_v (tapers +v)
    register("cliff_inner_corner", isl03[3]["crop"], 0.42, (0.50, 0.62), "cliff",
             [[0, -1], [0, 0], [1, 0], [-1, 0], [0, 1], [1, 1]],
             shade_radius=(82.0, 50.0), shade_offset=(20.0, 14.0), shade_strength=0.36, tall_occluder=True)
    register("cliff_end_u", isl03[4]["crop"], 0.42, (0.50, 0.68), "cliff",
             [[-2, 0], [-1, 0], [0, 0], [1, 0], [-1, 1], [0, 1]],
             shade_radius=(78.0, 48.0), shade_offset=(20.0, 14.0), shade_strength=0.34, tall_occluder=True)
    register("cliff_end_v", isl03[5]["crop"], 0.42, (0.50, 0.68), "cliff",
             [[0, -2], [0, -1], [0, 0], [0, 1], [1, -1], [1, 0]],
             shade_radius=(78.0, 48.0), shade_offset=(20.0, 14.0), shade_strength=0.34, tall_occluder=True)

    # --- Sheet 04: Exposed Shelf Drop-Off Rims, Boulders, Slabs & Fences (7 islands) ---
    # Keep soft lower cliff mist fade on Row 0 and tint pale bottom haze to cool Fight-4 valley mist!
    s04_raw = load_rgba("04_shelf_dropoff_and_props.png")
    s04_top = s04_raw.copy()
    raw_a04 = s04_top[:, :, 3]
    s04_top[:, :, 3] = smoothstep(10.0, 205.0, raw_a04) * 255.0
    # Un-whiten semi-transparent lower cliff mist skirt toward cool blue-slate valley mist (#587e96)
    haze_mask = (raw_a04 > 6.0) & (raw_a04 < 230.0)
    mist_tint = np.array([86.0, 124.0, 148.0], dtype=np.float32)
    whiteness = np.clip((s04_top[:, :, :3].min(axis=-1) - 135.0) / 95.0, 0.0, 1.0)
    blend_w = (whiteness * (1.0 - np.clip(raw_a04 / 235.0, 0.0, 1.0) * 0.55))[..., None]
    s04_top[:, :, :3] = np.where(haze_mask[..., None], s04_top[:, :, :3] * (1.0 - blend_w) + mist_tint * blend_w, s04_top[:, :, :3])
    isl04 = extract_islands(s04_top, min_area=1200, alpha_thresh=18)
    top04 = sorted([d for d in isl04 if d["center"][1] < 512], key=lambda d: d["center"][0])
    bot04 = sorted([d for d in isl04 if d["center"][1] >= 512], key=lambda d: d["center"][0])
    assert len(top04) == 3 and len(bot04) == 4, f"Expected 3+4 on sheet 04, got {len(top04)}+{len(bot04)}"

    # Anchor shelf rims near their upper mossy lip so they hang down into the misty void!
    register("shelf_rim_u", top04[0]["crop"], 0.42, (0.52, 0.28), "shelf_rim",
             [[-2, 0], [-1, 0], [0, 0], [1, 0], [2, 0]])
    register("shelf_rim_v", top04[1]["crop"], 0.42, (0.48, 0.28), "shelf_rim",
             [[0, -2], [0, -1], [0, 0], [0, 1], [0, 2]])
    register("shelf_rim_corner_s", top04[2]["crop"], 0.42, (0.50, 0.30), "shelf_rim",
             [[-1, 0], [0, 0], [0, -1]])

    # bot04 sorted by x: [0]=boulder_moss_pair, [1]=step_slabs, [2]=fence_u (-30 SW), [3]=fence_v (+30 SE)
    register("boulder_moss_pair", clean_alpha(bot04[0]["crop"]), 0.34, (0.50, 0.78), "obstacle",
             [[0, 0], [1, 0]], shade_radius=(54.0, 34.0), shade_offset=(14.0, 10.0), shade_strength=0.32)
    register("step_slabs_moss", clean_alpha(bot04[1]["crop"]), 0.34, (0.50, 0.56), "ground_decal", [])
    register("fence_rail_u", clean_alpha(bot04[2]["crop"]), 0.34, (0.50, 0.76), "obstacle",
             [[0, 0], [1, 0]], shade_radius=(32.0, 20.0), shade_offset=(8.0, 6.0), shade_strength=0.18)
    register("fence_rail_v", clean_alpha(bot04[3]["crop"]), 0.34, (0.50, 0.76), "obstacle",
             [[0, 0], [0, -1]], shade_radius=(32.0, 20.0), shade_offset=(8.0, 6.0), shade_strength=0.18)

    # --- Sheet 05: Hero Buttress Tree, Medium Canopy Trees & Undergrowth (5 islands) ---
    s05 = clean_alpha(load_rgba("05_trees_and_undergrowth.png"))
    isl05 = extract_islands(s05)
    assert len(isl05) == 5, f"Expected 5 foliage islands, got {len(isl05)}"
    # Identify unambiguously by x/y region
    hero_tree = [d for d in isl05 if d["center"][0] < 550][0]
    med_trees = sorted([d for d in isl05 if 550 <= d["center"][0] < 1100], key=lambda d: d["center"][1])
    shrubs = sorted([d for d in isl05 if d["center"][0] >= 1100], key=lambda d: d["center"][1])

    # Hero tree: trunk blocks 2x2 root core; broad sunlit canopy overhangs 6x6 walkable ground!
    register("tree_hero_buttress", hero_tree["crop"], 0.36, (0.48, 0.88), "tree",
             [[0, 0], [1, 0], [0, 1], [1, 1]],
             shade_radius=(135.0, 84.0), shade_offset=(24.0, 16.0), shade_strength=0.34,
             canopy_split=(0.54, 0.68), tall_occluder=True)
    register("tree_canopy_warm", med_trees[0]["crop"], 0.42, (0.50, 0.89), "tree",
             [[0, 0]],
             shade_radius=(82.0, 50.0), shade_offset=(18.0, 12.0), shade_strength=0.28,
             canopy_split=(0.56, 0.70), tall_occluder=True)
    register("tree_canopy_cool", med_trees[1]["crop"], 0.42, (0.50, 0.90), "tree",
             [[0, 0]],
             shade_radius=(84.0, 52.0), shade_offset=(18.0, 12.0), shade_strength=0.30,
             canopy_split=(0.58, 0.72), tall_occluder=True)
    register("undergrowth_fern", shrubs[0]["crop"], 0.28, (0.50, 0.80), "prop",
             [], shade_radius=(28.0, 18.0), shade_offset=(6.0, 4.0), shade_strength=0.14)
    register("undergrowth_red_shoot", shrubs[1]["crop"], 0.28, (0.50, 0.82), "prop",
             [], shade_radius=(26.0, 16.0), shade_offset=(6.0, 4.0), shade_strength=0.14)

    # --- Sheet 06: Orichalcum Outcrop, Clearing Ring Arc, Cave Bluff & Hollow Log (4 islands) ---
    s06 = clean_alpha(load_rgba("06_orichalcum_and_landmarks.png"))
    isl06 = sorted(extract_islands(s06), key=lambda d: (0 if d["center"][1] < 512 else 1, d["center"][0]))
    assert len(isl06) == 4, f"Expected 4 landmark islands, got {len(isl06)}"

    register("orichalcum_outcrop", isl06[0]["crop"], 0.34, (0.50, 0.68), "obstacle",
             [[-1, -1], [0, -1], [1, -1], [-1, 0], [0, 0], [1, 0], [-1, 1], [0, 1], [1, 1]],
             shade_radius=(96.0, 60.0), shade_offset=(20.0, 14.0), shade_strength=0.36,
             is_orichalcum=True, tall_occluder=True)
    register("clearing_stone_arc", isl06[1]["crop"], 0.38, (0.50, 0.56), "ground_decal", [])
    register("cave_alcove_bluff", isl06[2]["crop"], 0.38, (0.50, 0.72), "cliff",
             [[-1, -1], [0, -1], [1, -1], [-1, 0], [0, 0], [1, 0], [-1, 1], [1, 1]],
             shade_radius=(104.0, 64.0), shade_offset=(22.0, 16.0), shade_strength=0.40, tall_occluder=True)
    register("fallen_moss_log", isl06[3]["crop"], 0.32, (0.50, 0.66), "obstacle",
             [[0, -1], [0, 0], [0, 1]],
             shade_radius=(64.0, 38.0), shade_offset=(12.0, 9.0), shade_strength=0.26)

    return catalog


def relight_mirrored_upper_left(rgba: np.ndarray, strength: float = 0.11) -> np.ndarray:
    """Flip horizontally and gently shift highlight/shadow gradient back toward upper-left
    so mirrored poses preserve coherent top-left sunlight."""
    flipped = np.ascontiguousarray(rgba[:, ::-1, :]).copy()
    a = flipped[:, :, 3] > 20.0
    if not np.any(a):
        return flipped
    ys, xs = np.nonzero(a)
    cx = float(xs.mean())
    sx = max(float(xs.std()), 8.0)
    x_grid = (np.arange(flipped.shape[1], dtype=np.float32)[None, :] - cx) / sx
    # Left side (-x) gets slight warm sun lift; right side (+x) gets slight cool lavender shade
    sun = np.clip(-x_grid, -1.3, 1.3)[..., None]
    warm_cool = np.array([1.05, 1.01, 0.94], dtype=np.float32)
    mult = 1.0 + sun * strength * warm_cool
    flipped[:, :, :3] = np.clip(flipped[:, :, :3] * mult, 0.0, 255.0)
    return flipped


def warp_humanoid_stride(cell_img: Image.Image, phase: float) -> Image.Image:
    """Smooth lower-body isometric stride animation (adapted from Forest Fight 4)."""
    w, h = cell_img.size
    split_x = w * 0.5
    y_hip = h * 0.54
    y_foot = h * 0.94

    def map_pt(x: float, y: float) -> tuple[float, float]:
        lower = float(smoothstep(y_hip, y_foot, np.array(y)))
        side = 2.0 * float(smoothstep(split_x - w * 0.08, split_x + w * 0.08, np.array(x))) - 1.0
        dx = -w * 0.042 * sin(phase) * lower * side
        dy = h * 0.024 * max(0.0, cos(phase) * side) * lower - h * 0.010 * abs(sin(phase)) * (1.0 - lower * 0.5)
        return (x + dx, y + dy)

    mesh = []
    step = 8
    xs = [*range(0, w, step), w]
    ys = [*range(0, h, step), h]
    for x0, x1 in zip(xs, xs[1:]):
        for y0, y1 in zip(ys, ys[1:]):
            pts = (map_pt(x0, y0), map_pt(x0, y1), map_pt(x1, y1), map_pt(x1, y0))
            mesh.append(((x0, y0, x1, y1), tuple(v for p in pts for v in p)))
    return cell_img.transform((w, h), Image.Transform.MESH, mesh, Image.Resampling.BICUBIC)


def pack_humanoid_sheet(poses_5: list[np.ndarray], out_name: str, cell_w: int = 96, cell_h: int = 112,
                        target_h: int = 92) -> None:
    """5 source poses [0:UP, 1:UP_RIGHT, 2:RIGHT, 3:DOWN_RIGHT, 4:DOWN] ->
    8 columns [0:RIGHT, 1:DOWN_RIGHT, 2:DOWN, 3:DOWN_LEFT, 4:LEFT, 5:UP_LEFT, 6:UP, 7:UP_RIGHT] x 4 walk rows."""
    # Normalize each of the 5 poses to uniform boot-line & height
    norm_5: list[np.ndarray] = []
    boot_y = cell_h - 12
    for crop in poses_5:
        ys, xs = np.nonzero(crop[:, :, 3] > 32.0)
        sub = crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        sh, sw = sub.shape[:2]
        ratio = target_h / max(sh, 1)
        nw = max(8, int(round(sw * ratio)))
        nh = max(8, int(round(sh * ratio)))
        resized = cv2.resize(sub, (nw, nh), interpolation=cv2.INTER_AREA)
        # Center horizontally by lower-body boot center so feet stay planted when turning
        lower_a = resized[int(nh * 0.65):, :, 3]
        _, lxs = np.nonzero(lower_a > 32.0)
        foot_cx = float(lxs.mean()) if len(lxs) else nw * 0.5
        canvas = np.zeros((cell_h, cell_w, 4), dtype=np.float32)
        px = int(round(cell_w * 0.5 - foot_cx))
        py = boot_y - nh
        # Paste safely clipped
        sx0 = max(0, -px)
        sy0 = max(0, -py)
        dx0 = max(0, px)
        dy0 = max(0, py)
        pw = min(nw - sx0, cell_w - dx0)
        ph = min(nh - sy0, cell_h - dy0)
        canvas[dy0:dy0 + ph, dx0:dx0 + pw] = resized[sy0:sy0 + ph, sx0:sx0 + pw]
        norm_5.append(canvas)

    # Map to 8 screen headings:
    # 0:RIGHT(2), 1:DOWN_RIGHT(3), 2:DOWN(4), 3:DOWN_LEFT(flip 3), 4:LEFT(flip 2), 5:UP_LEFT(flip 1), 6:UP(0), 7:UP_RIGHT(1)
    dir_sources = [
        (2, False),
        (3, False),
        (4, False),
        (3, True),
        (2, True),
        (1, True),
        (0, False),
        (1, False),
    ]
    atlas = Image.new("RGBA", (cell_w * 8, cell_h * 4), (0, 0, 0, 0))
    phases = [0.0, pi * 0.5, pi, pi * 1.5]
    for col, (src_idx, mirror) in enumerate(dir_sources):
        base_arr = relight_mirrored_upper_left(norm_5[src_idx]) if mirror else norm_5[src_idx]
        base_pil = Image.fromarray(np.clip(np.rint(base_arr), 0, 255).astype(np.uint8), mode="RGBA")
        atlas.paste(base_pil, (col * cell_w, 0))
        for row in range(1, 4):
            stepped = warp_humanoid_stride(base_pil, phases[row])
            atlas.paste(stepped, (col * cell_w, row * cell_h))

    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / f"{out_name}.png", optimize=True)


def find_turret_body_pivot(crop: np.ndarray) -> tuple[float, float]:
    """Erode narrow cannon barrel and antenna so only the wide circular turret dome remains;
    return its exact sub-pixel centroid."""
    mask = (crop[:, :, 3] > 48.0).astype(np.uint8)
    for r in (26, 20, 14, 8):
        kern = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (r * 2 + 1, r * 2 + 1))
        eroded = cv2.erode(mask, kern)
        ys, xs = np.nonzero(eroded > 0)
        if len(xs) >= 120:
            return float(xs.mean()), float(ys.mean())
    ys, xs = np.nonzero(mask > 0)
    return float(xs.mean()), float(ys.mean())


def find_hull_ring_pivot(crop: np.ndarray) -> tuple[float, float]:
    """Locate the circular recessed turret well on the upper hull deck."""
    mask = (crop[:, :, 3] > 60.0).astype(np.uint8)
    ys, xs = np.nonzero(mask > 0)
    bx0, bx1 = xs.min(), xs.max()
    by0, by1 = ys.min(), ys.max()
    bw, bh = bx1 - bx0 + 1, by1 - by0 + 1
    # The circular turret well sits horizontally centered and ~40% down from top of hull deck
    # Refine by searching dark circular interior near (cx, by0 + 0.40 * bh)
    cx_est = (bx0 + bx1) * 0.5
    cy_est = by0 + bh * 0.41
    lum = crop[:, :, 0] * 0.3 + crop[:, :, 1] * 0.59 + crop[:, :, 2] * 0.11
    yy, xx = np.ogrid[:crop.shape[0], :crop.shape[1]]
    win = ((xx - cx_est) / max(bw * 0.22, 12.0)) ** 2 + ((yy - cy_est) / max(bh * 0.22, 12.0)) ** 2 <= 1.0
    dark = win & (crop[:, :, 3] > 200.0) & (lum < np.percentile(lum[win & (crop[:, :, 3] > 200.0)], 38))
    dys, dxs = np.nonzero(dark)
    if len(dxs) >= 40:
        return float(dxs.mean()), float(dys.mean())
    return float(cx_est), float(cy_est)


def pack_tank_sheets(sheet_name: str, prefix: str, cell_size: int = 128, scale: float = 0.34) -> None:
    """Pack 8-direction x 2-row Hull sheet and 8-direction x 1-row Turret sheet with
    co-registered turret mounting ring pivot at exact cell center (cell_size/2, cell_size/2)."""
    sheet = clean_alpha(load_rgba(sheet_name))
    islands = extract_islands(sheet)
    hulls_5 = sorted([d for d in islands if d["center"][1] < 512], key=lambda d: d["center"][0])
    turrets_5 = sorted([d for d in islands if d["center"][1] >= 512], key=lambda d: d["center"][0])
    assert len(hulls_5) == 5 and len(turrets_5) == 5, f"{sheet_name}: got {len(hulls_5)} hulls, {len(turrets_5)} turrets"

    norm_hulls: list[np.ndarray] = []
    norm_turrets: list[np.ndarray] = []
    half = cell_size * 0.5

    for h_item, t_item in zip(hulls_5, turrets_5):
        hc = h_item["crop"]
        hx, hy = find_hull_ring_pivot(hc)
        hs = resize_scale(hc, scale)
        hx_s, hy_s = hx * scale, hy * scale
        h_cell = np.zeros((cell_size, cell_size, 4), dtype=np.float32)
        px = int(round(half - hx_s))
        py = int(round(half - hy_s))
        sx0, sy0 = max(0, -px), max(0, -py)
        dx0, dy0 = max(0, px), max(0, py)
        pw = min(hs.shape[1] - sx0, cell_size - dx0)
        ph = min(hs.shape[0] - sy0, cell_size - dy0)
        h_cell[dy0:dy0 + ph, dx0:dx0 + pw] = hs[sy0:sy0 + ph, sx0:sx0 + pw]
        norm_hulls.append(h_cell)

        tc = t_item["crop"]
        tx, ty = find_turret_body_pivot(tc)
        ts = resize_scale(tc, scale)
        tx_s, ty_s = tx * scale, ty * scale
        t_cell = np.zeros((cell_size, cell_size, 4), dtype=np.float32)
        tpx = int(round(half - tx_s))
        tpy = int(round(half - ty_s))
        tsx0, tsy0 = max(0, -tpx), max(0, -tpy)
        tdx0, tdy0 = max(0, tpx), max(0, tpy)
        tpw = min(ts.shape[1] - tsx0, cell_size - tdx0)
        tph = min(ts.shape[0] - tsy0, cell_size - tdy0)
        t_cell[tdy0:tdy0 + tph, tdx0:tdx0 + tpw] = ts[tsy0:tsy0 + tph, tsx0:tsx0 + tpw]
        norm_turrets.append(t_cell)

    dir_sources = [
        (2, False), (3, False), (4, False), (3, True),
        (2, True), (1, True), (0, False), (1, False),
    ]
    hull_atlas = np.zeros((cell_size * 2, cell_size * 8, 4), dtype=np.float32)
    turret_atlas = np.zeros((cell_size, cell_size * 8, 4), dtype=np.float32)

    for col, (src_idx, mirror) in enumerate(dir_sources):
        h0 = relight_mirrored_upper_left(norm_hulls[src_idx], 0.09) if mirror else norm_hulls[src_idx]
        # Row 1: subtle 1px engine/track rumble + tread highlight shift when driving
        h1 = np.roll(h0, -1, axis=0)
        h1[-1, :, :] = 0.0
        hull_atlas[0:cell_size, col * cell_size:(col + 1) * cell_size] = h0
        hull_atlas[cell_size:cell_size * 2, col * cell_size:(col + 1) * cell_size] = h1

        t0 = relight_mirrored_upper_left(norm_turrets[src_idx], 0.09) if mirror else norm_turrets[src_idx]
        turret_atlas[0:cell_size, col * cell_size:(col + 1) * cell_size] = t0

    save_rgba(f"{prefix}_hull", hull_atlas)
    save_rgba(f"{prefix}_turret", turret_atlas)


def build_units() -> None:
    s07 = clean_alpha(load_rgba("07_infantry_blue_and_red.png"))
    isl07 = extract_islands(s07)
    blue_inf = sorted([d["crop"] for d in isl07 if d["center"][1] < 512], key=lambda _: 0)
    # Sort strictly by center x!
    blue_inf = [d["crop"] for d in sorted([d for d in isl07 if d["center"][1] < 512], key=lambda d: d["center"][0])]
    red_inf = [d["crop"] for d in sorted([d for d in isl07 if d["center"][1] >= 512], key=lambda d: d["center"][0])]
    assert len(blue_inf) == 5 and len(red_inf) == 5
    pack_humanoid_sheet(blue_inf, "blue_soldier", cell_w=96, cell_h=112, target_h=90)
    pack_humanoid_sheet(red_inf, "red_soldier", cell_w=96, cell_h=112, target_h=92)

    s08 = clean_alpha(load_rgba("08_commanders_blue_and_red.png"))
    isl08 = extract_islands(s08)
    blue_cmd = [d["crop"] for d in sorted([d for d in isl08 if d["center"][1] < 512], key=lambda d: d["center"][0])]
    red_cmd = [d["crop"] for d in sorted([d for d in isl08 if d["center"][1] >= 512], key=lambda d: d["center"][0])]
    assert len(blue_cmd) == 5 and len(red_cmd) == 5
    pack_humanoid_sheet(blue_cmd, "blue_commander", cell_w=104, cell_h=120, target_h=100)
    pack_humanoid_sheet(red_cmd, "red_commander", cell_w=104, cell_h=120, target_h=102)

    pack_tank_sheets("09_blue_tank_isometric.png", "blue_tank", cell_size=128, scale=0.34)
    pack_tank_sheets("10_red_tank_isometric.png", "red_tank", cell_size=128, scale=0.34)


def save_kit_contact_sheet(catalog: dict[str, dict]) -> None:
    """Render an inspection sheet showing extracted cutouts + anchor crosshairs + assembled 8-way tanks."""
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1680, 1180), (34, 48, 56, 255))
    draw = ImageDraw.Draw(sheet)

    x, y, row_h = 20, 20, 0
    for pid, meta in catalog.items():
        im = Image.open(OUT / f"{pid}.png").convert("RGBA")
        # Fit into max 220x220 preview box
        scale = min(1.0, 210.0 / max(im.width, im.height))
        pw, ph = int(round(im.width * scale)), int(round(im.height * scale))
        thumb = im.resize((pw, ph), Image.Resampling.LANCZOS)
        if x + max(pw, 150) > 1650:
            x = 20
            y += row_h + 36
            row_h = 0
        sheet.alpha_composite(thumb, (x, y))
        ax = x + int(round(meta["anchor_px"][0] * scale))
        ay = y + int(round(meta["anchor_px"][1] * scale))
        draw.ellipse((ax - 4, ay - 4, ax + 4, ay + 4), fill=(255, 220, 60, 255), outline=(20, 20, 20, 255))
        draw.text((x, y + ph + 4), pid, fill=(235, 232, 220, 255))
        row_h = max(row_h, ph)
        x += max(pw, 150) + 22

    # Bottom strip: assembled Blue & Red Tanks across all 8 headings + turret cross-angles!
    ty = 960
    for row_i, prefix in enumerate(["blue_tank", "red_tank"]):
        hull = Image.open(OUT / f"{prefix}_hull.png").convert("RGBA")
        tur = Image.open(OUT / f"{prefix}_turret.png").convert("RGBA")
        for col in range(8):
            hc = hull.crop((col * 128, 0, (col + 1) * 128, 128))
            # Test independent turret rotated +2 steps from hull on odd columns!
            t_col = (col + (2 if col % 2 == 1 else 0)) % 8
            tc = tur.crop((t_col * 128, 0, (t_col + 1) * 128, 128))
            comp = Image.alpha_composite(hc, tc).resize((96, 96), Image.Resampling.LANCZOS)
            px = 24 + (row_i * 8 + col) * 102
            sheet.alpha_composite(comp, (px, ty))
            draw.text((px + 12, ty + 96), f"{prefix[0].upper()} h{col}/t{t_col}", fill=(220, 235, 245, 255))

    sheet.convert("RGB").save(PREVIEW_DIR / "kit_and_tanks_check.png", optimize=True)


def main() -> None:
    build_ground_textures()
    catalog = build_environment_kit()
    build_units()
    OUT.mkdir(parents=True, exist_ok=True)
    with open(OUT / "kit_catalog.json", "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2)
    save_kit_contact_sheet(catalog)
    print(f"Built {len(catalog)} modular environment pieces, 3 seamless ground/mask textures, and 6 unit/tank atlases in {OUT}")


if __name__ == "__main__":
    main()
