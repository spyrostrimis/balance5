"""Build the six rounded sandstone blocks of the 3D cliff kit from assets/textures/cliffs/cliff_blocks.json.

Each block's footprint is the outline of its drawn top (tools/python/build_cliff_atlas.py), so the model
matches the ChatGPT drawing. Rings from the ground up: a buried base, a slightly bulging middle (the
pillowy look), a shoulder, and a smaller top ring that rounds the rim. Sides wear the drawn front
(wrapped: front half left -> right, back half mirrored), the top cap wears the drawn top. Foot pivot at
the centre of the base; +Y (Blender) = away from the camera. No materials: Godot assigns the atlas.

  C:/Blender/blender.exe -b --factory-startup --disable-autoexec --python tools/blender/build_cliff_blocks.py
"""
import json
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]
DATA = json.loads((ROOT / "assets" / "textures" / "cliffs" / "cliff_blocks.json").read_text(encoding="utf-8"))
OUT = ROOT / "assets" / "models" / "cliffs" / "cliff_blocks.glb"
SINK = 0.06          # buried below the ground or the block underneath
BULGE = 1.035        # middle ring scale
RIM = 0.07           # height of the rounded rim
RIM_INSET = 0.055    # how far the top ring pulls in, metres
LIP_V = 0.16         # share of the drawn front that shows the top lip (mapped onto the rim)

aw, ah = DATA["atlas_px"]
bpy.ops.wm.read_factory_settings(use_empty=True)


def atlas_uv(rect, u, v):
    x, y, w, h = rect
    return ((x + u * w) / aw, 1.0 - (y + v * h) / ah)


objects = []
for index, block in enumerate(DATA["blocks"]):
    outline = [tuple(p) for p in block["outline_m"]]
    us = block["side_u"]
    height = block["height_m"]
    n = len(outline)
    cx = sum(p[0] for p in outline) / n
    cy = sum(p[1] for p in outline) / n
    xs = [p[0] for p in outline]
    ys = [p[1] for p in outline]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    size = max(maxx - minx, maxy - miny)

    def ring(z, scale=1.0, inset=0.0):
        k = scale * (1.0 - 2.0 * inset / size)
        return [(cx + (x - cx) * k, cy + (y - cy) * k, z) for x, y in outline]

    # (points, v on the side texture)
    rings = [
        (ring(-SINK), 1.0),
        (ring(height * 0.45, BULGE), 0.55),
        (ring(height - RIM), LIP_V),
        (ring(height, 1.0, RIM_INSET), 0.0),
    ]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    verts = [[bm.verts.new(p) for p in pts] for pts, _ in rings]
    for r in range(len(rings) - 1):
        lo, hi = verts[r], verts[r + 1]
        v_lo, v_hi = rings[r][1], rings[r + 1][1]
        for i in range(n):
            j = (i + 1) % n
            u_i, u_j = us[i], us[j]
            f = bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
            for loop, (u, v) in zip(f.loops, ((u_i, v_lo), (u_j, v_lo), (u_j, v_hi), (u_i, v_hi))):
                loop[uv].uv = atlas_uv(block["side"], u, v)
    # Top cap: a fan around a centre slightly raised, so the top reads gently domed.
    centre = bm.verts.new((cx, cy, height + 0.02))
    top = verts[-1]
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new((top[i], top[j], centre))
        for loop, vert in zip(f.loops, (top[i], top[j], centre)):
            x, y, _ = vert.co
            loop[uv].uv = atlas_uv(block["top"], (x - minx) / (maxx - minx), (maxy - y) / (maxy - miny))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(f"cliff_block_{index}")
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(f"cliff_block_{index}", mesh)
    obj.location.x = index * 2.0  # spread out only for inspection in Blender
    bpy.context.scene.collection.objects.link(obj)
    objects.append(obj)

OUT.parent.mkdir(parents=True, exist_ok=True)
for obj in objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True, export_materials="NONE")
print(f"Wrote {OUT}: {len(objects)} sandstone blocks")
