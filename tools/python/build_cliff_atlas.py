"""Cut the ChatGPT cliff sheets into pixel textures and block outlines for the 3D cliff kit.

Inputs (assets/source_inputs/):
  cliff_blocks_gpt.webp   six rounded sandstone blocks: tops in the upper row, fronts in the lower row
  cliff_masonry_gpt.webp  two seamless tiles: dry-stone wall face (left) and paved terrace top (right)

Outputs (assets/textures/cliffs/):
  cliff_blocks_{gpt,goal}.png (+ _normal)  atlas with each block's top and its wrapped side
  cliff_wall_{gpt,goal}.png (+ _normal)    dry-stone wall tile, one repeat = TILE_M metres
  cliff_paving_{gpt,goal}.png (+ _normal)  paved terrace tile, one repeat = TILE_M metres
  cliff_blocks.json                        per block: outline polygon in metres, height, atlas rectangles
'gpt' keeps the sheets' own colours (art_gpt look); 'goal' maps them one-to-one onto the shared goal
palette (B64 look). Everything is at 64 texels per metre.

Each block's 3D footprint is the outline of its drawn top, so the model matches the drawing. Scale: one
sheet pixel = SHEET_M metres (the first block is about 1.1 m across and 0.9 m tall). The side texture is
the drawn front, stretched along half the outline (front half) and mirrored back along the other half.

  C:/Python312/python.exe tools/python/build_cliff_atlas.py
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel_snap import GOAL_PALETTE, IMPORT_STUB, normal_map, seam_ratio  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source_inputs"
OUT = ROOT / "assets" / "textures" / "cliffs"
DENSITY = 64.0
SHEET_M = 0.005     # metres per sheet pixel for the blocks
TILE_M = 2.0        # metres per masonry tile repeat
OUTLINE_POINTS = 40
PAD = 2


def components(sheet: np.ndarray, min_area: int):
    bg = np.median(sheet[:30, :30].reshape(-1, 3), axis=0)
    mask = (np.abs(sheet.astype(int) - bg).sum(axis=2) > 60).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    return [tuple(stats[i][:4]) for i in range(1, n) if stats[i][4] > min_area], mask


def cut(sheet, mask, box):
    x, y, w, h = box
    face = sheet[y:y + h, x:x + w].copy()
    hole = cv2.dilate((1 - mask[y:y + h, x:x + w]).astype(np.uint8), np.ones((7, 7), np.uint8)) * 255
    return cv2.inpaint(face, hole, 5, cv2.INPAINT_TELEA), mask[y:y + h, x:x + w]


def outline(face_mask: np.ndarray, box) -> np.ndarray:
    """Footprint polygon in metres (x right, y = up the image = away from the camera), CCW, centred,
    starting at the leftmost point and running along the front (camera) half first."""
    m = cv2.morphologyEx(face_mask, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    contours, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(contours, key=cv2.contourArea)[:, 0, :].astype(float)
    c = cv2.GaussianBlur(c.reshape(-1, 1, 2), (1, 9), 0).reshape(-1, 2) if len(c) > 20 else c
    pts = np.column_stack(((c[:, 0] - box[2] / 2) * SHEET_M, -(c[:, 1] - box[3] / 2) * SHEET_M))
    seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(np.vstack([pts, pts[:1]]), axis=0), axis=1))]
    total = seg[-1]
    even = np.linspace(0, total, OUTLINE_POINTS, endpoint=False)
    closed = np.vstack([pts, pts[:1]])
    poly = np.column_stack([np.interp(even, seg, closed[:, k]) for k in range(2)])
    area = 0.5 * np.sum(poly[:, 0] * np.roll(poly[:, 1], -1) - np.roll(poly[:, 0], -1) * poly[:, 1])
    if area < 0:
        poly = poly[::-1]
    start = int(np.argmin(poly[:, 0]))
    return np.roll(poly, -start, axis=0)


def side_u(poly: np.ndarray) -> list:
    """u along the side texture: 0 -> 1 across the front half (left -> right), then back 1 -> 0."""
    right = int(np.argmax(poly[:, 0]))
    closed = np.vstack([poly, poly[:1]])
    lengths = np.linalg.norm(np.diff(closed, axis=0), axis=1)
    front = np.r_[0, np.cumsum(lengths[:right])]
    back = np.r_[0, np.cumsum(lengths[right:])]
    u = list(front / front[-1])
    u += list(1.0 - back[1:-1] / back[-1])
    return [round(float(v), 4) for v in u], float(max(front[-1], back[-1]))


def resample(rgb: np.ndarray, size) -> np.ndarray:
    return np.asarray(Image.fromarray(rgb).resize(size, Image.BOX))


def palettes(samples: list):
    pixels = np.concatenate([s.reshape(-1, 3) for s in samples])
    own = Image.fromarray(pixels[None, :, :]).quantize(colors=28, method=Image.Quantize.MEDIANCUT, kmeans=4)
    goal = Image.open(GOAL_PALETTE).convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    return own, goal


def reduce(rgb: np.ndarray, own, goal, look: str) -> np.ndarray:
    q = np.asarray(Image.fromarray(rgb).quantize(palette=own, dither=Image.Dither.NONE).convert("RGB"))
    if look == "goal":
        q = np.asarray(Image.fromarray(q).quantize(palette=goal, dither=Image.Dither.NONE).convert("RGB"))
    return q


def save(array: np.ndarray, path: Path) -> None:
    Image.fromarray(array, "RGB").save(path)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")


def lum(rgb):
    return rgb.astype(float) @ np.array([0.299, 0.587, 0.114]) / 255.0


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # --- Blocks ---
    sheet = np.asarray(Image.open(SRC / "cliff_blocks_gpt.webp").convert("RGB"))
    boxes, mask = components(sheet, 3000)
    centres = [y + h / 2 for _, y, _, h in boxes]
    split = (min(centres) + max(centres)) / 2
    tops = sorted((b for b, c in zip(boxes, centres) if c < split), key=lambda b: b[0])
    fronts = sorted((b for b, c in zip(boxes, centres) if c >= split), key=lambda b: b[0])
    assert len(tops) == len(fronts), (len(tops), len(fronts))
    blocks, pieces = [], []
    for tb, fb in zip(tops, fronts):
        top_rgb, top_mask = cut(sheet, mask, tb)
        front_rgb, _ = cut(sheet, mask, fb)
        # Drop the rounded left/right ends of the drawn front: they are refilled background, and the
        # wrapped side meets itself there.
        trim = max(1, round(front_rgb.shape[1] * 0.07))
        front_rgb = front_rgb[:, trim:-trim]
        poly = outline(top_mask, tb)
        u, half = side_u(poly)
        width = tb[2] * SHEET_M
        height = round(fb[3] * SHEET_M * (tb[2] / fb[2]), 3)
        top_px = (max(2, round(tb[2] * SHEET_M * DENSITY)), max(2, round(tb[3] * SHEET_M * DENSITY)))
        side_px = (max(2, round(half * DENSITY)), max(2, round(height * DENSITY)))
        pieces.append({"top": resample(top_rgb, top_px), "side": resample(front_rgb, side_px)})
        blocks.append({"outline_m": [[round(float(x), 4), round(float(y), 4)] for x, y in poly], "side_u": u,
                       "height_m": height, "size_m": [round(width, 3), round(tb[3] * SHEET_M, 3)]})
    # Pack: one column per block, top above side.
    x, rects, atlas_h = PAD, [], 0
    for piece in pieces:
        tw, th = piece["top"].shape[1], piece["top"].shape[0]
        sw, sh = piece["side"].shape[1], piece["side"].shape[0]
        rects.append({"top": [x, PAD, tw, th], "side": [x, th + 3 * PAD, sw, sh]})
        atlas_h = max(atlas_h, th + sh + 4 * PAD)
        x += max(tw, sw) + 2 * PAD
    atlas_w = x
    for block, rect in zip(blocks, rects):
        block.update(rect)
    own, goal = palettes([p[k] for p in pieces for k in p])
    for look in ("gpt", "goal"):
        atlas = np.zeros((atlas_h, atlas_w, 3), np.uint8)
        normal = np.full((atlas_h, atlas_w, 3), (128, 128, 255), np.uint8)
        for piece, rect in zip(pieces, rects):
            for key in ("top", "side"):
                rx, ry, rw, rh = rect[key]
                rgb = reduce(piece[key], own, goal, look)
                atlas[ry - PAD:ry + rh + PAD, rx - PAD:rx + rw + PAD] = np.pad(rgb, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge")
                nrm = normal_map(lum(rgb), 2.0)
                normal[ry - PAD:ry + rh + PAD, rx - PAD:rx + rw + PAD] = np.pad(nrm, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge")
        save(atlas, OUT / f"cliff_blocks_{look}.png")
        save(normal, OUT / f"cliff_blocks_{look}_normal.png")
    print(f"Blocks: {len(blocks)}, atlas {atlas_w}x{atlas_h}; sizes (m): "
          + ", ".join(f"{b['size_m'][0]}x{b['size_m'][1]}x{b['height_m']}" for b in blocks))
    (OUT / "cliff_blocks.json").write_text(json.dumps({"source": "cliff_blocks_gpt.webp", "density": DENSITY,
                                                        "atlas_px": [atlas_w, atlas_h], "blocks": blocks}, indent=1)
                                           + "\n", encoding="utf-8", newline="\n")

    # --- Masonry tiles ---
    sheet = np.asarray(Image.open(SRC / "cliff_masonry_gpt.webp").convert("RGB"))
    boxes, _ = components(sheet, 100000)
    boxes = sorted(boxes, key=lambda b: b[0])
    tiles = {}
    for name, (bx, by, bw, bh) in zip(("wall", "paving"), boxes):
        inset = 4
        crop = sheet[by + inset:by + bh - inset, bx + inset:bx + bw - inset]
        size = round(TILE_M * DENSITY)
        tiles[name] = resample(crop, (size, size))
    own, goal = palettes(list(tiles.values()))
    for name, rgb_src in tiles.items():
        for look in ("gpt", "goal"):
            rgb = reduce(rgb_src, own, goal, look)
            save(rgb, OUT / f"cliff_{name}_{look}.png")
            save(normal_map(lum(rgb), 2.0), OUT / f"cliff_{name}_{look}_normal.png")
        print(f"Tile {name}: {rgb_src.shape[1]} texels = {TILE_M} m; seam ratio X {seam_ratio(rgb_src, 1):.2f}, "
              f"Y {seam_ratio(rgb_src, 0):.2f}")
    preview = ROOT / "tmp" / "cliff_atlas_preview.png"
    a = Image.open(OUT / "cliff_blocks_gpt.png")
    b = Image.open(OUT / "cliff_blocks_goal.png")
    w = Image.new("RGB", (a.width, a.height * 2 + 4))
    w.paste(a, (0, 0))
    w.paste(b, (0, a.height + 4))
    w.resize((w.width * 3, w.height * 3), Image.NEAREST).save(preview)
    print(f"Preview: {preview}")


if __name__ == "__main__":
    main()
