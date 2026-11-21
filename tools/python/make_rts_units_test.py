"""Build the RTS units test: the style test 5 map with units that walk, drive and fight on it.

    C:/Python312/python.exe tools/python/make_rts_units_test.py

Reads the style test 5 layers (run make_rts_style_test.py first) and writes:
  assets/textures/rts/units_test/walk_mask.png    one pixel per 32 px tile, white = blocked
                                                  (cliffs, mesas, the Orichalcum rock)
  assets/textures/rts/units_test/ground_light.png how bright the ground is under each art pixel
                                                  (128 = average sand), so units can be lit like it
  assets/textures/rts/units/tank_red_sheet.png    the Balance4 8-facing tank sheet in Red
  scenes/rts/units/look/*.tres                    unit types with sprites (stand-ins)
  scenes/maps/rts_units_test.tscn                 the scene
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
T5 = ROOT / "assets" / "textures" / "rts" / "style_test" / "t5"
STYLE = ROOT / "assets" / "textures" / "rts" / "style_test"
OUT = ROOT / "assets" / "textures" / "rts" / "units_test"
UNITS_DIR = ROOT / "assets" / "textures" / "rts" / "units"
STATS_DIR = ROOT / "scenes" / "rts" / "units" / "look"
SCENE = ROOT / "scenes" / "maps" / "rts_units_test.tscn"
TILE = 32

# name, faction (0 Blue, 1 Red), kind (0 troop, 1 commander), hp, attack, armour, range, cooldown,
# guard, speed, sprite path (res://), directions, frames, vehicle, scale
TYPES = {
    "blue_squad": ("Blue Squad", 0, 0, 60, 10, 3, 3, 1.0, 5, 2.4, "res://assets/textures/rts/style_test/unit_blue_squad.png", 1, 1, False, 1.0),
    "red_squad": ("Red Legionaries", 1, 0, 60, 12, 4, 1, 0.9, 4, 2.6, "res://assets/textures/rts/style_test/unit_red_squad.png", 1, 1, False, 1.0),
    "blue_commander": ("Blue Commander", 0, 1, 120, 14, 6, 4, 1.2, 6, 2.2, "res://assets/textures/rts/style_test/unit_blue_commander.png", 1, 1, False, 1.0),
    "red_commander": ("Red Commander", 1, 1, 120, 18, 6, 2, 1.1, 5, 2.4, "res://assets/textures/rts/style_test/unit_red_commander.png", 1, 1, False, 1.0),
    "blue_tank": ("Blue Tank", 0, 0, 200, 20, 8, 3, 1.6, 6, 2.0, "res://assets/textures/units/tank_blue.png", 8, 3, True, 0.85),
    "red_tank": ("Red Tank", 1, 0, 200, 20, 8, 3, 1.6, 6, 2.0, "res://assets/textures/rts/units/tank_red_sheet.png", 8, 3, True, 0.85),
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

    # Red tank: the blue sheet with its blue paint turned red.
    sheet = np.array(Image.open(ROOT / "assets" / "textures" / "units" / "tank_blue.png").convert("RGBA")).astype(np.float32)
    blue = (sheet[..., 2] > sheet[..., 0] + 20) & (sheet[..., 3] > 0)
    red = sheet.copy()
    red[blue, 0] = sheet[blue, 2]
    red[blue, 1] = sheet[blue, 1] * 0.55
    red[blue, 2] = sheet[blue, 0] * 0.6
    Image.fromarray(red.clip(0, 255).astype(np.uint8)).save(UNITS_DIR / "tank_red_sheet.png")

    for key, (name, fac, kind, hp, atk, arm, rng_, cd, guard, speed, sprite, dirs, frames, veh, scale) in TYPES.items():
        (STATS_DIR / f"{key}.tres").write_text(f'''[gd_resource type="Resource" script_class="UnitStats" format=3]

[ext_resource type="Script" path="res://scripts/rts/unit_stats.gd" id="1"]
[ext_resource type="Texture2D" path="{sprite}" id="2"]

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
sprite_directions = {dirs}
sprite_frames = {frames}
vehicle = {"true" if veh else "false"}
sprite_scale = {scale}
''')

    res = [("Script", "res://scripts/rts/rts_units_test.gd"), ("Script", "res://scripts/rts/rts_grid.gd"),
           ("Script", "res://scripts/rts/rts_look.gd"), ("Script", "res://scripts/rts/rts_commands.gd"),
           ("Script", "res://scripts/rts/rts_camera.gd"), ("PackedScene", "res://scenes/actors/rts_unit.tscn"),
           ("Texture2D", "res://assets/textures/rts/style_test/t5/sand_dunes.png"),
           ("Texture2D", "res://assets/textures/rts/style_test/t5/road.png"),
           ("Texture2D", "res://assets/textures/rts/style_test/t5/rocks.png"),
           ("Texture2D", "res://assets/textures/rts/style_test/t5/scatter.png"),
           ("Texture2D", "res://assets/textures/rts/units_test/walk_mask.png"),
           ("Texture2D", "res://assets/textures/rts/units_test/ground_light.png")]
    res += [("Resource", f"res://scenes/rts/units/look/{k}.tres") for k in TYPES]
    ids = {path: f"r{i}" for i, (_, path) in enumerate(res)}
    lines = ["[gd_scene format=3]", ""]
    lines += [f'[ext_resource type="{t}" path="{p}" id="{ids[p]}"]' for t, p in res]

    def ref(path: str) -> str:
        return f'ExtResource("{ids[path]}")'

    lines += ["", '[node name="RtsUnitsTest" type="Node2D"]', "texture_filter = 1",
              f'script = {ref("res://scripts/rts/rts_units_test.gd")}', ""]
    for node, tex in (("Ground", "sand_dunes"), ("Road", "road"), ("Rocks", "rocks"), ("Scatter", "scatter")):
        lines += [f'[node name="{node}" type="Sprite2D" parent="."]',
                  f'texture = {ref(f"res://assets/textures/rts/style_test/t5/{tex}.png")}', "centered = false", ""]
    lines += ['[node name="Look" type="Node2D" parent="."]', f'script = {ref("res://scripts/rts/rts_look.gd")}',
              f'light_map = {ref("res://assets/textures/rts/units_test/ground_light.png")}', "",
              '[node name="Grid" type="Node2D" parent="."]', f'script = {ref("res://scripts/rts/rts_grid.gd")}',
              f'blocked_cells = {ref("res://assets/textures/rts/units_test/walk_mask.png")}', "",
              '[node name="Units" type="Node2D" parent="."]', "y_sort_enabled = true", ""]
    for node, key, (x, y) in SPAWNS:
        lines += [f'[node name="{node}" parent="Units" instance={ref("res://scenes/actors/rts_unit.tscn")}]',
                  f"position = Vector2({x}, {y})", f'stats = {ref(f"res://scenes/rts/units/look/{key}.tres")}', ""]
    lines += ['[node name="Commands" type="Node2D" parent="."]', f'script = {ref("res://scripts/rts/rts_commands.gd")}', "",
              '[node name="Camera" type="Camera2D" parent="."]', f"position = Vector2({w // 2}, {h // 2})",
              "zoom = Vector2(1.3333, 1.3333)", f'script = {ref("res://scripts/rts/rts_camera.gd")}',
              "zoom_min = 1.3333", "zoom_max = 3.0", "",
              '[node name="HUD" type="CanvasLayer" parent="."]', "",
              '[node name="Help" type="Label" parent="HUD"]',
              "offset_left = 10.0", "offset_top = 6.0", "offset_right = 1270.0", "offset_bottom = 30.0",
              "mouse_filter = 2", "theme_override_colors/font_outline_color = Color(0, 0, 0, 0.85)",
              "theme_override_constants/outline_size = 5", "theme_override_font_sizes/font_size = 14", ""]
    SCENE.write_text("\n".join(lines))
    print(f"Blocked tiles: {int((cells > 0.3).sum())} of {cells.size}. Wrote {SCENE}")


if __name__ == "__main__":
    main()
