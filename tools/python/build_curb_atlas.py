"""Cut a ChatGPT curb-face sheet into pixel texture atlases for the 3D curb blocks.

Input: one image with six curb stones seen from above (top row) and the same six from the side (bottom
row) on a flat background (assets/source_inputs/curb_faces_gpt.webp). For each stone:
  1. find the face by keying the background, fill the rounded corners with the stone's own colours
     (the 3D block is square-cornered; Blender's bevel rounds it),
  2. resample the top to the block's top (LENGTH x WIDTH), the side to its long sides (LENGTH x HEIGHT)
     and a slice of the side to its ends (WIDTH x HEIGHT), all at 64 texels per metre,
  3. reduce colours: 'gpt' keeps the sheet's own 24 colours (the art_gpt look), 'goal' maps onto the
     shared 48-colour goal palette (the B64 look),
  4. pack all faces into one atlas with 2-texel edge padding (nearest filtering, mipmaps stay clean),
     plus a normal map from the pixel luminance, and write the face rectangles to curb_atlas.json for
     tools/blender/build_curb_blocks.py.

  C:/Python312/python.exe tools/python/build_curb_atlas.py assets/source_inputs/curb_faces_gpt.webp
"""
import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel_snap import GOAL_PALETTE, IMPORT_STUB, normal_map  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "textures" / "curbs"
DENSITY = 64.0
# Block size in metres: the top face's 1.87:1 ratio sets length to width; the height is a low curb.
LENGTH, WIDTH, HEIGHT = 0.72, 0.39, 0.22
PAD = 2


def texels(metres: float) -> int:
    return max(1, round(metres * DENSITY))


def faces(sheet: np.ndarray, bg: np.ndarray):
    mask = (np.abs(sheet.astype(int) - bg).sum(axis=2) > 60).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    boxes = [tuple(stats[i][:4]) for i in range(1, n) if stats[i][4] > 2000]
    centres = [y + h / 2 for _, y, _, h in boxes]
    split = (min(centres) + max(centres)) / 2  # top row above, side row below
    top = sorted((b for b, c in zip(boxes, centres) if c < split), key=lambda b: b[0])
    side = sorted((b for b, c in zip(boxes, centres) if c >= split), key=lambda b: b[0])
    if len(top) != len(side):
        raise SystemExit(f"Found {len(top)} top faces and {len(side)} side faces; expected matching rows.")
    return top, side, mask


def cut(sheet: np.ndarray, mask: np.ndarray, box) -> np.ndarray:
    x, y, w, h = box
    face = sheet[y:y + h, x:x + w].copy()
    # Background plus the anti-aliased fringe next to it (purple-tinted) is refilled from the stone inside.
    hole = cv2.dilate((1 - mask[y:y + h, x:x + w]).astype(np.uint8), np.ones((7, 7), np.uint8)) * 255
    return cv2.inpaint(face, hole, 5, cv2.INPAINT_TELEA) if hole.any() else face


def resample(face: np.ndarray, size) -> np.ndarray:
    return np.asarray(Image.fromarray(face).resize(size, Image.BOX))


def reduce(rgb: np.ndarray, palette_img: Image.Image) -> np.ndarray:
    q = Image.fromarray(rgb).quantize(palette=palette_img, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB"))


def save(array: np.ndarray, path: Path) -> None:
    Image.fromarray(array, "RGB").save(path)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sheet", type=Path)
    args = parser.parse_args()

    sheet = np.asarray(Image.open(args.sheet).convert("RGB"))
    bg = np.median(sheet[:40, :40].reshape(-1, 3), axis=0)
    top_boxes, side_boxes, mask = faces(sheet, bg)
    tw, tl, th = texels(WIDTH), texels(LENGTH), texels(HEIGHT)
    col_w = tl + 2 * PAD
    rects, pieces = [], []
    for i, (tb, sb) in enumerate(zip(top_boxes, side_boxes)):
        top = resample(cut(sheet, mask, tb), (tw, tl))              # long axis vertical, as drawn
        side_src = cut(sheet, mask, sb)
        side = resample(side_src, (tl, th))
        # Ends: the left third of the side face (its eroded corner reads as the block's end).
        end = resample(side_src[:, : max(8, side_src.shape[1] // 3)], (tw, th))
        x0 = i * col_w + PAD
        rows = {"top": (x0, PAD, tw, tl), "side": (x0, tl + 3 * PAD, tl, th), "end": (x0, tl + th + 5 * PAD, tw, th)}
        rects.append(rows)
        pieces.append({"top": top, "side": side, "end": end})
    atlas_w = len(rects) * col_w
    atlas_h = tl + 2 * th + 6 * PAD
    print(f"{len(rects)} stones; block {LENGTH} x {WIDTH} x {HEIGHT} m = top {tw}x{tl}, side {tl}x{th}, "
          f"end {tw}x{th} texels; atlas {atlas_w}x{atlas_h}")

    all_faces = np.concatenate([p[k].reshape(-1, 3) for p in pieces for k in p])
    gpt_palette = Image.fromarray(all_faces[None, :, :]).quantize(colors=24, method=Image.Quantize.MEDIANCUT, kmeans=4)
    goal_palette = Image.open(GOAL_PALETTE).convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, palette in (("gpt", gpt_palette), ("goal", goal_palette)):
        atlas = np.zeros((atlas_h, atlas_w, 3), np.uint8)
        normal = np.zeros((atlas_h, atlas_w, 3), np.uint8)
        normal[:] = (128, 128, 255)
        for rect, piece in zip(rects, pieces):
            for key, (x, y, w, h) in rect.items():
                # The goal look maps the sheet's own 24 colours onto the goal palette, one to one, so the
                # stones keep their clean shapes instead of breaking into speckles between two goal colours.
                rgb = reduce(piece[key], gpt_palette)
                if name == "goal":
                    rgb = reduce(rgb, palette)
                lum = rgb.astype(float) @ np.array([0.299, 0.587, 0.114]) / 255.0
                nrm = normal_map(lum, 2.0)
                # Edge padding: repeat the border texels so mipmaps and nearest sampling never see black.
                atlas[y - PAD:y + h + PAD, x - PAD:x + w + PAD] = np.pad(rgb, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge")
                normal[y - PAD:y + h + PAD, x - PAD:x + w + PAD] = np.pad(nrm, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge")
        save(atlas, OUT / f"curb_atlas_{name}.png")
        save(normal, OUT / f"curb_atlas_{name}_normal.png")
        print(f"Wrote curb_atlas_{name}.png ({len(np.unique(atlas.reshape(-1, 3), axis=0))} colours) and its normal map")
    layout = {"source": args.sheet.name, "density": DENSITY, "block_m": [LENGTH, WIDTH, HEIGHT],
              "atlas_px": [atlas_w, atlas_h], "stones": rects}
    (OUT / "curb_atlas.json").write_text(json.dumps(layout, indent=2) + "\n", encoding="utf-8", newline="\n")
    preview = ROOT / "tmp" / "curb_atlas_preview.png"
    preview.parent.mkdir(exist_ok=True)
    a = Image.open(OUT / "curb_atlas_gpt.png")
    b = Image.open(OUT / "curb_atlas_goal.png")
    sheet_img = Image.new("RGB", (atlas_w, atlas_h * 2 + 4))
    sheet_img.paste(a, (0, 0))
    sheet_img.paste(b, (0, atlas_h + 4))
    sheet_img.resize((atlas_w * 4, (atlas_h * 2 + 4) * 4), Image.NEAREST).save(preview)
    print(f"Preview: {preview}")


if __name__ == "__main__":
    main()
