"""Generate ultra-crisp 2048x2048 (4.0m x 4.0m) hand-laid sandstone cobble PBR maps
and assemble side-by-side comparison strips for desert_canyon_ultra_crisp_test.

Usage:
  & "C:/Python312/python.exe" "tools/python/build_ultra_crisp_cobble.py"
  & "C:/Python312/python.exe" "tools/python/build_ultra_crisp_cobble.py" --make-strips
"""

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

SIZE = 2048
TILE_METRES = 4.0
PER_METRE = SIZE / TILE_METRES  # 512 texels / metre
ROOT = Path(__file__).resolve().parents[2]
TEX_DIR = ROOT / "assets" / "textures" / "canyon_pbr"
CAP_DIR = ROOT / "render_captures" / "ultra_crisp_test"


def smoothstep(value: np.ndarray) -> np.ndarray:
    t = np.clip(value, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def angular_periodic_noise(rng: np.random.Generator, divisions: int, power: float = 1.0) -> np.ndarray:
    """Piecewise-linear periodic lattice noise (crisp facets, zero INTER_CUBIC Gaussian blur)."""
    lattice = rng.uniform(-1.0, 1.0, (divisions, divisions)).astype(np.float32)
    if power != 1.0:
        lattice = np.sign(lattice) * (np.abs(lattice) ** power)
    tiled = np.tile(lattice, (3, 3))
    up = cv2.resize(tiled, (3 * SIZE, 3 * SIZE), interpolation=cv2.INTER_LINEAR)
    return up[SIZE:2 * SIZE, SIZE:2 * SIZE]


def cell_fracture_noise(rng: np.random.Generator, num_cells: int) -> np.ndarray:
    """Periodic Voronoi crystal fracture edge noise for sharp rock facets & pits."""
    pts = rng.uniform(0.0, float(SIZE), (num_cells, 2)).astype(np.float32)
    # Build tiled points for exact wrap
    all_pts = []
    for ox in (-SIZE, 0.0, SIZE):
        for oy in (-SIZE, 0.0, SIZE):
            shifted = pts + np.array([ox, oy], dtype=np.float32)
            all_pts.append(shifted)
    all_pts_arr = np.vstack(all_pts)

    # Evaluate on a 512 grid and bilinear-upscale (keeps crisp ridges with fast build)
    g = 512
    scale = SIZE / g
    coords = (np.arange(g, dtype=np.float32) + 0.5) * scale
    gx, gy = np.meshgrid(coords, coords)
    q = np.stack([gx.ravel(), gy.ravel()], axis=1)  # (262144, 2)

    # Chunked nearest-2 distance computation
    d1 = np.full(q.shape[0], 1e12, dtype=np.float32)
    d2 = np.full(q.shape[0], 1e12, dtype=np.float32)
    for k in range(0, all_pts_arr.shape[0], 64):
        chunk = all_pts_arr[k:k + 64]
        dist2 = ((q[:, None, :] - chunk[None, :, :]) ** 2).sum(axis=2)
        part = np.partition(dist2, 1, axis=1)[:, :2]
        cand1 = np.minimum(d1, part[:, 0])
        cand2 = np.minimum(d2, np.maximum(d1, part[:, 0]))
        cand2 = np.minimum(cand2, part[:, 1])
        d1, d2 = cand1, cand2

    edge_dist = (np.sqrt(d2) - np.sqrt(d1)).reshape(g, g)
    tiled = np.tile(edge_dist, (3, 3))
    full = cv2.resize(tiled, (3 * SIZE, 3 * SIZE), interpolation=cv2.INTER_LINEAR)[SIZE:2 * SIZE, SIZE:2 * SIZE]
    return full


def encode_u8(arr: np.ndarray) -> np.ndarray:
    return np.clip(np.rint(arr), 0.0, 255.0).astype(np.uint8)


def measure_wrap(arr: np.ndarray) -> None:
    f = arr.astype(np.float32)
    x_adj = float(np.abs(f[:, 1:, :] - f[:, :-1, :]).mean())
    x_wrap = float(np.abs(f[:, -1, :] - f[:, 0, :]).mean())
    z_adj = float(np.abs(f[1:, :, :] - f[:-1, :, :]).mean())
    z_wrap = float(np.abs(f[-1, :, :] - f[0, :, :]).mean())
    print(f"Wrap check | X adj={x_adj:.3f} wrap={x_wrap:.3f} ({x_wrap / max(x_adj, 1e-4):.2f}x) | "
          f"Z adj={z_adj:.3f} wrap={z_wrap:.3f} ({z_wrap / max(z_adj, 1e-4):.2f}x)")


def generate_maps() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(771301)

    # Sharp, non-bicubic mineral & stone surface detail scaled to survive -13 deg foreshortening
    facet_rough = angular_periodic_noise(rng, 48, 0.85) * 0.55 + angular_periodic_noise(rng, 128, 0.9) * 0.45
    crystal_edges = cell_fracture_noise(rng, 220)  # distance to facet ridges in texels
    fine_grains = angular_periodic_noise(rng, 320, 0.7) * 0.6 + angular_periodic_noise(rng, 640, 0.6) * 0.4
    sand_specks = rng.normal(0.0, 1.0, (SIZE // 2, SIZE // 2)).astype(np.float32)
    sand_specks = cv2.resize(np.tile(sand_specks, (3, 3)), (3 * SIZE, 3 * SIZE), interpolation=cv2.INTER_NEAREST)[SIZE:2 * SIZE, SIZE:2 * SIZE]

    # Sharp hairline fracture lines inside rocks
    cracks = 1.0 - smoothstep(crystal_edges / 3.2)

    # Recessed joint mortar: warm sand pockets + crisp 2-texel dark/bright sand grains
    sand_pocket = smoothstep((facet_rough + 0.20) / 1.10)
    mortar_col = (
        np.array([94.0, 62.0, 36.0], dtype=np.float32)[None, None, :]
        + sand_pocket[..., None] * np.array([42.0, 30.0, 18.0], dtype=np.float32)
        + np.clip(fine_grains, -1.0, 1.0)[..., None] * np.array([16.0, 12.0, 8.0], dtype=np.float32)
        + np.clip(sand_specks, -1.5, 1.5)[..., None] * np.array([14.0, 11.0, 7.0], dtype=np.float32)
    )
    height = np.full((SIZE, SIZE), 0.0012, dtype=np.float32) + fine_grains * 0.00035
    faces = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    coverage = np.zeros((SIZE, SIZE), dtype=np.float32)
    crevice_weight = np.ones((SIZE, SIZE), dtype=np.float32)
    rim_weight = np.zeros((SIZE, SIZE), dtype=np.float32)
    inset_max = np.full((SIZE, SIZE), -50.0, dtype=np.float32)

    # 18 transverse courses across 4.0m (mean ~22.2cm per row = ~114 texels)
    course_depths = rng.uniform(86.0, 142.0, 18)
    course_depths *= SIZE / course_depths.sum()
    course_edges = np.r_[0.0, np.cumsum(course_depths)]

    for course, depth in enumerate(course_depths):
        centre_z = (course_edges[course] + depth * 0.5 + 28.0) % SIZE
        count = int(rng.integers(10, 14))
        widths = rng.uniform(0.68, 1.36, count)
        widths *= SIZE / widths.sum()
        offset = (course * 89.0 + rng.uniform(-45.0, 45.0)) % SIZE
        row_warmth = rng.uniform(-8.0, 8.0)

        for width in widths:
            centre_x = (offset + width * 0.5) % SIZE
            offset += width
            z_start = rng.uniform(-8.5, 8.5)

            margin = 34
            x_indices = np.arange(int(centre_x - width * 0.5 - margin), int(centre_x + width * 0.5 + margin + 1))
            z_indices = np.arange(int(centre_z - depth * 0.5 - margin), int(centre_z + depth * 0.5 + margin + 1))
            ix = np.ix_(z_indices % SIZE, x_indices % SIZE)

            x = x_indices[None, :] - centre_x
            phase = 2.0 * np.pi * x_indices[None, :] / SIZE
            bend = 11.4 * np.sin(3.0 * phase + course * 0.53) + 5.6 * np.sin(7.0 * phase - course * 1.11)
            z = z_indices[:, None] - centre_z - bend - z_start - x * rng.uniform(-0.12, 0.12)

            wedge = rng.uniform(-0.44, 0.44) if rng.random() < 0.18 else rng.uniform(-0.14, 0.14)
            x = x - z * wedge * 0.50

            # Leave ~14-18 texels (~2.8-3.5cm) total joint gap so dark crevices never average out vertically at -13 deg
            half_x = np.maximum(24.0, (width * 0.5 - rng.uniform(7.0, 12.5)) * (1.0 + wedge * z / depth))
            half_z = max(22.0, depth * 0.5 - rng.uniform(7.0, 11.5))
            rounding = float(min(half_z * rng.uniform(0.32, 0.62), float(half_x.min()) * 0.55))

            qx = np.abs(x) - half_x + rounding
            qz = np.abs(z) - half_z + rounding
            inset = rounding - (np.hypot(np.maximum(qx, 0.0), np.maximum(qz, 0.0)) + np.minimum(np.maximum(qx, qz), 0.0))

            # Angular rock edge chipping (crisp fractal notches along perimeter)
            edge_chip = np.maximum(0.0, 1.0 - crystal_edges[ix] / 9.0) * 5.2
            inset = inset + facet_rough[ix] * 3.4 + fine_grains[ix] * 1.6 - edge_chip

            # Angular corner fracture bevel (straight chisel cleavage cut off one corner, never a circular donut hole!)
            if rng.random() < 0.62:
                sx_sgn = -1.0 if rng.random() < 0.5 else 1.0
                sz_sgn = -1.0 if rng.random() < 0.5 else 1.0
                ang_cut = (half_x * rng.uniform(0.55, 0.82) - sx_sgn * x) * 0.72 + (half_z * rng.uniform(0.50, 0.78) - sz_sgn * z) * 1.05
                inset = np.minimum(inset, ang_cut + facet_rough[ix] * 2.8)

            # HARD 1.8-texel boundary (~3.5mm) — eliminates 10-texel soft blurry gradient
            alpha = smoothstep((inset + 0.9) / 1.8)

            # Tight dark crevice seam right outside each stone border (-7 < inset <= 0.6)
            near_crev = smoothstep((inset + 8.5) / 3.5) * (1.0 - smoothstep((inset - 0.3) / 1.4))
            crevice_weight[ix] = np.minimum(crevice_weight[ix], 1.0 - near_crev * 0.78)
            inset_max[ix] = np.maximum(inset_max[ix], inset)

            # Height profile: crisp plateau crown with short beveled cliff lip (6-10 texels)
            shoulder = smoothstep(inset / rng.uniform(5.5, 9.5))
            dome = np.clip(1.0 - 0.30 * (x / half_x) ** 2 - 0.36 * (z / half_z) ** 2, 0.0, 1.0)
            planar_tilt = (x / half_x) * rng.uniform(-0.0022, 0.0022) + (z / half_z) * rng.uniform(-0.0022, 0.0022)
            stone_h = 0.0025 + shoulder * (
                rng.uniform(0.022, 0.032) * (0.65 + 0.35 * dome)
                + planar_tilt
                + facet_rough[ix] * 0.0018
                + fine_grains[ix] * 0.0008
                - cracks[ix] * 0.0028
            )

            # Concept color palette: sunlit warm sandstone stones (155..238) + subtle hue diversity per stone
            tone = rng.uniform(-22.0, 20.0) + row_warmth
            hue_shift = np.array([rng.uniform(-6.0, 8.0), rng.uniform(-4.0, 5.0), rng.uniform(-7.0, 5.0)], dtype=np.float32)
            base_stone = np.array([182.0, 138.0, 92.0], dtype=np.float32) + tone + hue_shift

            # Crisp sunlit upper/right bevel highlight (-Z / +X rim) + subtle camera-facing +Z/-X front chamfer
            norm_x = x / np.maximum(half_x, 1.0)
            norm_z = z / np.maximum(half_z, 1.0)
            # In Godot world X=right, Z=back-to-front (+Z toward camera). DesertSun comes from (+X, -Z) upper-right!
            sun_face = np.clip(0.55 * norm_x - 0.72 * norm_z + 0.15, -1.0, 1.0)
            rim_band = smoothstep((inset - 0.5) / 2.0) * (1.0 - smoothstep((inset - 11.0) / 5.0))
            crown_lift = np.maximum(0.0, sun_face) * rim_band * 46.0
            front_lip_dark = np.maximum(0.0, -sun_face) * rim_band * 26.0
            joint_dark = (1.0 - shoulder) * 26.0

            surface_detail = (
                facet_rough[ix] * 11.0
                + fine_grains[ix] * 9.5
                + np.clip(sand_specks[ix], -1.2, 1.2) * 5.0
                - cracks[ix] * 24.0
            )
            paint = base_stone + crown_lift[..., None] + surface_detail[..., None] - front_lip_dark[..., None] - joint_dark[..., None]
            paint += dome[..., None] * 12.0

            # Angular linear spall flake inside stone (faceted wedge notch, NOT circular dots)
            if rng.random() < 0.65:
                u_sp = (x / np.maximum(half_x, 1.0)) * rng.uniform(-1.0, 1.0) + (z / np.maximum(half_z, 1.0)) * rng.uniform(-0.8, 0.8)
                v_sp = -(x / np.maximum(half_x, 1.0)) * 0.7 + (z / np.maximum(half_z, 1.0)) * 1.1
                flake_d = max_d = np.maximum(np.abs(u_sp - 0.35) * 2.8, np.abs(v_sp - 0.20) * 3.4)
                flake_mask = (1.0 - smoothstep((flake_d - 0.42 + facet_rough[ix] * 0.08) / 0.12)) * alpha * shoulder
                flake_rim = (1.0 - smoothstep((flake_d - 0.55) / 0.12)) * (1.0 - flake_mask) * np.clip(-v_sp + 0.25, 0.0, 1.0) * alpha
                paint = paint - flake_mask[..., None] * 26.0 + flake_rim[..., None] * 22.0
                stone_h = stone_h - flake_mask * 0.0038

            height[ix] = np.where(alpha > coverage[ix], np.maximum(height[ix], stone_h), height[ix])
            faces[ix] = np.where((alpha > coverage[ix])[..., None], paint, faces[ix])
            coverage[ix] = np.maximum(coverage[ix], alpha)
            rim_weight[ix] = np.maximum(rim_weight[ix], rim_band * alpha)

    # Darken tight crevices in mortar drastically (Concept espresso-umber crevices RGB ~[36, 22, 12])
    dark_crevice = np.array([34.0, 20.0, 11.0], dtype=np.float32)[None, None, :]
    mortar_final = mortar_col * crevice_weight[..., None] + dark_crevice * (1.0 - crevice_weight[..., None])
    # Add crisp high-contrast stray sand grains right along stone seams
    speck_hi = (sand_specks > 1.35) & (coverage < 0.5) & (crevice_weight > 0.45)
    mortar_final = np.where(speck_hi[..., None], np.array([228.0, 186.0, 128.0], dtype=np.float32), mortar_final)

    albedo = mortar_final * (1.0 - coverage[..., None]) + faces * coverage[..., None]
    albedo = encode_u8(albedo)

    # Tangent-space normal map matching Godot conventions (-dx, +dz, +1) from physical metre height
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * (PER_METRE * 0.5)
    dz = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * (PER_METRE * 0.5)
    normal = np.stack((-dx, dz, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    normal_u8 = encode_u8((normal * 0.5 + 0.5) * 255.0)

    # ORM map: R = deep cavity AO (0.16 in crevices -> 1.0 on stone crowns), G = roughness (0.46 crown -> 0.96 joint), B = rim highlight
    cavity_ao = np.where(
        coverage > 0.5,
        0.74 + 0.26 * smoothstep(np.clip(inset_max, 0.0, 24.0) / 10.0) - cracks * 0.36,
        0.16 + 0.48 * crevice_weight,
    )
    cavity_ao = np.clip(cavity_ao, 0.14, 1.0)
    roughness = np.where(
        coverage > 0.5,
        0.48 + (1.0 - smoothstep(np.clip(inset_max, 0.0, 24.0) / 14.0)) * 0.24 - rim_weight * 0.08 + np.clip(cracks, 0.0, 1.0) * 0.25,
        0.96,
    )
    roughness = np.clip(roughness, 0.40, 0.98)
    orm_u8 = encode_u8(np.dstack((cavity_ao * 255.0, roughness * 255.0, rim_weight * 255.0)))

    Image.fromarray(albedo).save(TEX_DIR / "ultra_crisp_cobble_albedo.png")
    Image.fromarray(normal_u8).save(TEX_DIR / "ultra_crisp_cobble_normal.png")
    Image.fromarray(orm_u8).save(TEX_DIR / "ultra_crisp_cobble_orm.png")
    print(f"Saved ultra_crisp_cobble_* (2048x2048) to {TEX_DIR}")
    measure_wrap(albedo)


def make_comparison_strips() -> None:
    """Assemble close-up road-detail strip (comparing directly with uploaded Concept crop)
    and full-frame strip across locked cam & steeper diorama cameras."""
    CAP_DIR.mkdir(parents=True, exist_ok=True)
    concept_src = ROOT / "assets" / "textures" / "maps" / "desert_approach_rpg_albedo.png"
    s3_spawn = ROOT / "render_captures" / "session3_sandstone" / "walk_pos1_start.png"

    # Match the Concept · road detail crop around the sunlit center cobblestones (1376x768 coords)
    def crop_road(img: Image.Image) -> Image.Image:
        # Center-foreground cobblestone band right below/around Commander's boots: 360x220 zoomed cleanly to 420x256
        w, h = img.size
        box = (int(w * 0.37), int(h * 0.50), int(w * 0.65), int(h * 0.80))
        return img.crop(box).resize((420, 260), Image.Resampling.LANCZOS)

    # Load captures if available
    panels = []
    if concept_src.exists():
        c_im = Image.open(concept_src).convert("RGB")
        panels.append(("Concept · road detail", crop_road(c_im)))
    if s3_spawn.exists():
        s3_im = Image.open(s3_spawn).convert("RGB")
        panels.append(("Session 3 (-13 deg)", crop_road(s3_im)))

    test_files = [
        ("Split Patch (-13 deg)", CAP_DIR / "1_locked_cam_split_patch_pos1_start.png"),
        ("Ultra-Crisp (-13 deg)", CAP_DIR / "2_locked_cam_full_crisp_pos1_start.png"),
        ("Ultra-Crisp (-17.5 deg)", CAP_DIR / "3_cam_a_pitch17_5_pos1_start.png"),
        ("Ultra-Crisp (-21.0 deg)", CAP_DIR / "4_cam_b_pitch21_0_pos1_start.png"),
    ]
    for label, path in test_files:
        if path.exists():
            panels.append((label, crop_road(Image.open(path).convert("RGB"))))

    if panels:
        header = 32
        pad = 6
        tw = sum(p[1].width for p in panels) + pad * (len(panels) - 1)
        th = panels[0][1].height + header
        strip = Image.new("RGB", (tw, th), (24, 20, 17))
        draw = ImageDraw.Draw(strip)
        x = 0
        for label, im in panels:
            draw.text((x + 8, 8), label, fill=(242, 230, 210))
            strip.paste(im, (x, header))
            x += im.width + pad
        strip.save(CAP_DIR / "comparison_road_detail_spawn.png")
        print(f"Saved {CAP_DIR / 'comparison_road_detail_spawn.png'}")

    # Full-frame 2x2 grid comparing Spawn across the 4 captures
    grid_files = [
        ("1. Center Patch vs Session 3 (-13° Locked)", CAP_DIR / "1_locked_cam_split_patch_pos1_start.png"),
        ("2. Full Ultra-Crisp Road (-13° Locked)", CAP_DIR / "2_locked_cam_full_crisp_pos1_start.png"),
        ("3. Ultra-Crisp + Camera -17.5° / Y=4.85m", CAP_DIR / "3_cam_a_pitch17_5_pos1_start.png"),
        ("4. Ultra-Crisp + Camera -21.0° / Y=5.65m", CAP_DIR / "4_cam_b_pitch21_0_pos1_start.png"),
    ]
    loaded = [(lbl, Image.open(p).convert("RGB")) for lbl, p in grid_files if p.exists()]
    if len(loaded) >= 2:
        cw, ch = 688, 384
        header = 28
        cols = 2
        rows = (len(loaded) + 1) // 2
        sheet = Image.new("RGB", (cols * cw + 8, rows * (ch + header) + 8), (22, 18, 15))
        draw = ImageDraw.Draw(sheet)
        for idx, (lbl, im) in enumerate(loaded):
            r = idx // cols
            c = idx % cols
            x0 = c * (cw + 8)
            y0 = r * (ch + header + 8)
            draw.text((x0 + 10, y0 + 6), lbl, fill=(245, 232, 210))
            sheet.paste(im.resize((cw, ch), Image.Resampling.LANCZOS), (x0, y0 + header))
        sheet.save(CAP_DIR / "comparison_full_frames.png")
        print(f"Saved {CAP_DIR / 'comparison_full_frames.png'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--make-strips", action="store_true")
    args = parser.parse_args()
    if args.make_strips:
        make_comparison_strips()
    else:
        generate_maps()
