"""Convert our seamless ChatGPT cobblestone maps into native editable authoring files
for Krita (.kra), Aseprite (.aseprite), and Tiled (.tsx + .tmx) inside assets/textures/source/.

Usage:
  & "C:/Python312/python.exe" "d:/Games/Balance5/scripts/export_chatgpt_authoring.py"
"""

import io
import subprocess
from pathlib import Path
import zipfile
from xml.etree.ElementTree import Element, SubElement, tostring

import cv2
import numpy as np
from PIL import Image

ROOT = Path(r"d:\Games\Balance5")
TEX_DIR = ROOT / "assets" / "textures" / "canyon_pbr"
SRC_DIR = ROOT / "assets" / "textures" / "source"
TILED_DIR = SRC_DIR / "tiled"
TMP_DIR = ROOT / "tmp" / "chatgpt_authoring"

KRITA_EXE = Path(r"C:\Krita\bin\krita.exe")
ASEPRITE_EXE = Path(r"C:\Aseprite\Aseprite.exe")


def png_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def save_ora(layers: list[tuple[str, Image.Image, bool]], out_ora: Path, w: int, h: int) -> None:
    doc = Element("image", {"w": str(w), "h": str(h), "name": out_ora.stem})
    stack = SubElement(doc, "stack")
    merged = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    with zipfile.ZipFile(out_ora, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("mimetype", "image/openraster", compress_type=zipfile.ZIP_STORED)
        for i, (name, layer, visible) in enumerate(layers):
            rel = f"data/layer{i}.png"
            rgba = layer.convert("RGBA")
            zf.writestr(rel, png_bytes(rgba))
            SubElement(
                stack,
                "layer",
                {
                    "name": name,
                    "src": rel,
                    "visibility": "visible" if visible else "hidden",
                    "opacity": "1.0",
                    "composite-op": "svg:src-over",
                    "x": "0",
                    "y": "0",
                },
            )
        for _, layer, visible in reversed(layers):
            if visible:
                merged.alpha_composite(layer.convert("RGBA"))
        zf.writestr("stack.xml", tostring(doc, encoding="utf-8"))
        zf.writestr("mergedimage.png", png_bytes(merged))


def build_layers_from_chatgpt() -> dict[str, Image.Image]:
    alb = np.asarray(Image.open(TEX_DIR / "chatgpt_cobble_albedo.png").convert("RGB"))
    nrm = np.asarray(Image.open(TEX_DIR / "chatgpt_cobble_normal.png").convert("RGB"))
    orm = np.asarray(Image.open(TEX_DIR / "chatgpt_cobble_orm.png").convert("RGB"))

    # Use ORM R (cavity AO) & G (roughness mask) to separate stone faces cleanly from sandy joints
    cav = orm[:, :, 0].astype(np.float32) / 255.0
    stone_alpha = np.clip((cav - 0.34) / 0.24, 0.0, 1.0)
    stone_alpha_u8 = np.clip(np.rint(stone_alpha * 255.0), 0, 255).astype(np.uint8)
    stone_layer = Image.fromarray(np.dstack((alb, stone_alpha_u8)), mode="RGBA")

    # Joint/crevice base layer tinted slightly darker where crevices sit
    joint_rgb = np.clip(alb.astype(np.float32) * np.clip(cav[..., None] * 0.85 + 0.18, 0.25, 1.0), 0, 255).astype(np.uint8)
    joint_layer = Image.fromarray(joint_rgb).convert("RGBA")

    # Reconstruct grayscale height approximation from ORM & normal brightness for Krita/Aseprite painting
    hgt_u8 = np.clip(np.rint(np.clip((1.0 - orm[:, :, 1].astype(np.float32) / 255.0) * 1.9 + cav * 0.35, 0.0, 1.0) * 255.0), 0, 255).astype(np.uint8)
    height_layer = Image.fromarray(np.dstack((hgt_u8, hgt_u8, hgt_u8))).convert("RGBA")
    ao_layer = Image.fromarray(np.dstack((orm[:, :, 0], orm[:, :, 0], orm[:, :, 0]))).convert("RGBA")
    normal_layer = Image.fromarray(nrm).convert("RGBA")
    full_albedo = Image.fromarray(alb).convert("RGBA")

    return {
        "full_albedo": full_albedo,
        "stones": stone_layer,
        "joints": joint_layer,
        "ao": ao_layer,
        "height": height_layer,
        "normal": normal_layer,
    }


def export_krita(layers_map: dict[str, Image.Image]) -> Path:
    ora_path = TMP_DIR / "chatgpt_cobble.ora"
    kra_path = SRC_DIR / "chatgpt_cobble.kra"
    save_ora(
        [
            ("Tangent Normal (Reference)", layers_map["normal"], False),
            ("Height Estimate (Paintable)", layers_map["height"], False),
            ("Cavity AO Mask", layers_map["ao"], False),
            ("Stone Crowns (Cutout)", layers_map["stones"], True),
            ("Sand & Crevice Bed", layers_map["joints"], True),
        ],
        ora_path,
        1024,
        1024,
    )
    subprocess.run(
        [str(KRITA_EXE), str(ora_path), "--export", "--export-filename", str(kra_path)],
        check=True,
    )
    print(f"Exported Krita master -> {kra_path} ({kra_path.stat().st_size} bytes)")
    return kra_path


def export_aseprite(layers_map: dict[str, Image.Image]) -> list[Path]:
    # Save temporary layer PNGs for Aseprite Lua assembly
    p_joints = TMP_DIR / "ase_joints.png"
    p_stones = TMP_DIR / "ase_stones.png"
    p_ao = TMP_DIR / "ase_ao.png"
    p_height = TMP_DIR / "ase_height.png"
    p_normal = TMP_DIR / "ase_normal.png"
    layers_map["joints"].save(p_joints)
    layers_map["stones"].save(p_stones)
    layers_map["ao"].save(p_ao)
    layers_map["height"].save(p_height)
    layers_map["normal"].save(p_normal)

    # Also build a crisp 256x256 quantized pixel-art version (64 colors) for easy sprite/tile pixel editing
    p_pixel_256 = TMP_DIR / "ase_pixel_256.png"
    pix_256 = layers_map["full_albedo"].convert("RGB").resize((256, 256), Image.Resampling.BILINEAR)
    pix_quant = pix_256.quantize(colors=48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    pix_quant.save(p_pixel_256)

    out_1024 = SRC_DIR / "chatgpt_cobble_1024.aseprite"
    out_256 = SRC_DIR / "chatgpt_cobble_pixel_256.aseprite"
    lua_script = TMP_DIR / "build_aseprite_files.lua"

    def lua_str(p: Path) -> str:
        return str(p).replace("\\", "/")

    lua_script.write_text(
        f"""
local function addLayerFromFile(sprite, name, filepath, visible)
  local src = app.open(filepath)
  local srcImg = src.cels[1].image:clone()
  src:close()
  local lay = sprite:newLayer()
  lay.name = name
  lay.isVisible = visible
  sprite:newCel(lay, sprite.frames[1], srcImg, Point(0, 0))
end

-- 1. Layered 1024x1024 source .aseprite
local sp = Sprite(1024, 1024, ColorMode.RGB)
sp.gridBounds = Rectangle(0, 0, 128, 128)
local baseLay = sp.layers[1]
baseLay.name = "Sand & Crevices"
local imgJ = app.open("{lua_str(p_joints)}")
sp:newCel(baseLay, sp.frames[1], imgJ.cels[1].image:clone(), Point(0, 0))
imgJ:close()

addLayerFromFile(sp, "Stone Crowns", "{lua_str(p_stones)}", true)
addLayerFromFile(sp, "Cavity AO", "{lua_str(p_ao)}", false)
addLayerFromFile(sp, "Height Map", "{lua_str(p_height)}", false)
addLayerFromFile(sp, "Tangent Normal", "{lua_str(p_normal)}", false)
sp:saveAs("{lua_str(out_1024)}")
sp:close()

-- 2. Pixel-art ready 256x256 (32x32 grid, 48-color desert palette)
local pix = app.open("{lua_str(p_pixel_256)}")
pix.gridBounds = Rectangle(0, 0, 32, 32)
pix.layers[1].name = "Cobble Pixel Tile (48-col)"
pix:saveAs("{lua_str(out_256)}")
pix:close()
""",
        encoding="utf-8",
    )
    subprocess.run([str(ASEPRITE_EXE), "-b", "--script", str(lua_script)], check=True)
    print(f"Exported Aseprite files -> {out_1024.name}, {out_256.name}")
    return [out_1024, out_256]


def export_tiled(layers_map: dict[str, Image.Image]) -> list[Path]:
    TILED_DIR.mkdir(parents=True, exist_ok=True)
    cob = np.asarray(layers_map["full_albedo"].convert("RGB"))
    sand = np.asarray(Image.open(TEX_DIR / "hd2d_sand_albedo.png").convert("RGB").resize((1024, 1024), Image.Resampling.BICUBIC))

    # Build a 1024x1280 tileset atlas (8 columns x 10 rows of 128x128 tiles = 80 tiles):
    # Rows 0..7 (IDs 0..63): full 8x8 seamless ChatGPT cobble grid (0.4m per tile at 3.2m scale)
    # Rows 8..9 (IDs 64..79): sand ground tiles + left/right/top/bottom feathered verge transition tiles!
    tile = 128
    atlas = np.zeros((10 * tile, 8 * tile, 3), dtype=np.uint8)
    atlas[:1024, :, :] = cob

    yy, xx = np.mgrid[0:tile, 0:tile].astype(np.float32) / float(tile)
    for col in range(8):
        sx = (col * tile) % 1024
        s_patch = sand[0:tile, sx:sx + tile, :].astype(np.float32)
        c_patch = cob[0:tile, sx:sx + tile, :].astype(np.float32)
        if col < 4:
            # Pure desert sand variants (IDs 64..67)
            atlas[8 * tile:9 * tile, col * tile:(col + 1) * tile, :] = np.clip(s_patch * (0.94 + col * 0.03), 0, 255).astype(np.uint8)
        elif col < 6:
            # Left verge fade (sand on left -> cobbles on right) (IDs 68..69)
            w = np.clip((xx - 0.20) / 0.60, 0.0, 1.0)[..., None]
            mix = s_patch * (1.0 - w) + c_patch * w
            atlas[8 * tile:9 * tile, col * tile:(col + 1) * tile, :] = np.clip(mix, 0, 255).astype(np.uint8)
        else:
            # Right verge fade (cobbles on left -> sand on right) (IDs 70..71)
            w = np.clip((0.80 - xx) / 0.60, 0.0, 1.0)[..., None]
            mix = s_patch * (1.0 - w) + c_patch * w
            atlas[8 * tile:9 * tile, col * tile:(col + 1) * tile, :] = np.clip(mix, 0, 255).astype(np.uint8)

        # Row 9 (IDs 72..79): darker roadside shadow sand & transition tiles
        shadow_mult = 0.62 if col >= 4 else 0.78
        atlas[9 * tile:10 * tile, col * tile:(col + 1) * tile, :] = np.clip(s_patch * shadow_mult, 0, 255).astype(np.uint8)

    atlas_path = TILED_DIR / "chatgpt_road_tileset.png"
    Image.fromarray(atlas).save(atlas_path)

    tsx_path = TILED_DIR / "chatgpt_road_tileset.tsx"
    tsx_path.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.0" name="chatgpt_road_tileset" tilewidth="128" tileheight="128" tilecount="80" columns="8">
 <image source="chatgpt_road_tileset.png" width="1024" height="1280"/>
</tileset>
""",
        encoding="utf-8",
    )

    # Pre-paint a playable 16x24 canyon trail sandbox map (S-curve cobblestone path + sand + shaded right verge)
    W, H = 16, 24
    sand_rows = []
    road_rows = []
    for r in range(H):
        # S-curve matching Balance5 path curve
        cx = int(round(7.5 + np.sin(r * 0.35) * 1.8))
        s_line = []
        r_line = []
        for c in range(W):
            s_id = 65 + ((r * 3 + c * 5) % 4)  # sand base (1-based in TMX = +1)
            if c > cx + 3:
                s_id = 73 + ((r + c) % 2)  # darker right-wall shadow sand
            s_line.append(str(s_id))

            dx = c - cx
            if abs(dx) <= 2:
                # Seamless cobble grid coordinates (rows 0..7, cols 0..7) -> 1-based tile ID
                tid = 1 + (r % 8) * 8 + (c % 8)
            elif dx == -3:
                tid = 69  # left sand->cobble fade
            elif dx == 3:
                tid = 71  # right cobble->sand fade
            else:
                tid = 0
            r_line.append(str(tid))
        sand_rows.append(",".join(s_line))
        road_rows.append(",".join(r_line))

    tmx_path = TILED_DIR / "canyon_road_sandbox.tmx"
    tmx_path.write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.11.0" orientation="orthogonal" renderorder="right-down" width="{W}" height="{H}" tilewidth="128" tileheight="128" infinite="0" nextlayerid="3" nextobjectid="1">
 <tileset firstgid="1" source="chatgpt_road_tileset.tsx"/>
 <layer id="1" name="Desert Sand Base" width="{W}" height="{H}">
  <data encoding="csv">
{",\n".join(sand_rows)}
</data>
 </layer>
 <layer id="2" name="Winding ChatGPT Cobblestone Road" width="{W}" height="{H}">
  <data encoding="csv">
{",\n".join(road_rows)}
</data>
 </layer>
</map>
""",
        encoding="utf-8",
    )
    print(f"Exported Tiled pack -> {atlas_path.name}, {tsx_path.name}, {tmx_path.name}")
    return [atlas_path, tsx_path, tmx_path]


def main() -> None:
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    layers_map = build_layers_from_chatgpt()
    export_krita(layers_map)
    export_aseprite(layers_map)
    export_tiled(layers_map)


if __name__ == "__main__":
    main()
