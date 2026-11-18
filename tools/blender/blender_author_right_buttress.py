"""Author or export the canyon buttress from Blender's background mode.

--create builds the editable source. --notch shallow|deep edits and saves
the named notch corners. With neither option, export the open .blend as-is.
"""

import argparse
from pathlib import Path
import sys

import bmesh
import bpy


MODELS = Path(__file__).resolve().parents[2] / "assets" / "models"
OBJECT_NAME = "ButtressMesh"
NOTCH_GROUP = "Trailward notch"
NOTCH_DEPTHS = {"shallow": 0.10, "deep": 0.78}


def create_source():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0

    vertices = []
    faces = []
    face_masks = []
    notch_indices = []

    def add_course(bottom, top, outline, inset, slate=False, notch_corners=()):
        # Outline entries are (trailward X, Godot Z). Blender Z is elevation.
        start = len(vertices)
        count = len(outline)
        for height, taper in ((bottom, 0.0), (top, inset)):
            for index, (x, route_z) in enumerate(outline):
                if index in notch_corners:
                    notch_indices.append(len(vertices))
                vertices.append((x + taper * (1.7 - x), -route_z * (1.0 - taper), height))
        lower = list(range(start, start + count))
        upper = list(range(start + count, start + 2 * count))
        faces.extend((lower[::-1], upper))
        face_masks.extend((slate, True))
        for i in range(count):
            j = (i + 1) % count
            faces.append((lower[i], lower[j], upper[j], upper[i]))
            face_masks.append(slate)

    add_course(0.0, 0.49, [
        (0.10, -2.87), (0.45, -3.12), (2.96, -3.02), (3.99, -2.49),
        (4.34, 1.86), (3.49, 3.31), (1.18, 3.42), (0.67, 2.80),
        (0.59, 1.25), (0.33, 0.58), (0.34, -0.62), (0.12, -1.48),
    ], 0.025, slate=True)
    add_course(0.43, 1.43, [
        (0.015, -2.46), (0.18, -2.96), (2.95, -2.91), (4.15, -2.28),
        (4.20, 1.98), (3.22, 3.39), (1.05, 3.11), (0.56, 2.57),
        (0.65, 1.18), (0.46, 0.46), (0.38, -0.61), (0.045, -1.69),
    ], 0.021, slate=True)
    add_course(1.35, 2.42, [
        (0.26, -2.62), (0.60, -2.89), (3.28, -2.63), (4.31, -1.72),
        (4.10, 1.48), (3.48, 2.97), (1.21, 2.84), (0.78, 2.41),
        (0.86, 1.41), (0.59, 0.79), (0.45, -0.51), (0.25, -1.32),
    ], 0.026)
    add_course(2.33, 3.54, [
        (0.27, -2.26), (0.54, -2.77), (0.95, -2.88), (3.10, -2.76),
        (4.23, -1.96), (4.14, 0.97), (3.60, 2.48), (1.54, 2.37),
        (1.18, 1.96), (1.04, 0.77), (0.80, 0.19), (0.56, -1.05),
        (0.35, -1.55),
    ], 0.029, notch_corners=(0, 1, 2, 12))
    add_course(3.46, 4.58, [
        (0.85, -2.49), (1.22, -2.69), (3.55, -2.38), (4.12, -1.44),
        (4.14, 0.74), (3.71, 2.22), (2.09, 2.05), (1.41, 1.58),
        (1.48, 0.53), (1.07, -0.20), (0.80, -1.56),
    ], 0.036)
    add_course(4.50, 5.72, [
        (1.54, -2.21), (1.99, -2.55), (3.60, -2.18), (4.08, -1.15),
        (3.94, 0.84), (3.46, 1.79), (2.61, 1.57), (2.03, 1.13),
        (2.05, 0.25), (1.58, -0.45),
    ], 0.033)
    add_course(5.65, 6.47, [
        (2.17, -2.07), (2.82, -2.22), (3.62, -1.90), (3.92, -1.17),
        (3.71, 0.67), (3.20, 1.03), (2.62, 0.87), (2.24, 0.30),
    ], 0.039)

    mesh = bpy.data.meshes.new(OBJECT_NAME)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    color = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    for face in mesh.polygons:
        for loop_index in face.loop_indices:
            x, _, height = vertices[mesh.loops[loop_index].vertex_index]
            ao = min(0.98, 0.64 + min(height, 1.0) * 0.18 + x * 0.038)
            color.data[loop_index].color = (float(face_masks[face.index]), ao, 0.0, 1.0)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()

    rock = bpy.data.objects.new(OBJECT_NAME, mesh)
    bpy.context.collection.objects.link(rock)
    bpy.context.view_layer.objects.active = rock
    rock.select_set(True)
    material = bpy.data.materials.new("Matte sandstone preview")
    material.diffuse_color = (0.31, 0.14, 0.074, 1.0)
    material.roughness = 0.88
    surface = material.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = material.diffuse_color
    surface.inputs["Roughness"].default_value = material.roughness
    mesh.materials.append(material)
    notch = rock.vertex_groups.new(name=NOTCH_GROUP)
    notch.add(notch_indices, 1.0, "REPLACE")
    rock["notch_depth_m"] = 0.0
    bevel = rock.modifiers.new("Chipped bedding edges", "BEVEL")
    bevel.width = 0.03
    bevel.segments = 1
    return rock


def set_notch(rock, depth):
    group = rock.vertex_groups[NOTCH_GROUP]
    change = depth - rock["notch_depth_m"]
    for vertex in rock.data.vertices:
        if any(member.group == group.index for member in vertex.groups):
            vertex.co.x += change
    rock.data.update()
    rock["notch_depth_m"] = depth


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--create", action="store_true")
    parser.add_argument("--notch", choices=NOTCH_DEPTHS)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    rock = create_source() if args.create else bpy.data.objects[OBJECT_NAME]
    if args.create or args.notch:
        set_notch(rock, NOTCH_DEPTHS[args.notch or "shallow"])
        master = MODELS / "source" / "right_buttress.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(master))

    bpy.ops.object.select_all(action="DESELECT")
    rock.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(MODELS / "right_buttress.glb"),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_vertex_color="ACTIVE",
    )
    print(f"Exported {rock.name} at origin with notch depth {rock['notch_depth_m']:.2f} m")


if __name__ == "__main__":
    main()
