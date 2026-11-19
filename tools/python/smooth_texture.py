"""Process an AI-generated texture the high-resolution way, for comparison with pixel_snap.py.

This is the procedure Antigravity used for the ChatGPT cobbles and the sandstone on the Trellis boulders
(build_chatgpt_cobble.py, build_chatgpt_sandstone.py), generalised to every texture role:
  1. resize to 1024 on the long side (Lanczos), keeping the aspect ratio,
  2. make it tile with a narrow cosine cross-fade on both axes (albedo and height share the same cut),
  3. derive a normal map from the height image (macro relief) plus high-passed luminance (micro grit),
     and for the cobbles and boulders an ORM map (cavity AO, roughness, rim),
  4. write to assets/textures/pixel_ab/<set>/ (default hr) with a manifest in metres.
The A/B scene shows these sets with key 5: the scene's own shaders with smooth (linear, mipmapped)
filtering, the same surfaces, and by default the same metres as the pixel_snap version of the same
image, so the procedure is the only difference.

  C:/Python312/python.exe tools/python/smooth_texture.py cobble path/to/gpt_cobble.png --height path/to/gpt_cobble_height.png --set hr_gpt
  C:/Python312/python.exe tools/python/smooth_texture.py strata path/to/gpt_strata.png --metres 2 1
"""
import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel_snap import IMPORT_STUB, ROLES, SETS, seam_ratio  # noqa: E402

PREVIEWS = Path(__file__).resolve().parents[2] / "tmp" / "smooth_texture"
LONG_SIDE = 1024
# Relief depth in metres for the height image and the luminance grit (Antigravity's values).
MACRO_DEPTH, MICRO_DEPTH = 0.030, 0.008


def cosine_wrap(arrays: list, margin: int, axis: int) -> list:
    """Cross-fade the last `margin` rows (axis 0) or columns (axis 1) into the first, so the image tiles."""
    out = []
    for a in arrays:
        a = np.moveaxis(a, axis, 0)
        n = a.shape[0]
        t = 0.5 - 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, margin, dtype=np.float32))
        t = t.reshape((margin,) + (1,) * (a.ndim - 1))
        seam = a[n - margin:] * (1.0 - t) + a[:margin] * t
        tiled = np.concatenate([seam, a[margin:n - margin]], axis=0)
        size = (a.shape[1], n)  # cv2 takes (width, height)
        tiled = cv2.resize(tiled, size, interpolation=cv2.INTER_LANCZOS4)
        out.append(np.moveaxis(tiled, 0, axis))
    return out


def pixel_metres(file_name: str, source_name: str):
    """Metres used by a pixel_snap set for the same source image, so both procedures cover the same area."""
    for manifest in sorted(SETS.glob("art*/manifest.json")):
        entry = json.loads(manifest.read_text(encoding="utf-8")).get("textures", {}).get(file_name, {})
        if entry.get("source") == source_name and len(entry.get("metres", [])) == 2:
            return entry["metres"], manifest.parent.name
    return None, None


def save_png(array: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(array, "RGB").save(path)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    textures = sorted(r for r, v in ROLES.items() if v[1] == "texture")
    parser.add_argument("role", choices=textures)
    parser.add_argument("image", type=Path)
    parser.add_argument("--height", type=Path, help="grey height image aligned with the albedo (white = raised)")
    parser.add_argument("--metres", type=float, nargs=2, metavar=("ALONG", "UP"),
                        help="area one repeat covers (default: the pixel_snap version of this image, else the role's size)")
    parser.add_argument("--seam", type=int, default=36, help="cross-fade width in pixels (default 36)")
    parser.add_argument("--set", default="hr", help="output folder under assets/textures/pixel_ab, starting with 'hr'")
    args = parser.parse_args()
    if not args.set.startswith("hr"):
        parser.error("--set must start with 'hr' (the A/B scene lists smooth sets by that prefix)")

    file_name, _, extras, coverage = ROLES[args.role]
    source = Image.open(args.image).convert("RGB")
    scale = LONG_SIDE / max(source.size)
    size = (round(source.width * scale), round(source.height * scale))
    albedo = np.asarray(source.resize(size, Image.LANCZOS)).astype(np.float32)
    if args.height:
        height = np.asarray(Image.open(args.height).convert("L").resize(size, Image.LANCZOS)).astype(np.float32)
        lum0 = albedo @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        corr = np.corrcoef(np.hypot(*np.gradient(height)).ravel(), np.hypot(*np.gradient(lum0)).ravel())[0, 1]
        print(f"Height alignment (edge correlation with the albedo): {corr:+.2f}")
        if corr < 0.3:
            print("WARNING: the height image does not line up with the albedo; ask for it as an edit of this exact image.")
    else:
        # No height image: broad luminance stands in for the macro relief.
        lum0 = albedo @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        height = cv2.GaussianBlur(lum0, (0, 0), 3.0)

    print(f"Raw seam ratio: X {seam_ratio(albedo, 1):.2f}, Y {seam_ratio(albedo, 0):.2f}")
    albedo, height = cosine_wrap([albedo, height], args.seam, 0)
    albedo, height = cosine_wrap([albedo, height], args.seam, 1)
    print(f"Tiled seam ratio: X {seam_ratio(albedo, 1):.2f}, Y {seam_ratio(albedo, 0):.2f}")

    metres, matched = (args.metres, None) if args.metres else pixel_metres(file_name, args.image.name)
    if metres is None:
        metres = list(coverage)
    metres = [round(float(m), 4) for m in metres]
    per_metre = size[0] / metres[0]
    print(f"One repeat covers {metres[0]} x {metres[1]} m"
          + (f", matching the pixel_snap version in '{matched}'" if matched else "")
          + f" ({per_metre:.0f} texels per metre).")

    p2, p98 = np.percentile(height, [2.0, 98.0])
    h_norm = np.clip((height - p2) / max(p98 - p2, 1.0), 0.0, 1.0)
    lum = (albedo @ np.array([0.299, 0.587, 0.114], dtype=np.float32)) / 255.0
    padded = cv2.copyMakeBorder(lum, 16, 16, 16, 16, cv2.BORDER_WRAP)
    micro = lum - cv2.GaussianBlur(padded, (15, 15), 4.0)[16:-16, 16:-16]
    relief = h_norm * MACRO_DEPTH + micro * MICRO_DEPTH
    dx = (np.roll(relief, -1, axis=1) - np.roll(relief, 1, axis=1)) * (per_metre * 0.5)
    dy = (np.roll(relief, -1, axis=0) - np.roll(relief, 1, axis=0)) * (per_metre * 0.5)
    normal = np.dstack((-dx, dy, np.ones_like(dx)))
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)

    out_dir = SETS / args.set
    to_u8 = lambda a: np.clip(np.rint(a), 0, 255).astype(np.uint8)  # noqa: E731
    save_png(to_u8(albedo), out_dir / file_name)
    if "normal" in extras:
        save_png(to_u8((normal * 0.5 + 0.5) * 255.0), out_dir / file_name.replace("_albedo", "_normal"))
    if "orm" in extras:
        cavity = np.clip((h_norm - 0.10) / 0.42, 0.0, 1.0)
        cavity = cavity * cavity * (3.0 - 2.0 * cavity)
        ao = np.clip(0.22 + 0.78 * cavity + micro * 0.35, 0.18, 1.0)
        rough = np.clip(0.95 - 0.43 * cavity, 0.46, 0.96)
        rim = np.clip(1.0 - np.abs(h_norm - 0.42) / 0.22, 0.0, 1.0) * 0.8
        save_png(to_u8(np.dstack((ao, rough, rim)) * 255.0), out_dir / file_name.replace("_albedo", "_orm"))

    manifest_path = out_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest.setdefault("textures", {})[file_name] = {
        "role": args.role, "procedure": "smooth", "source": args.image.name,
        "height": args.height.name if args.height else None, "pixels": list(size), "metres": metres,
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")

    PREVIEWS.mkdir(parents=True, exist_ok=True)
    tile = np.tile(to_u8(albedo), (3, 3, 1))
    Image.fromarray(tile).resize((tile.shape[1] // 2, tile.shape[0] // 2), Image.LANCZOS).save(PREVIEWS / f"{args.role}_3x3.png")
    print(f"Wrote {out_dir / file_name} ({size[0]}x{size[1]}) and {PREVIEWS / (args.role + '_3x3.png')}.\n"
          f"Open the A/B scene and press 5 (again to cycle sets) until it shows '{args.set}'.")


if __name__ == "__main__":
    main()
