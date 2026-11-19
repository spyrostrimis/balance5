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

# Raised-stone road (A/B key R): lift the cobble stones by a height map on a dense road mesh. relief_depth 0
# (the default) leaves the vertex stage as in the source. The mask repeats the fragment's road mask (path
# edge, verge wear, fade into the dunes) so the stones sink into the sand where the paint does.
RELIEF_UNIFORMS = (
    "uniform sampler2D cobble_height : hint_default_black, filter_linear_mipmap, repeat_enable; // relief_height.py\n"
    "uniform float relief_depth = 0.0; // metres a stone top rises above its joints; 0 = flat (source behaviour)\n"
    "uniform float relief_side_shade : hint_range(0.0, 1.0) = 0.55; // darken stone sides like the painted joints\n"
    "varying float relief_side;"
)
RELIEF_VERTEX = """float relief_at(vec2 xz) {
	float path_cx = route_center(xz.y);
	vec2 uv = xz / cobble_tile_metres;
	float h = textureLod(cobble_height, uv, 0.0).r;
	vec3 c_col = textureLod(cobble_tex, uv, 0.0).rgb * mix(0.40, 1.06, textureLod(cobble_orm, uv, 0.0).r);
	float edge_noise = (c_col.r - 0.5) * 0.22 + sin(xz.y * 2.3 + c_col.g * 1.6) * 0.07;
	float dist = abs(xz.x - path_cx) + edge_noise;
	float keep = (1.0 - smoothstep(1.10, 1.38, dist)) * (1.0 - smoothstep(-12.6, -16.0, xz.y));
	if (cobble_verge_wear > 0.0) {
		float edge = smoothstep(0.76, 1.27, abs(xz.x - path_cx));
		float pockets = 0.56 * sin(xz.y * 1.71 + sin(xz.x * 2.9 + xz.y * 0.37))
			+ 0.29 * sin(xz.y * 4.45 - xz.x * 5.2)
			+ 0.15 * sin(xz.y * 8.3 + xz.x * 6.3);
		keep *= 1.0 - cobble_verge_wear * edge * smoothstep(-0.05, 0.72, pockets);
	}
	return h * keep * relief_depth;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	relief_side = 0.0;
	if (relief_depth > 0.0) {
		// The relief mesh sits at the origin, so local and world axes agree.
		float e = 0.01;
		float h = relief_at(world_pos.xz);
		float dx = (relief_at(world_pos.xz + vec2(e, 0.0)) - relief_at(world_pos.xz - vec2(e, 0.0))) / (2.0 * e);
		float dz = (relief_at(world_pos.xz + vec2(0.0, e)) - relief_at(world_pos.xz - vec2(0.0, e))) / (2.0 * e);
		VERTEX.y += h;
		world_pos.y += h;
		NORMAL = normalize(vec3(-dx, 1.0, -dz));
		// Steep sides take the joint's place on screen, so they carry its darkness (dirt and occlusion).
		relief_side = clamp(length(vec2(dx, dz)) * 0.9, 0.0, 1.0);
		TANGENT = normalize(vec3(1.0, dx, 0.0));
		BINORMAL = normalize(cross(NORMAL, TANGENT));
	}
}"""

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
        ("void vertex() {\n\tworld_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n}", RELIEF_VERTEX, RELIEF_UNIFORMS),
        ("\tALBEDO = base_col;", "\tALBEDO = base_col * (1.0 - relief_side_shade * relief_side);", None),
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
