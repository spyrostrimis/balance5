"""Author unscaled 1:1 metric 3D meshes for 3D Kit Canyon v2 (flat z=0 base, exact metric UVs).

Reads tile sizes in metres from assets/textures/kit_v2/manifest.json so every UV unit equals
tile_m metres (exact 64 texels/m across all objects without any Godot node scaling).

Produces:
  assets/models/kit_v2/kit_v2_meshes.glb   (cliff_rock_0..5, rubble_0..3, road_boulder_0..2, curb_0..5)
  assets/models/kit_v2/kit_v2_meshes.json  (Godot-space bounds and footprint radii for placement/audit)

Run:
  C:/Blender/blender.exe -b --factory-startup --disable-autoexec --python tools/blender/build_kit_v2_meshes.py
"""
import json
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads((ROOT / "assets" / "textures" / "kit_v2" / "manifest.json").read_text(encoding="utf-8"))
OUT_GLB = ROOT / "assets" / "models" / "kit_v2" / "kit_v2_meshes.glb"
OUT_JSON = ROOT / "assets" / "models" / "kit_v2" / "kit_v2_meshes.json"

TILE_ROCK_SIDE = MANIFEST["cliff_rock_side"]["tile_m"]
TILE_ROCK_TOP = MANIFEST["cliff_rock_top"]["tile_m"]
TILE_BOULDER = MANIFEST["road_boulder"]["tile_m"]
TILE_CURB = MANIFEST["curb_stone"]["tile_m"]

bpy.ops.wm.read_factory_settings(use_empty=True)


def get_mat(name: str) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
    return mat


MAT_ROCK_SIDE = get_mat("mat_rock_side")
MAT_ROCK_TOP = get_mat("mat_rock_top")
MAT_BOULDER = get_mat("mat_road_boulder")
MAT_CURB = get_mat("mat_curb")


def assign_box_metric_uv(bm: bmesh.types.BMesh, uv_layer, tile_m: list, offset: tuple) -> None:
    """Assign exact metric box-projected UVs (1 UV unit = tile_m metres) to every face in bm."""
    tw, th = float(tile_m[0]), float(tile_m[1])
    ox, oy = offset
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            x, y, z = loop.vert.co
            if az >= ax and az >= ay:
                u, v = (x / tw) + ox, (y / th) + oy
            elif ax >= ay:
                u, v = (y / tw) + ox, (-z / th) + oy
            else:
                u, v = (x / tw) + ox, (-z / th) + oy
            loop[uv_layer].uv = (u, v)


def build_layered_rock(
    name: str,
    width_x: float,
    depth_y: float,
    height_z: float,
    seed: int,
    tile_side: list,
    tile_top: list,
    two_materials: bool = True,
    n_pts: int = 24,
) -> bpy.types.Object:
    """Create a stepped, asymmetric stratified sandstone outcrop with flat z=0 base and exact metric UVs."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # Blocky, asymmetric sandstone footprint starting at +pi/2 (back face) running CCW
    angles = [math.pi * 0.5 + (2.0 * math.pi * i / n_pts) for i in range(n_pts)]
    p1, p2, p3 = rng.uniform(0, math.tau), rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    # Squarish-blocky superellipse blend + asymmetric rock notches so blocks read as cleaved strata, not cones
    base_pts = []
    for a in angles:
        ca, sa = math.cos(a), math.sin(a)
        # Superellipse exponent ~3.2 makes broader rectangular shoulders without sharp corners
        se = (abs(ca) ** 3.2 + abs(sa) ** 3.2) ** (-1.0 / 3.2)
        lobe = 0.84 + 0.10 * math.sin(2.0 * a + p1) + 0.08 * math.cos(3.0 * a + p2) + 0.05 * math.sin(5.0 * a + p3)
        r = min(1.02, max(0.68, se * 0.86 * lobe))
        base_pts.append((ca * r, sa * r))

    # Stepped sedimentary rock profile: base shoulder -> bedding notch -> upper slab overhang -> beveled crown
    ring_specs = [
        (0.00, 1.00, 0.00),
        (0.26, 1.01, 0.03),
        (0.48, 0.91, 0.04),
        (0.73, 0.95, 0.03),
        (0.94, 0.85, 0.03),
    ]

    slope_x = rng.uniform(-0.14, 0.14) * height_z
    slope_y = rng.uniform(-0.10, 0.10) * height_z
    step_phase = rng.uniform(0, math.tau)
    rings = []
    for r_idx, (h_frac, scale_xy, jitter) in enumerate(ring_specs):
        pts = []
        for i, (ux, uy) in enumerate(base_pts):
            j_xy = 1.0 + (rng.uniform(-jitter, jitter) if r_idx > 0 else 0.0)
            # Subtle per-corner rock shift in upper tiers so top doesn't align concentric with base
            px = (width_x * 0.5) * ux * scale_xy * j_xy
            py = (depth_y * 0.5) * uy * scale_xy * j_xy
            pz = height_z * h_frac
            if r_idx >= 2:
                # Asymmetric sandstone bedding tilt & step across the upper rock
                step_mod = 0.06 * height_z * math.sin(angles[i] * 2.0 + step_phase)
                pz += (slope_x * ux + slope_y * uy + step_mod) * (h_frac - 0.2)
            pz = max(0.02 if r_idx > 0 else 0.0, pz)
            pts.append(Vector((px, py, pz)))
        rings.append([bm.verts.new(p) for p in pts])

    # Perimeter arc-length side UVs
    mid_ring = [v.co for v in rings[1]]
    seg_lens = [(mid_ring[(i + 1) % n_pts] - mid_ring[i]).xy.length for i in range(n_pts)]
    u_coords = [0.0]
    for sl in seg_lens:
        u_coords.append(u_coords[-1] + sl / float(tile_side[0]))

    v_coords = [0.0]
    for r_idx in range(len(rings) - 1):
        avg_step = sum((rings[r_idx + 1][i].co - rings[r_idx][i].co).length for i in range(n_pts)) / n_pts
        v_coords.append(v_coords[-1] + avg_step / float(tile_side[1]))

    u_off = rng.uniform(0.0, 1.0)
    v_off = rng.uniform(0.0, 1.0)

    for r_idx in range(len(rings) - 1):
        lo, hi = rings[r_idx], rings[r_idx + 1]
        v0 = 1.0 - (v_coords[r_idx] + v_off)
        v1 = 1.0 - (v_coords[r_idx + 1] + v_off)
        for i in range(n_pts):
            j = (i + 1) % n_pts
            f = bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
            # Upper shoulder bevel (last ring -> cap) gets top rock texture on flatter faces
            f.material_index = 0
            f.smooth = (r_idx != 2)  # keep crisp sedimentary bedding ledge crease at mid-height
            ui, uj = u_coords[i] + u_off, u_coords[i + 1] + u_off
            for loop, (uu, vv) in zip(f.loops, ((ui, v0), (uj, v0), (uj, v1), (ui, v1))):
                loop[uv].uv = (uu, vv)

    # Faceted uneven sandstone cap (avoid uniform flat circle lids!)
    top_ring = rings[-1]
    inner_pts = []
    for i, v in enumerate(top_ring):
        bump = 0.03 * height_z * math.cos(angles[i] * 3.0 + p1)
        inner_pts.append(Vector((v.co.x * 0.56, v.co.y * 0.56, v.co.z + 0.04 * height_z + bump)))
    inner_ring = [bm.verts.new(p) for p in inner_pts]
    centre_z = sum(v.co.z for v in inner_ring) / n_pts + 0.025 * height_z
    centre = bm.verts.new((rng.uniform(-0.08, 0.08) * width_x, rng.uniform(-0.08, 0.08) * depth_y, centre_z))

    top_tw = float(tile_top[0])
    top_th = float(tile_top[1])
    top_ox = rng.uniform(0.0, 1.0)
    top_oy = rng.uniform(0.0, 1.0)
    top_mat_idx = 1 if two_materials else 0

    for i in range(n_pts):
        j = (i + 1) % n_pts
        f1 = bm.faces.new((top_ring[i], top_ring[j], inner_ring[j], inner_ring[i]))
        f1.material_index = top_mat_idx
        f1.smooth = False
        for loop in f1.loops:
            loop[uv].uv = (loop.vert.co.x / top_tw + top_ox, loop.vert.co.y / top_th + top_oy)

        f2 = bm.faces.new((inner_ring[i], inner_ring[j], centre))
        f2.material_index = top_mat_idx
        f2.smooth = False
        for loop in f2.loops:
            loop[uv].uv = (loop.vert.co.x / top_tw + top_ox, loop.vert.co.y / top_th + top_oy)

    # Flat bottom cap at exact z = 0.0
    bot_center = bm.verts.new((0.0, 0.0, 0.0))
    bot_ring = rings[0]
    for i in range(n_pts):
        j = (i + 1) % n_pts
        f_bot = bm.faces.new((bot_ring[j], bot_ring[i], bot_center))
        f_bot.material_index = 0
        f_bot.smooth = False
        for loop in f_bot.loops:
            loop[uv].uv = (loop.vert.co.x / top_tw + top_ox, loop.vert.co.y / top_th + top_oy)

    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    min_z = min(v.co.z for v in bm.verts)
    assert abs(min_z) < 1e-6, f"{name} min_z={min_z} != 0"

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if two_materials:
        mesh.materials.append(MAT_ROCK_SIDE)
        mesh.materials.append(MAT_ROCK_TOP)
    else:
        mesh.materials.append(MAT_BOULDER)

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_craggy_boulder(name: str, width_x: float, depth_y: float, height_z: float, seed: int, tile_m: list) -> bpy.types.Object:
    """Create a craggy angular faceted desert boulder (peaked rock ridge, flat z=0 base, metric UVs)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    n_pts = 16
    angles = [math.pi * 0.5 + (2.0 * math.pi * i / n_pts) for i in range(n_pts)]
    p1, p2 = rng.uniform(0, math.tau), rng.uniform(0, math.tau)

    base_pts = []
    for a in angles:
        r = 0.85 + 0.16 * math.sin(2.0 * a + p1) + 0.10 * math.cos(3.0 * a + p2) + rng.uniform(-0.07, 0.07)
        r = min(1.02, max(0.62, r))
        base_pts.append((math.cos(a) * r, math.sin(a) * r))

    # Asymmetric craggy ridge profile (widest at lower hip, sharply angled fractured crown)
    ridge_angle = rng.uniform(0, math.tau)
    rx, ry = math.cos(ridge_angle), math.sin(ridge_angle)
    ring_specs = [
        (0.00, 0.96, 0.00),
        (0.32, 1.02, 0.08),
        (0.66, 0.82, 0.10),
        (0.88, 0.48, 0.09),
    ]
    rings = []
    for r_idx, (hf, sc, jit) in enumerate(ring_specs):
        pts = []
        for i, (ux, uy) in enumerate(base_pts):
            # Pull crown slightly toward the asymmetric rock peak
            shift_x = (0.14 * rx * hf) * width_x
            shift_y = (0.14 * ry * hf) * depth_y
            px = (width_x * 0.5) * ux * sc * (1.0 + (rng.uniform(-jit, jit) if r_idx > 0 else 0.0)) + shift_x
            py = (depth_y * 0.5) * uy * sc * (1.0 + (rng.uniform(-jit, jit) if r_idx > 0 else 0.0)) + shift_y
            pz = height_z * hf + (0.12 * height_z * (ux * rx + uy * ry) * hf if r_idx > 0 else 0.0)
            pts.append(Vector((px, py, max(0.04 if r_idx > 0 else 0.0, pz))))
        rings.append([bm.verts.new(p) for p in pts])

    peak = bm.verts.new((0.16 * rx * width_x, 0.16 * ry * depth_y, height_z * 1.04))
    bot_center = bm.verts.new((0.0, 0.0, 0.0))

    for r_idx in range(len(rings) - 1):
        lo, hi = rings[r_idx], rings[r_idx + 1]
        for i in range(n_pts):
            j = (i + 1) % n_pts
            f = bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
            f.smooth = False
            f.material_index = 0
    for i in range(n_pts):
        j = (i + 1) % n_pts
        f_top = bm.faces.new((rings[-1][i], rings[-1][j], peak))
        f_top.smooth = False
        f_top.material_index = 0
        f_bot = bm.faces.new((rings[0][j], rings[0][i], bot_center))
        f_bot.smooth = False
        f_bot.material_index = 0

    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    assign_box_metric_uv(bm, uv, tile_m, (rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0)))

    min_z = min(v.co.z for v in bm.verts)
    assert abs(min_z) < 1e-6, f"{name} min_z={min_z} != 0"

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(MAT_BOULDER)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_curb_block(name: str, length_y: float, width_x: float, height_z: float, seed: int) -> bpy.types.Object:
    """Create a chiseled curb block with exact flat z=0 base, subtle bevel above z=0, and 1:1 metric UVs."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    hx, hy = width_x * 0.5, length_y * 0.5
    inset_x = rng.uniform(0.010, 0.022)
    inset_y = rng.uniform(0.010, 0.022)
    tilt_x = rng.uniform(-0.008, 0.008)
    tilt_y = rng.uniform(-0.010, 0.010)

    # Subdivided slightly along edges (8-gon chamfered corners) for hand-cut stone character
    c_chamfer = rng.uniform(0.02, 0.04)
    base_pts = [
        (-hx + c_chamfer, -hy),
        (hx - c_chamfer, -hy),
        (hx, -hy + c_chamfer),
        (hx, hy - c_chamfer),
        (hx - c_chamfer, hy),
        (-hx + c_chamfer, hy),
        (-hx, hy - c_chamfer),
        (-hx, -hy + c_chamfer),
    ]
    base_verts = [bm.verts.new((x, y, 0.0)) for x, y in base_pts]
    top_verts = []
    for x, y in base_pts:
        sx = x * (1.0 - inset_x / hx) + rng.uniform(-0.004, 0.004)
        sy = y * (1.0 - inset_y / hy) + rng.uniform(-0.004, 0.004)
        sz = height_z + tilt_x * (x / hx) + tilt_y * (y / hy) + rng.uniform(-0.004, 0.004)
        top_verts.append(bm.verts.new((sx, sy, sz)))

    n = len(base_verts)
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new((base_verts[i], base_verts[j], top_verts[j], top_verts[i]))
        f.smooth = False

    bm.faces.new(top_verts).smooth = False
    bm.faces.new(list(reversed(base_verts))).smooth = False
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # Bevel ONLY top rim edges so bottom loop remains strictly flat at z=0.0
    top_edges = [e for e in bm.edges if all(v in top_verts for v in e.verts)]
    bmesh.ops.bevel(bm, geom=top_edges, offset=0.022, segments=2, profile=0.5, affect="EDGES")
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    min_z = min(v.co.z for v in bm.verts)
    assert abs(min_z) < 1e-6, f"{name} min_z={min_z} != 0"

    assign_box_metric_uv(bm, uv, TILE_CURB, (rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0)))

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(MAT_CURB)

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def godot_metrics(obj: bpy.types.Object) -> dict:
    """Compute exact Godot-space bounds from Blender mesh vertices: (bx, by, bz) -> (gx=bx, gy=bz, gz=-by)."""
    pts = [(v.co.x, v.co.z, -v.co.y) for v in obj.data.vertices]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    zs = [p[2] for p in pts]
    rad_xz = max(math.hypot(p[0], p[2]) for p in pts)
    return {
        "min_x": round(min(xs), 4),
        "max_x": round(max(xs), 4),
        "min_y": round(min(ys), 4),
        "max_y": round(max(ys), 4),
        "min_z": round(min(zs), 4),
        "max_z": round(max(zs), 4),
        "width_x": round(max(xs) - min(xs), 4),
        "height_y": round(max(ys) - min(ys), 4),
        "depth_z": round(max(zs) - min(zs), 4),
        "radius_xz": round(rad_xz, 4),
    }


def main() -> None:
    specs_cliff_rocks = [
        ("cliff_rock_0", 1.80, 0.84, 0.68, 101),
        ("cliff_rock_1", 1.56, 0.78, 0.60, 102),
        ("cliff_rock_2", 1.32, 0.72, 0.54, 103),
        ("cliff_rock_3", 1.12, 0.66, 0.48, 104),
        ("cliff_rock_4", 0.92, 0.60, 0.44, 105),
        ("cliff_rock_5", 0.78, 0.54, 0.38, 106),
    ]
    specs_rubble = [
        ("rubble_0", 0.42, 0.30, 0.19, 201),
        ("rubble_1", 0.34, 0.25, 0.16, 202),
        ("rubble_2", 0.28, 0.22, 0.13, 203),
        ("rubble_3", 0.48, 0.32, 0.21, 204),
    ]
    specs_boulders = [
        ("road_boulder_0", 0.90, 0.72, 0.64, 301),
        ("road_boulder_1", 0.76, 0.62, 0.54, 302),
        ("road_boulder_2", 1.02, 0.76, 0.72, 303),
    ]
    specs_curbs = [
        ("curb_0", 0.72, 0.36, 0.21, 401),
        ("curb_1", 0.68, 0.35, 0.20, 402),
        ("curb_2", 0.74, 0.37, 0.22, 403),
        ("curb_3", 0.70, 0.36, 0.21, 404),
        ("curb_4", 0.69, 0.35, 0.22, 405),
        ("curb_5", 0.73, 0.38, 0.20, 406),
    ]

    all_objs = []
    meta = {"meshes": {}}
    cursor_x = 0.0

    for name, wx, dy, hz, seed in specs_cliff_rocks:
        obj = build_layered_rock(name, wx, dy, hz, seed, TILE_ROCK_SIDE, TILE_ROCK_TOP, two_materials=True, n_pts=24)
        obj.location.x = cursor_x
        cursor_x += 2.2
        all_objs.append(obj)
        meta["meshes"][name] = godot_metrics(obj)

    for name, wx, dy, hz, seed in specs_rubble:
        obj = build_layered_rock(name, wx, dy, hz, seed, TILE_ROCK_SIDE, TILE_ROCK_TOP, two_materials=True, n_pts=16)
        obj.location.x = cursor_x
        cursor_x += 1.0
        all_objs.append(obj)
        meta["meshes"][name] = godot_metrics(obj)

    for name, wx, dy, hz, seed in specs_boulders:
        obj = build_craggy_boulder(name, wx, dy, hz, seed, TILE_BOULDER)
        obj.location.x = cursor_x
        cursor_x += 1.6
        all_objs.append(obj)
        meta["meshes"][name] = godot_metrics(obj)

    for name, ly, wx, hz, seed in specs_curbs:
        obj = build_curb_block(name, ly, wx, hz, seed)
        obj.location.x = cursor_x
        cursor_x += 0.9
        all_objs.append(obj)
        meta["meshes"][name] = godot_metrics(obj)

    OUT_GLB.parent.mkdir(parents=True, exist_ok=True)
    for obj in bpy.data.objects:
        obj.select_set(obj in all_objs)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_materials="PLACEHOLDER",
    )
    OUT_JSON.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {OUT_GLB} and {OUT_JSON}: {len(all_objs)} meshes")
    for k, m in meta["meshes"].items():
        print(f"  {k:16s}: {m['width_x']:.3f} x {m['depth_z']:.3f} x {m['height_y']:.3f} m (min_y={m['min_y']:.4f}, r={m['radius_xz']:.3f})")


if __name__ == "__main__":
    main()
