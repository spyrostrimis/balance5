"""Make the 3D kit road and sand tiles from ChatGPT images, as pixel-art sets for the canyon ground shader.

Inputs (assets/source_inputs/):
  road_cobble_gpt.webp  square cobblestone texture (the new road)
  road_sheet_gpt.webp   the 2D kit road sheet; its left panel is the sand used beside the road
Steps for each image:
  1. make it tile: on both axes the last band of pixels is joined to the first along the path of least
     difference (a minimum-error cut, no blending, so pixel edges stay hard),
  2. area-average to 64 texels per metre (cobble: one repeat = COBBLE_M, sand: SAND_M wide),
  3. reduce to the image's own colours ('gpt', art_gpt look) or map those onto the goal palette ('goal',
     B64 look), and derive normal (and ORM for the cobble) maps from the luminance.
Outputs: two A/B sets, assets/textures/pixel_ab/art_road_gpt/ and art_road_goal/, with manifests. Other
surfaces fall back to B64; art_road_gpt also gets art_gpt's ChatGPT strata so it matches the art_gpt look.

  C:/Python312/python.exe tools/python/build_road_tiles.py
"""
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel_snap import GOAL_PALETTE, IMPORT_STUB, SETS, normal_map, orm_map, seam_ratio  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source_inputs"
DENSITY = 64.0
COBBLE_M = 2.0
SAND_M = 2.0
CUT_BAND = 0.08  # share of the image used as the overlap band for the seam cut


def min_cut_wrap(img: np.ndarray, axis: int) -> np.ndarray:
    """Remove a band from the end of `axis` and join it to the start along a minimum-difference path."""
    a = np.moveaxis(img, axis, 1).astype(np.float32)   # cut runs across columns of `a`
    n = a.shape[1]
    w = max(8, int(n * CUT_BAND))
    tail, head = a[:, n - w:], a[:, :w]
    err = np.abs(tail - head).sum(axis=2)
    cost = err.copy()
    for r in range(1, cost.shape[0]):
        prev = cost[r - 1]
        best = np.minimum(prev, np.minimum(np.r_[np.inf, prev[:-1]], np.r_[prev[1:], np.inf]))
        cost[r] += best
    path = np.zeros(cost.shape[0], int)
    path[-1] = int(np.argmin(cost[-1]))
    for r in range(cost.shape[0] - 2, -1, -1):
        c = path[r + 1]
        lo, hi = max(0, c - 1), min(w, c + 2)
        path[r] = lo + int(np.argmin(cost[r, lo:hi]))
    joined = head.copy()
    for r, c in enumerate(path):
        joined[r, :c] = tail[r, :c]
    out = np.concatenate([joined, a[:, w:n - w]], axis=1)
    return np.moveaxis(out, 1, axis).astype(np.uint8)


def palettes(rgb: np.ndarray):
    own = Image.fromarray(rgb).quantize(colors=24, method=Image.Quantize.MEDIANCUT, kmeans=4)
    goal = Image.open(GOAL_PALETTE).convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    return own, goal


def reduce(rgb, own, goal, look):
    q = Image.fromarray(rgb).quantize(palette=own, dither=Image.Dither.NONE).convert("RGB")
    if look == "goal":
        q = q.quantize(palette=goal, dither=Image.Dither.NONE).convert("RGB")
    return np.asarray(q)


def save(array: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(array, "RGB").save(path)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")


def lum(rgb):
    return rgb.astype(float) @ np.array([0.299, 0.587, 0.114]) / 255.0


def make(img: np.ndarray, width_m: float):
    print(f"  raw seam ratio X {seam_ratio(img.astype(float), 1):.2f}, Y {seam_ratio(img.astype(float), 0):.2f}")
    img = min_cut_wrap(min_cut_wrap(img, 1), 0)
    print(f"  cut seam ratio X {seam_ratio(img.astype(float), 1):.2f}, Y {seam_ratio(img.astype(float), 0):.2f}")
    w = round(width_m * DENSITY)
    h = round(w * img.shape[0] / img.shape[1])
    small = np.asarray(Image.fromarray(img).resize((w, h), Image.BOX))
    return small, [round(w / DENSITY, 4), round(h / DENSITY, 4)]


def main() -> None:
    cobble_src = np.asarray(Image.open(SRC / "road_cobble_gpt.webp").convert("RGB"))
    sheet = np.asarray(Image.open(SRC / "road_sheet_gpt.webp").convert("RGB"))
    frame = sheet[2, 2].astype(int)
    cols = np.where(np.abs(sheet.astype(int) - frame).sum(axis=2).mean(axis=0) < 40)[0]
    rows = np.where(np.abs(sheet.astype(int) - frame).sum(axis=2).mean(axis=1) < 40)[0]
    left_end = int(cols[(cols > 20) & (cols < sheet.shape[1] // 2)].min())
    top = int(rows[rows < sheet.shape[0] // 2].max()) + 1 if (rows < sheet.shape[0] // 2).any() else 0
    bottom = int(rows[rows > sheet.shape[0] // 2].min()) if (rows > sheet.shape[0] // 2).any() else sheet.shape[0]
    inset = 6
    sand_src = sheet[top + inset:bottom - inset, int(cols[cols < 20].max()) + 1 + inset:left_end - inset]
    print(f"Cobble {cobble_src.shape[1]}x{cobble_src.shape[0]} px; sand panel {sand_src.shape[1]}x{sand_src.shape[0]} px")
    print("Cobble:")
    cobble, cobble_m = make(cobble_src, COBBLE_M)
    print("Sand:")
    sand, sand_m = make(sand_src, SAND_M)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    for look in ("gpt", "goal"):
        out = SETS / f"art_road_{look}"
        entries = {}
        own, goal = palettes(cobble)
        c = reduce(cobble, own, goal, look)
        save(c, out / "chatgpt_cobble_albedo.png")
        save(normal_map(lum(c), 2.0), out / "chatgpt_cobble_normal.png")
        save(orm_map(lum(c)), out / "chatgpt_cobble_orm.png")
        entries["chatgpt_cobble_albedo.png"] = {"role": "cobble", "procedure": "road_tiles", "source": "road_cobble_gpt.webp",
                                                "cells": list(c.shape[1::-1]), "metres": cobble_m, "updated": stamp}
        own, goal = palettes(sand)
        s = reduce(sand, own, goal, look)
        save(s, out / "hd2d_sand_albedo.png")
        save(normal_map(lum(s), 1.5), out / "hd2d_sand_normal.png")
        entries["hd2d_sand_albedo.png"] = {"role": "sand", "procedure": "road_tiles", "source": "road_sheet_gpt.webp (left panel)",
                                           "cells": list(s.shape[1::-1]), "metres": sand_m, "updated": stamp}
        if look == "gpt":
            # Match the art_gpt look: its ChatGPT strata on the cliff faces.
            gpt = SETS / "art_gpt"
            manifest = json.loads((gpt / "manifest.json").read_text(encoding="utf-8"))
            for name in ("d_sandstone_strata_albedo.png", "d_sandstone_strata_normal.png"):
                shutil.copyfile(gpt / name, out / name)
                stub = out / (name + ".import")
                if not stub.exists():
                    stub.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")
            entries["d_sandstone_strata_albedo.png"] = manifest["textures"]["d_sandstone_strata_albedo.png"]
        (out / "manifest.json").write_text(json.dumps({"textures": entries}, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"Wrote {out.name}: cobble {c.shape[1]}x{c.shape[0]} texels = {cobble_m} m, sand {s.shape[1]}x{s.shape[0]} = {sand_m} m")
    preview = ROOT / "tmp" / "road_tiles_preview.png"
    a = np.asarray(Image.open(SETS / "art_road_gpt" / "chatgpt_cobble_albedo.png"))
    b = np.asarray(Image.open(SETS / "art_road_goal" / "chatgpt_cobble_albedo.png"))
    Image.fromarray(np.hstack([np.tile(a, (2, 2, 1)), np.tile(b, (2, 2, 1))])).resize((a.shape[1] * 4 * 3, a.shape[0] * 2 * 3), Image.NEAREST).save(preview)
    print(f"Preview (2x2 repeats, gpt | goal): {preview}")


if __name__ == "__main__":
    main()
