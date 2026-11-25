"""Build game-ready textures for 2D Painted Forest Fight 2 from ChatGPT source art.

Copies raw source images into assets/source_inputs/forest_fight_2/ and outputs:
- assets/textures/forest_fight_2/forest_cave_trail.png   (1086x1448 seamless composite)
- assets/textures/forest_fight_2/forest_cave_lip.png     (1536x420 foreground rock arch/vines)
- assets/textures/forest_fight_2/cave_chamber_bg.png     (1536x1024 cave arena background)
- assets/textures/forest_fight_2/cave_foreground_rim.png (1536x110 low bottom rock rim)
- assets/textures/forest_fight_2/commander_hd_combat.png (6x1 strip of 360x360 aligned HD cells)
- assets/textures/forest_fight_2/alien_bat_hd.png        (4x1 strip of 512x512 aligned HD cells)
- assets/textures/forest_fight_2/bolt_hd.png             (72x24 HD cyan energy bolt)
- assets/textures/forest_fight_2/muzzle_flash_hd.png     (64x48 HD directional muzzle flash)
- assets/textures/forest_fight_2/armour_spark_hd.png     (96x96 HD blue armour deflection spark)
- assets/textures/forest_fight_2/bat_hit_spark_hd.png    (96x96 HD cyan-amber impact burst)
"""

from __future__ import annotations

import collections
import math
import os
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter


REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = REPO_ROOT / "assets" / "source_inputs" / "forest_fight_2"
OUT_DIR = REPO_ROOT / "assets" / "textures" / "forest_fight_2"
ORIG_FOREST = REPO_ROOT / "assets" / "scenes" / "forest_test" / "a-buttress-light.png"


def remove_solid_bg(
    cell_rgb: np.ndarray,
    bg_color: np.ndarray,
    flood_tol: float,
    hole_tol: float,
    soft_low: float,
    soft_high: float,
    protect_warm_cream: bool = False,
) -> np.ndarray:
    """Flood-fill exterior background + enclosed background holes with clean edge defringing."""
    h, w, _ = cell_rgb.shape
    diff = np.linalg.norm(cell_rgb.astype(np.float32) - bg_color[None, None, :], axis=2)

    # Color saturation / chroma helps distinguish cream scarf (warm yellow-ivory) from neutral grey-white bg
    max_c = cell_rgb.max(axis=2).astype(np.float32)
    min_c = cell_rgb.min(axis=2).astype(np.float32)
    chroma = max_c - min_c

    can_flood = diff < flood_tol
    if protect_warm_cream:
        # Scarf has noticeably warmer chroma (R-B > 18) than the neutral #E3E2DC card (R-B ~ 6)
        warmth = cell_rgb[:, :, 0].astype(np.float32) - cell_rgb[:, :, 2].astype(np.float32)
        can_flood = can_flood & (warmth < 18.0)

    bg_mask = np.zeros((h, w), dtype=bool)
    q: collections.deque[tuple[int, int]] = collections.deque()

    for x in range(w):
        for y in (0, h - 1):
            if can_flood[y, x] and not bg_mask[y, x]:
                bg_mask[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if can_flood[y, x] and not bg_mask[y, x]:
                bg_mask[y, x] = True
                q.append((y, x))

    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg_mask[ny, nx] and can_flood[ny, nx]:
                bg_mask[ny, nx] = True
                q.append((ny, nx))

    # Also clear enclosed background pockets (e.g. between arm, rifle stock, and torso)
    # Only clear pockets whose pixels closely match the neutral background color AND low chroma
    hole_candidates = (~bg_mask) & (diff < hole_tol) & (chroma < 12.0)
    visited = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if hole_candidates[y, x] and not visited[y, x]:
                comp: list[tuple[int, int]] = []
                cq = collections.deque([(y, x)])
                visited[y, x] = True
                min_diff_in_comp = 999.0
                while cq:
                    py, px = cq.popleft()
                    comp.append((py, px))
                    if diff[py, px] < min_diff_in_comp:
                        min_diff_in_comp = float(diff[py, px])
                    for ny, nx in ((py - 1, px), (py + 1, px), (py, px - 1), (py, px + 1)):
                        if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and hole_candidates[ny, nx]:
                            visited[ny, nx] = True
                            cq.append((ny, nx))
                # Genuine background cutout holes have centers very close to bg_color (< 8 RGB distance) and >= 12 px
                if len(comp) >= 12 and min_diff_in_comp < 8.5:
                    for py, px in comp:
                        bg_mask[py, px] = True

    # Build anti-aliased alpha along the 1-2 px boundary of bg_mask
    bg_img = Image.fromarray((bg_mask.astype(np.uint8) * 255), mode="L")
    dilated = np.array(bg_img.filter(ImageFilter.MaxFilter(3))) > 127
    rim = dilated & (~bg_mask)

    alpha = np.where(bg_mask, 0.0, 1.0).astype(np.float32)
    rim_alpha = np.clip((diff - soft_low) / max(1.0, (soft_high - soft_low)), 0.0, 1.0)
    alpha = np.where(rim, rim_alpha, alpha)

    # Decontaminate RGB on semi-transparent rim pixels: C_fg = (C_obs - (1-a)*C_bg) / a
    rgb = cell_rgb.astype(np.float32).copy()
    semi = (alpha > 0.02) & (alpha < 0.99)
    for ch in range(3):
        rgb[:, :, ch] = np.where(
            semi,
            np.clip((rgb[:, :, ch] - (1.0 - alpha) * bg_color[ch]) / np.maximum(alpha, 0.15), 0.0, 255.0),
            rgb[:, :, ch],
        )

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.round(rgb).astype(np.uint8)
    rgba[:, :, 3] = np.round(alpha * 255.0).astype(np.uint8)
    return rgba


def build_forest_plates(cave_patch_path: Path) -> None:
    orig = Image.open(ORIG_FOREST).convert("RGBA")  # 1086 x 1448
    patch = Image.open(cave_patch_path).convert("RGBA").resize((1086, 724), Image.Resampling.LANCZOS)

    # Blend ONLY the clearing end & cave rock outcrop onto orig so the two foreground tree trunks
    # and the entire lower walk stay 100% faithful to a-buttress-light.png.
    mask = Image.new("L", (1086, 1448), 0)
    draw = ImageDraw.Draw(mask)
    # Polygon covering the clearing north end between the two tall trunks (in 1086x1448 coords:
    # left trunk is around x=285..365, right trunk is around x=665..755, boulder is around x=585..685, y=225..310)
    draw.polygon(
        [
            (310, 0),
            (745, 0),
            (720, 195),
            (660, 235),  # Stay left/above the mossy boulder so the boulder matches 100%
            (595, 295),
            (565, 345),
            (405, 345),
            (355, 240),
        ],
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(radius=20))

    full_patch = orig.copy()
    full_patch.paste(patch, (0, 0))
    composite = Image.composite(full_patch, orig, mask)
    composite.convert("RGB").save(OUT_DIR / "forest_cave_trail.png", optimize=True)

    # Now build the foreground rock-arch & hanging-vines lip in 1536x420 (1536x2048 canvas top space)
    comp_canvas_top = composite.crop((0, 0, 1086, 297)).resize((1536, 420), Image.Resampling.LANCZOS)
    arr = np.array(comp_canvas_top, dtype=np.float32)
    luma = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    green_excess = arr[:, :, 1] - 0.5 * (arr[:, :, 0] + arr[:, :, 2])

    # Region where the Commander walks into the cave mouth: x in [560..900], y in [0..320]
    lip_alpha = np.zeros((420, 1536), dtype=np.float32)
    yy, xx = np.mgrid[0:420, 0:1536]

    # Arch roof curve: arch stone + hanging vines sit above the dark cave throat.
    # Anything inside the arch zone with sufficient brightness or green vine color above y=268 belongs to the lip!
    in_arch_box = (xx >= 520) & (xx <= 935) & (yy <= 285)
    # Soft arch ceiling curve: lower on the sides (cave walls), higher in the center (stone lip bottom at y=184, vines to 272)
    norm_x = (xx - 726.0) / 145.0
    arch_solid_y = 184.0 + 74.0 * np.clip(norm_x * norm_x, 0.0, 1.4)

    # Solid rock roof above arch_solid_y
    solid_roof = in_arch_box & (yy <= arch_solid_y)
    # Hanging vines hanging into the dark throat (between arch_solid_y and y=276)
    hanging_detail = (
        in_arch_box
        & (yy > arch_solid_y - 4.0)
        & (yy <= 276)
        & (green_excess > 8.5)
        & (luma > 34.0)
    )

    raw_lip = np.where(solid_roof | hanging_detail, 1.0, 0.0).astype(np.float32)
    # Feather outer box edges (left/right/top) so there is zero hard cut against the background painting
    side_fade = np.clip((xx - 520.0) / 28.0, 0.0, 1.0) * np.clip((935.0 - xx) / 28.0, 0.0, 1.0)
    bottom_fade = np.clip((282.0 - yy) / 14.0, 0.0, 1.0)
    lip_alpha = raw_lip * side_fade * bottom_fade

    lip_mask_img = Image.fromarray(np.round(lip_alpha * 255.0).astype(np.uint8), mode="L")
    lip_mask_img = lip_mask_img.filter(ImageFilter.GaussianBlur(radius=1.1))

    lip_rgba = comp_canvas_top.copy()
    lip_rgba.putalpha(lip_mask_img)
    lip_rgba.save(OUT_DIR / "forest_cave_lip.png", optimize=True)
    print("Saved forest_cave_trail.png (1086x1448) and forest_cave_lip.png (1536x420)")


def build_cave_plates(cave_int_path: Path) -> None:
    cave = Image.open(cave_int_path).convert("RGB").resize((1536, 1024), Image.Resampling.LANCZOS)
    # Subtle crispness pass after Lanczos upscale from 1024x682 -> 1536x1024
    cave = cave.filter(ImageFilter.UnsharpMask(radius=1.1, percent=55, threshold=2))
    cave.save(OUT_DIR / "cave_chamber_bg.png", optimize=True)

    # Extract bottom foreground dark rock rim (rows y=914..1024 -> 110 px tall)
    rim_crop = cave.crop((0, 914, 1536, 1024)).convert("RGBA")
    arr = np.array(rim_crop, dtype=np.float32)
    luma = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    yy, _ = np.mgrid[0:110, 0:1536]
    # Foreground rocks at the bottom are darker (luma < 68) than the brown-ochre floor (luma ~ 85..125)
    rock_mask = ((yy >= 58) | ((yy >= 18) & (luma < 66.0))).astype(np.float32)
    top_fade = np.clip((yy - 14.0) / 22.0, 0.0, 1.0)
    rim_alpha = Image.fromarray(np.round(rock_mask * top_fade * 255.0).astype(np.uint8), mode="L")
    rim_alpha = rim_alpha.filter(ImageFilter.GaussianBlur(radius=2.0))
    rim_crop.putalpha(rim_alpha)
    rim_crop.save(OUT_DIR / "cave_foreground_rim.png", optimize=True)
    print("Saved cave_chamber_bg.png (1536x1024) and cave_foreground_rim.png (1536x110)")


def build_commander_sheet(cmd_path: Path) -> None:
    src = np.array(Image.open(cmd_path).convert("RGB"))
    h, w, _ = src.shape
    cw, ch = w // 3, h // 2
    bg_color = np.median(src[0:8, :, :], axis=(0, 1)).astype(np.float32)

    cell_size = 360
    boot_anchor_y = 342
    body_anchor_x = 180
    strip = Image.new("RGBA", (cell_size * 6, cell_size), (0, 0, 0, 0))

    for idx in range(6):
        r, c = divmod(idx, 3)
        raw_cell = src[r * ch : (r + 1) * ch, c * cw : (c + 1) * cw]
        rgba = remove_solid_bg(
            raw_cell,
            bg_color=bg_color,
            flood_tol=26.0,
            hole_tol=22.0,
            soft_low=11.0,
            soft_high=28.0,
            protect_warm_cream=True,
        )
        alpha = rgba[:, :, 3]
        ys, xs = np.where(alpha > 32)
        y_bottom = int(ys.max())
        y_top = int(ys.min())
        # Measure torso horizontal center around waist/chest (40%..65% down from head) so scarf & wide legs don't shift torso
        mid_y0 = y_top + int(0.32 * (y_bottom - y_top))
        mid_y1 = y_top + int(0.58 * (y_bottom - y_top))
        torso_xs = np.where(alpha[mid_y0:mid_y1, :] > 128)[1]
        # Exclude rifle barrel extending far right by taking 35th percentile..65th percentile around torso
        x_torso = int(np.percentile(torso_xs, 45))

        # Measure muzzle tip (rightmost opaque pixel in upper half)
        upper_ys, upper_xs = np.where(alpha[y_top : y_top + int(0.5 * (y_bottom - y_top)), :] > 96)
        muzzle_x_raw = int(upper_xs.max())
        muzzle_ys_at_tip = upper_ys[upper_xs >= muzzle_x_raw - 3] + y_top
        muzzle_y_raw = int(np.median(muzzle_ys_at_tip))

        dx = body_anchor_x - x_torso
        dy = boot_anchor_y - y_bottom

        cell_img = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
        cell_img.alpha_composite(Image.fromarray(rgba), (dx, dy))
        strip.paste(cell_img, (idx * cell_size, 0))

        print(
            f"Commander frame {idx}: height={y_bottom - y_top + 1}px, "
            f"muzzle_rel_boot=({muzzle_x_raw + dx - body_anchor_x}, {muzzle_y_raw + dy - boot_anchor_y})"
        )

    strip.save(OUT_DIR / "commander_hd_combat.png", optimize=True)
    print("Saved commander_hd_combat.png (2160x360, 6 frames of 360x360)")


def build_bat_sheet(bat_path: Path) -> None:
    src = np.array(Image.open(bat_path).convert("RGB"))
    bg_color = np.median(src[0:10, :, :], axis=(0, 1)).astype(np.float32)

    cell_size = 512
    strip = Image.new("RGBA", (cell_size * 4, cell_size), (0, 0, 0, 0))

    for idx in range(4):
        r, c = divmod(idx, 2)
        raw_cell = src[r * 512 : (r + 1) * 512, c * 512 : (c + 1) * 512]
        rgba = remove_solid_bg(
            raw_cell,
            bg_color=bg_color,
            flood_tol=15.5,
            hole_tol=0.0,
            soft_low=8.0,
            soft_high=22.0,
            protect_warm_cream=False,
        )
        alpha = rgba[:, :, 3]
        ys, xs = np.where(alpha > 32)
        cx = int(0.5 * (xs.min() + xs.max()))
        cy = int(0.5 * (ys.min() + ys.max()))
        dx = (cell_size // 2) - cx
        dy = (cell_size // 2) - cy

        cell_img = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
        cell_img.alpha_composite(Image.fromarray(rgba), (dx, dy))
        strip.paste(cell_img, (idx * cell_size, 0))
        print(f"Bat frame {idx}: bbox=({xs.max()-xs.min()+1}x{ys.max()-ys.min()+1})")

    strip.save(OUT_DIR / "alien_bat_hd.png", optimize=True)
    print("Saved alien_bat_hd.png (2048x512, 4 frames of 512x512)")


def build_vfx_sprites() -> None:
    # 1. Horizontal Cyan Rifle Bolt (72x24)
    w, h = 72, 24
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - 38.0) / 30.0
    ny = (yy - 11.5) / 8.5
    # Tapered tear-drop plasma bolt brighter toward right tip
    taper = np.where(nx < 0, 1.0 + 0.45 * nx, 1.0 - 0.15 * nx)
    dist = np.sqrt((nx * 0.92) ** 2 + (ny / np.maximum(0.35, taper)) ** 2)
    glow = np.clip(1.0 - dist, 0.0, 1.0) ** 1.7
    core = np.clip(1.0 - dist * 2.3, 0.0, 1.0) ** 1.5
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, 0] = np.clip((0.28 * glow + 0.72 * core) * 255.0, 0, 255).astype(np.uint8)
    rgba[:, :, 1] = np.clip((0.86 * glow + 0.14 * core) * 255.0, 0, 255).astype(np.uint8)
    rgba[:, :, 2] = np.clip(1.0 * np.clip(glow * 1.3 + core, 0.0, 1.0) * 255.0, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(glow * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(rgba).save(OUT_DIR / "bolt_hd.png", optimize=True)

    # 2. Muzzle Flash (64x48, pointing right from x=8)
    mw, mh = 64, 48
    yy, xx = np.mgrid[0:mh, 0:mw].astype(np.float32)
    dx = xx - 10.0
    dy = yy - 23.5
    ang = np.arctan2(dy, np.maximum(1.0, dx))
    rad = np.sqrt((dx / 46.0) ** 2 + (dy / 19.0) ** 2)
    spikes = 0.72 + 0.28 * np.cos(ang * 5.0)
    flash = np.where(dx >= -4.0, np.clip(1.0 - rad / spikes, 0.0, 1.0) ** 1.6, 0.0)
    fcore = np.where(dx >= -2.0, np.clip(1.0 - rad * 2.4, 0.0, 1.0) ** 1.4, 0.0)
    m_rgba = np.zeros((mh, mw, 4), dtype=np.uint8)
    m_rgba[:, :, 0] = np.clip((0.40 * flash + 0.60 * fcore) * 255.0, 0, 255).astype(np.uint8)
    m_rgba[:, :, 1] = np.clip((0.90 * flash + 0.10 * fcore) * 255.0, 0, 255).astype(np.uint8)
    m_rgba[:, :, 2] = np.clip(np.clip(flash * 1.2 + fcore, 0.0, 1.0) * 255.0, 0, 255).astype(np.uint8)
    m_rgba[:, :, 3] = np.clip(flash * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(m_rgba).save(OUT_DIR / "muzzle_flash_hd.png", optimize=True)

    # 3. Blue Armour Deflection Spark (96x96) & 4. Bat Hit Spark (96x96)
    for name, tint_outer, rays in [
        ("armour_spark_hd.png", (0.20, 0.76, 1.0), 8),
        ("bat_hit_spark_hd.png", (0.35, 0.96, 0.88), 10),
    ]:
        sw = 96
        yy, xx = np.mgrid[0:sw, 0:sw].astype(np.float32) - 47.5
        r = np.sqrt(xx * xx + yy * yy) / 44.0
        theta = np.arctan2(yy, xx)
        star = 0.52 + 0.48 * (np.abs(np.cos(theta * (rays * 0.5))) ** 3.0)
        ring = np.exp(-(((r - 0.48) / 0.13) ** 2)) * 0.55 if "armour" in name else 0.0
        val = np.clip(np.clip(1.0 - r / star, 0.0, 1.0) ** 1.5 + ring, 0.0, 1.0)
        score = np.clip(1.0 - r * 3.0, 0.0, 1.0) ** 1.4
        s_rgba = np.zeros((sw, sw, 4), dtype=np.uint8)
        s_rgba[:, :, 0] = np.clip((tint_outer[0] * val + score) * 255.0, 0, 255).astype(np.uint8)
        s_rgba[:, :, 1] = np.clip((tint_outer[1] * val + score) * 255.0, 0, 255).astype(np.uint8)
        s_rgba[:, :, 2] = np.clip((tint_outer[2] * val + score) * 255.0, 0, 255).astype(np.uint8)
        s_rgba[:, :, 3] = np.clip(val * 255.0, 0, 255).astype(np.uint8)
        Image.fromarray(s_rgba).save(OUT_DIR / name, optimize=True)

    print("Saved HD VFX sprites (bolt_hd, muzzle_flash_hd, armour_spark_hd, bat_hit_spark_hd)")


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit(
            "Usage: python build_forest_fight_2_art.py <cave_patch.jpg> <cave_int.jpg> <bat_sheet.jpg> <cmd_sheet.jpg>"
        )
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    names = [
        "01_forest_cave_patch.jpg",
        "02_cave_interior.jpg",
        "03_alien_bat_sheet.jpg",
        "04_commander_combat_sheet.jpg",
    ]
    copied: list[Path] = []
    for arg, dst_name in zip(sys.argv[1:], names):
        dst = SRC_DIR / dst_name
        shutil.copy2(arg, dst)
        copied.append(dst)

    build_forest_plates(copied[0])
    build_cave_plates(copied[1])
    build_bat_sheet(copied[2])
    build_commander_sheet(copied[3])
    build_vfx_sprites()


if __name__ == "__main__":
    main()
