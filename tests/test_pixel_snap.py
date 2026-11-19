"""Self-test for tools/python/pixel_snap.py.

Builds fake "AI pixel art" from a known pixel image: non-integer upscale, slight blur, JPEG artefacts
and noise. Checks that the tool recovers the original cell grid and colours, then removes its output.

    C:/Python312/python.exe tests/test_pixel_snap.py
"""
import io
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "python" / "pixel_snap.py"
WORK = ROOT / "tmp" / "pixel_snap_selftest"
SET = "art_selftest"
OUT = ROOT / "assets" / "textures" / "pixel_ab" / SET


def fake_ai_art(truth: Image.Image, scale: float, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    big = truth.resize((round(truth.width * scale), round(truth.height * scale)), Image.NEAREST)
    big = big.filter(ImageFilter.GaussianBlur(0.6))
    arr = np.asarray(big).astype(float)
    arr[:, :, :3] += rng.normal(0, 4, arr[:, :, :3].shape)
    big = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), big.mode)
    if big.mode == "RGB":
        buf = io.BytesIO()
        big.save(buf, "JPEG", quality=88)
        big = Image.open(io.BytesIO(buf.getvalue())).convert("RGB")
    return big


def run(role: str, image: Path, *extra: str) -> str:
    cmd = [sys.executable, "-I", str(TOOL), role, str(image), "--set", SET, *extra]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout


def main() -> int:
    WORK.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(7)
    palette = rng.integers(40, 230, (12, 3))
    failures = 0

    # Texture: 64 x 32 cells of blocky strata, drawn at 7.37 source pixels per cell.
    truth = palette[(np.add.outer(np.arange(32) // 3, rng.integers(0, 4, 64) // 2)) % 12].astype(np.uint8)
    truth_img = Image.fromarray(truth, "RGB")
    fake = WORK / "fake_strata.jpg"
    fake_ai_art(truth_img, 7.37, 1).save(fake, quality=95)
    print(run("strata", fake, "--colors", "12").strip())
    out = np.asarray(Image.open(OUT / "d_sandstone_strata_albedo.png").convert("RGB"))
    if out.shape[:2] != truth.shape[:2]:
        print(f"FAIL texture grid: got {out.shape[1]}x{out.shape[0]}, expected 64x32")
        failures += 1
    else:
        match = (np.abs(out.astype(int) - truth.astype(int)).max(axis=2) <= 24).mean()
        print(f"Texture cells within 24 levels of the truth: {match:.1%}")
        failures += match < 0.95
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    metres = manifest["textures"]["d_sandstone_strata_albedo.png"]["metres"]
    print(f"Manifest metres {metres} (expected [1.0, 0.5] at 64/m)")
    failures += metres != [1.0, 0.5]
    for extra in ("d_sandstone_strata_normal.png",):
        failures += not (OUT / extra).exists()
    fit = manifest["textures"]["d_sandstone_strata_albedo.png"]["grid_fit"]
    print(f"Grid fit of the fake pixel art: {fit:.0%} (expected at least 85%)")
    failures += fit < 0.85

    # A painted image (smooth noise, no grid) must be flagged instead of silently resampled.
    painted = Image.fromarray(rng.integers(0, 255, (24, 40, 3)).astype(np.uint8)).resize((1000, 600), Image.BICUBIC)
    painted_path = WORK / "painted.png"
    painted.save(painted_path)
    report = run("strata", painted_path, "--dry-run")
    flagged = "not pixel art" in report
    print(f"Painted image flagged as not pixel art: {flagged}")
    failures += not flagged

    # Height image: an aligned height drives the normal map; the albedo stays the same.
    height = Image.fromarray(np.repeat(np.linspace(0, 255, truth.shape[0]), truth.shape[1]).reshape(truth.shape[:2]).astype(np.uint8))
    height_path = WORK / "fake_strata_height.png"
    height.resize(Image.open(fake).size, Image.NEAREST).save(height_path)
    report = run("strata", fake, "--colors", "12", "--height", str(height_path))
    normal = np.asarray(Image.open(OUT / "d_sandstone_strata_normal.png").convert("RGB")).astype(int)
    # A vertical ramp tilts every interior normal along Y only: X stays at 128, Y moves off 128.
    ramp_ok = abs(normal[1:-1, :, 0] - 128).max() <= 1 and (normal[1:-1, :, 1] != 128).all()
    print(f"Height drives the normal map: {ramp_ok}; manifest height = "
          f"{json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))['textures']['d_sandstone_strata_albedo.png']['height']}")
    failures += not ramp_ok

    # Sprite: a 30 x 20 cell blob on a green background at 9.1 source pixels per cell.
    sprite = np.zeros((20, 30, 3), np.uint8)
    sprite[:] = (0, 255, 0)
    yy, xx = np.mgrid[0:20, 0:30]
    blob = ((xx - 15) / 12) ** 2 + ((yy - 10) / 8) ** 2 < 1
    sprite[blob] = palette[(xx[blob] + yy[blob]) % 5 + 3]
    fake_sprite = WORK / "fake_bush.png"
    fake_ai_art(Image.fromarray(sprite, "RGB"), 9.1, 2).save(fake_sprite)
    print(run("bush_sage", fake_sprite, "--key", "green").strip())
    bush = np.asarray(Image.open(OUT / "d_sage_bush_2.png"))
    opaque = (bush[:, :, 3] > 0).sum()
    print(f"Sprite {bush.shape[1]}x{bush.shape[0]} cells, {opaque} opaque (truth {blob.sum()} inside a 30x20 grid)")
    failures += abs(int(opaque) - int(blob.sum())) > blob.sum() * 0.05
    failures += not (bush.shape[1] <= 32 and bush.shape[0] <= 22)

    shutil.rmtree(OUT, ignore_errors=True)
    print("PASS" if failures == 0 else f"FAIL ({failures})")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
