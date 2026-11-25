"""Build RTS Units Test — Units on the Map 3 (scenes/maps/rts_units_test_v3.tscn).

    C:/Python312/python.exe tools/python/make_rts_units_test_v3.py

Keeps the original RTS Units Test (scenes/maps/rts_units_test.tscn and scenes/rts/units/look/*.tres)
untouched, and writes the v3 assets and scene:
  assets/textures/rts/units/tank_neutral_1x.png      8x3 sheet of 32x32 neutral tank frames (1x pixel)
  assets/textures/rts/units/tank_mask_1x.png         8x3 sheet of 32x32 team-colour masks (R=team, G=shade, B=trim)
  assets/textures/rts/units/tank_neutral_2x.png      8x3 sheet of 64x64 neutral tank frames (2x hd_painted)
  assets/textures/rts/units/tank_mask_2x.png         8x3 sheet of 64x64 team-colour masks (2x hd_painted)
  assets/textures/rts/units/squad_neutral_1x.png     1x4 sheet of 30x30 4-figure squad frames (idle + 3 walk rows)
  assets/textures/rts/units/squad_mask_1x.png        1x4 sheet of 30x30 squad team-colour masks
  assets/textures/rts/units/squad_neutral_2x.png     1x4 sheet of 60x60 4-figure squad frames (2x hd_painted)
  assets/textures/rts/units/squad_mask_2x.png        1x4 sheet of 60x60 squad team-colour masks
  assets/textures/rts/units/commander_neutral_1x.png 1x4 sheet of 16x16 commander frames (scarf/trim + emblem)
  assets/textures/rts/units/commander_mask_1x.png    1x4 sheet of 16x16 commander masks (B=0.45 scarf/trim, B=1.0 cross/crest)
  assets/textures/rts/units/commander_neutral_2x.png 1x4 sheet of 32x32 commander frames (2x hd_painted)
  assets/textures/rts/units/commander_mask_2x.png    1x4 sheet of 32x32 commander masks (2x hd_painted)
  scenes/rts/units/look_v3/*.tres                    v3 unit types with 1:1 sprite_scale = 1.0 and shader masks
  scenes/maps/rts_units_test_v3.tscn                 the v3 scene
"""
from pathlib import Path
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rts_palette

ROOT = Path(__file__).resolve().parents[2]
T5 = ROOT / "assets" / "textures" / "rts" / "style_test" / "t5"
OUT = ROOT / "assets" / "textures" / "rts" / "units_test"
UNITS_DIR = ROOT / "assets" / "textures" / "rts" / "units"
STATS_DIR = ROOT / "scenes" / "rts" / "units" / "look_v3"
SCENE = ROOT / "scenes" / "maps" / "rts_units_test_v3.tscn"
TILE = 32
OUTLINE_RGB = (34, 24, 20)
SHADOW_RGB = (90, 40, 10)

# name, faction (0 Blue, 1 Red), kind (0 troop, 1 commander), hp, attack, armour, range, cooldown,
# guard, speed, sprite_1x, sprite_2x, mask_1x, mask_2x, directions, frames, vehicle, scale
TYPES = {
    "blue_squad": (
        "Blue Squad", 0, 0, 60, 10, 3, 3, 1.0, 5, 2.4,
        "res://assets/textures/rts/units/squad_neutral_1x.png",
        "res://assets/textures/rts/units/squad_neutral_2x.png",
        "res://assets/textures/rts/units/squad_mask_1x.png",
        "res://assets/textures/rts/units/squad_mask_2x.png",
        1, 4, False, 1.0,
    ),
    "red_squad": (
        "Red Legionaries", 1, 0, 60, 12, 4, 1, 0.9, 4, 2.6,
        "res://assets/textures/rts/units/squad_neutral_1x.png",
        "res://assets/textures/rts/units/squad_neutral_2x.png",
        "res://assets/textures/rts/units/squad_mask_1x.png",
        "res://assets/textures/rts/units/squad_mask_2x.png",
        1, 4, False, 1.0,
    ),
    "blue_commander": (
        "Blue Commander", 0, 1, 120, 14, 6, 4, 1.2, 6, 2.2,
        "res://assets/textures/rts/units/commander_neutral_1x.png",
        "res://assets/textures/rts/units/commander_neutral_2x.png",
        "res://assets/textures/rts/units/commander_mask_1x.png",
        "res://assets/textures/rts/units/commander_mask_2x.png",
        1, 4, False, 1.0,
    ),
    "red_commander": (
        "Red Commander", 1, 1, 120, 18, 6, 2, 1.1, 5, 2.4,
        "res://assets/textures/rts/units/commander_neutral_1x.png",
        "res://assets/textures/rts/units/commander_neutral_2x.png",
        "res://assets/textures/rts/units/commander_mask_1x.png",
        "res://assets/textures/rts/units/commander_mask_2x.png",
        1, 4, False, 1.0,
    ),
    "blue_tank": (
        "Blue Tank", 0, 0, 200, 20, 8, 3, 1.6, 6, 2.0,
        "res://assets/textures/rts/units/tank_neutral_1x.png",
        "res://assets/textures/rts/units/tank_neutral_2x.png",
        "res://assets/textures/rts/units/tank_mask_1x.png",
        "res://assets/textures/rts/units/tank_mask_2x.png",
        8, 3, True, 1.0,
    ),
    "red_tank": (
        "Red Tank", 1, 0, 200, 20, 8, 3, 1.6, 6, 2.0,
        "res://assets/textures/rts/units/tank_neutral_1x.png",
        "res://assets/textures/rts/units/tank_neutral_2x.png",
        "res://assets/textures/rts/units/tank_mask_1x.png",
        "res://assets/textures/rts/units/tank_mask_2x.png",
        8, 3, True, 1.0,
    ),
}
SPAWNS = [  # node name, type, art-pixel position (nearest free tile is used if blocked)
    ("BlueCommander", "blue_commander", (200, 150)), ("BlueSquad1", "blue_squad", (168, 160)),
    ("BlueSquad2", "blue_squad", (136, 176)), ("BlueTank", "blue_tank", (104, 132)),
    ("RedCommander", "red_commander", (480, 318)), ("RedSquad1", "red_squad", (452, 334)),
    ("RedSquad2", "red_squad", (560, 300)), ("RedTank", "red_tank", (528, 364)),
]


def rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA")).astype(np.float32) / 255


def over(dst: np.ndarray, src: np.ndarray) -> np.ndarray:
    a = src[..., 3:4]
    out = dst.copy()
    out[..., :3] = src[..., :3] * a + dst[..., :3] * (1 - a)
    return out


def build_tank_sheets() -> None:
    """Build 1x (32x32 per frame, 256x96 sheet) and 2x (64x64 per frame, 512x192 sheet)
    neutral tank sheets and team-colour masks from assets/textures/units/tank_blue.png.
    Eliminates the 0.85 fractional sprite_scale wobble and the RGB channel-swap hack."""
    src_sheet = Image.open(ROOT / "assets" / "textures" / "units" / "tank_blue.png").convert("RGBA")
    cols, rows = 8, 3
    src_fw, src_fh = src_sheet.width // cols, src_sheet.height // rows  # 36x36

    for density, fw in ((1, 32), (2, 64)):
        neutral_sheet = np.zeros((rows * fw, cols * fw, 4), np.uint8)
        mask_sheet = np.zeros((rows * fw, cols * fw, 4), np.uint8)
        red_compat_sheet = np.zeros((rows * fw, cols * fw, 4), np.uint8)

        for r in range(rows):
            for c in range(cols):
                tile_im = src_sheet.crop((c * src_fw, r * src_fh, (c + 1) * src_fw, (r + 1) * src_fh))
                # Crop 2px padding around the 36x36 source cell so the ~30x20 tank body sits at 1:1
                # inside a 32x32 frame at 1x (or 64x64 at 2x) with crisp integer alignment.
                cropped = tile_im.crop((2, 2, 34, 34))
                if density == 1:
                    frame_rgba = np.array(cropped, dtype=np.float32)
                else:
                    up = cropped.resize((fw, fw), Image.Resampling.LANCZOS)
                    frame_rgba = np.array(up, dtype=np.float32)
                    # Gentle unsharp mask on 2x HD frame so armor seams stay crisp
                    blur = cv2.GaussianBlur(frame_rgba[..., :3], (0, 0), 0.9)
                    frame_rgba[..., :3] = np.clip(frame_rgba[..., :3] + (frame_rgba[..., :3] - blur) * 0.45, 0, 255)

                rgb = frame_rgba[..., :3]
                alpha = frame_rgba[..., 3]
                if density == 1:
                    solid = alpha > 110
                    alpha = np.where(solid, 255.0, 0.0)
                else:
                    solid = alpha > 64
                    alpha = np.clip((alpha - 40.0) / 180.0, 0.0, 1.0) * 255.0

                # Detect blue painted hull/turret pixels vs neutral tracks/gun barrel/dark outline
                blue_excess = rgb[..., 2] - np.maximum(rgb[..., 0], rgb[..., 1] * 0.72)
                team_weight = np.clip((blue_excess - 10.0) / 38.0, 0.0, 1.0) * (alpha > 32)
                if density == 1:
                    team_weight = (team_weight > 0.32).astype(np.float32)

                # Local shading value (0..1) from green+blue luminance of the painted armor
                lum = (0.25 * rgb[..., 0] + 0.50 * rgb[..., 1] + 0.25 * rgb[..., 2])
                shade = np.clip((lum - 24.0) / 145.0, 0.0, 1.0)

                # Convert blue armor to neutral warm-grey steel in the base sprite
                neutral_rgb = rgb.copy()
                steel = np.stack([lum * 1.02, lum * 0.98, lum * 0.94], axis=-1)
                neutral_rgb = neutral_rgb * (1.0 - team_weight[..., None]) + steel * team_weight[..., None]

                # Crisp 1px dark outline (#221814) around the silhouette so it reads on orange sand & green grass
                solid_u8 = (alpha > 120).astype(np.uint8)
                inner = cv2.erode(solid_u8, np.ones((3, 3), np.uint8)).astype(bool)
                ring = (solid_u8 > 0) & ~inner
                if density == 1:
                    neutral_rgb[ring] = OUTLINE_RGB
                    team_weight[ring] = 0.0

                # Subtle turret highlight crest in mask B channel (around frame center)
                yy, xx = np.mgrid[0:fw, 0:fw].astype(np.float32)
                center_dist = np.hypot(xx - fw * 0.5, yy - fw * 0.48)
                turret_trim = ((center_dist < fw * 0.11) & (team_weight > 0.5) & (shade > 0.62)).astype(np.float32) * 0.45

                y0, y1 = r * fw, (r + 1) * fw
                x0, x1 = c * fw, (c + 1) * fw
                neutral_sheet[y0:y1, x0:x1, :3] = np.clip(neutral_rgb, 0, 255).astype(np.uint8)
                neutral_sheet[y0:y1, x0:x1, 3] = np.clip(alpha, 0, 255).astype(np.uint8)

                mask_sheet[y0:y1, x0:x1, 0] = np.clip(team_weight * 255.0, 0, 255).astype(np.uint8)
                mask_sheet[y0:y1, x0:x1, 1] = np.clip(shade * 255.0, 0, 255).astype(np.uint8)
                mask_sheet[y0:y1, x0:x1, 2] = np.clip(turret_trim * 255.0, 0, 255).astype(np.uint8)
                mask_sheet[y0:y1, x0:x1, 3] = np.clip(alpha, 0, 255).astype(np.uint8)

                # Also bake a clean 32x32 red compatibility sheet for tank_red_sheet.png
                red_rgb = neutral_rgb.copy()
                r_dark = np.array([112, 22, 16], np.float32)
                r_mid = np.array([204, 44, 32], np.float32)
                r_hi = np.array([255, 128, 104], np.float32)
                s2 = np.clip(shade * 2.0, 0, 1)[..., None]
                s_hi = np.clip((shade - 0.5) * 2.0, 0, 1)[..., None]
                ramp = np.where(shade[..., None] < 0.5, r_dark + (r_mid - r_dark) * s2, r_mid + (r_hi - r_mid) * s_hi)
                red_rgb = red_rgb * (1.0 - team_weight[..., None]) + ramp * team_weight[..., None]
                red_compat_sheet[y0:y1, x0:x1, :3] = np.clip(red_rgb, 0, 255).astype(np.uint8)
                red_compat_sheet[y0:y1, x0:x1, 3] = np.clip(alpha, 0, 255).astype(np.uint8)

        Image.fromarray(neutral_sheet).save(UNITS_DIR / f"tank_neutral_{density}x.png")
        Image.fromarray(mask_sheet).save(UNITS_DIR / f"tank_mask_{density}x.png")


# --- Soldier & Commander Patterns with 4 Walk Rows (row 0 = idle, rows 1..3 = walk stride) ---
# Legend:
#   h/H/k : neutral steel helmet highlight/mid/shadow
#   g/G   : commander golden helmet crown highlight/mid
#   f     : skin / face
#   l/B/d : team armour light (shade=0.88), mid (shade=0.52), dark (shade=0.18) -> mask R=1
#   s     : commander scarf / collar trim -> mask B=0.45 (pale scarf on Blue, gold trim on Red)
#   c     : commander emblem -> mask B=1.0 (cyan healer cross on Blue, gold crest on Red)
#   w     : rifle barrel (dark gunmetal)
#   L     : boots / legs

SOLDIER_ROWS = [
    [  # Row 0: Idle
        "..hhh..",
        ".hHHHk.",
        ".hHHHk.",
        "..fff..",
        ".lBBBd.",
        "lBBBBBw",
        "lBBBBBw",
        ".BBBBd.",
        ".BBBdd.",
        "..L.L..",
        "..L.L..",
    ],
    [  # Row 1: Left foot forward, rifle up
        "..hhh..",
        ".hHHHk.",
        ".hHHHk.",
        "..fff..",
        ".lBBBw.",
        "lBBBBBw",
        "lBBBBBd",
        ".BBBBd.",
        ".BBBdd.",
        ".L..L..",
        ".L.....",
    ],
    [  # Row 2: Passing stride
        "..hhh..",
        ".hHHHk.",
        ".hHHHk.",
        "..fff..",
        ".lBBBd.",
        "lBBBBBw",
        "lBBBBBw",
        ".BBBBd.",
        ".BBBdd.",
        "..LL...",
        "..LL...",
    ],
    [  # Row 3: Right foot forward
        "..hhh..",
        ".hHHHk.",
        ".hHHHk.",
        "..fff..",
        ".lBBBd.",
        "lBBBBBd",
        "lBBBBBw",
        ".BBBBw.",
        ".BBBdd.",
        "..L..L.",
        ".....L.",
    ],
]

COMMANDER_ROWS = [
    [  # Row 0: Idle (pale scarf / gold trim 's' + cyan cross / gold crest 'c')
        "...ggg...",
        "..gGGGk..",
        "..gGGGk..",
        "...fff...",
        ".ssssssd.",
        ".lBBcBBd.",
        "lBBcccBBw",
        "lBBBcBBBw",
        ".BBBBBBd.",
        ".BBBBBBd.",
        ".BBBBBdd.",
        "..LL.LL..",
        "..LL.LL..",
    ],
    [  # Row 1: Left stride
        "...ggg...",
        "..gGGGk..",
        "..gGGGk..",
        "...fff...",
        ".ssssss..",
        ".lBBcBBw.",
        "lBBcccBBw",
        "lBBBcBBBd",
        ".BBBBBBd.",
        ".BBBBBBd.",
        ".BBBBBdd.",
        ".LL...LL.",
        ".LL......",
    ],
    [  # Row 2: Mid stride
        "...ggg...",
        "..gGGGk..",
        "..gGGGk..",
        "...fff...",
        "..sssssd.",
        ".lBBcBBd.",
        "lBBcccBBw",
        "lBBBcBBBw",
        ".BBBBBBd.",
        ".BBBBBBd.",
        ".BBBBBdd.",
        "..LLLL...",
        "..LLLL...",
    ],
    [  # Row 3: Right stride
        "...ggg...",
        "..gGGGk..",
        "..gGGGk..",
        "...fff...",
        "..sssssd.",
        ".lBBcBBd.",
        "lBBcccBBd",
        "lBBBcBBBw",
        ".BBBBBBw.",
        ".BBBBBBd.",
        ".BBBBBdd.",
        ".LL...LL.",
        "......LL.",
    ],
]

NEUTRAL_COLORS = {
    "h": (238, 236, 232),
    "H": (190, 192, 202),
    "k": (110, 110, 124),
    "f": (226, 178, 138),
    "L": (44, 36, 38),
    "w": (76, 78, 86),
    "g": (255, 222, 120),
    "G": (226, 170, 60),
    "l": (195, 198, 205),
    "B": (140, 144, 152),
    "d": (82, 84, 92),
    "s": (225, 220, 208),
    "c": (210, 225, 225),
}

MASK_VALUES = {
    # ch: (R team_weight, G shade, B trim/emblem)
    "l": (255, 225, 0),
    "B": (255, 135, 0),
    "d": (255, 48, 0),
    "s": (0, 215, 115),   # trim / scarf (0.45)
    "c": (0, 235, 255),   # emblem / cyan healer cross / gold crest (1.0)
}


def draw_neutral_figure(pattern: list[str]) -> tuple[np.ndarray, np.ndarray]:
    h, w = len(pattern), len(pattern[0])
    img = np.zeros((h + 2, w + 2, 4), np.uint8)
    msk = np.zeros((h + 2, w + 2, 4), np.uint8)
    for y, row in enumerate(pattern):
        for x, ch in enumerate(row):
            if ch != ".":
                img[y + 1, x + 1] = (*NEUTRAL_COLORS[ch], 255)
                r_m, g_m, b_m = MASK_VALUES.get(ch, (0, 140, 0))
                msk[y + 1, x + 1] = (r_m, g_m, b_m, 255)
    solid = img[..., 3] > 0
    ring = cv2.dilate(solid.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & ~solid
    img[ring] = (*OUTLINE_RGB, 255)
    msk[ring] = (0, 0, 0, 255)
    return img, msk


def compose_frame(figures: list[tuple[np.ndarray, np.ndarray, int, int]], size: int) -> tuple[np.ndarray, np.ndarray]:
    canvas = np.zeros((size, size, 4), np.uint8)
    mask_canvas = np.zeros((size, size, 4), np.uint8)
    for fig, msk, ox, oy in sorted(figures, key=lambda f: f[3]):
        h, w = fig.shape[:2]
        sx, sy = ox + w // 2 + 1, oy + h - 2
        for yy in range(-1, 2):
            for xx in range(-3, 4):
                if (xx / 3.5) ** 2 + yy ** 2 <= 1 and 0 <= sy + yy < size and 0 <= sx + xx < size:
                    if canvas[sy + yy, sx + xx, 3] == 0:
                        canvas[sy + yy, sx + xx] = (*SHADOW_RGB, 120)
        a = fig[..., 3] > 0
        canvas[oy:oy + h, ox:ox + w][a] = fig[a]
        mask_canvas[oy:oy + h, ox:ox + w][a] = msk[a]
    return canvas, mask_canvas


def upscale_2x_smooth(sheet_1x: np.ndarray, mask_1x: np.ndarray, frame_w: int, rows: int) -> tuple[np.ndarray, np.ndarray]:
    fw2 = frame_w * 2
    out_img = np.zeros((rows * fw2, fw2, 4), np.uint8)
    out_msk = np.zeros((rows * fw2, fw2, 4), np.uint8)
    for r in range(rows):
        f_img = Image.fromarray(sheet_1x[r * frame_w:(r + 1) * frame_w])
        f_msk = Image.fromarray(mask_1x[r * frame_w:(r + 1) * frame_w])
        # Use 2x nearest + soft anti-aliased interior blend so 2x HD infantry has smooth painted edges
        up_img = np.array(f_img.resize((fw2, fw2), Image.Resampling.BICUBIC), dtype=np.float32)
        near_img = np.array(f_img.resize((fw2, fw2), Image.Resampling.NEAREST), dtype=np.float32)
        blend_img = np.clip(near_img * 0.55 + up_img * 0.45, 0, 255).astype(np.uint8)
        up_msk = np.array(f_msk.resize((fw2, fw2), Image.Resampling.NEAREST), dtype=np.uint8)
        out_img[r * fw2:(r + 1) * fw2] = blend_img
        out_msk[r * fw2:(r + 1) * fw2] = up_msk
    return out_img, out_msk


def build_infantry_sheets() -> None:
    rows = 4
    # 1. 4-figure Squad (30x30 per frame, 4 rows = 30x120 at 1x, 60x240 at 2x)
    squad_1x = np.zeros((rows * 30, 30, 4), np.uint8)
    squad_mask_1x = np.zeros((rows * 30, 30, 4), np.uint8)
    offsets = [(2, 3), (13, 1), (6, 14), (17, 13)]
    for r in range(rows):
        figs = []
        for idx, (ox, oy) in enumerate(offsets):
            pose_row = 0 if r == 0 else (1 + ((r - 1 + idx) % 3))
            fig, msk = draw_neutral_figure(SOLDIER_ROWS[pose_row])
            figs.append((fig, msk, ox, oy))
        c_img, c_msk = compose_frame(figs, 30)
        squad_1x[r * 30:(r + 1) * 30] = c_img
        squad_mask_1x[r * 30:(r + 1) * 30] = c_msk
    Image.fromarray(squad_1x).save(UNITS_DIR / "squad_neutral_1x.png")
    Image.fromarray(squad_mask_1x).save(UNITS_DIR / "squad_mask_1x.png")
    sq_2x, sq_m2x = upscale_2x_smooth(squad_1x, squad_mask_1x, 30, rows)
    Image.fromarray(sq_2x).save(UNITS_DIR / "squad_neutral_2x.png")
    Image.fromarray(sq_m2x).save(UNITS_DIR / "squad_mask_2x.png")

    # 2. Commander (16x16 per frame, 4 rows = 16x64 at 1x, 32x128 at 2x)
    cmd_1x = np.zeros((rows * 16, 16, 4), np.uint8)
    cmd_mask_1x = np.zeros((rows * 16, 16, 4), np.uint8)
    for r in range(rows):
        fig, msk = draw_neutral_figure(COMMANDER_ROWS[r])
        c_img, c_msk = compose_frame([(fig, msk, 2, 1)], 16)
        cmd_1x[r * 16:(r + 1) * 16] = c_img
        cmd_mask_1x[r * 16:(r + 1) * 16] = c_msk
    Image.fromarray(cmd_1x).save(UNITS_DIR / "commander_neutral_1x.png")
    Image.fromarray(cmd_mask_1x).save(UNITS_DIR / "commander_mask_1x.png")
    cm_2x, cm_m2x = upscale_2x_smooth(cmd_1x, cmd_mask_1x, 16, rows)
    Image.fromarray(cm_2x).save(UNITS_DIR / "commander_neutral_2x.png")
    Image.fromarray(cm_m2x).save(UNITS_DIR / "commander_mask_2x.png")


def enable_mipmaps_on_2x() -> None:
    for p in sorted(UNITS_DIR.glob("*_2x.png.import")):
        txt = p.read_text(encoding="utf-8")
        if "mipmaps/generate=false" in txt:
            p.write_text(txt.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    UNITS_DIR.mkdir(parents=True, exist_ok=True)
    STATS_DIR.mkdir(parents=True, exist_ok=True)

    # Blocked tiles: wherever cliffs and rocks are drawn (their top and front wall), not their
    # shadows or the loose stones round them.
    rocks = rgba(T5 / "rocks.png")
    solid = (rocks[..., 3] > 0.98).astype(np.uint8)
    solid = cv2.morphologyEx(solid, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    h, w = solid.shape
    cells = solid[: h // TILE * TILE, : w // TILE * TILE].reshape(h // TILE, TILE, w // TILE, TILE).mean((1, 3))
    Image.fromarray(((cells > 0.3) * 255).astype(np.uint8)).save(OUT / "walk_mask.png")

    # Ground light: the map as units see it (sand, road, rock shadows), blurred a little.
    ground = rgba(T5 / "sand_dunes.png")
    ground = over(over(ground, rgba(T5 / "road.png")), rocks)
    lum = cv2.GaussianBlur(ground[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32), (0, 0), 2.5)
    open_sand = solid == 0
    mid = np.median(lum[open_sand])
    light = np.clip(0.5 + (lum - mid) / 0.5, 0, 1)
    Image.fromarray((light * 255).astype(np.uint8)).save(OUT / "ground_light.png")

    build_tank_sheets()
    build_infantry_sheets()
    enable_mipmaps_on_2x()

    for key, (
        name, fac, kind, hp, atk, arm, rng_, cd, guard, speed,
        spr_1x, spr_2x, msk_1x, msk_2x, dirs, frames, veh, scale
    ) in TYPES.items():
        (STATS_DIR / f"{key}.tres").write_text(f'''[gd_resource type="Resource" script_class="UnitStats" format=3]

[ext_resource type="Script" path="res://scripts/rts/unit_stats.gd" id="1"]
[ext_resource type="Texture2D" path="{spr_1x}" id="2"]
[ext_resource type="Texture2D" path="{spr_2x}" id="3"]
[ext_resource type="Texture2D" path="{msk_1x}" id="4"]
[ext_resource type="Texture2D" path="{msk_2x}" id="5"]

[resource]
script = ExtResource("1")
display_name = "{name}"
faction = {fac}
kind = {kind}
max_health = {hp}
attack = {atk}
armour = {arm}
attack_range = {rng_}
attack_cooldown = {cd}
guard_range = {guard}
move_speed = {speed}
sprite = ExtResource("2")
sprite_hd = ExtResource("3")
team_mask = ExtResource("4")
team_mask_hd = ExtResource("5")
sprite_directions = {dirs}
sprite_frames = {frames}
vehicle = {"true" if veh else "false"}
sprite_scale = {scale}
''', encoding="utf-8")

    res = [
        ("Script", "res://scripts/rts/rts_units_test_v3.gd"),
        ("Script", "res://scripts/rts/rts_grid.gd"),
        ("Script", "res://scripts/rts/rts_look.gd"),
        ("Script", "res://scripts/rts/rts_commands.gd"),
        ("Script", "res://scripts/rts/rts_camera.gd"),
        ("PackedScene", "res://scenes/actors/rts_unit.tscn"),
        ("Texture2D", "res://assets/textures/rts/style_test/t5/sand_dunes.png"),
        ("Texture2D", "res://assets/textures/rts/style_test/t5/road.png"),
        ("Texture2D", "res://assets/textures/rts/style_test/t5/rocks.png"),
        ("Texture2D", "res://assets/textures/rts/style_test/t5/scatter.png"),
        ("Texture2D", "res://assets/textures/rts/units_test/walk_mask.png"),
        ("Texture2D", "res://assets/textures/rts/units_test/ground_light.png"),
    ]
    res += [("Resource", f"res://scenes/rts/units/look_v3/{k}.tres") for k in TYPES]
    ids = {path: f"r{i}" for i, (_, path) in enumerate(res)}
    lines = ["[gd_scene format=3]", ""]
    lines += [f'[ext_resource type="{t}" path="{p}" id="{ids[p]}"]' for t, p in res]

    def ref(path: str) -> str:
        return f'ExtResource("{ids[path]}")'

    lines += [
        "", '[node name="RtsUnitsTestV3" type="Node2D"]', "texture_filter = 1",
        f'script = {ref("res://scripts/rts/rts_units_test_v3.gd")}', "",
    ]
    for node, tex in (("Ground", "sand_dunes"), ("Road", "road"), ("Rocks", "rocks"), ("Scatter", "scatter")):
        lines += [
            f'[node name="{node}" type="Sprite2D" parent="."]',
            f'texture = {ref(f"res://assets/textures/rts/style_test/t5/{tex}.png")}',
            "centered = false", "",
        ]
    lines += [
        '[node name="Look" type="Node2D" parent="."]', f'script = {ref("res://scripts/rts/rts_look.gd")}',
        f'light_map = {ref("res://assets/textures/rts/units_test/ground_light.png")}', "",
        '[node name="Grid" type="Node2D" parent="."]', f'script = {ref("res://scripts/rts/rts_grid.gd")}',
        f'blocked_cells = {ref("res://assets/textures/rts/units_test/walk_mask.png")}', "",
        '[node name="Units" type="Node2D" parent="."]', "y_sort_enabled = true", "",
    ]
    for node, key, (x, y) in SPAWNS:
        lines += [
            f'[node name="{node}" parent="Units" instance={ref("res://scenes/actors/rts_unit.tscn")}]',
            f"position = Vector2({x}, {y})", f'stats = {ref(f"res://scenes/rts/units/look_v3/{key}.tres")}', "",
        ]
    lines += [
        '[node name="Commands" type="Node2D" parent="."]', f'script = {ref("res://scripts/rts/rts_commands.gd")}', "",
        '[node name="Camera" type="Camera2D" parent="."]', f"position = Vector2({w // 2}, {h // 2})",
        "zoom = Vector2(1.0, 1.0)", f'script = {ref("res://scripts/rts/rts_camera.gd")}',
        "zoom_min = 1.0", "zoom_max = 3.0", "",
        '[node name="HUD" type="CanvasLayer" parent="."]', "",
        '[node name="Help" type="Label" parent="HUD"]',
        "offset_left = 10.0", "offset_top = 6.0", "offset_right = 950.0", "offset_bottom = 30.0",
        "mouse_filter = 2", "theme_override_colors/font_outline_color = Color(0, 0, 0, 0.85)",
        "theme_override_constants/outline_size = 5", "theme_override_font_sizes/font_size = 13", "",
    ]
    SCENE.write_text("\n".join(lines), encoding="utf-8")
    print(f"Blocked tiles: {int((cells > 0.3).sum())} of {cells.size}. Wrote {SCENE}")


if __name__ == "__main__":
    main()
