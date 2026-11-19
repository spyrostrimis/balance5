"""Convert a downloaded pack model (FBX or OBJ) to a GLB that canyon v2 can place.

  - joins the meshes, applies transforms, scales so the model is --height metres tall and puts its base
    centre at the origin (foot-level pivot),
  - writes the rock vertex channels the canyon shader reads (AGENTS.md rule 6): red 1 on flat tops (slate
    caps), green a cheap height-based occlusion (darker near the ground), blue 0. Binary flags stay 0 or 1.
  - --keep-material keeps the model's own textured material (for photo scans); otherwise materials are
    dropped because the game overrides them with assets/materials/canyon_rock.tres.

  C:/Blender/blender.exe -b --factory-startup --disable-autoexec --python tools/blender/convert_pack_model.py -- \
      in.fbx out.glb --height 9
"""
import argparse
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("source")
parser.add_argument("out")
parser.add_argument("--height", type=float, required=True, help="target height in metres")
parser.add_argument("--keep-material", action="store_true")
parser.add_argument("--cap-slope", type=float, default=0.82, help="face normal Z above which a face is a slate cap")
parser.add_argument("--decimate", type=float, default=1.0, help="collapse ratio, e.g. 0.25 keeps a quarter of the triangles")
args = parser.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
if args.source.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=args.source)
else:
    bpy.ops.wm.obj_import(filepath=args.source)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if args.decimate < 1.0:
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = args.decimate
    bpy.ops.object.modifier_apply(modifier=mod.name)

mesh = obj.data
corners = [obj.matrix_world @ v.co for v in mesh.vertices]
lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
scale = args.height / max(hi.z - lo.z, 1e-6)
offset = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
for v in mesh.vertices:
    v.co = (v.co - offset) * scale
mesh.update()

if not args.keep_material:
    attr = mesh.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
    for poly in mesh.polygons:
        cap = 1.0 if poly.normal.z > args.cap_slope else 0.0
        for li in poly.loop_indices:
            z = mesh.vertices[mesh.loops[li].vertex_index].co.z / args.height
            attr.data[li].color = (cap, 0.55 + 0.45 * min(max(z, 0.0), 1.0), 0.0, 1.0)
    mesh.materials.clear()

bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", use_selection=True,
                          export_materials="EXPORT" if args.keep_material else "NONE",
                          export_vertex_color="ACTIVE" if not args.keep_material else "NONE",
                          export_all_vertex_colors=False)
print(f"Converted {args.source} -> {args.out}: {len(mesh.polygons)} faces, "
      f"{(hi.x - lo.x) * scale:.1f} x {(hi.y - lo.y) * scale:.1f} x {args.height:.1f} m")
