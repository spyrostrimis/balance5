"""Build a displacement height map for a cobble set, for the raised-stone road (A/B scene key R).

The nine-stone study showed that real raised stones cast small shadows that flat paint and normal maps
cannot. This tool makes the height that lifts every stone of a set's road texture, so the whole road can
be raised instead of a 1.2 m patch:
  1. start from the generator's height image when there is one (ChatGPT), else from broad luminance,
  2. cut the stones apart at the painted joints (dark lines in the albedo), so the raised edges sit exactly
     on the painted edges even where the height image was redrawn a little differently,
  3. shape each stone: steep shoulders, a gently domed top (white = top of a stone, black = joint),
  4. cut it the same way the set was cut (cosine wrap for hr* sets, none for art* sets) and write
     chatgpt_cobble_height.png (1024 px, linear) into each set.

  C:/Python312/python.exe tools/python/relief_height.py path/to/cobble_GPT.png --height path/to/cobble_height_GPT.png --sets art_gpt hr_gpt
"""
import argparse
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel_snap import IMPORT_STUB, SETS  # noqa: E402
from smooth_texture import LONG_SIDE, cosine_wrap  # noqa: E402

FILE_NAME = "chatgpt_cobble_height.png"
SHOULDER = 7.0  # px at 1024: about 1.7 cm on a 2.44 m repeat


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("image", type=Path, help="the cobble albedo the sets were made from")
    parser.add_argument("--height", type=Path, help="the generator's height image for it, if any")
    parser.add_argument("--sets", nargs="+", required=True, help="set folders to write into (art* and/or hr*)")
    parser.add_argument("--joint", type=float, default=0.42,
                        help="joint darkness threshold, as a fraction of the stone brightness (default 0.42)")
    parser.add_argument("--seam", type=int, default=36, help="cross-fade width for hr* sets (default 36, as smooth_texture)")
    args = parser.parse_args()

    source = Image.open(args.image).convert("RGB")
    size = (LONG_SIDE, round(source.height * LONG_SIDE / source.width))
    rgb = np.asarray(source.resize(size, Image.LANCZOS)).astype(np.float32) / 255.0
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    if args.height:
        base = np.asarray(Image.open(args.height).convert("L").resize(size, Image.LANCZOS)).astype(np.float32)
    else:
        base = cv2.GaussianBlur(lum, (0, 0), 6.0)
    p2, p98 = np.percentile(base, [2.0, 98.0])
    base = np.clip((base - p2) / max(p98 - p2, 1e-6), 0.0, 1.0)

    # Joints: pixels much darker than the local stone brightness. Wrap padding keeps the cut tileable.
    pad = 48
    lum_p = cv2.copyMakeBorder(lum, pad, pad, pad, pad, cv2.BORDER_WRAP)
    local = cv2.dilate(cv2.GaussianBlur(lum_p, (0, 0), 2.0), np.ones((25, 25), np.uint8))[pad:-pad, pad:-pad]
    darkness = 1.0 - lum / np.maximum(local, 1e-3)
    joint = np.clip((darkness - args.joint * 0.6) / (args.joint * 0.8), 0.0, 1.0)
    stone = (1.0 - joint) * np.clip((base - 0.10) / 0.25, 0.0, 1.0)

    # Distance from the edge of each stone gives steep shoulders and a flat-ish top.
    mask = (stone > 0.5).astype(np.uint8)
    mask_p = cv2.copyMakeBorder(mask, pad, pad, pad, pad, cv2.BORDER_WRAP)
    dist = cv2.distanceTransform(mask_p, cv2.DIST_L2, 5)[pad:-pad, pad:-pad]
    shoulder = np.clip(dist / SHOULDER, 0.0, 1.0)
    shoulder = shoulder * shoulder * (3.0 - 2.0 * shoulder)
    height = shoulder * (0.72 + 0.28 * base)
    height_p = cv2.copyMakeBorder(height, pad, pad, pad, pad, cv2.BORDER_WRAP)
    height = cv2.GaussianBlur(height_p, (0, 0), 1.2)[pad:-pad, pad:-pad]
    print(f"Stone cover {mask.mean():.0%}; shoulder width {SHOULDER:g} px "
          f"({SHOULDER / LONG_SIDE * 100:.1f}% of a repeat).")

    for set_name in args.sets:
        out = height
        if set_name.startswith("hr"):
            (out,) = cosine_wrap([out], args.seam, 0)
            (out,) = cosine_wrap([out], args.seam, 1)
        path = SETS / set_name / FILE_NAME
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(np.clip(np.rint(out * 255.0), 0, 255).astype(np.uint8), "L").save(path)
        stub = path.with_name(path.name + ".import")
        if not stub.exists():
            stub.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")
        print(f"Wrote {path}")
    preview = Path(__file__).resolve().parents[2] / "tmp" / "relief_height" / "cobble_height_check.jpg"
    preview.parent.mkdir(parents=True, exist_ok=True)
    side = np.dstack([height] * 3)
    Image.fromarray((np.hstack([rgb, side, rgb * (0.35 + 0.65 * side)]) * 255).astype(np.uint8)).save(preview, quality=88)
    print(f"Check image: {preview}")


if __name__ == "__main__":
    main()
