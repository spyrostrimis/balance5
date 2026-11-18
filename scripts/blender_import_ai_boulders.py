"""Import, inspect, clean, pivot-align, and export the two AI-generated canyon boulders."""

from pathlib import Path
import bmesh
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "assets" / "models" / "source"
OUT_DIR = ROOT / "assets" / "models"

SPECS = [
    {
        "name": "ai_boulder_hf_trellis2",
        "src": r"C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1795020839426_cc5f33df.glb",
        "target_width": 2.1,
        "decimate_ratio": 0.06,  # ~282k -> ~17k tris
    },
    {
        "name": "ai_boulder_trellis3dnet",
        "src": r"C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1795020844091_0aaf81c0.glb",
        "target_width": 2.1,
        "decimate_ratio": 0.65,  # ~17k -> ~11k tris
    },
]


def process_boulder(spec: dict) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0

    bpy.ops.import_scene.gltf(filepath=spec["src"])

    # Remove lights, cameras, empties; keep only meshes
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)

    if not meshes:
        raise RuntimeError(f"No meshes found in {spec['src']}")

    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()

    obj = bpy.context.view_layer.objects.active
    obj.name = spec["name"] + "_mesh"
    obj.data.name = spec["name"] + "_mesh"

    # Apply existing transforms
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Compute world bbox
    bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    span_x = max(xs) - min(xs)
    span_y = max(ys) - min(ys)
    span_z = max(zs) - min(zs)
    cx = 0.5 * (min(xs) + max(xs))
    cy = 0.5 * (min(ys) + max(ys))
    min_z = min(zs)

    scale = spec["target_width"] / max(span_x, span_y, 1e-4)
    for v in obj.data.vertices:
        v.co.x = (v.co.x - cx) * scale
        v.co.y = (v.co.y - cy) * scale
        v.co.z = (v.co.z - min_z) * scale
    obj.data.update()

    # Merge split glTF UV-seam vertices first so Decimate never tears UV islands open
    bm_pre = bmesh.new()
    bm_pre.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm_pre, verts=list(bm_pre.verts), dist=1e-4)
    boundary = [e for e in bm_pre.edges if e.is_boundary]
    if boundary:
        bmesh.ops.holes_fill(bm_pre, edges=boundary, sides=8)
    bm_pre.to_mesh(obj.data)
    bm_pre.free()
    obj.data.update()

    orig_tris = len(obj.data.polygons)
    if spec["decimate_ratio"] < 0.99:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = spec["decimate_ratio"]
        bpy.ops.object.modifier_apply(modifier=mod.name)

    # Re-snap foot pivot to Z=0 after decimation
    post_min_z = min(v.co.z for v in obj.data.vertices)
    if abs(post_min_z) > 1e-5:
        for v in obj.data.vertices:
            v.co.z -= post_min_z
        obj.data.update()

    # Clean normals
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    for poly in obj.data.polygons:
        poly.use_smooth = True

    # Fix materials: ensure non-metallic rock roughness
    for mat in obj.data.materials:
        if mat and mat.use_nodes:
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                # If no Metallic link, clamp Metallic to 0.0
                if not bsdf.inputs["Metallic"].is_linked:
                    bsdf.inputs["Metallic"].default_value = 0.0
                if not bsdf.inputs["Roughness"].is_linked:
                    bsdf.inputs["Roughness"].default_value = 0.88

    # Add Balance5 Col attribute: R=0 (not basalt), G=height AO, B=1.0 (boulder flag)
    if "Col" in obj.data.color_attributes:
        obj.data.color_attributes.remove(obj.data.color_attributes["Col"])
    col_attr = obj.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    new_zs = [v.co.z for v in obj.data.vertices]
    max_h = max(new_zs) if new_zs else 1.0
    for poly in obj.data.polygons:
        for loop_idx in poly.loop_indices:
            v_idx = obj.data.loops[loop_idx].vertex_index
            h_norm = max(0.0, min(1.0, obj.data.vertices[v_idx].co.z / max(max_h, 0.01)))
            ao = 0.58 + 0.40 * (h_norm ** 0.7)
            col_attr.data[loop_idx].color = (0.0, ao, 1.0, 1.0)

    final_bbox = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    f_xs = [v.x for v in final_bbox]
    f_ys = [v.y for v in final_bbox]
    f_zs = [v.z for v in final_bbox]
    print(
        f"[{spec['name']}] tris: {orig_tris} -> {len(obj.data.polygons)}, "
        f"size(m): W={max(f_xs)-min(f_xs):.2f}, D={max(f_ys)-min(f_ys):.2f}, H={max(f_zs)-min(f_zs):.2f}, "
        f"min_z={min(f_zs):.4f}"
    )

    SRC_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    blend_path = SRC_DIR / f"{spec['name']}.blend"
    glb_path = OUT_DIR / f"{spec['name']}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_tangents=True,
        export_texcoords=True,
        export_vertex_color="ACTIVE",
        export_materials="EXPORT",
    )
    print(f"Saved {blend_path} and {glb_path}")


if __name__ == "__main__":
    for s in SPECS:
        process_boulder(s)
