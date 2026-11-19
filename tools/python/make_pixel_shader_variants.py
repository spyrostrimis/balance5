"""Generate nearest-filter ("pixel") variants of the canyon shaders for the HD-2D A/B test.

The variants differ only in their sampler filter hints, so they stay in sync by regeneration:
    C:/Python312/python.exe tools/python/make_pixel_shader_variants.py
If the pixel direction is adopted, fold this into the source shaders with a preprocessor switch.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHADERS = ROOT / "assets" / "shaders"
OUT = SHADERS / "pixel"
SOURCES = ["hd2d_octopath_rock", "hd2d_canyon_ground_crisp", "hd2d_chatgpt_boulder"]

OUT.mkdir(exist_ok=True)
for name in SOURCES:
    text = (SHADERS / f"{name}.gdshader").read_text(encoding="utf-8")
    pixel = re.sub(r"filter_linear_mipmap(_anisotropic)?\b", "filter_nearest_mipmap", text)
    header = (
        f"// GENERATED from assets/shaders/{name}.gdshader by tools/python/make_pixel_shader_variants.py.\n"
        "// Nearest-filter samplers for pixel-art textures. Edit the source shader, then regenerate.\n"
    )
    (OUT / f"{name}_pixel.gdshader").write_text(header + pixel, encoding="utf-8", newline="\n")
    print(name, "->", f"pixel/{name}_pixel.gdshader", pixel.count("filter_nearest_mipmap"), "samplers")
