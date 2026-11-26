"""Build native-pixel matched unit comparison sheets for RTS Reusable 4."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CAP = ROOT / "render_captures" / "rts_reusable_4"


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in ["C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def load_bold_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in ["C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf"]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return load_font(size)


def make_matched_unit_sheets() -> None:
    orig = Image.open(CAP / "carbon_original_command.png").convert("RGB")
    col_only = Image.open(CAP / "reusable_4_color_only_command.png").convert("RGB")
    spaced = Image.open(CAP / "reusable_4_spaced_command.png").convert("RGB")

    # Exact native 1:1 crop of the playfield lineup (tanks, squads on road, 4-of-4 on sand, 3-of-4 on sand, commanders)
    crop_box = (180, 175, 625, 595)
    cw, ch = crop_box[2] - crop_box[0], crop_box[3] - crop_box[1]

    f_title = load_bold_font(19)
    f_label = load_font(15)

    # 1. Primary 2-panel matched comparison: Original Carbon vs RTS Reusable 4
    left_margin = 148
    pad = 18
    top_h = 46
    w2 = left_margin + cw * 2 + pad * 3
    h2 = top_h + ch + pad
    sheet2 = Image.new("RGB", (w2, h2), (44, 29, 18))
    d2 = ImageDraw.Draw(sheet2)
    d2.text((left_margin + pad, 12), "Original Carbon", fill=(246, 224, 182), font=f_title)
    d2.text((left_margin + pad * 2 + cw, 12), "RTS Reusable 4 (cobalt / crimson + 1.20× spacing)", fill=(246, 224, 182), font=f_title)
    sheet2.paste(orig.crop(crop_box), (left_margin + pad, top_h))
    sheet2.paste(spaced.crop(crop_box), (left_margin + pad * 2 + cw, top_h))
    d2.text((16, top_h + 70), "Pale road\n(Tank + 4 fit)", fill=(228, 206, 172), font=f_label)
    d2.text((16, top_h + 205), "Calm sand\n(4 of 4 fit)", fill=(228, 206, 172), font=f_label)
    d2.text((16, top_h + 292), "Wounded\n(3 of 4 fit)", fill=(228, 206, 172), font=f_label)
    sheet2.save(CAP / "matched_unit_comparison.png", optimize=True)

    # 2. 3-step progression: Original Carbon -> Colour-only (exact 1.0x spacing) -> Reusable 4 (1.20x spacing)
    w3 = left_margin + cw * 3 + pad * 4
    sheet3 = Image.new("RGB", (w3, h2), (44, 29, 18))
    d3 = ImageDraw.Draw(sheet3)
    titles = [
        "1. Original Carbon (1.0×)",
        "2. Reusable 4 Paint Only (1.0×)",
        "3. Reusable 4 Paint + 1.20× Spacing",
    ]
    for idx, (im, t) in enumerate([(orig, titles[0]), (col_only, titles[1]), (spaced, titles[2])]):
        ox = left_margin + pad + idx * (cw + pad)
        d3.text((ox, 12), t, fill=(246, 224, 182), font=f_title)
        sheet3.paste(im.crop(crop_box), (ox, top_h))
    d3.text((16, top_h + 70), "Pale road", fill=(228, 206, 172), font=f_label)
    d3.text((16, top_h + 205), "Sand · 4 fit", fill=(228, 206, 172), font=f_label)
    d3.text((16, top_h + 292), "Sand · 3 fit", fill=(228, 206, 172), font=f_label)
    sheet3.save(CAP / "uniforms_only_comparison.png", optimize=True)

    # 3. All 8 facings while walking (4x2 grid of native Command-zoom crops)
    dir_names = ["S (0)", "SW (1)", "W (2)", "NW (3)", "N (4)", "NE (5)", "E (6)", "SE (7)"]
    f_box = (235, 195, 575, 485)
    fw, fh = f_box[2] - f_box[0], f_box[3] - f_box[1]
    cols, rows = 4, 2
    wf = pad + cols * (fw + pad)
    hf = 46 + rows * (fh + 34 + pad)
    sheet_f = Image.new("RGB", (wf, hf), (44, 29, 18))
    df = ImageDraw.Draw(sheet_f)
    df.text((pad, 10), "RTS Reusable 4 · All 8 Facings with Stride Active at Command Zoom (no selection brackets)", fill=(246, 224, 182), font=f_title)
    for c_idx, dname in enumerate(dir_names):
        p = CAP / f"reusable_4_spaced_facing_{c_idx}.png"
        if not p.exists():
            continue
        fim = Image.open(p).convert("RGB").crop(f_box)
        gc, gr = c_idx % cols, c_idx // cols
        ox = pad + gc * (fw + pad)
        oy = 48 + gr * (fh + 34 + pad)
        df.text((ox, oy), f"Facing {dname}", fill=(232, 210, 176), font=f_label)
        sheet_f.paste(fim, (ox, oy + 24))
    sheet_f.save(CAP / "all_eight_facings.png", optimize=True)
    print("Saved matched_unit_comparison.png, uniforms_only_comparison.png, all_eight_facings.png")


if __name__ == "__main__":
    make_matched_unit_sheets()
