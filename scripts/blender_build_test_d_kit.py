"""
Builds Small Test D's modular chiseled 3D roadside canyon kit in Blender 5.2.3 LTS:
  1. TerraceLeftModule  (~6.4m long, 3 stepped interlocking dark-basalt + red-sandstone tiers)
  2. TerraceRightModule (~6.4m long, asymmetrical 3 tiers + rounded sandstone buttress)
  3. BoulderCluster     (3 planar-fractured angular chiseled sandstone boulders)
  4. CurbStoneStrip     (~6.4m row of 12 irregular bevelled flagstone curb slabs)

Vertex Color Channel "Col" (exported as COLOR_0 in GLB):
  R: material mask (1.0 = dark basalt cap slabs, 0.0 = red sandstone strata, 0.5 = sunlit boulder)
  G: ambient occlusion (0.42 at Y=0 / recessed crevices -> 1.0 on upper exposed ledges)
  B: bevel/sun edge highlight weight

Run:
  & "C:\\Blender\\blender.exe" -b -P "d:\\Games\\Balance5\\scripts\\blender_build_test_d_kit.py"
"""
import math
import os
import random
import bpy
import bmesh
from mathutils import Matrix, Vector, noise

OUT_GLB = r"d:\Games\Balance5\assets\models\canyon_kit_test_d.glb"


def hash_jitter(seed: int) -> random.Random:
    return random.Random(seed)


def _apply_box_uv(bm_local: bmesh.types.BMesh, uv_layer, scale: float = 0.55) -> None:
    for face in bm_local.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                loop[uv_layer].uv = (co.x * scale, co.y * scale)
            elif ax >= ay:
                loop[uv_layer].uv = (co.y * scale, co.z * scale)
            else:
                loop[uv_layer].uv = (co.x * scale, co.z * scale)


def _stamp_rock_outcrop(
    target_bm: bmesh.types.BMesh,
    center: Vector,
    size: Vector,
    yaw_rad: float,
    tilt_x: float,
    tilt_y: float,
    mat_id: float,
    base_ao: float,
    seed: int,
    bevel_width: float = 0.05,
    taper_top: float = 0.78,
    shear_cuts: int = 3,
    cap_basalt_on_top: bool = True,
    force_boulder_col: bool = False,
) -> None:
    """
    Builds an angular, chiseled sedimentary rock slab or outcrop using a stretched
    asymmetrical prism sliced by planar fracture cuts and single-segment sharp bevels
    (no boxy cubes, no barrel flutes).
    """
    rng = random.Random(seed)
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)

    # Stretch into rock slab dimensions, taper top, and apply asymmetrical corner shifts
    top_dx = rng.uniform(-0.10, 0.10) * size.x
    top_dy = rng.uniform(-0.10, 0.10) * size.y
    for v in tmp.verts:
        is_top = v.co.z > 0.0
        taper = taper_top if is_top else 1.0
        n_val = noise.noise(Vector((v.co.x * 1.9 + seed * 0.7, v.co.y * 1.9, v.co.z * 1.7)))
        vx = v.co.x * size.x * taper + (top_dx if is_top else 0.0) + 0.08 * size.x * n_val
        vy = v.co.y * size.y * taper + (top_dy if is_top else 0.0) + 0.08 * size.y * n_val
        top_slope = (0.07 * v.co.x - 0.06 * v.co.y) * size.z if is_top else 0.0
        vz = (v.co.z + 0.5) * size.z + top_slope
        v.co = Vector((vx, vy, vz))

    # 2-3 clean angled planar cleavage cuts break rectangular symmetry into jagged facets
    for k in range(shear_cuts):
        ang = rng.uniform(0.0, math.tau)
        elev = rng.uniform(0.18, 0.85) if k < 2 else rng.uniform(0.75, 1.20)
        p_norm = Vector((math.cos(ang) * math.cos(elev), math.sin(ang) * math.cos(elev), math.sin(elev))).normalized()
        cut_offset = min(size.x, size.y) * rng.uniform(0.32, 0.45)
        plane_co = Vector((0.0, 0.0, size.z * 0.48)) + p_norm * cut_offset
        geom = list(tmp.verts) + list(tmp.edges) + list(tmp.faces)
        ret = bmesh.ops.bisect_plane(
            tmp,
            geom=geom,
            plane_co=plane_co,
            plane_no=p_norm,
            clear_outer=True,
        )
        cut_edges = [g for g in ret.get("geom_cut", []) if isinstance(g, bmesh.types.BMEdge)]
        if cut_edges:
            bmesh.ops.contextual_create(tmp, geom=cut_edges)

    bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))

    # Crisp 1-segment bevel catches real directional sunlight along angular rock ridges
    if len(tmp.edges) > 0:
        bmesh.ops.bevel(
            tmp,
            geom=list(tmp.edges),
            offset=bevel_width,
            segments=1,
            affect='EDGES',
            clamp_overlap=True,
        )
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))

    rot = Matrix.Rotation(yaw_rad, 4, 'Z') @ Matrix.Rotation(tilt_y, 4, 'Y') @ Matrix.Rotation(tilt_x, 4, 'X')
    xform = Matrix.Translation(center) @ rot
    bmesh.ops.transform(tmp, matrix=xform, verts=list(tmp.verts))
    tmp.normal_update()

    uv_layer = target_bm.loops.layers.uv.get("UVMap") or target_bm.loops.layers.uv.new("UVMap")
    col_layer = target_bm.loops.layers.color.get("Col") or target_bm.loops.layers.color.new("Col")

    z_min = min((v.co.z for v in tmp.verts), default=0.0)
    z_max = max((v.co.z for v in tmp.verts), default=1.0)
    z_span = max(z_max - z_min, 0.05)

    vert_map = {}
    for v in tmp.verts:
        vert_map[v] = target_bm.verts.new(v.co)

    for face in tmp.faces:
        new_verts = [vert_map[v] for v in face.verts]
        try:
            nf = target_bm.faces.new(new_verts)
        except ValueError:
            continue
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        # Only truly horizontal step tops on basalt-capped outcrops get charcoal basalt
        if force_boulder_col:
            face_mat = 0.0
        elif cap_basalt_on_top and n.z > 0.78:
            face_mat = 1.0
        else:
            face_mat = mat_id

        for loop in nf.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                loop[uv_layer].uv = (co.x * 0.55, co.y * 0.55)
            elif ax >= ay:
                loop[uv_layer].uv = (co.y * 0.55, co.z * 0.55)
            else:
                loop[uv_layer].uv = (co.x * 0.55, co.z * 0.55)

            rel_z = max(0.0, min(1.0, (co.z - z_min) / z_span))
            ground_ao = 0.50 + 0.50 * max(0.0, min(1.0, co.z / 0.48))
            ao = min(1.0, base_ao * (0.72 + 0.28 * rel_z) * ground_ao)
            if force_boulder_col:
                loop[col_layer] = (0.0, ao, 1.0, 1.0)
            else:
                edge_wear = max(0.0, min(0.40, rel_z * (0.18 + 0.22 * max(0.0, n.z))))
                loop[col_layer] = (face_mat, ao, edge_wear, 1.0)

    tmp.free()


def build_terrace_module(name: str, side: str, variant_seed_offset: int = 0) -> bpy.types.Object:
    """
    side == 'left':  inner verge near x = 0.0 stepping upward outward toward x = -3.0m
    side == 'right': inner verge near x = 0.0 stepping upward outward toward x = +3.0m
    Constructed from chiseled angular sandstone slabs, dark basalt shelf caps, and
    clean terracotta sandstone bluffs (~6.4m along Blender Y).
    """
    sgn = -1.0 if side == "left" else 1.0
    seed_base = (101 if side == "left" else 509) + variant_seed_offset
    rng = random.Random(seed_base)
    bm = bmesh.new()

    # Tier 1: Wide low angular basalt & weathered sandstone roadside shelves + open coves (h = 0.22..0.48m)
    y_cursor = -3.05
    idx = 0
    while y_cursor < 3.05:
        blk_len = rng.uniform(0.74, 1.24)
        # Leave wider open sandy coves for boulders & sagebushes
        if (side == "left" and idx in (2, 5)) or (side == "right" and idx in (1, 4)):
            y_cursor += blk_len * 0.85
            idx += 1
            continue
        x_in = rng.uniform(0.04, 0.40) * sgn
        blk_w = rng.uniform(0.72, 1.08)
        blk_h = rng.uniform(0.22, 0.46)
        _stamp_rock_outcrop(
            bm,
            center=Vector((x_in + sgn * blk_w * 0.46, y_cursor + blk_len * 0.42, -0.05)),
            size=Vector((blk_w, blk_len * 1.10, blk_h + 0.05)),
            yaw_rad=rng.uniform(-0.34, 0.34),
            tilt_x=rng.uniform(-0.06, 0.06),
            tilt_y=rng.uniform(-0.06, 0.06) * sgn,
            mat_id=1.0 if (idx % 3 != 0) else 0.0,
            base_ao=0.88,
            seed=seed_base + idx * 17,
            bevel_width=0.045,
            taper_top=rng.uniform(0.74, 0.88),
            shear_cuts=3,
            cap_basalt_on_top=True,
        )
        y_cursor += blk_len * 0.84
        idx += 1

    # Tier 2: Stratified mid outcrops with clean terracotta risers & overhanging dark basalt caps (h = 0.86..1.35m)
    y_cursor = -3.15
    idx2 = 0
    while y_cursor < 3.15:
        blk_len = rng.uniform(0.86, 1.32)
        x_mid = rng.uniform(0.62, 1.12) * sgn
        blk_w = rng.uniform(0.98, 1.38)
        blk_h = rng.uniform(0.84, 1.32)
        _stamp_rock_outcrop(
            bm,
            center=Vector((x_mid + sgn * blk_w * 0.48, y_cursor + blk_len * 0.46, -0.06)),
            size=Vector((blk_w, blk_len * 1.14, blk_h * 0.78 + 0.06)),
            yaw_rad=rng.uniform(-0.28, 0.28),
            tilt_x=rng.uniform(-0.05, 0.05),
            tilt_y=rng.uniform(-0.05, 0.05),
            mat_id=0.0 if (idx2 % 3 != 2) else 1.0,
            base_ao=0.85,
            seed=seed_base + 200 + idx2 * 23,
            bevel_width=0.055,
            taper_top=rng.uniform(0.74, 0.88),
            shear_cuts=3,
            cap_basalt_on_top=False,  # Keep terracotta sandstone risers clean without diagonal black stripes
        )
        # Overhanging flat dark basalt shelf cap plate
        _stamp_rock_outcrop(
            bm,
            center=Vector((x_mid + sgn * blk_w * 0.45, y_cursor + blk_len * 0.44, blk_h * 0.68)),
            size=Vector((blk_w * rng.uniform(0.92, 1.06), blk_len * 1.06, blk_h * rng.uniform(0.22, 0.30))),
            yaw_rad=rng.uniform(-0.24, 0.24),
            tilt_x=rng.uniform(-0.04, 0.04),
            tilt_y=rng.uniform(-0.04, 0.04),
            mat_id=1.0,
            base_ao=0.96,
            seed=seed_base + 400 + idx2 * 29,
            bevel_width=0.042,
            taper_top=rng.uniform(0.78, 0.90),
            shear_cuts=2,
            cap_basalt_on_top=True,
        )
        y_cursor += blk_len * 0.88
        idx2 += 1

    # Tier 3: Clean terracotta sandstone cliff bluffs & buttresses (zero basalt stripes on sheared flanks)
    y_cursor = -3.20
    idx3 = 0
    while y_cursor < 3.20:
        blk_len = rng.uniform(1.15, 1.66)
        buttress_bulge = 0.42 if (side == "right" and -1.3 < y_cursor < 1.3) else rng.uniform(0.0, 0.22)
        x_back = (rng.uniform(1.42, 1.88) - buttress_bulge) * sgn
        blk_w = rng.uniform(1.28, 1.68)
        blk_h = rng.uniform(1.62, 2.38)
        _stamp_rock_outcrop(
            bm,
            center=Vector((x_back + sgn * blk_w * 0.48, y_cursor + blk_len * 0.48, -0.06)),
            size=Vector((blk_w, blk_len * 1.15, blk_h + 0.06)),
            yaw_rad=rng.uniform(-0.26, 0.26),
            tilt_x=rng.uniform(-0.04, 0.04),
            tilt_y=rng.uniform(-0.04, 0.04),
            mat_id=0.0,
            base_ao=0.92,
            seed=seed_base + 700 + idx3 * 31,
            bevel_width=0.075,
            taper_top=rng.uniform(0.68, 0.82),
            shear_cuts=3,
            cap_basalt_on_top=False,  # 100% warm terracotta sandstone strata!
        )
        y_cursor += blk_len * 0.90
        idx3 += 1

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mesh.color_attributes:
        mesh.color_attributes.active_color_index = 0
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _make_faceted_boulder(target_bm: bmesh.types.BMesh, center: Vector, radii: Vector, seed: int) -> None:
    """Carves an angular planar-faceted chiseled sandstone boulder using bisect planes."""
    rng = random.Random(seed)
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=2, radius=1.0)
    for v in tmp.verts:
        n = noise.noise(v.co * 1.5 + Vector((seed, seed * 0.3, 0.0)))
        v.co = Vector((v.co.x * radii.x * (1.0 + 0.20 * n),
                       v.co.y * radii.y * (1.0 + 0.20 * n),
                       v.co.z * radii.z * (1.0 + 0.16 * n)))

    # Cut 7 sharp planar cleavage planes for sculpted angular sandstone silhouette
    for k in range(7):
        ang_z = rng.uniform(0, math.tau)
        elev = rng.uniform(0.18, 1.15)
        p_norm = Vector((math.cos(ang_z) * math.cos(elev), math.sin(ang_z) * math.cos(elev), math.sin(elev))).normalized()
        plane_dist = radii.length * rng.uniform(0.42, 0.56)
        geom = list(tmp.verts) + list(tmp.edges) + list(tmp.faces)
        ret = bmesh.ops.bisect_plane(
            tmp,
            geom=geom,
            plane_co=p_norm * plane_dist,
            plane_no=p_norm,
            clear_outer=True,
        )
        cut_edges = [g for g in ret.get("geom_cut", []) if isinstance(g, bmesh.types.BMEdge)]
        if cut_edges:
            bmesh.ops.contextual_create(tmp, geom=cut_edges)
    # Flat-ish bottom cut so boulders embed cleanly into Y=0 sand
    geom = list(tmp.verts) + list(tmp.edges) + list(tmp.faces)
    ret_bot = bmesh.ops.bisect_plane(
        tmp,
        geom=geom,
        plane_co=Vector((0.0, 0.0, -radii.z * 0.45)),
        plane_no=Vector((0.0, 0.0, -1.0)),
        clear_outer=True,
    )
    cut_edges_bot = [g for g in ret_bot.get("geom_cut", []) if isinstance(g, bmesh.types.BMEdge)]
    if cut_edges_bot:
        bmesh.ops.contextual_create(tmp, geom=cut_edges_bot)

    bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=0.024, segments=1, affect='EDGES', clamp_overlap=True)
    bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(center), verts=list(tmp.verts))
    tmp.normal_update()

    uv_layer = target_bm.loops.layers.uv.get("UVMap") or target_bm.loops.layers.uv.new("UVMap")
    col_layer = target_bm.loops.layers.color.get("Col") or target_bm.loops.layers.color.new("Col")

    z_min = min(v.co.z for v in tmp.verts)
    z_max = max(v.co.z for v in tmp.verts)
    z_span = max(z_max - z_min, 0.05)

    vmap = {v: target_bm.verts.new(v.co) for v in tmp.verts}
    for face in tmp.faces:
        try:
            nf = target_bm.faces.new([vmap[v] for v in face.verts])
        except ValueError:
            continue
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in nf.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                loop[uv_layer].uv = (co.x * 0.7, co.y * 0.7)
            elif ax >= ay:
                loop[uv_layer].uv = (co.y * 0.7, co.z * 0.7)
            else:
                loop[uv_layer].uv = (co.x * 0.7, co.z * 0.7)
            rel_z = (co.z - z_min) / z_span
            ao = 0.58 + 0.42 * rel_z
            # Exact (0.0, ao, 1.0, 1.0): 0.0 and 1.0 are invariant across sRGB->linear conversion in GLTF/Godot
            loop[col_layer] = (0.0, ao, 1.0, 1.0)
    tmp.free()


def build_boulder_cluster(name: str = "BoulderCluster") -> bpy.types.Object:
    bm = bmesh.new()
    _make_faceted_boulder(bm, Vector((0.0, 0.0, 0.21)), Vector((0.44, 0.40, 0.38)), seed=301)
    _make_faceted_boulder(bm, Vector((0.36, -0.32, 0.12)), Vector((0.30, 0.27, 0.23)), seed=302)
    _make_faceted_boulder(bm, Vector((-0.28, 0.34, 0.08)), Vector((0.21, 0.19, 0.15)), seed=303)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mesh.color_attributes:
        mesh.color_attributes.active_color_index = 0
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_curb_strip(name: str = "CurbStoneStrip") -> bpy.types.Object:
    """Clustered irregular flat 3D sandstone/slate flagstones with natural sandy gaps along ~6.4m."""
    rng = random.Random(909)
    bm = bmesh.new()
    y_pos = -2.95
    idx = 0
    while y_pos < 2.95:
        s_len = rng.uniform(0.38, 0.72)
        # Leave natural sandy breaks along the road verge (not a uniform dotted line)
        if idx in (2, 6, 9):
            y_pos += s_len * rng.uniform(0.75, 1.05)
            idx += 1
            continue
        s_wid = rng.uniform(0.26, 0.44)
        s_hei = rng.uniform(0.035, 0.075)
        use_golden = (idx % 3 == 0)
        _stamp_rock_outcrop(
            bm,
            center=Vector((rng.uniform(-0.14, 0.14), y_pos, -0.015)),
            size=Vector((s_wid, s_len, s_hei + 0.02)),
            yaw_rad=rng.uniform(-0.48, 0.48),
            tilt_x=rng.uniform(-0.04, 0.04),
            tilt_y=rng.uniform(-0.04, 0.04),
            mat_id=0.0 if (idx % 2 == 0) else 1.0,
            base_ao=0.86,
            seed=950 + idx * 13,
            bevel_width=0.016,
            taper_top=0.82,
            shear_cuts=2,
            cap_basalt_on_top=False,
            force_boulder_col=use_golden,
        )
        y_pos += s_len * rng.uniform(0.88, 1.25)
        idx += 1

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mesh.color_attributes:
        mesh.color_attributes.active_color_index = 0
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)

    left_obj = build_terrace_module("TerraceLeftModule", "left", 0)
    left_obj_b = build_terrace_module("TerraceLeftModuleB", "left", 77)
    right_obj = build_terrace_module("TerraceRightModule", "right", 0)
    right_obj_b = build_terrace_module("TerraceRightModuleB", "right", 91)
    boulder_obj = build_boulder_cluster("BoulderCluster")
    curb_obj = build_curb_strip("CurbStoneStrip")

    for ob in (left_obj, left_obj_b, right_obj, right_obj_b, boulder_obj, curb_obj):
        mesh = ob.data
        print(f"Built {ob.name}: verts={len(mesh.vertices)}, faces={len(mesh.polygons)}, cols={list(mesh.color_attributes.keys())}")

    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format='GLB',
        use_selection=False,
        export_yup=True,
        export_attributes=True,
    )
    print(f"Exported kit -> {OUT_GLB}")


if __name__ == "__main__":
    main()
