"""Compose annotated handoff comparison plates for 'RTS Isometric 2— Forest Claim Carbon':
1) handoff_01_command_vs_fight4_and_close.png: Live Command view beside Fight 4 forest.png + Close view.
2) handoff_02_layouts_a_and_b_modularity.png: Layouts A & B side-by-side with reused cliff/tree callouts and Tank routes."""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CAP = ROOT / "render_captures/rts_iso_forest_carbon"
FIGHT4 = ROOT / "render_captures/forest_fight_4/forest.png"


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in ["C:/Windows/Fonts/consolab.ttf", "C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arialbd.ttf"]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def map_cell_to_play_px(u: float, v: float, cam_u: float, cam_v: float) -> tuple[int, int]:
    """Exact projection matching RtsIsoTransform + HUD playable_screen_rect at 1376x768 Command zoom."""
    cell = 32.0
    ix = 0.70710678 * (u - v) * cell
    iy = 0.40824829 * (u + v) * cell
    cx = 0.70710678 * (cam_u - cam_v) * cell
    cy = 0.40824829 * (cam_u + cam_v) * cell
    # Playable rect at 1376x768 (ui_scale = 768/540 = 1.4222): x in [0..1074.5], y in [48.4..768], center=(537.2, 408.2)
    sx = 537.2 + (ix - cx)
    sy = 408.2 + (iy - cy)
    return int(round(sx)), int(round(sy))


def draw_badge(draw: ImageDraw.ImageDraw, pos: tuple[int, int], text: str,
               font: ImageFont.ImageFont, fg: tuple[int, int, int] = (255, 244, 200),
               bg: tuple[int, int, int, int] = (22, 28, 36, 220),
               border: tuple[int, int, int, int] = (218, 174, 88, 255)) -> None:
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    r = (pos[0], pos[1], pos[0] + tw + 14, pos[1] + th + 8)
    draw.rounded_rectangle(r, radius=5, fill=bg, outline=border, width=2)
    draw.text((pos[0] + 7, pos[1] + 3), text, font=font, fill=fg)


def draw_route_arrow(draw: ImageDraw.ImageDraw, pts: list[tuple[int, int]], color: tuple[int, int, int, int]) -> None:
    if len(pts) < 2:
        return
    draw.line(pts, fill=(14, 22, 34, 210), width=8, joint="curve")
    draw.line(pts, fill=color, width=4, joint="curve")
    for p in pts[1:-1]:
        draw.ellipse((p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4), fill=color)
    # Arrowhead at end
    x0, y0 = pts[-2]
    x1, y1 = pts[-1]
    dx, dy = x1 - x0, y1 - y0
    ln = max((dx * dx + dy * dy) ** 0.5, 1.0)
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    head = [(x1, y1), (int(x1 - ux * 15 + px * 8), int(y1 - uy * 15 + py * 8)), (int(x1 - ux * 15 - px * 8), int(y1 - uy * 15 - py * 8))]
    draw.polygon(head, fill=color, outline=(14, 22, 34, 230))


def build_handoff_01() -> None:
    cmd_im = Image.open(CAP / "01_layout_a_command_hud.png").convert("RGBA")
    f4_im = Image.open(FIGHT4).convert("RGBA").resize(cmd_im.size, Image.Resampling.LANCZOS)
    close_im = Image.open(CAP / "02_layout_a_close_squad_tree_cliff.png").convert("RGBA")

    pad = 20
    header = 44
    w = cmd_im.width * 2 + pad * 3
    h = header + cmd_im.height + header + close_im.height + pad * 2
    canvas = Image.new("RGBA", (w, h), (20, 24, 28, 255))
    draw = ImageDraw.Draw(canvas)
    f_title = load_font(20)

    draw.text((pad, 11), "RTS Isometric 2— Forest Claim Carbon · Live Command View (1376x768, HUD On)", font=f_title, fill=(246, 224, 158))
    draw.text((pad * 2 + cmd_im.width, 11), "2D Painted Forest Fight 4 · Primary Reference (forest.png)", font=f_title, fill=(190, 228, 245))
    canvas.alpha_composite(cmd_im, (pad, header))
    canvas.alpha_composite(f4_im, (pad * 2 + cmd_im.width, header))

    y2 = header + cmd_im.height + pad
    cx = (w - close_im.width) // 2
    draw.text((cx, y2 + 6), "Close Inspection View (1.55x Zoom) · 4-Soldier Rifle Squad Under Translucent Hero Canopy & Beside Mossy Bluff", font=f_title, fill=(235, 238, 220))
    canvas.alpha_composite(close_im, (cx, y2 + header))

    canvas.convert("RGB").save(CAP / "handoff_01_command_vs_fight4_and_close.png", optimize=True)


def build_handoff_02() -> None:
    la = Image.open(CAP / "01_layout_a_command_hud.png").convert("RGBA")
    lb = Image.open(CAP / "04_layout_b_command_hud.png").convert("RGBA")

    # Overlay Tank routes & reused module callout tags onto copies of Layout A and Layout B
    la_ann = la.copy()
    lb_ann = lb.copy()
    da = ImageDraw.Draw(la_ann, "RGBA")
    db = ImageDraw.Draw(lb_ann, "RGBA")
    f_tag = load_font(14)

    # Layout A Tank Route: SW Spawn (10.5, 26.5) -> SE Cliff-Rim Road (16.5, 26.2) -> (21.5, 22.5) -> Orichalcum East (20.5, 19.0)
    route_a = [map_cell_to_play_px(u, v, 16.8, 19.4) for u, v in [(10.5, 26.5), (16.5, 26.2), (21.5, 22.5), (20.5, 19.0)]]
    draw_route_arrow(da, route_a, (76, 228, 255, 245))
    draw_badge(da, (route_a[1][0] - 40, route_a[1][1] + 14), "Tank Route A: SE Cliff-Rim Road", f_tag, fg=(165, 245, 255))

    # Reused piece callouts on Layout A
    p_hero_a = map_cell_to_play_px(7.5, 15.0, 16.8, 19.4)
    draw_badge(da, (p_hero_a[0] - 90, p_hero_a[1] - 125), "tree_hero_buttress (7,15)", f_tag)
    p_bluff_a = map_cell_to_play_px(14.0, 21.5, 16.8, 19.4)
    draw_badge(da, (p_bluff_a[0] - 115, p_bluff_a[1] - 58), "cliff_end_u + bluff_u + outer_corner", f_tag)
    p_log_a = map_cell_to_play_px(15.5, 8.5, 16.8, 19.4)
    draw_badge(da, (p_log_a[0] - 50, p_log_a[1] - 42), "fallen_moss_log (15,8)", f_tag)

    # Layout B Tank Route: SW Spawn (10.5, 26.5) -> NW Trail (10.5, 15.0) -> North Flank (16.2, 11.8) -> Orichalcum North-East (18.5, 14.5)
    route_b = [map_cell_to_play_px(u, v, 16.8, 19.4) for u, v in [(10.5, 26.5), (10.2, 20.5), (10.5, 14.5), (16.2, 11.8), (18.5, 14.5)]]
    draw_route_arrow(db, route_b, (76, 228, 255, 245))
    draw_badge(db, (route_b[3][0] - 75, route_b[3][1] - 36), "Tank Route B: New North Woodland Flank", f_tag, fg=(165, 245, 255))

    # Reused piece callouts on Layout B (exact same textures & catalog!)
    p_hero_b = map_cell_to_play_px(6.5, 19.0, 16.8, 19.4)
    draw_badge(db, (p_hero_b[0] - 80, p_hero_b[1] - 125), "Moved tree_hero_buttress (6,19)", f_tag)
    p_bluff_b = map_cell_to_play_px(21.0, 26.5, 16.8, 19.4)
    draw_badge(db, (p_bluff_b[0] - 155, p_bluff_b[1] - 52), "Re-joined L-Bluff: end_v+bluff_v+inner_corner+bluff_u+end_u (SE Sealed)", f_tag, fg=(255, 215, 155))
    p_log_b = map_cell_to_play_px(19.0, 20.5, 16.8, 19.4)
    draw_badge(db, (p_log_b[0] - 30, p_log_b[1] - 28), "Moved fallen_moss_log (19,20)", f_tag)

    pad = 20
    header = 54
    w = la.width * 2 + pad * 3
    h = header + la.height + pad
    canvas = Image.new("RGBA", (w, h), (20, 24, 28, 255))
    draw = ImageDraw.Draw(canvas)
    f_title = load_font(18)
    draw.text((pad, 8), "Layout A · scenes/rts_iso_carbon/layout_a_shelf_clearing.tres", font=f_title, fill=(246, 224, 158))
    draw.text((pad, 30), "Central-West bluff splits approach; Tank uses SE Cliff-Rim Road", font=f_tag, fill=(200, 215, 225))

    draw.text((pad * 2 + la.width, 8), "Layout B · scenes/rts_iso_carbon/layout_b_split_bluff.tres (Same Art Kit, Data-Only Swap)", font=f_title, fill=(176, 242, 188))
    draw.text((pad * 2 + la.width, 30), "Moved cliff pieces seal SE road in L-join; Tank reroutes via new North Flank", font=f_tag, fill=(200, 215, 225))

    canvas.alpha_composite(la_ann, (pad, header))
    canvas.alpha_composite(lb_ann, (pad * 2 + la.width, header))
    canvas.convert("RGB").save(CAP / "handoff_02_layouts_a_and_b_modularity.png", optimize=True)


if __name__ == "__main__":
    build_handoff_01()
    build_handoff_02()
    print("Built handoff_01_command_vs_fight4_and_close.png and handoff_02_layouts_a_and_b_modularity.png")
