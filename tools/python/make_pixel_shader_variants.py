"""Generate variants of the canyon shaders for the HD-2D A/B test.

  pixel/<name>_pixel.gdshader   nearest-mipmap filtering on every sampler, for pixel-art sets (keys 2-4)
  pixel/<name>_smooth.gdshader  the source filtering, for high-resolution authored sets (key 5)

Both stay in sync with their sources by regeneration. In both, the texture repeat scales that are hard-coded
in the sources become uniforms (defaults unchanged), so authored sets of any size map at an exact size in
metres (see pixel_snap.py and smooth_texture.py).

    C:/Python312/python.exe tools/python/make_pixel_shader_variants.py

If the pixel direction is adopted, fold this into the source shaders with a preprocessor switch.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHADERS = ROOT / "assets" / "shaders"
OUT = SHADERS / "pixel"

# shader -> list of (literal in source, replacement, uniform declaration)
SCALE_UNIFORMS = {
    "hd2d_octopath_rock": [
        ("w, 0.34, 0.72)", "w, strata_scale.x, strata_scale.y)",
         "uniform vec2 strata_scale = vec2(0.34, 0.72); // repeats per metre along / up the wall"),
        ("w, 1.05)", "w, basalt_scale)", "uniform float basalt_scale = 1.05; // slate tops, repeats per metre"),
        ("world_pos.y * 1.45, world_pos.z * 0.52", "world_pos.y * basalt_side_scale.x, world_pos.z * basalt_side_scale.y", None),
        ("world_pos.y * 1.45, world_pos.x * 0.52", "world_pos.y * basalt_side_scale.x, world_pos.x * basalt_side_scale.y",
         "uniform vec2 basalt_side_scale = vec2(1.45, 0.52); // dark slate courses (up, along)"),
        ("w, 0.65)", "w, boulder_scale)", "uniform float boulder_scale = 0.65; // ochre boulder clusters"),
    ],
    "hd2d_canyon_ground_crisp": [
        ("world_pos.xz * vec2(0.46, 0.24)", "world_pos.xz * sand_scale", None),
        ("world_pos.xz * vec2(0.31, 0.17)", "world_pos.xz * sand_scale_detail",
         "uniform vec2 sand_scale = vec2(0.46, 0.24); // verge sand, repeats per metre (x, z)\n"
         "uniform vec2 sand_scale_detail = vec2(0.31, 0.17); // second sand octave"),
        ("world_pos.xz * 0.24", "world_pos.xz * desert_scale", "uniform float desert_scale = 0.24; // open dunes"),
    ],
    "hd2d_chatgpt_boulder": [],
}

OUT.mkdir(exist_ok=True)
for (name, swaps), variant in [(item, v) for item in SCALE_UNIFORMS.items() for v in ("pixel", "smooth")]:
    text = (SHADERS / f"{name}.gdshader").read_text(encoding="utf-8")
    pixel = text if variant == "smooth" else re.sub(r"filter_linear_mipmap(_anisotropic)?\b", "filter_nearest_mipmap", text)
    declarations = []
    for literal, replacement, declaration in swaps:
        count = pixel.count(literal)
        if count == 0:
            raise SystemExit(f"{name}: expected literal not found: {literal}")
        pixel = pixel.replace(literal, replacement)
        if declaration:
            declarations.append(declaration)
    if declarations:
        # Insert after the last top-level uniform declaration.
        last = max(m.end() for m in re.finditer(r"^uniform [^\n]*\n", pixel, re.M))
        pixel = pixel[:last] + "\n// Repeat scales exposed for authored pixel sets (defaults match the source shader).\n" + "\n".join(declarations) + "\n" + pixel[last:]
    header = (
        f"// GENERATED from assets/shaders/{name}.gdshader by tools/python/make_pixel_shader_variants.py.\n"
        + ("// Nearest-filter samplers and uniform repeat scales for pixel-art textures."
           if variant == "pixel" else "// Source filtering and uniform repeat scales for high-resolution authored textures.")
        + " Edit the source, then regenerate.\n"
    )
    (OUT / f"{name}_{variant}.gdshader").write_text(header + pixel, encoding="utf-8", newline="\n")
    print(name, "->", f"pixel/{name}_{variant}.gdshader", pixel.count("filter_nearest_mipmap"), "nearest samplers,", len(swaps), "scale swaps")
