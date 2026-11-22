"""Build all 3D GLB modules and extract linear textures for '3D Canyon · Way 1B Free 3D Modules'.

Reads from:
  - D:/Pictures/Saved Pictures/Canyon/*.zip
  - C:/Users/PC/blenderkit_data/models/*/*.blend

Writes to:
  - assets/models/way1b_free_3d/*.glb
  - tmp/way1b_raw_tex/*.npy (converted to JPG/PNG + ORM by tools/python/build_way1b_textures.py)
"""
import bpy
import bmesh
import os
import io
import sys
import json
import math
import shutil
import zipfile
import pathlib
import numpy as np
from mathutils import Vector, Matrix

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CANYON_DIR = pathlib.Path(r"D:\Pictures\Saved Pictures\Canyon")
BK_DIR = pathlib.Path(r"C:\Users\PC\blenderkit_data\models")
OUT_MODELS = REPO_ROOT / "assets" / "models" / "way1b_free_3d"
TMP_TEX = REPO_ROOT / "tmp" / "way1b_raw_tex"
TMP_WORK = REPO_ROOT / "tmp" / "way1b_work"

OUT_MODELS.mkdir(parents=True, exist_ok=True)
TMP_TEX.mkdir(parents=True, exist_ok=True)
TMP_WORK.mkdir(parents=True, exist_ok=True)


def downsample_box(arr: np.ndarray, target_res: int) -> np.ndarray:
    h, w, c = arr.shape
    if h == target_res and w == target_res:
        return arr
    factor_h = h // target_res
    factor_w = w // target_res
    if factor_h >= 1 and factor_w >= 1 and (h % target_res == 0) and (w % target_res == 0):
        return arr.reshape(target_res, factor_h, target_res, factor_w, c).mean(axis=(1, 3))
    # Fallback nearest/grid sample
    yi = np.linspace(0, h - 1, target_res, dtype=np.int32)
    xi = np.linspace(0, w - 1, target_res, dtype=np.int32)
    return arr[np.ix_(yi, xi)]


def save_blender_image_to_npy(img_path: pathlib.Path, out_npy: pathlib.Path, target_res: int, is_color: bool = False):
    img = bpy.data.images.load(str(img_path))
    w, h = img.size
    c = img.channels
    arr = np.empty(w * h * c, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    arr = arr.reshape(h, w, c)
    # Flip Y because Blender image buffers start at bottom-left
    arr = arr[::-1, :, :]
    arr_ds = downsample_box(arr, target_res)
    np.save(out_npy, arr_ds.astype(np.float32))
    print(f"  [TEX] {img_path.name} ({w}x{h}) -> {out_npy.name} ({target_res}x{target_res})")


def extract_zip_textures(zip_path: pathlib.Path, prefix: str, target_res: int):
    with zipfile.ZipFile(zip_path, "r") as z:
        for name in z.namelist():
            low = name.lower()
            if low.endswith(".blend"):
                continue
            p = TMP_WORK / pathlib.Path(name).name
            with z.open(name) as s, open(p, "wb") as d:
                shutil.copyfileobj(s, d)
            if "diff" in low or "albedo" in low or "color" in low:
                shutil.copy2(p, TMP_TEX / f"{prefix}_diff_raw{p.suffix.lower()}")
            elif "nor_gl" in low or "normal" in low:
                save_blender_image_to_npy(p, TMP_TEX / f"{prefix}_nor.npy", target_res)
            elif "rough" in low:
                save_blender_image_to_npy(p, TMP_TEX / f"{prefix}_rough.npy", target_res)
            elif "alpha" in low:
                shutil.copy2(p, TMP_TEX / f"{prefix}_alpha_raw{p.suffix.lower()}")
            elif "translucency" in low:
                shutil.copy2(p, TMP_TEX / f"{prefix}_trans_raw{p.suffix.lower()}")
            elif "_ao_" in low:
                shutil.copy2(p, TMP_TEX / f"{prefix}_ao_raw{p.suffix.lower()}")
            p.unlink()


def bake_vertex_colors(obj, height: float, cap_slope: float = 0.78):
    mesh = obj.data
    while mesh.color_attributes:
        mesh.color_attributes.remove(mesh.color_attributes[0])
    attr = mesh.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
    h_inv = 1.0 / max(height, 0.05)
    for poly in mesh.polygons:
        cap = 1.0 if poly.normal.z > cap_slope else 0.0
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index]
            z_norm = min(max((v.co.z + 0.08) * h_inv, 0.0), 1.0)
            # Smooth ground-contact AO in green channel (0.38 at ground, 1.0 by 35% height)
            ao = 0.38 + 0.62 * min(max(z_norm / 0.35, 0.0), 1.0)
            attr.data[li].color = (cap, ao, 0.0, 1.0)


def add_cliff_back_skirt(obj, depth_back: float = 3.2):
    """Extrudes high/back open boundary edges backward (-X) and down to Z=0 so one-sided cliff scans
    are solid from a -21 deg elevated camera and cast solid shadows."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.edges.ensure_lookup_table()

    zs = [v.co.z for v in bm.verts]
    xs = [v.co.x for v in bm.verts]
    if not zs:
        bm.free()
        return
    min_z, max_z = min(zs), max(zs)
    min_x, max_x = min(xs), max(xs)
    h = max(max_z - min_z, 0.1)

    # Find boundary edges that sit along the top or back rim (z > min_z + 0.28 * h)
    rim_edges = [
        e for e in bm.edges
        if e.is_boundary and (e.verts[0].co.z > min_z + 0.28 * h or e.verts[1].co.z > min_z + 0.28 * h)
    ]
    if rim_edges:
        # 1) Extrude rim backward in -X (slightly sloped down) to create a solid top plateau cap
        res1 = bmesh.ops.extrude_edge_only(bm, edges=rim_edges)
        verts1 = [ele for ele in res1["geom"] if isinstance(ele, bmesh.types.BMVert)]
        edges1 = [ele for ele in res1["geom"] if isinstance(ele, bmesh.types.BMEdge)]
        for v in verts1:
            v.co.x -= depth_back
            v.co.z = max(min_z, v.co.z - 0.18)
        # 2) Extrude the back edge straight down to min_z to close the back wall for shadow casting
        if edges1:
            res2 = bmesh.ops.extrude_edge_only(bm, edges=edges1)
            verts2 = [ele for ele in res2["geom"] if isinstance(ele, bmesh.types.BMVert)]
            for v in verts2:
                v.co.z = min_z - 0.08

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()


def ensure_in_view_layer(obj):
    if obj.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(obj)
    obj.hide_viewport = False
    obj.hide_render = False
    obj.hide_set(False)


def orient_and_prepare_cliff(obj, decimate_ratio: float = 1.0, add_skirt: bool = True):
    ensure_in_view_layer(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    if decimate_ratio < 0.999:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = decimate_ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)

    # Rotate +90 deg around Blender Z so:
    # - old X (long cliff width) -> new Y (Godot Z, along the canyon route)
    # - old -Y (scanned front face normal) -> new +X (Godot +X, facing inward toward road center from Left wall)
    rot = Matrix.Rotation(math.pi * 0.5, 4, "Z")
    obj.data.transform(rot)
    obj.data.update()

    co = np.array([v.co[:] for v in obj.data.vertices], dtype=np.float32)
    min_x, min_y, min_z = co.min(axis=0)
    max_x, max_y, max_z = co.max(axis=0)
    height = float(max_z - min_z)

    # Front toe X: 78th percentile of X among lower-third vertices so front toe sits at X = 0
    low_mask = co[:, 2] < (min_z + height * 0.35)
    front_x = float(np.percentile(co[low_mask, 0], 78)) if low_mask.any() else float(max_x)
    center_y = float((min_y + max_y) * 0.5)
    base_z = float(min_z + 0.06)  # bury bottom 6 cm

    offset = Vector((front_x, center_y, base_z))
    for v in obj.data.vertices:
        v.co -= offset
    obj.data.update()

    if False and add_skirt:
        add_cliff_back_skirt(obj, depth_back=3.2)

    bake_vertex_colors(obj, height)
    obj.data.materials.clear()
    return height


def orient_and_prepare_prop(obj, decimate_ratio: float = 1.0, align_long_to_y: bool = True, flatten_top: float = 0.0, bury_m: float = 0.02):
    ensure_in_view_layer(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    if decimate_ratio < 0.999:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = decimate_ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)

    co = np.array([v.co[:] for v in obj.data.vertices], dtype=np.float32)
    span_x = co[:, 0].max() - co[:, 0].min()
    span_y = co[:, 1].max() - co[:, 1].min()
    if align_long_to_y and span_x > span_y:
        rot = Matrix.Rotation(math.pi * 0.5, 4, "Z")
        obj.data.transform(rot)
        obj.data.update()
        co = np.array([v.co[:] for v in obj.data.vertices], dtype=np.float32)

    min_x, min_y, min_z = co.min(axis=0)
    max_x, max_y, max_z = co.max(axis=0)
    height = float(max_z - min_z)
    cx = float((min_x + max_x) * 0.5)
    cy = float((min_y + max_y) * 0.5)
    bz = float(min_z + bury_m)

    offset = Vector((cx, cy, bz))
    for v in obj.data.vertices:
        v.co -= offset
        if flatten_top > 0.0 and v.co.z > height * 0.55:
            # Gently level the top crown for walkable cobblestones
            excess = v.co.z - height * 0.55
            v.co.z = height * 0.55 + excess * (1.0 - flatten_top)
    obj.data.update()

    bake_vertex_colors(obj, height)
    obj.data.materials.clear()


def export_selected_glb(out_path: pathlib.Path):
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=True,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_yup=True,
    )
    print(f"  [GLB] Exported {out_path.name} ({out_path.stat().st_size // 1024} KB)")


def open_blend_from_zip(zip_path: pathlib.Path):
    with zipfile.ZipFile(zip_path, "r") as z:
        bname = [n for n in z.namelist() if n.endswith(".blend")][0]
        p = TMP_WORK / pathlib.Path(bname).name
        with z.open(bname) as s, open(p, "wb") as d:
            shutil.copyfileobj(s, d)
        bpy.ops.wm.open_mainfile(filepath=str(p), load_ui=False)
        p.unlink()


# ---------------------------------------------------------------------------
# 1. CLIFF MODULES
# ---------------------------------------------------------------------------
cliff_jobs = [
    ("namaqualand_cliff_02_4k.blend.zip", "namaqualand_cliff_02_LOD2", "namaqualand_cliff_02", 0.65, 2048),
    ("namaqualand_cliff_01_4k.blend.zip", "namaqualand_cliff_01_LOD2", "namaqualand_cliff_01", 1.0, 2048),
    ("rock_face_01_4k.blend.zip", "rock_face_01", "rock_face_01", 1.0, 2048),
    ("rock_face_02_4k.blend.zip", "rock_face_02", "rock_face_02", 0.75, 2048),
]

for zip_name, obj_name, prefix, dec, res in cliff_jobs:
    zp = CANYON_DIR / zip_name
    extract_zip_textures(zp, prefix, res)
    open_blend_from_zip(zp)
    obj = bpy.data.objects[obj_name]
    orient_and_prepare_cliff(obj, decimate_ratio=dec, add_skirt=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    obj.name = prefix
    export_selected_glb(OUT_MODELS / f"{prefix}.glb")

# Lower stratified cliff ledge from BlenderKit cliff-scan_2K
cliff_scan_blend = BK_DIR / "cliff-scan_2ef1dd47-faa4-4aba-98df-7d10e6cc277b" / "cliff-scan_2K_f71beb60-ecb1-45db-af47-0a178f70a85d.blend"
bpy.ops.wm.open_mainfile(filepath=str(cliff_scan_blend), load_ui=False)
for img in bpy.data.images:
    if img.packed_file is not None:
        n = img.name.lower()
        if "normal" in n:
            p = TMP_WORK / "cs_nor.jpg"
            p.write_bytes(img.packed_file.data)
            save_blender_image_to_npy(p, TMP_TEX / "cliff_scan_ledge_nor.npy", 2048)
            p.unlink()
        elif "roughness" in n:
            p = TMP_WORK / "cs_rough.jpg"
            p.write_bytes(img.packed_file.data)
            save_blender_image_to_npy(p, TMP_TEX / "cliff_scan_ledge_rough.npy", 2048)
            p.unlink()
        elif "metallic" not in n:
            (TMP_TEX / "cliff_scan_ledge_diff_raw.jpg").write_bytes(img.packed_file.data)
obj = bpy.data.objects["3DModel_Custom"]
orient_and_prepare_cliff(obj, decimate_ratio=0.22, add_skirt=True)
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
obj.name = "cliff_scan_ledge"
export_selected_glb(OUT_MODELS / "cliff_scan_ledge.glb")


# ---------------------------------------------------------------------------
# 2. CURB BLOCKS & LEDGE BOULDERS (Rock 07, Namaqualand Boulder 03, 02, 05)
# ---------------------------------------------------------------------------
boulder_jobs = [
    ("rock_07_4k.blend.zip", "rock_07_LOD2", "rock_07", 1.0, 1024),
    ("namaqualand_boulder_03_4k.blend.zip", "namaqualand_boulder_03_LOD3", "namaqualand_boulder_03", 1.0, 1024),
    ("namaqualand_boulder_02_4k.blend.zip", "namaqualand_boulder_02_LOD3", "namaqualand_boulder_02", 1.0, 1024),
    ("namaqualand_boulder_05_4k.blend.zip", "namaqualand_boulder_05_LOD2", "namaqualand_boulder_05", 1.0, 1024),
]

for zip_name, obj_name, prefix, dec, res in boulder_jobs:
    zp = CANYON_DIR / zip_name
    extract_zip_textures(zp, prefix, res)
    open_blend_from_zip(zp)
    obj = bpy.data.objects[obj_name]
    orient_and_prepare_prop(obj, decimate_ratio=dec, align_long_to_y=True, bury_m=0.015)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    obj.name = prefix
    export_selected_glb(OUT_MODELS / f"{prefix}.glb")


# ---------------------------------------------------------------------------
# 3. 3D COBBLESTONE PATH STONES (Namaqualand Stones 01 a..e + Moon Rock 04)
# ---------------------------------------------------------------------------
zp = CANYON_DIR / "namaqualand_stones_01_4k.blend.zip"
extract_zip_textures(zp, "namaqualand_stones_01", 1024)
open_blend_from_zip(zp)
stone_names = [f"namaqualand_stones_01_{ch}_LOD3" for ch in ("a", "b", "c", "d", "e")]
stone_objs = []
for ch, sname in zip(("a", "b", "c", "d", "e"), stone_names):
    sobj = bpy.data.objects[sname]
    orient_and_prepare_prop(sobj, decimate_ratio=1.0, align_long_to_y=True, flatten_top=0.35, bury_m=0.008)
    sobj.name = f"stone_{ch}"
    stone_objs.append(sobj)
bpy.ops.object.select_all(action="DESELECT")
for sobj in stone_objs:
    sobj.select_set(True)
bpy.context.view_layer.objects.active = stone_objs[0]
export_selected_glb(OUT_MODELS / "namaqualand_stones_01.glb")

zp = CANYON_DIR / "moon_rock_04_4k.blend.zip"
extract_zip_textures(zp, "moon_rock_04", 1024)
open_blend_from_zip(zp)
mobj = bpy.data.objects["moon_rock_04_LOD3"]
orient_and_prepare_prop(mobj, decimate_ratio=1.0, align_long_to_y=True, flatten_top=0.40, bury_m=0.008)
mobj.name = "moon_rock_04"
bpy.ops.object.select_all(action="DESELECT")
mobj.select_set(True)
export_selected_glb(OUT_MODELS / "moon_rock_04.glb")


# ---------------------------------------------------------------------------
# 4. PLANTS & VERGE ROCKS (Cheiridopsis Succulent, Sand Rocks Small 01, Namaqualand Rocks 01)
# ---------------------------------------------------------------------------
zp = CANYON_DIR / "cheiridopsis_succulent_4k.blend.zip"
extract_zip_textures(zp, "cheiridopsis_succulent", 1024)
open_blend_from_zip(zp)
succ_variants = ("a", "c", "d", "f", "h", "i")
succ_objs = []
for ch in succ_variants:
    sobj = bpy.data.objects[f"cheiridopsis_succulent_{ch}_LOD2"]
    orient_and_prepare_prop(sobj, decimate_ratio=1.0, align_long_to_y=False, bury_m=0.01)
    sobj.name = f"succulent_{ch}"
    succ_objs.append(sobj)
bpy.ops.object.select_all(action="DESELECT")
for sobj in succ_objs:
    sobj.select_set(True)
bpy.context.view_layer.objects.active = succ_objs[0]
export_selected_glb(OUT_MODELS / "cheiridopsis_succulent.glb")

zp = CANYON_DIR / "sand_rocks_small_01_4k.blend.zip"
extract_zip_textures(zp, "sand_rocks_small_01", 1024)
open_blend_from_zip(zp)
srobj = bpy.data.objects["sand_rocks_small_01_LOD3"]
orient_and_prepare_prop(srobj, decimate_ratio=0.16, align_long_to_y=True, bury_m=0.04)
srobj.name = "sand_rocks_small_01"
bpy.ops.object.select_all(action="DESELECT")
srobj.select_set(True)
export_selected_glb(OUT_MODELS / "sand_rocks_small_01.glb")

zp = CANYON_DIR / "namaqualand_rocks_01_4k.blend.zip"
extract_zip_textures(zp, "namaqualand_rocks_01", 1024)
open_blend_from_zip(zp)
verge_rocks = []
for ch in ("a", "b", "c", "d"):
    robj = bpy.data.objects[f"namaqualand_rocks_01_{ch}_LOD3"]
    orient_and_prepare_prop(robj, decimate_ratio=1.0, align_long_to_y=True, bury_m=0.01)
    robj.name = f"verge_rock_{ch}"
    verge_rocks.append(robj)
bpy.ops.object.select_all(action="DESELECT")
for robj in verge_rocks:
    robj.select_set(True)
bpy.context.view_layer.objects.active = verge_rocks[0]
export_selected_glb(OUT_MODELS / "namaqualand_rocks_01.glb")


# ---------------------------------------------------------------------------
# 5. EXIT VIEW (Canyon River Terrain 2K & Mountain Desert 009 Arch)
# ---------------------------------------------------------------------------
river_blend = BK_DIR / "canyon-river-ter_2d5f9aa3-4ad5-4e4a-9d58-ad9b5e223238" / "canyon-river-terrain_2K_7dd5186e-6b78-48b5-90db-0a32f65e3276.blend"
bpy.ops.wm.open_mainfile(filepath=str(river_blend), load_ui=False)
for img in bpy.data.images:
    if img.packed_file is not None:
        n = img.name.lower()
        if "basecol" in n:
            p = TMP_WORK / "rt_col.exr"
            p.write_bytes(img.packed_file.data)
            save_blender_image_to_npy(p, TMP_TEX / "canyon_river_terrain_col.npy", 1024)
            p.unlink()
        elif "normal" in n:
            p = TMP_WORK / "rt_nor.jpg"
            p.write_bytes(img.packed_file.data)
            save_blender_image_to_npy(p, TMP_TEX / "canyon_river_terrain_nor.npy", 1024)
            p.unlink()
        elif "roughness" in n:
            p = TMP_WORK / "rt_rough.jpg"
            p.write_bytes(img.packed_file.data)
            save_blender_image_to_npy(p, TMP_TEX / "canyon_river_terrain_rough.npy", 1024)
            p.unlink()
        elif "ao_out" in n:
            (TMP_TEX / "canyon_river_terrain_ao_raw.jpg").write_bytes(img.packed_file.data)

rt_obj = bpy.data.objects["Canyon River Terrain"]
bpy.ops.object.select_all(action="DESELECT")
rt_obj.select_set(True)
bpy.context.view_layer.objects.active = rt_obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mod = rt_obj.modifiers.new("Decimate", "DECIMATE")
mod.ratio = 0.14
bpy.ops.object.modifier_apply(modifier=mod.name)
# Scale from 1500m down to 68m wide vista gorge
co = np.array([v.co[:] for v in rt_obj.data.vertices], dtype=np.float32)
mn = co.min(axis=0)
mx = co.max(axis=0)
scale_f = 68.0 / max(mx[0] - mn[0], 1.0)
offset = Vector(((mn[0] + mx[0]) * 0.5, (mn[1] + mx[1]) * 0.5, mn[2]))
for v in rt_obj.data.vertices:
    v.co = (v.co - offset) * scale_f
rt_obj.data.update()
bake_vertex_colors(rt_obj, float((mx[2] - mn[2]) * scale_f))
rt_obj.data.materials.clear()
rt_obj.name = "canyon_river_terrain"
export_selected_glb(OUT_MODELS / "canyon_river_terrain.glb")

# Mountain Desert 009 (Natural Arch!) from CraftPix zip
with zipfile.ZipFile(CANYON_DIR / "free-desert-mountain-3d-low-poly-models.zip", "r") as z:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    p = TMP_WORK / "Mountain_desert_009.fbx"
    with z.open("Fbx/Mountain_desert_009.fbx") as s, open(p, "wb") as d:
        shutil.copyfileobj(s, d)
    bpy.ops.import_scene.fbx(filepath=str(p))
    p.unlink()
m9 = [o for o in bpy.data.objects if o.type == "MESH"][0]
bpy.ops.object.select_all(action="DESELECT")
m9.select_set(True)
bpy.context.view_layer.objects.active = m9
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = np.array([v.co[:] for v in m9.data.vertices], dtype=np.float32)
mn = co.min(axis=0)
mx = co.max(axis=0)
target_h = 12.5
scale_m9 = target_h / max(mx[2] - mn[2], 1e-4)
off_m9 = Vector(((mn[0] + mx[0]) * 0.5, (mn[1] + mx[1]) * 0.5, mn[2] + 0.05))
for v in m9.data.vertices:
    v.co = (v.co - off_m9) * scale_m9
m9.data.update()
bake_vertex_colors(m9, target_h, cap_slope=0.82)
m9.data.materials.clear()
m9.name = "mountain_desert_009"
export_selected_glb(OUT_MODELS / "mountain_desert_009.glb")

print("=== ALL WAY 1B GLB MODULES & RAW TEXTURE ARRAYS EXPORTED ===")
