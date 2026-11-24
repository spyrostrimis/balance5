"""Recolour the 3D kit canyon with five colour ramps sampled from the RPG goal image ('ramp' look).

The goal image (docs/references/rpg_canyon_goal.jpg) is built from a few colour families: terracotta
sandstone and near-black umber layers on the cliffs, pale beige sand, cool grey stone for the curbs and
cobbles, and dusty sage for the plants. Each family becomes a ramp: the colours of its sample regions,
sorted by brightness, at six steps from dark to light, expanded to RAMP_STEPS shades.

Every kit texture is then repainted by brightness (a gradient map): each texel keeps how light or dark it
is within its own texture, and takes the matching shade of its material's ramp. Shapes, cracks and pixel
detail stay as drawn; only the colours change. Normal and ORM maps are reused from the 'gpt' versions.

Outputs, next to the existing 'gpt' and 'goal' versions:
  assets/textures/curbs/curb_atlas_ramp.png                       stone
  assets/textures/cliffs/cliff_blocks_ramp.png                    sandstone
  assets/textures/cliffs/cliff_wall_ramp.png, cliff_paving_ramp   dark layers
  assets/textures/kit_sprites/<plant>_ramp.png                    sage
  assets/textures/pixel_ab/art_road_ramp/                         cobble -> stone, sand -> sand,
                                                                  strata (faces between rows) -> dark
  assets/textures/kit_ramps.json and tmp/kit_ramps_preview.png    the ramps

  C:/Python312/python.exe tools/python/recolor_kit.py
"""
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GOAL = ROOT / "docs" / "references" / "rpg_canyon_goal.jpg"
TEX = ROOT / "assets" / "textures"
SETS = TEX / "pixel_ab"
RAMP_ANCHORS = 6
RAMP_STEPS = 11
# Sample regions in the 1376 x 768 goal image (x0, y0, x1, y1).
REGIONS = {
    "sandstone": [(20, 470, 240, 700), (1210, 420, 1370, 700), (130, 60, 300, 220)],
    "dark": [(90, 250, 360, 330), (170, 380, 330, 470), (1000, 300, 1170, 420)],
    "sand": [(420, 610, 560, 700), (870, 590, 980, 690), (470, 700, 560, 760)],
    "stone": [(650, 600, 790, 760), (560, 650, 620, 760), (830, 580, 870, 640)],
    "sage": [(405, 540, 470, 600), (540, 540, 610, 590), (800, 440, 870, 490)],
}
# The goal image's colours include its own light and shadow, while our textures are surface colour that the
# scene lights again. So each ramp is taken from the lit part of its samples (brightness percentiles), and
# two families are nudged toward what the eye reads in the picture: the road stone is cool grey (it only
# looks warm in the golden light), and the plants are sampled from their greenish pixels only.
WINDOWS = {"sandstone": (0.30, 0.98), "dark": (0.10, 0.85), "sand": (0.35, 0.98), "stone": (0.05, 0.98), "sage": (0.20, 0.98)}
STONE_DESATURATE = 0.65
STONE_COOL = (-10, 0, 14)
# The sampled stone is the brightest family; in full sun it read almost white. Road and curbs are dimmed,
# the curbs a little more, as in the goal image.
ROAD_STONE = 0.78
CURB_STONE = 0.70
IMPORT_STUB = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=%s
detect_3d/compress_to=0
"""


def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., :3].astype(float) @ np.array([0.299, 0.587, 0.114])


def sample_ramp(goal: np.ndarray, boxes, name: str) -> np.ndarray:
    pixels = np.concatenate([goal[y0:y1, x0:x1].reshape(-1, 3) for x0, y0, x1, y1 in boxes]).astype(float)
    if name == "sage":
        pixels = pixels[(pixels[:, 1] >= pixels[:, 0] * 0.92) & (pixels[:, 1] > pixels[:, 2])]
    order = np.argsort(luminance(pixels))
    pixels = pixels[order]
    lo, hi = WINDOWS[name]
    # Six anchors across the lit window: the median colour of each slice.
    edges = np.linspace(lo, hi, RAMP_ANCHORS + 1) * len(pixels)
    anchors = np.array([np.median(pixels[int(a):max(int(a) + 1, int(b))], axis=0) for a, b in zip(edges[:-1], edges[1:])])
    if name == "stone":
        grey = luminance(anchors)[:, None]
        anchors = np.clip(anchors * (1 - STONE_DESATURATE) + grey * STONE_DESATURATE + np.array(STONE_COOL), 0, 255)
    t = np.linspace(0, RAMP_ANCHORS - 1, RAMP_STEPS)
    return np.array([anchors[int(np.floor(v))] * (1 - (v % 1)) + anchors[min(int(np.floor(v)) + 1, RAMP_ANCHORS - 1)] * (v % 1)
                     for v in t]).round().astype(np.uint8)


def gradient_map(rgba: np.ndarray, ramp: np.ndarray) -> np.ndarray:
    """Repaint by brightness: the texel's brightness rank within its texture picks the ramp shade."""
    out = rgba.copy()
    opaque = rgba[..., 3] > 0 if rgba.shape[2] == 4 else np.ones(rgba.shape[:2], bool)
    lum = luminance(rgba)
    lo, hi = np.percentile(lum[opaque], [3, 97])
    t = np.clip((lum - lo) / max(hi - lo, 1.0), 0.0, 1.0)
    index = np.rint(t * (len(ramp) - 1)).astype(int)
    out[..., :3] = ramp[index]
    return out


def write(img: np.ndarray, path: Path, mipmaps=True) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(path)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(IMPORT_STUB % ("true" if mipmaps else "false"), encoding="utf-8", newline="\n")


def recolour(src: Path, dst: Path, ramp: np.ndarray, mipmaps=True, scale=1.0) -> None:
    img = np.asarray(Image.open(src).convert("RGBA" if not mipmaps else "RGB"))
    write(gradient_map(img, np.clip(ramp.astype(float) * scale, 0, 255).astype(np.uint8)), dst, mipmaps)


def copy_with_stub(src: Path, dst: Path) -> None:
    shutil.copyfile(src, dst)
    stub = dst.with_name(dst.name + ".import")
    if not stub.exists():
        stub.write_text(IMPORT_STUB % "true", encoding="utf-8", newline="\n")


def main() -> None:
    goal = np.asarray(Image.open(GOAL).convert("RGB"))
    ramps = {name: sample_ramp(goal, boxes, name) for name, boxes in REGIONS.items()}
    (TEX / "kit_ramps.json").write_text(json.dumps({"source": "docs/references/rpg_canyon_goal.jpg", "regions": REGIONS,
                                                    "ramps": {k: v.tolist() for k, v in ramps.items()}}, indent=1) + "\n",
                                        encoding="utf-8", newline="\n")
    for name, ramp in ramps.items():
        print(f"{name:9s} dark {ramp[0].tolist()} -> light {ramp[-1].tolist()}")

    # Curbs and cliffs.
    recolour(TEX / "curbs/curb_atlas_gpt.png", TEX / "curbs/curb_atlas_ramp.png", ramps["stone"], scale=CURB_STONE)
    copy_with_stub(TEX / "curbs/curb_atlas_gpt_normal.png", TEX / "curbs/curb_atlas_ramp_normal.png")
    for part, ramp in (("blocks", "sandstone"), ("wall", "dark"), ("paving", "dark")):
        recolour(TEX / f"cliffs/cliff_{part}_gpt.png", TEX / f"cliffs/cliff_{part}_ramp.png", ramps[ramp])
        copy_with_stub(TEX / f"cliffs/cliff_{part}_gpt_normal.png", TEX / f"cliffs/cliff_{part}_ramp_normal.png")
    # Plants (sprites keep their alpha; no mipmaps).
    plants = json.loads((TEX / "kit_sprites/kit_sprites.json").read_text(encoding="utf-8"))["sprites"]
    for plant in plants:
        recolour(TEX / f"kit_sprites/{plant['name']}_gpt.png", TEX / f"kit_sprites/{plant['name']}_ramp.png", ramps["sage"], mipmaps=False)
    # Road set: cobble -> stone, sand -> sand, strata faces -> dark.
    src, dst = SETS / "art_road_gpt", SETS / "art_road_ramp"
    dst.mkdir(exist_ok=True)
    for name, ramp, scale in (("chatgpt_cobble_albedo.png", "stone", ROAD_STONE), ("hd2d_sand_albedo.png", "sand", 1.0),
                              ("d_sandstone_strata_albedo.png", "dark", 1.0)):
        recolour(src / name, dst / name, ramps[ramp], scale=scale)
    for name in ("chatgpt_cobble_normal.png", "chatgpt_cobble_orm.png", "hd2d_sand_normal.png", "d_sandstone_strata_normal.png"):
        copy_with_stub(src / name, dst / name)
    manifest = json.loads((src / "manifest.json").read_text(encoding="utf-8"))
    for entry in manifest["textures"].values():
        entry["procedure"] = f"{entry.get('procedure', '')} + recolor_kit ramp".strip(" +")
    (dst / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")

    preview = ROOT / "tmp" / "kit_ramps_preview.png"
    strip = np.concatenate([np.repeat(np.repeat(r[None, :, :], 24, axis=0), 24, axis=1) for r in ramps.values()], axis=0)
    Image.fromarray(strip).save(preview)
    print(f"Wrote the 'ramp' look; ramps preview: {preview}")


if __name__ == "__main__":
    main()
