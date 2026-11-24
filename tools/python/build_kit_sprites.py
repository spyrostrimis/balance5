"""Cut the bushes and grass tufts from the ChatGPT props sheet into pixel sprites for the 3D kit canyon.

Input: assets/source_inputs/props_kit_gpt.webp (the 2D kit props sheet: two large and two medium olive
sagebushes, three grass tufts, an archway and four rocks on a dark purple background; only the plants
are used here). Each plant is keyed off the background, scaled to its real size at 64 texels per metre
(the same density as the road, curbs and cliffs), given a hard 1-bit edge, and reduced to the sheet's own
colours ('gpt', art_gpt look) or mapped one-to-one onto the shared goal palette ('goal', B64 look).

Outputs: assets/textures/kit_sprites/<name>_<look>.png and kit_sprites.json (name, kind, metres).

  C:/Python312/python.exe tools/python/build_kit_sprites.py
"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets" / "source_inputs" / "props_kit_gpt.webp"
OUT = ROOT / "assets" / "textures" / "kit_sprites"
DENSITY = 64.0
SPRITE_STUB = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
detect_3d/compress_to=0
"""
# Reading order on the sheet (rows top to bottom, left to right) -> (name, kind, width in metres).
# None skips a piece (archway, rocks).
LAYOUT = [
    [("bush_large_a", "bush", 1.05), ("bush_large_b", "bush", 1.0), None],
    [("bush_med_a", "bush", 0.72), ("bush_med_b", "bush", 0.68), ("grass_large", "grass", 0.55),
     ("grass_med", "grass", 0.42), ("grass_small", "grass", 0.32)],
]


def main() -> None:
    sheet = np.asarray(Image.open(SHEET).convert("RGB"))
    bg = np.median(sheet[:20, :20].reshape(-1, 3), axis=0)
    dist = np.abs(sheet.astype(int) - bg).sum(axis=2)
    mask = cv2.morphologyEx((dist > 70).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    n, _, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    boxes = [tuple(stats[i][:4]) for i in range(1, n) if stats[i][4] > 1500]
    # Group into rows by vertical centre.
    boxes.sort(key=lambda b: b[1] + b[3] / 2)
    rows, current = [], [boxes[0]]
    for b in boxes[1:]:
        if (b[1] + b[3] / 2) - (current[-1][1] + current[-1][3] / 2) > 120:
            rows.append(sorted(current, key=lambda c: c[0]))
            current = []
        current.append(b)
    rows.append(sorted(current, key=lambda c: c[0]))

    pieces = []
    for row_spec, row in zip(LAYOUT, rows):
        for spec, (x, y, w, h) in zip(row_spec, row):
            if spec is None:
                continue
            name, kind, metres = spec
            rgb = sheet[y:y + h, x:x + w].astype(np.float32)
            alpha = np.clip((dist[y:y + h, x:x + w] - 50) / 60.0, 0.0, 1.0).astype(np.float32)
            size = (max(2, round(metres * DENSITY)), max(2, round(metres * DENSITY * h / w)))
            premult = np.dstack([rgb * alpha[..., None], alpha * 255.0])
            small = np.asarray(Image.fromarray(np.clip(premult, 0, 255).astype(np.uint8), "RGBA").resize(size, Image.BOX)).astype(np.float32)
            a = small[..., 3] / 255.0
            colour = np.where(a[..., None] > 0.01, small[..., :3] / np.maximum(a[..., None], 0.01), 0.0)
            solid = a >= 0.5
            pieces.append({"name": name, "kind": kind, "rgb": np.clip(colour, 0, 255).astype(np.uint8), "solid": solid,
                           "metres": [round(size[0] / DENSITY, 3), round(size[1] / DENSITY, 3)]})

    opaque = np.concatenate([p["rgb"][p["solid"]] for p in pieces])
    own = Image.fromarray(opaque[None, :, :]).quantize(colors=24, method=Image.Quantize.MEDIANCUT, kmeans=4)
    OUT.mkdir(parents=True, exist_ok=True)
    for p in pieces:
        q = np.asarray(Image.fromarray(p["rgb"]).quantize(palette=own, dither=Image.Dither.NONE).convert("RGB"))
        for look in ("gpt", "goal"):
            # The goal palette has no living greens (it turned every bush brown), so plants keep the sheet's own
            # colours in both looks; only rock uses the goal palette.
            rgb = q
            rgba = np.dstack([rgb, np.where(p["solid"], 255, 0).astype(np.uint8)])
            path = OUT / f"{p['name']}_{look}.png"
            Image.fromarray(rgba, "RGBA").save(path)
            stub = path.with_name(path.name + ".import")
            if not stub.exists():
                stub.write_text(SPRITE_STUB, encoding="utf-8", newline="\n")
    manifest = [{"name": p["name"], "kind": p["kind"], "metres": p["metres"]} for p in pieces]
    (OUT / "kit_sprites.json").write_text(json.dumps({"density": DENSITY, "sprites": manifest}, indent=1) + "\n",
                                         encoding="utf-8", newline="\n")
    print("Sprites:", ", ".join(f"{p['name']} {p['rgb'].shape[1]}x{p['rgb'].shape[0]}" for p in pieces))
    preview = ROOT / "tmp" / "kit_sprites_preview.png"
    tiles = [Image.open(OUT / f"{p['name']}_{look}.png") for look in ("gpt", "goal") for p in pieces]
    width = sum(t.width + 4 for t in tiles[:len(pieces)])
    sheet_img = Image.new("RGBA", (width, 80 * 2), (60, 50, 70, 255))
    x = 0
    for i, t in enumerate(tiles):
        if i == len(pieces):
            x = 0
        sheet_img.alpha_composite(t, (x, 80 * (i // len(pieces)) + 80 - t.height))
        x += t.width + 4
    sheet_img.resize((sheet_img.width * 5, sheet_img.height * 5), Image.NEAREST).save(preview)
    print(f"Preview: {preview}")


if __name__ == "__main__":
    main()
