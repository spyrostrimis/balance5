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


def _stamp_stepped_ledge_block(
    target_bm: bmesh.types.BMesh,
    center: Vector,
    size: Vector,
    yaw_rad: float,
    mat_id: float,
    base_ao: float,
    seed: int,
    bevel_width: float = 0.028,
    taper_top: float = 0.95,
    cap_basalt_on_top: bool = True,
) -> None:
    """
    Builds a crisp, blocky Octopath-style sedimentary terrace block with a flat
    horizontal top, near-vertical striated walls, subtle micro-roughness, and
    small bevelled edges (preserving D1's locked blocky structure).
    """
    sub_stages = 2 if size.z > 1.25 else 1
    z_base = center.z

    uv_layer = target_bm.loops.layers.uv.get("UVMap") or target_bm.loops.layers.uv.new("UVMap")
    col_layer = target_bm.loops.layers.color.get("Col") or target_bm.loops.layers.color.new("Col")

    for st in range(sub_stages):
        st_frac_0 = float(st) / float(sub_stages)
        st_frac_1 = float(st + 1) / float(sub_stages)
        st_h = size.z * (st_frac_1 - st_frac_0)
        st_shrink = 1.0 - st * 0.06
        st_z = z_base + size.z * st_frac_0

        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            is_top = v.co.z > 0.0
            taper = taper_top if is_top else 1.0
            n_val = noise.noise(Vector((v.co.x * 1.3 + seed + st * 17, v.co.y * 1.3, v.co.z * 1.5)))
            vx = v.co.x * size.x * st_shrink * taper + n_val * 0.018 * size.x
            vy = v.co.y * size.y * (1.0 - st * 0.02) * taper + n_val * 0.018 * size.y
            # Keep horizontal tops crisp and flat (tiny 0.008m vertical variation only)
            vz = (v.co.z + 0.5) * st_h + (n_val * 0.008 if is_top else 0.0)
            v.co = Vector((vx, vy, vz))

        bmesh.ops.bevel(
            tmp,
            geom=list(tmp.edges),
            offset=bevel_width,
            segments=1,
            affect='EDGES',
            clamp_overlap=True,
        )
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))

        rot = Matrix.Rotation(yaw_rad, 4, 'Z')
        xform = Matrix.Translation(Vector((center.x - st * 0.06, center.y, st_z))) @ rot
        bmesh.ops.transform(tmp, matrix=xform, verts=list(tmp.verts))
        tmp.normal_update()

        z_min = min((v.co.z for v in tmp.verts), default=0.0)
        z_max = max((v.co.z for v in tmp.verts), default=1.0)
        z_span = max(z_max - z_min, 0.05)

        vert_map = {v: target_bm.verts.new(v.co) for v in tmp.verts}
        for face in tmp.faces:
            try:
                nf = target_bm.faces.new([vert_map[v] for v in face.verts])
            except ValueError:
                continue
            n = face.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            # Only true flat horizontal shelf tops receive warm grey-brown cap stone when enabled
            face_mat = 1.0 if (cap_basalt_on_top and n.z > 0.82) else mat_id

            for loop in nf.loops:
                co = loop.vert.co
                if az >= ax and az >= ay:
                    loop[uv_layer].uv = (co.x * 0.55, co.y * 0.55)
                elif ax >= ay:
                    loop[uv_layer].uv = (co.y * 0.55, co.z * 0.55)
                else:
                    loop[uv_layer].uv = (co.x * 0.55, co.z * 0.55)

                rel_z = max(0.0, min(1.0, (co.z - z_min) / z_span))
                ground_ao = 0.56 + 0.44 * max(0.0, min(1.0, co.z / 0.55))
                ao = min(1.0, base_ao * (0.76 + 0.24 * rel_z) * ground_ao)
                edge_wear = max(0.0, min(0.40, rel_z * (0.16 + 0.22 * max(0.0, n.z))))
                loop[col_layer] = (face_mat, ao, edge_wear, 1.0)

        tmp.free()


def build_strata_wall_left(name: str, variant_seed_offset: int = 0) -> bpy.types.Object:
    """
    Full-Height Left 'Strata Wall' (6.5m along Blender Y = -3.25..+3.25, overlapping 0.3m at 6.2m spacing):
    7 continuous blocky stepped courses rising from road verge (x = 0.0) up to Y = 5.95m (above camera 3.8m)
    matching Img 1's left terraced sedimentary cliff framing.
    """
    seed_base = 101 + variant_seed_offset
    rng = random.Random(seed_base)
    bm = bmesh.new()

    def _stamp_course(
        y_start: float,
        y_end: float,
        len_range: tuple,
        x_inner_range: tuple,
        width_range: tuple,
        height_range: tuple,
        mat_id: float,
        base_ao: float,
        cap_on_top: bool,
        course_seed: int,
        cove_y: tuple = (),
        cove_recess: float = 0.38,
        promontory_y: float = -99.0,
        overhang_cap: bool = False,
        base_z: float = -0.06,
    ) -> None:
        yc = y_start
        idx = 0
        while yc < y_end:
            blk_len = rng.uniform(len_range[0], len_range[1])
            blk_mid_y = yc + blk_len * 0.5
            in_cove = any(abs(blk_mid_y - cy) < 0.68 for cy in cove_y)
            cove_dx = -cove_recess if in_cove else 0.0
            prom_dx = 0.34 if abs(blk_mid_y - promontory_y) < 0.85 else 0.0

            x_in = -rng.uniform(x_inner_range[0], x_inner_range[1]) + cove_dx + prom_dx
            blk_w = rng.uniform(width_range[0], width_range[1])
            blk_h = rng.uniform(height_range[0], height_range[1])
            cx = x_in - blk_w * 0.48
            cy = yc + blk_len * 0.48
            step_yaw = rng.uniform(-0.045, 0.045)

            if overhang_cap:
                # Terracotta riser underneath + thick flat dark weathered stone cap overhang
                riser_h = blk_h * 0.82
                cap_h = max(0.22, blk_h * 0.22)
                _stamp_stepped_ledge_block(
                    bm,
                    center=Vector((cx, cy, base_z)),
                    size=Vector((blk_w, blk_len * 1.08, riser_h - base_z)),
                    yaw_rad=step_yaw,
                    mat_id=0.0,
                    base_ao=base_ao * 0.94,
                    seed=course_seed + idx * 17,
                    bevel_width=0.026,
                    taper_top=0.96,
                    cap_basalt_on_top=False,
                )
                _stamp_stepped_ledge_block(
                    bm,
                    center=Vector((cx + 0.04, cy, riser_h - 0.04)),
                    size=Vector((blk_w * 1.03, blk_len * 1.08, cap_h)),
                    yaw_rad=step_yaw * 0.8,
                    mat_id=1.0,
                    base_ao=min(1.0, base_ao * 1.06),
                    seed=course_seed + 400 + idx * 19,
                    bevel_width=0.024,
                    taper_top=0.95,
                    cap_basalt_on_top=True,
                )
            else:
                _stamp_stepped_ledge_block(
                    bm,
                    center=Vector((cx, cy, base_z)),
                    size=Vector((blk_w, blk_len * 1.09, blk_h - base_z)),
                    yaw_rad=step_yaw,
                    mat_id=mat_id,
                    base_ao=base_ao,
                    seed=course_seed + idx * 17,
                    bevel_width=0.030,
                    taper_top=0.95,
                    cap_basalt_on_top=cap_on_top,
                )

            yc += blk_len * 0.92
            idx += 1

    # Course 0: Continuous dark slate verge step along road border (h = 0.38..0.52m, deeper coves at y=-1.35 & +1.15)
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(0.75, 1.12), x_inner_range=(0.04, 0.16), width_range=(0.58, 0.72), height_range=(0.38, 0.52),
        mat_id=1.0, base_ao=0.88, cap_on_top=True, course_seed=seed_base + 100,
        cove_y=(-1.35, 1.15), cove_recess=0.54,
    )

    # Course 1: Second dark stepped course (h = 0.82..1.06m)
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(0.82, 1.18), x_inner_range=(0.48, 0.66), width_range=(0.72, 0.88), height_range=(0.82, 1.06),
        mat_id=1.0, base_ao=0.86, cap_on_top=True, course_seed=seed_base + 200,
        cove_y=(1.15,), cove_recess=0.34,
    )

    # Course 2: Transition terracotta riser topped with continuous warm grey-brown cap slab (h = 1.32..1.65m)
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(0.90, 1.32), x_inner_range=(1.05, 1.24), width_range=(0.88, 1.04), height_range=(1.32, 1.65),
        mat_id=0.0, base_ao=0.89, cap_on_top=True, course_seed=seed_base + 300,
        overhang_cap=True,
    )

    # Course 3: Lower blocky red sandstone bluff course (h = 2.15..2.65m) with flat grey-brown top shelf
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(1.05, 1.52), x_inner_range=(1.72, 1.96), width_range=(1.08, 1.26), height_range=(2.15, 2.65),
        mat_id=0.0, base_ao=0.92, cap_on_top=True, course_seed=seed_base + 500,
        promontory_y=-0.35 if variant_seed_offset == 0 else 0.75,
    )

    # Course 4: Mid sandstone cliff wall with stacked buttress & promontories (h = 3.10..3.75m)
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(1.12, 1.58), x_inner_range=(2.52, 2.78), width_range=(1.18, 1.42), height_range=(3.10, 3.75),
        mat_id=0.0, base_ao=0.93, cap_on_top=True, course_seed=seed_base + 700,
        promontory_y=0.95 if variant_seed_offset == 0 else -1.10,
    )

    # Course 5: Above-camera sandstone cliff wall rising past CameraRig Y=3.8m (h = 4.15..4.85m)
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(1.18, 1.65), x_inner_range=(3.32, 3.62), width_range=(1.32, 1.58), height_range=(4.15, 4.85),
        mat_id=0.0, base_ao=0.94, cap_on_top=True, course_seed=seed_base + 900,
        promontory_y=-1.40 if variant_seed_offset == 0 else 0.45,
    )

    # Course 6: Upper canyon rim wall (h = 5.20..6.10m)
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(1.25, 1.72), x_inner_range=(4.12, 4.46), width_range=(1.75, 2.10), height_range=(5.20, 6.10),
        mat_id=0.0, base_ao=0.96, cap_on_top=True, course_seed=seed_base + 1100,
    )

    # Course 7: Outer Mesa Rim Wall extending wide & high so no sky peeks at upper-left (h = 6.35..7.55m)
    _stamp_course(
        y_start=-3.25, y_end=3.20,
        len_range=(1.35, 1.85), x_inner_range=(5.25, 5.65), width_range=(2.60, 3.10), height_range=(6.35, 7.55),
        mat_id=0.0, base_ao=0.98, cap_on_top=True, course_seed=seed_base + 1300,
    )

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mesh.color_attributes:
        mesh.color_attributes.active_color_index = 0
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_gateway_bluff_left(name: str = "GatewayBluffLeft") -> bpy.types.Object:
    """
    Tall outer stepped canyon-mouth shoulder placed at Z = -13.2 on the left flank
    to frame the upper-left canyon mouth cleanly (closing the sky triangle at far left
    while keeping the sunlit canyon exit corridor completely open).
    """
    bm = bmesh.new()
    # Stepped buttresses rising outward from x = -1.6m out to -14.5m and h = 1.6m -> 8.2m
    steps = [
        # (cx, cy, sx, sy, h, mat_id, seed)
        (-2.25, 0.2, 1.5, 2.8, 1.65, 1.0, 2101),
        (-3.45, 0.0, 2.1, 3.2, 3.10, 0.0, 2102),
        (-5.10, -0.2, 2.6, 3.5, 4.85, 0.0, 2103),
        (-7.40, -0.4, 3.4, 3.8, 6.45, 0.0, 2104),
        (-10.80, -0.6, 4.6, 4.2, 8.15, 0.0, 2105),
    ]
    for cx, cy, sx, sy, h, mid, sd in steps:
        _stamp_stepped_ledge_block(
            bm,
            center=Vector((cx, cy, -0.06)),
            size=Vector((sx, sy, h + 0.06)),
            yaw_rad=0.06,
            mat_id=mid,
            base_ao=0.94,
            seed=sd,
            bevel_width=0.04,
            taper_top=0.93,
            cap_basalt_on_top=True,
        )

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

    left_obj = build_strata_wall_left("TerraceLeftModule", 0)
    left_obj_b = build_strata_wall_left("TerraceLeftModuleB", 77)
    gate_left_obj = build_gateway_bluff_left("GatewayBluffLeft")
    right_obj = build_terrace_module("TerraceRightModule", "right", 0)
    right_obj_b = build_terrace_module("TerraceRightModuleB", "right", 91)
    boulder_obj = build_boulder_cluster("BoulderCluster")
    curb_obj = build_curb_strip("CurbStoneStrip")

    for ob in (left_obj, left_obj_b, gate_left_obj, right_obj, right_obj_b, boulder_obj, curb_obj):
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
