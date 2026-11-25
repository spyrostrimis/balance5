"""Build the reversible art overlays for Units in Motion. Requires Pillow, numpy and cv2.

The generated Blue proof supplies the material ramps and a playing-size candidate.
The shipped sprites share a projected pose, with the original tank as its chassis.
Style Test 5 supplies the map's geometry and shadows. Original paintings supply the
detail in each 2x material layer. This tool writes only the successor's textures.
"""
import argparse
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageColor, ImageDraw, ImageFilter

import rts_palette

ROOT = Path(__file__).resolve().parents[2]
RTS = ROOT / "assets/textures/rts"
SOURCES = ROOT / "assets/source_inputs/rts"
OUT = RTS / "units_motion"
PROOF = SOURCES / "units_motion/blue_proof.png"
OUT.mkdir(parents=True, exist_ok=True)
PALETTE = np.array([ImageColor.getrgb(c) for c in json.loads(
    (RTS / "palette_desert.json").read_text())["colors"]], np.uint8)
AA = 8
SIZE = (18, 20)
ANCHOR = (9, 15)
OUTLINE = "#211c1f"


def paint_detail(name, shrink, world_u, world_v, spread):
    img = Image.open(SOURCES / name).convert("RGB")
    img = img.resize(tuple(round(n * 2 / shrink) for n in img.size), Image.Resampling.LANCZOS)
    data = np.asarray(img, dtype=np.float32)
    # Soften the seam in the higher-frequency tile before repeating the material.
    from smooth_texture import cosine_wrap

    margin = max(2, min(data.shape[:2]) // 16)
    data = cosine_wrap(cosine_wrap([data], margin, 0), margin, 1)[0]
    detail = data - cv2.GaussianBlur(data, (0, 0), spread)
    return cv2.remap(detail, world_u, world_v, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)


def battlefield():
    base = RTS / "style_test/t5"
    y, x = np.mgrid[0:1080, 0:1920].astype(np.float32)
    angle = -0.17
    along = x * math.cos(angle) + y * math.sin(angle)
    across = y * math.cos(angle) - x * math.sin(angle)
    for layer, file in [("ground", "sand_dunes"), ("road", "road"),
                        ("rocks", "rocks"), ("scatter", "scatter")]:
        original = Image.open(base / (file + ".png")).convert("RGBA")
        rgba = np.array(original.resize((1920, 1080), Image.Resampling.LANCZOS))
        rgb = rgba[..., :3].astype(np.float32)
        alpha = rgba[..., 3]
        # The lower frequencies retain the dunes, stone joints and all placement contours.
        if layer == "ground":
            rgb = cv2.bilateralFilter(rgb, 5, 20, 1.4)
            grain = paint_detail("sand.png", 2.0, x, y, 5)
            ripple = paint_detail("dunes2.png", 2.4, along, across, 3)
            rgb += grain * 0.55 + ripple * 0.22
        elif layer == "road":
            rgb = cv2.bilateralFilter(rgb, 5, 12, 1.4)
            rgb += paint_detail("road.png", 10, x + 39, y + 91, 7) * 0.48
            rgb += paint_detail("road_height.png", 10, x + 39, y + 91, 3) * 0.12
        elif layer == "rocks":
            # Subtle cool grain on slabs, warmer vertical grain on exposed south walls.
            slab = paint_detail("rock_top.png", 5.5, x, y, 7)
            wall = paint_detail("cliff_wall2.png", 8, x, y * 2, 6)
            crystal = paint_detail("crystals2.png", 4, x, y, 5)
            warm = np.clip((rgb[..., 0] - rgb[..., 2] - 18) / 45, 0, 1)[..., None]
            amber = np.clip((rgb[..., 0] - 138) / 65, 0, 1)[..., None]
            raw = (slab * (1 - warm) + wall * warm) * (1 - amber) + crystal * amber * 0.5
            rgb += raw * (alpha > 236)[..., None] * 0.58
        rgba[..., :3] = rgb.clip(0, 255).astype(np.uint8)
        Image.fromarray(rgba).save(OUT / (layer + "_hd.png"), optimize=True)


def proof_materials():
    # Sample the troop's shoulder and helmet and the Commander's scarf from the source sheet.
    arr = np.array(Image.open(PROOF).convert("RGBA"))
    def ramp(bounds, filt, percentiles):
        x1, y1, x2, y2 = bounds
        pixels = arr[y1:y2, x1:x2].reshape(-1, 4).astype(float)
        rgb = pixels[(pixels[:, 3] > 245) & filt(pixels)][:, :3]
        rank = np.argsort(rgb @ [0.3, 0.59, 0.11])
        return [tuple(rgb[rank[round(q * (len(rank) - 1))]].astype(int)) for q in percentiles]
    blue = ramp((265, 52, 414, 230), lambda p: p[:, 2] > p[:, 0] * 1.45, (0.20, 0.77, 0.97))
    cloth = ramp((906, 211, 1133, 369), lambda p: (p[:, 0] > 180) & (p[:, 1] > 142), (0.24, 0.88))
    return blue, cloth


def shape(draw, xy, fill, outline=None, width=0.5):
    draw.polygon([(round(x * AA), round(y * AA)) for x, y in xy], fill=fill,
                 outline=outline, width=max(1, round(AA * width)))


def line(draw, a, b, fill, width):
    draw.line([(round(x * AA), round(y * AA)) for x, y in (a, b)], fill=fill, width=max(1, round(AA * width)))


def oval(draw, xy, radii, fill, outline=None, width=0.45):
    x, y = xy
    rx, ry = radii
    draw.ellipse(tuple(round(p * AA) for p in (x-rx, y-ry, x+rx, y+ry)), fill=fill,
                 outline=outline, width=max(1, round(width * AA)))


def figure(facing, row, commander, armor, scarf):
    art = Image.new("RGBA", (SIZE[0] * AA, SIZE[1] * AA))
    gun = Image.new("RGBA", art.size)
    d = ImageDraw.Draw(art)
    gd = ImageDraw.Draw(gun)
    angle = facing * math.pi / 4
    forward = np.array([math.cos(angle), math.sin(angle)])
    right = np.array([-forward[1], forward[0]])
    dark, body, lit = armor
    height = 1.18 if commander else 1.0

    def project(x, y, z):
        return np.asarray(ANCHOR) + right * x + forward * y - (0, z * height)

    def joint(x, y, z, radii, color, edge=None):
        oval(d, project(x, y, z), radii, color, edge)

    # A stance boot travels backwards exactly as far as the body travels forwards.
    # The other boot swings forward, with a small lift in screen space.
    feet = []
    stride = 9.0 if commander else 8.0
    for side in [-1, 1]:
        cycle = ((row - 1) / 16 + (0.5 if side == 1 else 0)) % 1
        progress = cycle * 2
        along = stride * (0.25 - 0.5 * progress)
        lift = 0.0
        if progress > 1:
            along = stride * (-0.25 + 0.5 * (progress - 1))
            lift = math.sin(math.pi * (progress - 1)) * 1.35
        if row == 0:
            along, lift = 0.0, 0.0
        ankle = project(side * 1.35, along, lift)
        feet.append((ankle, side, along))
    for ankle, side, along in sorted(feet, key=lambda item: item[0][1]):
        hip = project(side * 1.12, 0, 3.7)
        line(d, hip, ankle, OUTLINE, 2.05)
        line(d, hip - (0.15, 0), ankle - (0.15, 0.22), dark, 1.2)
        toe = ankle + forward * 0.62
        oval(d, toe, (1.0, 0.75), "#423c3e", OUTLINE)

    # Torso and shoulder plates have individually lit facets. The scorer's clearance
    # stays set by the grid cell, independent of which poses happen to overlap a pixel.
    torso = [project(-2.1, 0, 7.2), project(2.1, 0, 7.2), project(1.65, 0, 3.3),
             project(-1.6, 0, 3.3)]
    if abs(right[0]) < 0.3:
        torso = [project(0, 0, 7.1) + (-1.8, 0), project(0, 0, 7.1) + (1.8, 0),
                 project(0, 0, 3.4) + (1.25, 0), project(0, 0, 3.4) + (-1.25, 0)]
    shape(d, torso, body, OUTLINE)
    for side in [-1, 1]:
        shoulder = project(side * 1.8, 0.22 + side * 0.68 * abs(forward[0]), 6.9)
        oval(d, shoulder, (1.48, 1.25), lit if shoulder[0] < ANCHOR[0] else body, OUTLINE)
        line(d, shoulder + (-0.7, -0.55), shoulder + (0.22, -0.65), lit, 0.42)
    # Track the rifle separately so reduction can restore a one-pixel muzzle.
    stock = project(1.75, -0.9, 5.9)
    tip = project(1.75, 4.3, 5.9)
    if forward[0] < -0.1:
        stock = project(-1.75, -0.9, 5.9)
        tip = project(-1.75, 4.3, 5.9)
    line(gd, stock, tip, OUTLINE, 1.55)
    line(gd, stock - (0.2, 0.22), tip - (0.2, 0.22), "#9c969b", 0.74)
    art.alpha_composite(gun)

    if commander:
        joint(0, 0.26, 6.75, (2.55, 1.65), scarf[0], OUTLINE)
        line(d, project(0, 0.26, 6.75) + (-1.8, -0.35), project(0, 0.26, 6.75) + (1.55, 0.32), scarf[1], 1.35)
        tail = project(-1.8, -0.7, 7.2)
        line(d, tail, tail - forward * 1.1 + (0, 1.6), scarf[1], 0.95)
    if forward[1] >= -0.15:
        joint(0, 0.56, 8.25, (1.56, 1.28), "#cea886" if commander else "#b79778", OUTLINE)
    head = project(0, 0, 9.35)
    oval(d, head, (2.18, 1.92), body, OUTLINE)
    oval(d, head + (-0.37, -0.56), (1.56, 1.05), lit)
    oval(d, head + (-0.66, -0.99), (0.52, 0.26), "#d4d8d4")
    if forward[1] > 0.1:
        line(d, head + (-1.48, 0.54), head + (1.15, 0.68), dark, 0.55)
    return art, tip, head, project(0, 0, 4.95)


def pixelize(frame):
    rgb = rts_palette.map_to_palette(np.array(frame)[..., :3], PALETTE)
    alpha = (np.array(frame)[..., 3] >= 125).astype(np.uint8) * 255
    return Image.fromarray(np.dstack((rgb, alpha)))


def infantry(faction, blue, scarf):
    if faction == "red":
        armor = ["#652a32", "#ca342f", "#eb6f60"]
        scarf = ["#b77939", "#ffce75"]
    else:
        armor = blue
    for role in ("squad", "commander"):
        large = Image.new("RGBA", (SIZE[0] * 16, SIZE[1] * 34))
        small = Image.new("RGBA", (SIZE[0] * 8, SIZE[1] * 17))
        for row in range(17):
            for direction in range(8):
                pose, tip, helmet, torso = figure(direction, row, role == "commander", armor, scarf)
                large.paste(pose.resize((SIZE[0] * 2, SIZE[1] * 2), Image.Resampling.LANCZOS),
                            (direction * SIZE[0] * 2, row * SIZE[1] * 2))
                px = pixelize(pose.resize(SIZE, Image.Resampling.BOX))
                # The last pixel of the rifle survives on the side where the weapon projects.
                if direction in (0, 1, 3, 4, 5, 7):
                    tip_xy = tuple(int(v) for v in tip)
                    if px.getpixel(tip_xy)[3] == 0:
                        px.putpixel(tip_xy, (49, 39, 34, 255))
                team_color = (202, 52, 47, 255) if faction == "red" else (30, 106, 204, 255)
                for point in (helmet, torso):
                    xy = tuple(int(v) for v in point)
                    if px.getpixel(xy)[3] != 0:
                        px.putpixel(xy, team_color)
                small.paste(px, (direction * SIZE[0], row * SIZE[1]))
        large.save(OUT / f"{faction}_{role}_hd.png")
        small.save(OUT / f"{faction}_{role}_pixel.png")


def tank(faction, blue):
    source = Image.open(ROOT / "assets/textures/units/tank_blue.png").convert("RGBA")
    large = Image.new("RGBA", (608, 228))
    small = Image.new("RGBA", (304, 114))
    dark, body, lit = [np.array(c, np.float32) for c in blue]
    if faction == "red":
        dark, body, lit = [np.array(c, np.float32) for c in [(73, 31, 34), (153, 46, 53), (236, 126, 103)]]
    for row in range(3):
        for direction in range(8):
            col = (direction + 6) % 8
            original = source.crop((col * 36, row * 36, (col + 1) * 36, (row + 1) * 36))
            rgba = np.array(original)
            rgb = rgba[..., :3].astype(np.float32)
            blue_paint = (rgb[..., 2] > rgb[..., 0] + 16) & (rgba[..., 3] > 0)
            brightness = rgb[..., 1]
            lo = np.clip((brightness - 31) / 65, 0, 1)[..., None]
            hi = np.clip((brightness - 87) / 62, 0, 1)[..., None]
            paint = dark + ((body - dark) * lo + (lit - body) * hi)
            rgb[blue_paint] = paint[blue_paint]
            opaque = (rgba[..., 3] > 200)[..., None]
            base = cv2.GaussianBlur(rgb, (0, 0), 0.9)
            rgb += (rgb - base) * 0.45 * opaque
            rgba[..., :3] = rgb.clip(0, 255).astype(np.uint8)
            frame = Image.fromarray(rgba)
            marks = Image.new("RGBA", (38 * AA, 38 * AA))
            pen = ImageDraw.Draw(marks)
            angle = direction * math.pi / 4
            forward = np.array([math.cos(angle), math.sin(angle)])
            center = np.array([19, 18.5])
            line(pen, center + forward * 3, center + forward * 14.5, OUTLINE, 2.7)
            line(pen, center + forward * 3 - (0.45, 0.5), center + forward * 14.5 - (0.45, 0.5),
                 "#b1b2a7", 0.89)
            oval(pen, center, (4.0, 3.45), tuple(body.astype(int)), OUTLINE, 0.7)
            oval(pen, center + (-0.6, -0.7), (2.28, 1.9), tuple(lit.astype(int)))
            line(pen, center + (-1.75, -0.7), center + (0.45, -1.65), "#b8c2bd", 0.55)
            for density, sheet in [(1, small), (2, large)]:
                pose = Image.new("RGBA", (38 * density, 38 * density))
                body_frame = frame.resize((32 * density, 32 * density), Image.Resampling.LANCZOS)
                pose.paste(body_frame, (3 * density, 3 * density))
                pose.alpha_composite(marks.resize(pose.size, Image.Resampling.LANCZOS))
                if density == 1:
                    pose = pixelize(pose)
                sheet.paste(pose, (direction * 38 * density, row * 38 * density))
    large.save(OUT / f"{faction}_tank_hd.png")
    small.save(OUT / f"{faction}_tank_pixel.png")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blue-only", action="store_true", help="build ground and Blue for the first proof")
    parser.add_argument("--units-only", action="store_true", help="keep the generated ground layers")
    args = parser.parse_args()
    if not args.units_only:
        battlefield()
    blue, scarf = proof_materials()
    for faction in ["blue"] if args.blue_only else ["blue", "red"]:
        infantry(faction, blue, scarf)
        tank(faction, blue)


if __name__ == "__main__":
    main()
