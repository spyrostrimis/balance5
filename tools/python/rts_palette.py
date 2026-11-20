"""Extract the RTS desert palette from the Mission 1 reference image.

    C:/Python312/python.exe tools/python/rts_palette.py [--colors 48]

Clusters the reference's colours (k-means in Lab, frame trimmed off) into a fixed palette and
writes, to assets/textures/rts/:
  palette_desert.json   the colours as hex, darkest first (tools read this)
  palette_desert.png    swatches, 12 per row, for people
and render_captures/rts_style/reference_palette_check.png: the reference redrawn with only these
colours, to confirm the palette is enough.
Also prints the measured sand, crest, trough, road and rock colours used by the style test.
"""
from pathlib import Path
import argparse
import json

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / "docs" / "references" / "rts_mission1_desert_red.webp"
OUT_DIR = ROOT / "assets" / "textures" / "rts"
CHECK_DIR = ROOT / "render_captures" / "rts_style"
TRIM = 10  # the gold frame and corner logo


def to_lab(rgb: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(rgb.reshape(-1, 1, 3).astype(np.uint8), cv2.COLOR_RGB2LAB).reshape(-1, 3).astype(np.float32)


def map_to_palette(rgb: np.ndarray, palette: np.ndarray) -> np.ndarray:
    """Nearest palette colour (in Lab) for every pixel of an HxWx3 uint8 image."""
    lab = to_lab(rgb)
    pal_lab = to_lab(palette)
    idx = np.empty(len(lab), np.int32)
    for start in range(0, len(lab), 200_000):
        chunk = lab[start:start + 200_000]
        idx[start:start + 200_000] = np.argmin(((chunk[:, None, :] - pal_lab[None]) ** 2).sum(-1), axis=1)
    return palette[idx].reshape(rgb.shape)


def load_palette() -> np.ndarray:
    data = json.loads((OUT_DIR / "palette_desert.json").read_text())
    return np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in data["colors"]], np.uint8)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--colors", type=int, default=48)
    args = ap.parse_args()

    ref = np.array(Image.open(REF).convert("RGB"))[TRIM:-TRIM, TRIM:-TRIM]
    lab = to_lab(ref)
    rng = np.random.default_rng(1)
    sample = lab[rng.choice(len(lab), 120_000, replace=False)]
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 60, 0.2)
    _, _, centers = cv2.kmeans(sample, args.colors, None, criteria, 4, cv2.KMEANS_PP_CENTERS)
    centers = np.clip(centers, 0, 255).astype(np.uint8)
    palette = cv2.cvtColor(centers.reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3)
    palette = palette[np.argsort(centers[:, 0])]  # darkest first

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    hexes = ["#%02x%02x%02x" % tuple(int(v) for v in c) for c in palette]
    (OUT_DIR / "palette_desert.json").write_text(json.dumps({
        "source": "docs/references/rts_mission1_desert_red.webp",
        "method": f"k-means in Lab, {args.colors} colours, frame trimmed {TRIM} px",
        "colors": hexes}, indent=1))
    cols, sw = 12, 16
    rows = (len(palette) + cols - 1) // cols
    sheet = np.zeros((rows * sw, cols * sw, 3), np.uint8)
    for i, c in enumerate(palette):
        r, k = divmod(i, cols)
        sheet[r * sw:(r + 1) * sw, k * sw:(k + 1) * sw] = c
    Image.fromarray(sheet).save(OUT_DIR / "palette_desert.png")

    CHECK_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray(map_to_palette(ref, palette)).save(CHECK_DIR / "reference_palette_check.png")

    # Measured material colours (median of hand-picked reference regions, in reference pixels).
    full = np.array(Image.open(REF).convert("RGB"))
    def region(x0, y0, x1, y1):
        return full[y0:y1, x0:x1].reshape(-1, 3)
    dunes = region(100, 420, 400, 600)
    lum = dunes.astype(np.float32) @ np.array([0.3, 0.59, 0.11])
    report = {
        "sand": np.median(region(560, 120, 700, 220), 0),
        "crest (dune light, 92nd pct)": np.median(dunes[lum > np.percentile(lum, 92)], 0),
        "trough (dune shadow, 8th pct)": np.median(dunes[lum < np.percentile(lum, 8)], 0),
        "road": np.median(region(470, 330, 520, 360), 0),
        "rock top": np.median(region(90, 30, 200, 70), 0),
    }
    for name, c in report.items():
        print(f"{name:32s} rgb{tuple(int(v) for v in c)}")
    print(f"Wrote {len(hexes)} colours to {OUT_DIR / 'palette_desert.json'}")


if __name__ == "__main__":
    main()
