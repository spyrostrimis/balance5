"""Build the six 3D curb blocks for the canyon road from the curb atlas layout.

Each block is a box of the size in assets/textures/curbs/curb_atlas.json (metres, foot pivot at the
centre of its base, length along Blender +Y = the road direction in Godot). Its faces are mapped onto
that stone's rectangles in the atlas: top -> top, the two long sides -> side, the two ends -> end. Then
each block gets its own small irregularities (a slightly narrower top, a tilted top, jittered corners)
and a 2-segment bevel so the edges catch the light. Writes assets/models/curbs/curb_blocks.glb with
objects curb_0 .. curb_5 (no materials: Godot assigns the pixel atlas).

  C:/Blender/blender.exe -b --factory-startup --disable-autoexec --python tools/blender/build_curb_blocks.py
"""
import json
import random
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]
LAYOUT = ROOT / "assets" / "textures" / "curbs" / "curb_atlas.json"
OUT = ROOT / "assets" / "models" / "curbs" / "curb_blocks.glb"
BEVEL = 0.022       # metres
SINK = 0.03         # the block extends this far below the sand so uneven ground never shows a gap

layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
L, W, H = layout["block_m"]
aw, ah = layout["atlas_px"]
bpy.ops.wm.read_factory_settings(use_empty=True)


def uv_rect(rect, u, v):
    """Map (u, v) in 0..1 across a face onto an atlas rectangle [x, y, w, h] in pixels (y down)."""
    x, y, w, h = rect
    return ((x + u * w) / aw, 1.0 - (y + v * h) / ah)


objects = []
for index, stone in enumerate(layout["stones"]):
    rng = random.Random(1000 + index)
    mesh = bpy.data.meshes.new(f"curb_{index}")
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    hx, hy = W / 2, L / 2
    z0, z1 = -SINK, H
    # Irregular top: a little narrower than the base and tilted, so a row of blocks is not machine-made.
    inset = rng.uniform(0.006, 0.016)
    tilt_x, tilt_y = rng.uniform(-0.012, 0.012), rng.uniform(-0.015, 0.015)

    def top_z(x, y):
        return z1 + tilt_x * (x / hx) + tilt_y * (y / hy) + rng.uniform(-0.004, 0.004)

    corners = [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)]
    base = [bm.verts.new((x, y, z0)) for x, y in corners]
    top = [bm.verts.new((x - inset * (1 if x > 0 else -1), y - inset * (1 if y > 0 else -1), top_z(x, y)))
           for x, y in corners]

    def face(verts, rect, uvs):
        f = bm.faces.new(verts)
        for loop, (u, v) in zip(f.loops, uvs):
            loop[uv].uv = uv_rect(rect, u, v)
        return f

    # The top image is drawn with its long axis vertical: image down (v) runs along -Y, toward the camera.
    face(top, stone["top"], [(0, 1), (1, 1), (1, 0), (0, 0)])
    face(list(reversed(base)), stone["top"], [(0, 0), (1, 0), (1, 1), (0, 1)])
    # Long sides (x = -hx facing -X, x = +hx facing +X): image u runs along the block, v from top (0) to base (1).
    face([base[0], base[3], top[3], top[0]], stone["side"], [(0, 1), (1, 1), (1, 0), (0, 0)])
    face([base[2], base[1], top[1], top[2]], stone["side"], [(0, 1), (1, 1), (1, 0), (0, 0)])
    # Ends (y = -hy toward the camera, y = +hy away).
    face([base[1], base[0], top[0], top[1]], stone["end"], [(0, 1), (1, 1), (1, 0), (0, 0)])
    face([base[3], base[2], top[2], top[3]], stone["end"], [(0, 1), (1, 1), (1, 0), (0, 0)])
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Round the edges that show: the top rim and the four vertical corners (not the buried base edges).
    show = [e for e in bm.edges if any(v in top for v in e.verts)]
    bmesh.ops.bevel(bm, geom=show, offset=BEVEL, segments=2, profile=0.5, affect="EDGES")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(f"curb_{index}", mesh)
    obj.location.x = index * (W + 0.3)  # spread out only for inspection in Blender
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = False
    objects.append(obj)

OUT.parent.mkdir(parents=True, exist_ok=True)
for obj in objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True, export_materials="NONE")
print(f"Wrote {OUT}: {len(objects)} curb blocks {L} x {W} x {H} m, bevel {BEVEL} m")
