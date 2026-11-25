#!/usr/bin/env python3
"""Split a prop sprite sheet on pure magenta (#FF00FF) into separate transparent PNGs.

Usage:
    python tools/cut_sheet.py <sheet.png> [--out-dir <dir>] [--pad 8] [--group-radius 12]

Pipeline:
1. Local-foreground color-line chroma key against pure magenta (#FF00FF) with soft anti-aliased edge.
2. Exact linear unmixing + boundary magenta despill + RGB edge bleed into transparent pixels.
3. 8-connected components (with morphological grouping so detached pebbles/tips stay with their prop).
4. Reading-order sort (rows top-to-bottom, left-to-right), crop with 8 px transparent padding,
   and save as assets/prop_01.png, assets/prop_02.png, ...
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

try:
    from scipy import ndimage as _scipy_ndimage
except ImportError:
    _scipy_ndimage = None


def _label_connected_components(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """8-connected components labeling (uses scipy if available, else fast RLE union-find)."""
    if _scipy_ndimage is not None:
        structure = np.ones((3, 3), dtype=np.int32)
        labels, count = _scipy_ndimage.label(mask, structure=structure)
        return labels.astype(np.int32), int(count)

    h, w = mask.shape
    parent = [0]
    labels = np.zeros((h, w), dtype=np.int32)
    next_lbl = 1

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            if ra < rb:
                parent[rb] = ra
            else:
                parent[ra] = rb

    prev_runs: list[tuple[int, int, int]] = []
    for y in range(h):
        row = mask[y]
        if not row.any():
            prev_runs = []
            continue
        padded = np.concatenate(([False], row, [False]))
        diffs = np.diff(padded.astype(np.int8))
        starts = np.where(diffs == 1)[0]
        ends = np.where(diffs == -1)[0]
        cur_runs: list[tuple[int, int, int]] = []
        p_idx = 0
        n_prev = len(prev_runs)
        for s, e in zip(starts, ends):
            s_i, e_i = int(s), int(e)
            while p_idx < n_prev and prev_runs[p_idx][1] < s_i:
                p_idx += 1
            lbl = 0
            j = p_idx
            while j < n_prev and prev_runs[j][0] <= e_i:
                plbl = prev_runs[j][2]
                if lbl == 0:
                    lbl = plbl
                else:
                    union(lbl, plbl)
                j += 1
            if lbl == 0:
                lbl = next_lbl
                parent.append(lbl)
                next_lbl += 1
            labels[y, s_i:e_i] = lbl
            cur_runs.append((s_i, e_i, lbl))
        prev_runs = cur_runs

    lut = np.zeros(next_lbl, dtype=np.int32)
    remap: dict[int, int] = {}
    cid = 0
    for i in range(1, next_lbl):
        r = find(i)
        if r not in remap:
            cid += 1
            remap[r] = cid
        lut[i] = remap[r]
    return lut[labels], cid


def _dilate_mask(mask: np.ndarray, radius: int) -> np.ndarray:
    """Fast binary dilation using Pillow MaxFilter (odd kernel size 2*radius + 1)."""
    if radius <= 0:
        return mask.copy()
    size = radius * 2 + 1
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    return np.array(img.filter(ImageFilter.MaxFilter(size))) > 0


def _erode_mask(mask: np.ndarray, radius: int) -> np.ndarray:
    """Fast binary erosion using Pillow MinFilter (odd kernel size 2*radius + 1)."""
    if radius <= 0:
        return mask.copy()
    size = radius * 2 + 1
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    return np.array(img.filter(ImageFilter.MinFilter(size))) > 0


def _propagate_rgb(rgb: np.ndarray, seed_mask: np.ndarray, iterations: int) -> tuple[np.ndarray, np.ndarray]:
    """Dilate RGB values from seed_mask outward via 4-neighbor averaging."""
    out = rgb.copy()
    valid = seed_mask.copy()
    for _ in range(iterations):
        if valid.all():
            break
        acc = np.zeros_like(out)
        cnt = np.zeros(seed_mask.shape, dtype=np.float32)
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
    return out, valid


def chroma_key_magenta(rgb_u8: np.ndarray) -> np.ndarray:
    """Chroma key #FF00FF with local-foreground color-line soft keying and despill.

    Because warm/olive/yellow foliage has B << G, even 30% magenta contamination can have
    min(R, B) - G near 0 while appearing salmon/pink. Estimating the clean local foreground
    color F_est from nearby uncontaminated core pixels lets us solve C = a*F + (1-a)*M
    accurately across rocks, shrubs, thin golden grass blades, and red/white flowers.
    """
    rgb = rgb_u8.astype(np.float32) / 255.0
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]

    mag_key = np.array([1.0, 0.0, 1.0], dtype=np.float32)
    mag_excess = np.minimum(r, b) - g
    dist_mag = np.sqrt((r - 1.0) ** 2 + g ** 2 + (b - 1.0) ** 2)

    # 1. Definite background (pure or near-pure magenta).
    sure_bg = (mag_excess >= 0.55) | (dist_mag <= 0.30)

    # 2. Definite clean (uncontaminated) foreground core:
    #    - Strictly negative magenta excess (B < G or R < G) and not immediately touching sure_bg.
    #    - Bright neutral whites (e.g. white flower petals) allowed up to mag_excess <= 0.02.
    near_bg = _dilate_mask(sure_bg, radius=2)
    bright_white = (r > 0.72) & (g > 0.70) & (b > 0.65) & (mag_excess <= 0.02)
    clean_core = ((mag_excess <= -0.04) & (~near_bg)) | (bright_white & (~sure_bg))
    # Also ensure thick dark interiors far from background stay in clean_core.
    far_from_bg = ~_dilate_mask(sure_bg, radius=6)
    clean_core = clean_core | (far_from_bg & (mag_excess <= 0.02))

    # 3. Propagate clean foreground colors outward across the spill/edge transition band.
    f_est, f_valid = _propagate_rgb(rgb, clean_core, iterations=18)

    # 4. Compute matte fraction (1 - alpha) by projecting C onto the segment F_est -> M = (1, 0, 1).
    v = mag_key[None, None, :] - f_est
    v_dot = np.maximum(np.sum(v * v, axis=2), 1e-4)
    c_minus_f = rgb - f_est
    t_proj = np.clip(np.sum(c_minus_f * v, axis=2) / v_dot, 0.0, 1.0)

    # Orthogonal distance from C to the F_est -> M mixing line (small when C is truly F + magenta).
    recon = f_est + t_proj[:, :, None] * v
    ortho_err = np.sqrt(np.sum((rgb - recon) ** 2, axis=2))

    # Fallback global soft key for any pixel far from clean_core (e.g. isolated 1-2 px tip).
    t_global = np.clip((mag_excess - 0.02) / (0.48 - 0.02), 0.0, 1.0)

    # Apply the color-line matte wherever a pixel is near background or exhibits magenta spill,
    # and its blue channel is pulled up toward magenta relative to the clean local foreground.
    spill_zone = _dilate_mask(sure_bg, radius=7) | (mag_excess > 0.0)
    pulled_toward_magenta = (b > f_est[:, :, 2] + 0.04) & (g < f_est[:, :, 1] - 0.01) & (ortho_err < 0.35)
    use_line = spill_zone & f_valid & (pulled_toward_magenta | (mag_excess > 0.0))

    matte = np.where(sure_bg, 1.0, 0.0)
    matte = np.where((~sure_bg) & (~clean_core) & use_line, np.maximum(t_proj, t_global), matte)
    matte = np.where((~sure_bg) & (~clean_core) & (~use_line), t_global, matte)

    # Gentle dead-zone on tiny matte noise (< 0.06) and clean snap at high matte (> 0.94).
    matte = np.clip((matte - 0.05) / (0.94 - 0.05), 0.0, 1.0)
    alpha = 1.0 - matte
    alpha = np.where(alpha < 0.02, 0.0, alpha)
    alpha = np.where(alpha > 0.99, 1.0, alpha)

    # 5. Despill & foreground color recovery:
    #    Unmix C = a*F + (1-a)*M where alpha is moderate, and smoothly blend toward clean F_est
    #    as magenta contamination rises (prevents pink/salmon tips on thin grass blades and twigs).
    out_rgb = rgb.copy()
    contaminated = (alpha > 0.0) & ((alpha < 0.99) | (use_line & (t_proj > 0.08)))
    a_safe = np.maximum(alpha, 0.25)
    unmixed = np.clip((rgb - (1.0 - alpha)[:, :, None] * mag_key[None, None, :]) / a_safe[:, :, None], 0.0, 1.0)

    # Blend weight toward clean F_est rises with magenta spill strength.
    blend_f = np.clip(np.maximum(1.0 - alpha, t_proj) * 1.45, 0.0, 1.0)
    recovered = np.where(
        f_valid[:, :, None],
        (1.0 - blend_f[:, :, None]) * unmixed + blend_f[:, :, None] * f_est,
        unmixed,
    )
    out_rgb = np.where(contaminated[:, :, None], recovered, out_rgb)

    # 6. Final residual magenta clamp on boundary band (guarantees zero pink/purple halo).
    edge_band = _dilate_mask(alpha < 0.98, radius=4) & (alpha > 0.0)
    er, eg, eb = out_rgb[:, :, 0], out_rgb[:, :, 1], out_rgb[:, :, 2]
    res_spill = np.maximum(0.0, np.minimum(er, eb) - eg)
    out_rgb[:, :, 2] = np.where(edge_band, np.clip(eb - res_spill, 0.0, 1.0), eb)
    r_trim = res_spill * np.clip(1.0 - np.maximum(0.0, er - eb) * 1.2, 0.0, 1.0)
    out_rgb[:, :, 0] = np.where(edge_band, np.clip(er - r_trim, 0.0, 1.0), er)

    # 7. Bleed clean foreground RGB into transparent pixels so Godot's bilinear/mipmap filter
    #    never samples magenta from alpha == 0 texels.
    out_rgb, _ = _propagate_rgb(out_rgb, alpha >= 0.30, iterations=10)

    rgba = np.empty((rgb_u8.shape[0], rgb_u8.shape[1], 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(np.round(out_rgb * 255.0), 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(np.round(alpha * 255.0), 0, 255).astype(np.uint8)
    return rgba


def _sort_reading_order(items: list[dict]) -> list[dict]:
    """Group bounding boxes into horizontal rows (by Y overlap) and sort left-to-right."""
    if not items:
        return []
    by_top = sorted(items, key=lambda d: d["y0"])
    rows: list[list[dict]] = []
    for item in by_top:
        placed = False
        for row in rows:
            row_y0 = min(r["y0"] for r in row)
            row_y1 = max(r["y1"] for r in row)
            overlap = min(row_y1, item["y1"]) - max(row_y0, item["y0"])
            min_h = min(row_y1 - row_y0 + 1, item["y1"] - item["y0"] + 1)
            if overlap > 0.25 * min_h:
                row.append(item)
                placed = True
                break
        if not placed:
            rows.append([item])

    rows.sort(key=lambda row: sum(r["cy"] for r in row) / len(row))
    ordered: list[dict] = []
    for row in rows:
        row.sort(key=lambda r: r["x0"])
        ordered.extend(row)
    return ordered


def cut_sheet(
    sheet_path: Path,
    out_dir: Path,
    pad: int = 8,
    group_radius: int = 12,
    min_area: int = 400,
) -> list[Path]:
    """Key, despill, segment, pad, and write prop_01.png..prop_NN.png."""
    im = Image.open(sheet_path).convert("RGB")
    rgb_u8 = np.array(im)
    rgba = chroma_key_magenta(rgb_u8)

    fg_mask = rgba[:, :, 3] >= 16
    grouped_mask = _dilate_mask(fg_mask, radius=group_radius)
    labels, count = _label_connected_components(grouped_mask)

    components: list[dict] = []
    for cid in range(1, count + 1):
        comp_mask = (labels == cid) & fg_mask
        area = int(comp_mask.sum())
        if area < min_area:
            continue
        ys, xs = np.where(comp_mask)
        y0, y1 = int(ys.min()), int(ys.max())
        x0, x1 = int(xs.min()), int(xs.max())
        components.append(
            {
                "cid": cid,
                "area": area,
                "x0": x0,
                "y0": y0,
                "x1": x1,
                "y1": y1,
                "cy": 0.5 * (y0 + y1),
            }
        )

    components = _sort_reading_order(components)
    out_dir.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    for idx, comp in enumerate(components, start=1):
        cid = comp["cid"]
        x0, y0, x1, y1 = comp["x0"], comp["y0"], comp["x1"], comp["y1"]
        crop_w = (x1 - x0 + 1) + 2 * pad
        crop_h = (y1 - y0 + 1) + 2 * pad

        sub_rgba = rgba[y0 : y1 + 1, x0 : x1 + 1].copy()
        sub_lbl = labels[y0 : y1 + 1, x0 : x1 + 1]
        sub_rgba[sub_lbl != cid, 3] = 0

        canvas = np.zeros((crop_h, crop_w, 4), dtype=np.uint8)
        canvas[pad : pad + (y1 - y0 + 1), pad : pad + (x1 - x0 + 1)] = sub_rgba
        c_rgb = canvas[:, :, :3].astype(np.float32) / 255.0
        c_a = canvas[:, :, 3].astype(np.float32) / 255.0
        c_rgb, _ = _propagate_rgb(c_rgb, c_a >= 0.25, iterations=max(pad, 4))
        canvas[:, :, :3] = np.clip(np.round(c_rgb * 255.0), 0, 255).astype(np.uint8)

        out_path = out_dir / f"prop_{idx:02d}.png"
        Image.fromarray(canvas, mode="RGBA").save(out_path)
        written.append(out_path)
        print(
            f"Wrote {out_path.name}: {crop_w}x{crop_h} "
            f"(bbox {x0},{y0}..{x1},{y1}, area={comp['area']})"
        )

    return written


def main() -> None:
    default_out = Path(__file__).resolve().parent.parent / "assets"
    parser = argparse.ArgumentParser(description="Cut a #FF00FF magenta prop sheet into transparent PNGs.")
    parser.add_argument("sheet", type=Path, help="Path to magenta-keyed prop sheet PNG.")
    parser.add_argument("--out-dir", type=Path, default=default_out, help="Output directory (default: assets/).")
    parser.add_argument("--pad", type=int, default=8, help="Transparent border padding in pixels (default: 8).")
    parser.add_argument(
        "--group-radius",
        type=int,
        default=12,
        help="Dilation radius in pixels for grouping scattered fragments into one prop (default: 12).",
    )
    parser.add_argument("--min-area", type=int, default=400, help="Minimum foreground pixel area (default: 400).")
    args = parser.parse_args()

    written = cut_sheet(
        sheet_path=args.sheet,
        out_dir=args.out_dir,
        pad=args.pad,
        group_radius=args.group_radius,
        min_area=args.min_area,
    )
    print(f"Done: extracted {len(written)} props to {args.out_dir}")


if __name__ == "__main__":
    main()
