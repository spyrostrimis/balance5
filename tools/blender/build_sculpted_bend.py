"""Build the study kit. Run with system Python (Pillow and numpy), passing the download folder and Blender executable."""
from pathlib import Path
import sys

SOURCES = {
    "namaqualand_cliff_02": ("wall", 3, 512, ["695050", "896253", "a57761", "b3886b", "c99c78", "d4ae88"]),
    "rock_face_01": ("shelf", 0, 512, ["644c49", "865f50", "a47562", "ad816b", "c09778", "d2aa85"]),
    "rock_07": ("curb", 3, 128, ["9c7964", "af8a73", "b8957c", "c3a289", "cdae92", "d7b99a"]),
    "namaqualand_stones_01": ("stone", 3, 256, ["a38673", "ac8e79", "b59984", "c0a28b", "c8ac93", "d1b59c"]),
    "cheiridopsis_succulent": ("plant", 2, 256, ["30392e", "49523b", "62684b", "767655", "92926a", "acab79"]),
}
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/models/sculpted_bend/bend_kit.glb"


def prepare(downloads, blender):
    import io
    import shutil
    import subprocess
    import tempfile
    import zipfile
    import numpy as np
    from PIL import Image, ImageFilter

    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        for key, (role, _, pixels, colours) in SOURCES.items():
            with zipfile.ZipFile(downloads / f"{key}_4k.blend.zip") as pack:
                with pack.open(f"{key}_4k.blend") as source, (work / f"{key}.blend").open("wb") as target:
                    shutil.copyfileobj(source, target)
                rgb = Image.open(io.BytesIO(pack.read(f"textures/{key}_diff_4k.jpg"))).convert("RGB")
                rgb.thumbnail((pixels, pixels), Image.Resampling.LANCZOS)
                rgb = rgb.filter(ImageFilter.MedianFilter(3))
                value = np.asarray(rgb.convert("L"), dtype=float)
                valid = value[value > 15]
                low, high = np.percentile(valid, [5, 95])
                tone = np.clip((value - low) / max(1, high - low), 0, 1)
                palette = np.array([tuple(bytes.fromhex(colour)) for colour in colours], dtype=np.uint8)
                painted = Image.fromarray(palette[np.rint(tone * (len(palette) - 1)).astype(int)])
                if role == "plant":
                    alpha = Image.open(io.BytesIO(pack.read(f"textures/{key}_alpha_4k.png"))).convert("L")
                    painted.putalpha(alpha.resize(rgb.size, Image.Resampling.LANCZOS))
                painted.save(work / f"{key}.png")
        subprocess.run([str(blender), "-b", "--factory-startup", "--disable-autoexec",
                        "--python-exit-code", "1", "--python", __file__, "--",
                        str(work)], check=True)


def build(work):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    def material(key):
        mat = bpy.data.materials.new(key)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        shader = nodes.get("Principled BSDF")
        shader.inputs["Roughness"].default_value = 1
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(work / f"{key}.png"))
        tex.image.pack()
        mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        if SOURCES[key][0] == "plant":
            mat.node_tree.links.new(tex.outputs["Alpha"], shader.inputs["Alpha"])
            mat.surface_render_method = "DITHERED"
        return mat

    def normalized_mesh(name, mesh, matrix, mat):
        mesh.transform(matrix)
        verts = [v.co.copy() for v in mesh.vertices]
        lo = Vector([min(v[j] for v in verts) for j in range(3)])
        hi = Vector([max(v[j] for v in verts) for j in range(3)])
        origin = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        for v in mesh.vertices:
            v.co = Vector([(v.co[j] - origin[j]) / max(0.00001, hi[j] - lo[j]) for j in range(3)])
        mesh.materials.clear()
        if mat:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        scene.collection.objects.link(obj)
        return obj

    def get_objects(path, criterion):
        with bpy.data.libraries.load(str(path), link=False) as (source, target):
            target.objects = sorted(n for n in source.objects if criterion(n))
        return [obj for obj in target.objects if obj and obj.type == "MESH"]

    for key, (role, lod, _, _) in SOURCES.items():
        mat = material(key)
        objs = get_objects(work / f"{key}.blend", lambda n: n.endswith(f"_LOD{lod}") or n == key)
        expected = {"plant": 3, "stone": 5}.get(role, 1)
        parts = objs[:expected] if role == "plant" else objs
        if len(parts) != expected:
            raise ValueError(f"{key}: expected {expected} {role} meshes, found {len(parts)}")
        for j, obj in enumerate(parts):
            result = normalized_mesh(f"{role}{j}", obj.data.copy(), obj.matrix_world.copy(), mat)
            if role in ("stone", "curb", "shelf"):
                dec = result.modifiers.new("Walking view", "DECIMATE")
                dec.ratio = {"stone": 0.42, "curb": 0.4, "shelf": 0.65}[role]

    OUTPUT.parent.mkdir(exist_ok=True, parents=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_apply=True,
                              export_animations=False, export_cameras=False, export_lights=False)


if __name__ == "__main__":
    if "--" in sys.argv:
        build(*map(Path, sys.argv[sys.argv.index("--")+1:]))
    else:
        prepare(*map(Path, sys.argv[1:]))
