"""Build game-ready isometric textures for 2D Painted Forest Fight 3.

Reads native PNGs from assets/source_inputs/forest_fight_3/ and writes to assets/textures/forest_fight_3/:
- iso_forest_bg.png          (1920x1280 strictly-isometric forest cliff trail)
- iso_forest_cave_lip.png    (640x480 foreground NE cave arch + hanging vines, placed at (1280, 0))
- iso_cavern_bg.png          (1920x1280 Miyazaki dreamy pastel cavern)
- iso_cavern_entry_lip.png   (480x580 foreground SW entrance arch roof, placed at (0, 500))
- commander_iso_8way.png     (960x1600, 3 cols x 5 rows of 320x320 normalized RGBA cells: SE, NE, E, S, N)
- bat_iso_sheet.png          (2100x420, 5 cols x 1 row of 420x420 RGBA cells: FlapUp, FlapDown, Dive, DorsalNW, HangSleep)
"""

from __future__ import annotations

import collections
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = REPO_ROOT / "assets" / "source_inputs" / "forest_fight_3"
OUT_DIR = REPO_ROOT / "assets" / "textures" / "forest_fight_3"


def remove_solid_bg(
    cell_rgb: np.ndarray,
    bg_color: np.ndarray,
    flood_tol: float,
    hole_tol: float,
    soft_low: float,
    soft_high: float,
    protect_warm_cream: bool = False,
) -> np.ndarray:
    """Flood-fill exterior background + enclosed neutral holes with RGB edge decontamination."""
    h, w, _ = cell_rgb.shape
    diff = np.linalg.norm(cell_rgb.astype(np.float32) - bg_color[None, None, :], axis=2)
    max_c = cell_rgb.max(axis=2).astype(np.float32)
    min_c = cell_rgb.min(axis=2).astype(np.float32)
    chroma = max_c - min_c

    can_flood = diff < flood_tol
    if protect_warm_cream:
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

    if hole_tol > 0.0:
        hole_candidates = (~bg_mask) & (diff < hole_tol) & (chroma < 12.0)
        visited = np.zeros((h, w), dtype=bool)
        for y in range(h):
            for x in range(w):
                if hole_candidates[y, x] and not visited[y, x]:
                    comp: list[tuple[int, int]] = []
                    cq = collections.deque([(y, x)])
                    visited[y, x] = True
                    min_d = 999.0
                    while cq:
                        py, px = cq.popleft()
                        comp.append((py, px))
                        if diff[py, px] < min_d:
                            min_d = float(diff[py, px])
                        for ny, nx in ((py - 1, px), (py + 1, px), (py, px - 1), (py, px + 1)):
                            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and hole_candidates[ny, nx]:
                                visited[ny, nx] = True
                                cq.append((ny, nx))
                    if len(comp) >= 12 and min_d < 8.5:
                        for py, px in comp:
                            bg_mask[py, px] = True

    bg_img = Image.fromarray((bg_mask.astype(np.uint8) * 255), mode="L")
    dilated = np.array(bg_img.filter(ImageFilter.MaxFilter(3))) > 127
    rim = dilated & (~bg_mask)

    alpha = np.where(bg_mask, 0.0, 1.0).astype(np.float32)
    rim_alpha = np.clip((diff - soft_low) / max(1.0, (soft_high - soft_low)), 0.0, 1.0)
    alpha = np.where(rim, rim_alpha, alpha)

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


def build_environment_plates() -> None:
    # 1. Isometric Forest Trail (1536x1024 -> 1920x1280 exact 1.25x)
    trail = Image.open(SRC_DIR / "forest_trail.png").convert("RGB").resize((1920, 1280), Image.Resampling.LANCZOS)
    trail = trail.filter(ImageFilter.UnsharpMask(radius=1.0, percent=40, threshold=2))
    trail.save(OUT_DIR / "iso_forest_bg.png", optimize=True)

    # Extract NE cave arch + right cave wall foreground lip in [1280..1920, 0..480] (640x480)
    # In 1920x1280 coords, the dark cave throat spans roughly x=1470..1760, y=130..315.
    # The upper stone slab arch sits above y_arch(x), and the right-hand foreground stone pillar sits at x >= 1735!
    lip_crop = trail.crop((1280, 0, 1920, 480)).convert("RGBA")
    arr = np.array(lip_crop, dtype=np.float32)
    luma = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    green_ex = arr[:, :, 1] - 0.5 * (arr[:, :, 0] + arr[:, :, 2])
    yy, xx = np.mgrid[0:480, 0:640]
    wx = xx + 1280

    # Isometric arch roof line across the cave mouth + right-side stone pillar that stands in front of a walking hero!
    arch_roof_y = 176.0 + 0.0024 * ((wx - 1615.0) ** 2)
    in_box = (wx >= 1410) & (wx <= 1870) & (yy <= 385)
    solid_arch = in_box & ((yy <= arch_roof_y) | ((wx >= 1742) & (yy <= 355) & (luma > 48.0)))
    hanging_vines = in_box & (yy > arch_roof_y - 4.0) & (yy <= 252) & (green_ex > 9.5) & (luma > 38.0)

    raw_mask = np.where(solid_arch | hanging_vines, 1.0, 0.0).astype(np.float32)
    fade_x = np.clip((wx - 1410.0) / 24.0, 0.0, 1.0) * np.clip((1870.0 - wx) / 24.0, 0.0, 1.0)
    fade_y = np.clip((382.0 - yy) / 18.0, 0.0, 1.0)
    lip_alpha = Image.fromarray(np.round(raw_mask * fade_x * fade_y * 255.0).astype(np.uint8), mode="L")
    lip_alpha = lip_alpha.filter(ImageFilter.GaussianBlur(radius=1.1))
    lip_crop.putalpha(lip_alpha)
    lip_crop.save(OUT_DIR / "iso_forest_cave_lip.png", optimize=True)

    # 2. Isometric Miyazaki Dreamy Pastel Cavern (1536x1024 -> 1920x1280 exact 1.25x)
    cavern = Image.open(SRC_DIR / "forest_cave.png").convert("RGB").resize((1920, 1280), Image.Resampling.LANCZOS)
    cavern = cavern.filter(ImageFilter.UnsharpMask(radius=1.0, percent=40, threshold=2))
    cavern.save(OUT_DIR / "iso_cavern_bg.png", optimize=True)

    # Extract SW sunlit cavern entrance arch upper roof in [0..480, 500..1080] (480x580)
    # In 1920x1280, the sunlit opening is around x=65..320, y=760..1120; the mossy stone arch roof sits above y=775!
    c_lip = cavern.crop((0, 500, 480, 1080)).convert("RGBA")
    cyy, cxx = np.mgrid[0:580, 0:480]
    wy = cyy + 500
    # Upper stone arch & left mossy wall above the sunlit tunnel floor
    arch_curve = 796.0 + 0.35 * (cxx - 140.0)
    in_c_arch = (cxx <= 345) & (wy >= 530) & (wy <= 940) & ((wy <= arch_curve) | (cxx <= 82))
    c_fade = (
        np.clip((365.0 - cxx) / 24.0, 0.0, 1.0)
        * np.clip((wy - 530.0) / 22.0, 0.0, 1.0)
        * np.clip((960.0 - wy) / 22.0, 0.0, 1.0)
    )
    c_alpha = Image.fromarray(np.round(in_c_arch.astype(np.float32) * c_fade * 255.0).astype(np.uint8), mode="L")
    c_alpha = c_alpha.filter(ImageFilter.GaussianBlur(radius=1.4))
    c_lip.putalpha(c_alpha)
    c_lip.save(OUT_DIR / "iso_cavern_entry_lip.png", optimize=True)
    print("Saved iso_forest_bg.png, iso_forest_cave_lip.png, iso_cavern_bg.png, iso_cavern_entry_lip.png")


def build_commander_8way_atlas() -> None:
    s1 = np.array(Image.open(SRC_DIR / "forest_commander_sheet1.png").convert("RGB"))  # 1536x1024 (3x2 of 512x512)
    s2 = np.array(Image.open(SRC_DIR / "forest_commander_sheet2.png").convert("RGB"))  # 1254x1254 (3x3 of 418x418)

    bg1 = np.median(s1[0:8, :, :], axis=(0, 1)).astype(np.float32)
    bg2 = np.median(s2[0:8, :, :], axis=(0, 1)).astype(np.float32)

    out_cell = 320
    boot_anchor_y = 296
    center_anchor_x = 160
    target_idle_h = 256.0  # Uniform height across all 5 directional rows!

    atlas = Image.new("RGBA", (out_cell * 3, out_cell * 5), (0, 0, 0, 0))
    row_names = ["SE", "NE", "E", "S", "N"]

    # Gather raw rows: 2 rows from s1, 3 rows from s2
    raw_rows: list[tuple[str, list[np.ndarray], np.ndarray]] = [
        ("SE", [s1[0:512, c * 512 : (c + 1) * 512] for c in range(3)], bg1),
        ("NE", [s1[512:1024, c * 512 : (c + 1) * 512] for c in range(3)], bg1),
    ]
    cw2 = s2.shape[1] // 3
    for r_idx, name in enumerate(["E", "S", "N"]):
        raw_rows.append(
            (name, [s2[r_idx * cw2 : (r_idx + 1) * cw2, c * cw2 : (c + 1) * cw2] for c in range(3)], bg2)
        )

    for out_r, (r_name, cells, bg_col) in enumerate(raw_rows):
        cutouts: list[np.ndarray] = []
        heights: list[int] = []
        for raw_c in cells:
            rgba = remove_solid_bg(
                raw_c,
                bg_color=bg_col,
                flood_tol=25.0,
                hole_tol=21.0,
                soft_low=10.5,
                soft_high=27.0,
                protect_warm_cream=True,
            )
            cutouts.append(rgba)
            ys, _ = np.where(rgba[:, :, 3] > 32)
            heights.append(int(ys.max() - ys.min() + 1))

        # Scale the entire row uniformly based on its Idle cell (col 0) so stride bob stays natural!
        row_scale = target_idle_h / float(heights[0])

        for col_idx, rgba in enumerate(cutouts):
            im = Image.fromarray(rgba)
            nw = max(1, int(round(im.width * row_scale)))
            nh = max(1, int(round(im.height * row_scale)))
            im_scaled = im.resize((nw, nh), Image.Resampling.LANCZOS)
            arr_s = np.array(im_scaled)
            ys, xs = np.where(arr_s[:, :, 3] > 32)
            y_top, y_bot = int(ys.min()), int(ys.max())

            # Measure torso horizontal center around waist/chest (35%..60% height) so scarf & rifle barrel don't skew X!
            ty0 = y_top + int(0.35 * (y_bot - y_top))
            ty1 = y_top + int(0.60 * (y_bot - y_top))
            torso_xs = np.where(arr_s[ty0:ty1, :, 3] > 128)[1]
            x_torso = int(np.median(torso_xs))

            dx = center_anchor_x - x_torso
            dy = boot_anchor_y - y_bot

            cell_canvas = Image.new("RGBA", (out_cell, out_cell), (0, 0, 0, 0))
            cell_canvas.alpha_composite(im_scaled, (dx, dy))
            atlas.paste(cell_canvas, (col_idx * out_cell, out_r * out_cell))

        print(f"Commander row {out_r} ({r_name}): raw_idle_h={heights[0]}px -> scaled to {target_idle_h:.0f}px")

    atlas.save(OUT_DIR / "commander_iso_8way.png", optimize=True)
    print("Saved commander_iso_8way.png (960x1600, 3x5 of 320x320)")


def build_bat_iso_sheet() -> None:
    src = np.array(Image.open(SRC_DIR / "forest_bats.png").convert("RGB"))  # 1254x1254 (2x2 of 627x627)
    bg_col = np.median(src[0:10, :, :], axis=(0, 1)).astype(np.float32)
    half = src.shape[0] // 2

    out_cell = 420
    strip = Image.new("RGBA", (out_cell * 5, out_cell), (0, 0, 0, 0))
    scaled_cells: list[Image.Image] = []

    for idx in range(4):
        r, c = divmod(idx, 2)
        raw_c = src[r * half : (r + 1) * half, c * half : (c + 1) * half]
        rgba = remove_solid_bg(
            raw_c,
            bg_color=bg_col,
            flood_tol=17.0,
            hole_tol=0.0,
            soft_low=8.5,
            soft_high=23.0,
            protect_warm_cream=False,
        )
        # Scale 627 -> 380 so each bat fits comfortably in 420x420 with crisp detail
        im_s = Image.fromarray(rgba).resize((380, 380), Image.Resampling.LANCZOS)
        arr_s = np.array(im_s)
        ys, xs = np.where(arr_s[:, :, 3] > 32)
        cx = int(0.5 * (xs.min() + xs.max()))
        cy = int(0.5 * (ys.min() + ys.max()))

        canvas = Image.new("RGBA", (out_cell, out_cell), (0, 0, 0, 0))
        canvas.alpha_composite(im_s, (out_cell // 2 - cx, out_cell // 2 - cy))
        strip.paste(canvas, (idx * out_cell, 0))
        scaled_cells.append(canvas)
        print(f"Bat iso frame {idx}: centered bbox=({xs.max()-xs.min()+1}x{ys.max()-ys.min()+1})")

    # Build Frame 4: Sleeping / Roosting Bat hanging upside-down under a tree branch!
    # Rotate Frame 2 (-52 deg) so claws point straight UP to grip a branch while wings drape vertically down!
    roost_base = scaled_cells[2].rotate(-52.0, resample=Image.Resampling.BICUBIC, expand=False)
    rw = int(round(out_cell * 0.72))
    roost_wrapped = roost_base.resize((rw, out_cell), Image.Resampling.LANCZOS)
    roost_rgb = ImageEnhance.Brightness(roost_wrapped.convert("RGB")).enhance(0.86)
    roost_final = Image.merge("RGBA", (*roost_rgb.split(), roost_wrapped.split()[3]))

    r_arr = np.array(roost_final)
    rys, rxs = np.where(r_arr[:, :, 3] > 32)
    rcx = int(0.5 * (rxs.min() + rxs.max()))
    rcy = int(0.5 * (rys.min() + rys.max()))
    roost_canvas = Image.new("RGBA", (out_cell, out_cell), (0, 0, 0, 0))
    roost_canvas.alpha_composite(roost_final, (out_cell // 2 - rcx, out_cell // 2 - rcy))
    strip.paste(roost_canvas, (4 * out_cell, 0))
    print("Built Frame 4 (upside-down wrapped sleeping bat for forest tree branch)")

    strip.save(OUT_DIR / "bat_iso_sheet.png", optimize=True)
    print("Saved bat_iso_sheet.png (2100x420, 5 frames of 420x420)")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_environment_plates()
    build_commander_8way_atlas()
    build_bat_iso_sheet()


if __name__ == "__main__":
    main()
