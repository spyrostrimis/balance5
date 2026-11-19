"""Turn an AI-generated "pixel-art" image into a true pixel texture for the canyon A/B scene.

Image models draw pixel art with blocks of uneven size, slightly off-grid, soft edges and too many
colours. This tool:
  1. detects the drawn pixel grid (cell size and offset, separately for X and Y),
  2. samples one colour per cell (median of the cell's centre),
  3. reduces colours (adaptive, or onto a palette image you supply),
  4. handles transparency for sprites (existing alpha or a keyed background colour),
  5. derives a normal map (and an ORM map for the cobbles) from an aligned height image (--height)
     or, without one, from the pixel luminance,
  6. writes everything to assets/textures/pixel_ab/art/ with lossless Godot import settings and
     records the exact size in metres in manifest.json, so the A/B scene maps it at --density.
Then open the A/B scene (Developers Page -> HD-2D Pixel A/B) and press 4.

Examples (from the project root):
  C:/Python312/python.exe tools/python/pixel_snap.py strata  path/to/gpt_strata.png
  C:/Python312/python.exe tools/python/pixel_snap.py cobble  path/to/gpt_cobbles.png --colors 20
  C:/Python312/python.exe tools/python/pixel_snap.py bush_sage path/to/gpt_bush.png --key auto
  C:/Python312/python.exe tools/python/pixel_snap.py strata  in.png --dry-run      (only report the grid)
  C:/Python312/python.exe tools/python/pixel_snap.py strata  in.png --cell 7.5     (override detection)
  C:/Python312/python.exe tools/python/pixel_snap.py cobble  in.png --height in_height.png --set art_gpt

Each --set folder (art, art_gpt, art_perchance, ...) is one selectable set in the A/B scene: press 4 again
to cycle through them. tools/python/smooth_texture.py processes the same image the high-resolution way
(sets named hr*, key 5) for a procedure-against-procedure comparison.

Roles and target sizes are listed in docs/PIXEL_TEXTURE_PROMPTS.md.
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SETS = ROOT / "assets" / "textures" / "pixel_ab"
PREVIEWS = ROOT / "tmp" / "pixel_snap"

# role -> (game file name, kind, extra maps, intended coverage in metres)
ROLES = {
    "strata": ("d_sandstone_strata_albedo.png", "texture", ["normal"], (2.0, 1.0)),
    "slate": ("d_basalt_cap_albedo.png", "texture", ["normal"], (1.0, 1.0)),
    "cobble": ("chatgpt_cobble_albedo.png", "texture", ["normal", "orm"], (3.0, 3.0)),
    "sand": ("hd2d_sand_albedo.png", "texture", ["normal"], (2.0, 2.0)),
    "dune": ("pure_dune_sand_albedo.png", "texture", ["normal"], (2.0, 2.0)),
    "boulder": ("d_boulder_rock_albedo.png", "texture", ["normal"], (1.0, 1.0)),
    "ai_boulder": ("chatgpt_sandstone_albedo.png", "texture", ["normal", "orm"], (1.5, 1.5)),
    "bush_cluster": ("hd2d_bush_cluster.png", "sprite", [], (0.9, 0.7)),
    "bush_sage": ("d_sage_bush_2.png", "sprite", [], (0.9, 0.7)),
}
IMPORT_STUB = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=true
detect_3d/compress_to=0
"""


def edge_profile(rgb: np.ndarray, axis: int) -> np.ndarray:
    """Mean colour change between neighbouring columns (axis=1) or rows (axis=0)."""
    diff = np.abs(np.diff(rgb, axis=axis)).sum(axis=2)
    return diff.mean(axis=0 if axis == 1 else 1)


def detect_grid(profile: np.ndarray, min_cell: float, max_cell: float):
    """Find the cell size and offset whose boundaries capture the colour changes best.

    Score = share of the edge energy that falls within one pixel of the grid lines, minus the share of
    positions those lines cover. The true grid captures nearly all energy with few lines. Multiples of it
    miss boundaries; fractions of it cover more positions for no extra energy. Flat runs of colour (which
    hide many real boundaries) therefore do not pull the answer towards multiples.
    """
    n = profile.size
    energy = np.maximum(profile - np.median(profile), 0.0)
    total = energy.sum()
    if total <= 0:
        raise RuntimeError("image has no edges")
    best = (-1.0, min_cell, 0.0)
    for cell in np.arange(min_cell, max_cell + 1e-6, 0.02):
        for phase in np.arange(0.0, cell, 0.25):
            # A boundary before image column b is index b-1 of the diff profile.
            idx = np.round(np.arange(phase, n + 1, cell)).astype(int) - 1
            mask = np.zeros(n, bool)
            for offset in (-1, 0, 1):
                j = idx + offset
                mask[j[(j >= 0) & (j < n)]] = True
            score = energy[mask].sum() / total - mask.mean()
            if score > best[0]:
                best = (score, cell, phase)
    return float(best[1]), float(best[2]), float(best[0])


def first_line(phase: float, cell: float) -> float:
    """Earliest grid line, so the first cell is not lost when no edge marks the image border."""
    start = phase % cell
    return start - cell if start > cell * 0.5 else start


def sample_cells(rgba: np.ndarray, cell_x, phase_x, cell_y, phase_y) -> np.ndarray:
    h, w, _ = rgba.shape
    xs = np.arange(first_line(phase_x, cell_x), w - cell_x * 0.5, cell_x)
    ys = np.arange(first_line(phase_y, cell_y), h - cell_y * 0.5, cell_y)
    out = np.zeros((len(ys), len(xs), 4), dtype=np.uint8)
    mx, my = cell_x * 0.25, cell_y * 0.25
    for j, y0 in enumerate(ys):
        for i, x0 in enumerate(xs):
            ya, yb = max(int(round(y0 + my)), 0), min(int(round(y0 + cell_y - my)), h)
            xa, xb = max(int(round(x0 + mx)), 0), min(int(round(x0 + cell_x - mx)), w)
            block = rgba[ya:max(yb, ya + 1), xa:max(xb, xa + 1)]
            out[j, i] = np.median(block.reshape(-1, 4), axis=0)
    return out


def grid_fit(rgba: np.ndarray, cells: np.ndarray, cell_x, phase_x, cell_y, phase_y) -> float:
    """Share of cell interiors (away from the blurred boundaries) that match their cell's colour.

    True pixel art, even soft and JPEG-compressed, scores above about 0.9. A painted or photographic image
    scores far lower: the "grid" found in it is arbitrary and snapping it is only a resample.
    """
    rgb = rgba[:, :, :3].astype(float)
    h, w = rgb.shape[:2]
    x0, y0 = first_line(phase_x, cell_x), first_line(phase_y, cell_y)
    ix = np.clip(((np.arange(w) - x0) // cell_x).astype(int), 0, cells.shape[1] - 1)
    iy = np.clip(((np.arange(h) - y0) // cell_y).astype(int), 0, cells.shape[0] - 1)
    err = np.abs(cells[iy][:, ix, :3].astype(float) - rgb).mean(axis=2)
    fx, fy = (np.arange(w) - x0) % cell_x, (np.arange(h) - y0) % cell_y
    inner = ((fx > 1.5) & (fx < cell_x - 1.5))[None, :] & ((fy > 1.5) & (fy < cell_y - 1.5))[:, None]
    return float((err[inner] < 8).mean()) if inner.any() else 0.0


def load_height(path: Path, size: tuple, albedo_rgb: np.ndarray) -> np.ndarray:
    """Grey height image at the albedo's source size, with a warning when it does not line up."""
    height = Image.open(path).convert("L")
    if height.size != size:
        print(f"Height {height.width}x{height.height} resized to the albedo's {size[0]}x{size[1]}.")
        height = height.resize(size, Image.LANCZOS)
    h = np.asarray(height).astype(float)
    lum = albedo_rgb @ np.array([0.299, 0.587, 0.114])
    gh, ga = np.hypot(*np.gradient(h)), np.hypot(*np.gradient(lum))
    corr = float(np.corrcoef(gh.ravel(), ga.ravel())[0, 1])
    print(f"Height alignment (edge correlation with the albedo): {corr:+.2f}")
    if corr < 0.3:
        print("WARNING: the height image does not line up with the albedo (below +0.30). It is probably a "
              "different generation; ask for the height as an edit of this exact image, or drop --height.")
    return h


def quantize(rgba: np.ndarray, colors: int, palette_path) -> np.ndarray:
    rgb = Image.fromarray(rgba[:, :, :3], "RGB")
    if palette_path:
        pal = Image.open(palette_path).convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT)
        q = rgb.quantize(palette=pal, dither=Image.Dither.NONE)
    else:
        q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE)
    out = rgba.copy()
    out[:, :, :3] = np.asarray(q.convert("RGB"))
    return out


def key_alpha(rgba: np.ndarray, key: str, threshold: float) -> np.ndarray:
    out = rgba.copy()
    if key == "none":
        out[:, :, 3] = np.where(rgba[:, :, 3] >= 128, 255, 0)
        return out
    if key == "auto":
        corners = np.array([rgba[0, 0, :3], rgba[0, -1, :3], rgba[-1, 0, :3], rgba[-1, -1, :3]], dtype=float)
        colour = np.median(corners, axis=0)
    else:
        colour = {"green": (0, 255, 0), "magenta": (255, 0, 255), "white": (255, 255, 255), "black": (0, 0, 0)}[key]
    distance = np.linalg.norm(rgba[:, :, :3].astype(float) - np.array(colour, dtype=float), axis=2)
    out[:, :, 3] = np.where((distance > threshold) & (rgba[:, :, 3] >= 128), 255, 0)
    return out


def trim(rgba: np.ndarray, margin: int = 1) -> np.ndarray:
    ys, xs = np.nonzero(rgba[:, :, 3])
    if ys.size == 0:
        raise SystemExit("Nothing left after keying the background; check --key / --key-threshold.")
    y0, y1 = max(ys.min() - margin, 0), min(ys.max() + margin + 1, rgba.shape[0])
    x0, x1 = max(xs.min() - margin, 0), min(xs.max() + margin + 1, rgba.shape[1])
    return rgba[y0:y1, x0:x1]


def luminance(rgb: np.ndarray) -> np.ndarray:
    return (rgb[:, :, :3].astype(float) @ np.array([0.299, 0.587, 0.114])) / 255.0


def normal_map(h: np.ndarray, strength: float) -> np.ndarray:
    """Normal map from a 0..1 height field (luminance of the cells when there is no height image)."""
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    n = np.dstack([-dx * strength, dy * strength, np.ones_like(h)])  # OpenGL / Godot convention (green up)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).round().astype(np.uint8)


def orm_map(h: np.ndarray) -> np.ndarray:
    lum = (h - h.min()) / max(h.max() - h.min(), 1e-6)
    ao = 0.45 + 0.55 * lum          # dark joints read as cavities
    rough = 0.95 - 0.4 * lum        # bright crowns a little smoother
    return (np.dstack([ao, rough, np.zeros_like(lum)]) * 255).round().astype(np.uint8)


def seam_ratio(rgb: np.ndarray, axis: int) -> float:
    a = rgb[:, :, :3].astype(float)
    inner = np.abs(np.diff(a, axis=axis)).mean()
    wrap = np.abs((a[:, 0] - a[:, -1]) if axis == 1 else (a[0] - a[-1])).mean()
    return wrap / max(inner, 1e-6)


def save_png(array: np.ndarray, path: Path, mode: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(array, mode).save(path)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("role", choices=sorted(ROLES))
    parser.add_argument("image", type=Path)
    parser.add_argument("--density", type=float, default=64.0, help="texels per metre in the game (default 64)")
    parser.add_argument("--cell", type=float, help="force the drawn pixel size in source pixels (both axes)")
    parser.add_argument("--non-square", action="store_true",
                        help="keep separate X/Y cell sizes (default: pixels are square, the axis with long flat runs borrows the other's size)")
    parser.add_argument("--min-cell", type=float, default=2.0)
    parser.add_argument("--max-cell", type=float, default=32.0)
    parser.add_argument("--colors", type=int, default=24, help="colours after reduction (default 24)")
    parser.add_argument("--palette", type=Path, help="map onto the colours of this image instead")
    parser.add_argument("--key", default="auto", choices=["auto", "none", "green", "magenta", "white", "black"],
                        help="sprites: background colour to remove (default: corner colour); 'none' uses alpha")
    parser.add_argument("--key-threshold", type=float, default=70.0)
    parser.add_argument("--height", type=Path, help="grey height image aligned with the albedo (white = raised); "
                        "drives the normal and ORM maps instead of the luminance")
    parser.add_argument("--normal-strength", type=float, default=2.0)
    parser.add_argument("--set", default="art",
                        help="output folder under assets/textures/pixel_ab, starting with 'art' (default art)")
    parser.add_argument("--dry-run", action="store_true", help="only report the detected grid")
    args = parser.parse_args()
    if not args.set.startswith("art"):
        parser.error("--set must start with 'art' (the A/B scene lists pixel sets by that prefix)")

    file_name, kind, extras, coverage = ROLES[args.role]
    source = Image.open(args.image).convert("RGBA")
    rgba = np.asarray(source)
    rgb = rgba[:, :, :3].astype(float)
    if args.cell:
        cell_x = cell_y = args.cell
        phase_x = detect_grid(edge_profile(rgb, 1), args.cell, args.cell)[1]
        phase_y = detect_grid(edge_profile(rgb, 0), args.cell, args.cell)[1]
        score_x = score_y = float("nan")
    else:
        profile_x, profile_y = edge_profile(rgb, 1), edge_profile(rgb, 0)
        cell_x, phase_x, score_x = detect_grid(profile_x, args.min_cell, args.max_cell)
        cell_y, phase_y, score_y = detect_grid(profile_y, args.min_cell, args.max_cell)
        small, large = sorted((cell_x, cell_y))
        ratio = large / small
        if not args.non_square and ratio > 1.03 and abs(ratio - round(ratio)) < 0.06 * round(ratio):
            # One axis only shows every k-th boundary (flat runs). Use the finer cell on both axes.
            if cell_x > cell_y:
                cell_x, phase_x, score_x = detect_grid(profile_x, cell_y, cell_y)
            else:
                cell_y, phase_y, score_y = detect_grid(profile_y, cell_x, cell_x)
    cells = sample_cells(rgba, cell_x, phase_x, cell_y, phase_y)
    print(f"{args.image.name}: {source.width}x{source.height} px | drawn pixel {cell_x:.2f} x {cell_y:.2f} "
          f"(offset {phase_x:.2f}, {phase_y:.2f}; edge contrast {score_x:.2f}, {score_y:.2f}) -> "
          f"{cells.shape[1]} x {cells.shape[0]} cells")
    fit = grid_fit(rgba, cells, cell_x, phase_x, cell_y, phase_y)
    print(f"Grid fit: {fit:.0%} of cell interiors are flat colour.")
    if fit < 0.85:
        print("WARNING: this image is not pixel art on a regular grid (below 85%). The snap below is only a "
              "resample and will look smeared. Regenerate as pixel art, or use tools/python/smooth_texture.py.")
    if kind == "texture":
        span = (cells.shape[1] / args.density, cells.shape[0] / args.density)
        print(f"At {args.density:g}/m one repeat covers {span[0]:.2f} x {span[1]:.2f} m "
              f"(intended about {coverage[0]:g} x {coverage[1]:g} m).")
        ratios = (span[0] / coverage[0], span[1] / coverage[1])
        if max(ratios) > 1.6 or min(ratios) < 0.6:
            print("WARNING: everything drawn in the image (stones, beds, cracks) will appear that much larger or "
                  "smaller than designed. Check the feature size in the 3x3 preview, or regenerate.")
    if args.dry_run:
        return

    if kind == "sprite":
        cells = key_alpha(cells, args.key, args.key_threshold)
        cells = trim(cells)
    cells = quantize(cells, args.colors, args.palette)
    if kind == "sprite":
        cells[cells[:, :, 3] == 0, :3] = 0
    h, w = cells.shape[:2]
    metres = [round(w / args.density, 4), round(h / args.density, 4)]

    heights = None
    if args.height and kind == "texture":
        h_src = load_height(args.height, source.size, rgb)
        h_rgba = np.dstack([h_src, h_src, h_src, np.full_like(h_src, 255)]).astype(np.uint8)
        heights = sample_cells(h_rgba, cell_x, phase_x, cell_y, phase_y)[:, :, 0].astype(float) / 255.0
    relief = heights if heights is not None else luminance(cells)

    out_dir = SETS / args.set
    if kind == "sprite":
        save_png(cells, out_dir / file_name, "RGBA")
    else:
        save_png(np.ascontiguousarray(cells[:, :, :3]), out_dir / file_name, "RGB")
        if "normal" in extras:
            save_png(normal_map(relief, args.normal_strength), out_dir / file_name.replace("_albedo", "_normal"), "RGB")
        if "orm" in extras:
            save_png(orm_map(relief), out_dir / file_name.replace("_albedo", "_orm"), "RGB")
        print(f"Seam ratio (wrap / inner change): X {seam_ratio(cells, 1):.2f}, Y {seam_ratio(cells, 0):.2f}. "
              "Above about 1.5 the repeat will show; fix the edges in Aseprite's tiled mode.")

    manifest_path = out_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest.setdefault("textures", {})[file_name] = {
        "role": args.role, "cells": [w, h], "density": args.density, "metres": metres,
        "procedure": "pixel_snap", "source": args.image.name, "height": args.height.name if heights is not None else None,
        "drawn_pixel": [round(cell_x, 2), round(cell_y, 2)], "grid_fit": round(fit, 3),
        "colors": len(np.unique(cells[:, :, :3].reshape(-1, 3), axis=0)),
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")

    PREVIEWS.mkdir(parents=True, exist_ok=True)
    scale = max(1, 512 // max(w, h))
    big = Image.fromarray(cells).resize((w * scale, h * scale), Image.NEAREST)
    big.save(PREVIEWS / f"{args.role}_x{scale}.png")
    if kind == "texture":
        tile = Image.new("RGBA", (w * 3, h * 3))
        for j in range(3):
            for i in range(3):
                tile.paste(Image.fromarray(cells), (i * w, j * h))
        tile.resize((w * 3 * max(1, scale // 2), h * 3 * max(1, scale // 2)), Image.NEAREST).save(PREVIEWS / f"{args.role}_3x3.png")
    print(f"Wrote {out_dir / file_name} ({w}x{h} texels = {metres[0]} x {metres[1]} m at {args.density:g}/m)"
          f" and previews in {PREVIEWS}.\nOpen the A/B scene and press 4 (again to cycle sets) until it shows '{args.set}'.")


if __name__ == "__main__":
    main()
