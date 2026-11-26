"""Generate human-editable Godot .tres layout resources (Layout A and Layout B)
and launchable .tscn scenes for 'RTS Isometric 2— Forest Claim Carbon'."""

from __future__ import annotations

from math import hypot
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAYOUT_DIR = ROOT / "scenes/rts_iso_carbon"
MAP_DIR = ROOT / "scenes/maps"


def dist_to_seg(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    l2 = vx * vx + vy * vy
    if l2 <= 1e-6:
        return hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / l2))
    return hypot(px - (ax + t * vx), py - (ay + t * vy))


def make_grid(trails: list[list[tuple[float, float]]], clearing_center: tuple[float, float],
              clearing_r: float, shelf_max_u: int = 28, shelf_max_v: int = 28) -> list[str]:
    rows: list[str] = []
    for v in range(36):
        chars: list[str] = []
        for u in range(36):
            # Continuous woodland hillside across North/NW/NE (u>=0, v>=0);
            # ONLY foreground SW (v > shelf_max_v) and SE (u > shelf_max_u) drop into valley mist!
            if u > shelf_max_u or v > shelf_max_v:
                chars.append(".")
                continue
            dc = hypot(u - clearing_center[0], v - clearing_center[1])
            d_trail = min(
                dist_to_seg(u, v, seg[0][0], seg[0][1], seg[1][0], seg[1][1])
                for poly in trails
                for seg in zip(poly, poly[1:])
            )
            if dc <= clearing_r - 1.0 or d_trail <= 1.45:
                chars.append("T")
            elif dc <= clearing_r + 0.8 or d_trail <= 2.45:
                chars.append("O")
            elif dc <= clearing_r + 2.5 or d_trail <= 3.90:
                chars.append("M")
            else:
                chars.append("F")
        rows.append("".join(chars))
    return rows


def place(pid: str, u: int, v: int, ox: float = 0.0, oy: float = 0.0,
          flip_x: bool = False, tag: str = "", tint: tuple[float, float, float, float] = (1.0, 1.0, 1.0, 1.0),
          valley_below: bool = False) -> dict:
    return {
        "id": pid,
        "cell": (u, v),
        "offset": (ox, oy),
        "flip_x": flip_x,
        "tag": tag,
        "tint": tint,
        "valley_below": valley_below,
    }


def shared_unit_spawns() -> list[dict]:
    return [
        # Blue Coalition (SW sunlit trailhead: Commander + 2 four-man Rifle Squads + Vanguard Tank)
        {"node_name": "BlueCommander", "team": 0, "role": 1, "cell": (9, 24)},
        {"node_name": "BlueSquad1", "team": 0, "role": 0, "cell": (8, 22)},
        {"node_name": "BlueSquad2", "team": 0, "role": 0, "cell": (11, 25)},
        {"node_name": "BlueTank", "team": 0, "role": 2, "cell": (10, 26)},
        # Red Order (NE sunlit hillside clearing in front of Cave Alcove: Commander + 2 Squads + Heavy Tank)
        {"node_name": "RedCommander", "team": 1, "role": 1, "cell": (23, 12)},
        {"node_name": "RedSquad1", "team": 1, "role": 0, "cell": (22, 10)},
        {"node_name": "RedSquad2", "team": 1, "role": 0, "cell": (25, 13)},
        {"node_name": "RedTank", "team": 1, "role": 2, "cell": (25, 11)},
    ]


def build_layout_a() -> dict:
    # Layout A: Sunlit Shelf Clearing (homage to 2D Painted Forest Fight 4!)
    # Open sunlit central Orichalcum arena at (18, 18), open Red staging at (23, 12),
    # open Blue staging at (9, 24), and two clear routes around the West-Central Bluff (13, 21):
    #   Route 1 (NW Rooted Canopy Trail): (8,22) -> (11,17) -> (15,15) -> (18,18)
    #   Route 2 (SE Cliff-Rim Tank Road): (10,26) -> (17,26) -> (22,23) -> (21,19) -> (18,18)
    trails = [
        [(6, 26), (9, 24), (11, 17), (15, 15), (18, 18)],
        [(9, 26), (17, 26), (22, 23), (21, 19), (18, 18)],
        [(18, 18), (22, 14), (25, 11)],
    ]
    rows = make_grid(trails, clearing_center=(18.0, 18.0), clearing_r=4.2, shelf_max_u=28, shelf_max_v=28)

    valley_tint = (0.38, 0.58, 0.72, 0.72)
    placements = [
        # Recessed lower-valley misty tree crowns peeking out beneath the cliff shelf (forest.png bottom corners!)
        place("tree_canopy_cool", 7, 36, tint=valley_tint, valley_below=True),
        place("tree_canopy_cool", 17, 37, flip_x=True, tint=valley_tint, valley_below=True),
        place("tree_canopy_cool", 36, 26, tint=valley_tint, valley_below=True),
        place("tree_canopy_cool", 36, 16, flip_x=True, tint=valley_tint, valley_below=True),

        # Continuous Foreground Cliff Drop-Off Rims over blue valley mist
        place("shelf_rim_u", 4, 28, tag="SW Rim 0"),
        place("shelf_rim_u", 9, 28, tag="SW Rim 1"),
        place("shelf_rim_u", 14, 28, tag="SW Rim 2"),
        place("shelf_rim_u", 19, 28, tag="SW Rim 3"),
        place("shelf_rim_u", 24, 28, tag="SW Rim 4"),
        place("shelf_rim_corner_s", 28, 28, tag="South Cliff Point"),
        place("shelf_rim_v", 28, 24, tag="SE Rim 1"),
        place("shelf_rim_v", 28, 19, tag="SE Rim 2"),
        place("shelf_rim_v", 28, 14, tag="SE Rim 3"),
        place("shelf_rim_v", 28, 9, tag="SE Rim 4"),
        place("shelf_rim_v", 28, 4, tag="SE Rim 0"),

        # Ground decals (step slabs & clearing boundary stone arc)
        place("clearing_stone_arc", 17, 16, tag="Clearing Ring"),
        place("step_slabs_moss", 10, 22),
        place("step_slabs_moss", 20, 22, flip_x=True),
        place("step_slabs_moss", 21, 14),

        # Central Objective in quiet sunlit ochre arena
        place("orichalcum_outcrop", 18, 18, tag="Orichalcum Vein"),

        # NW Hero Framing Group (Hero Buttress Tree + Root Boulder + Red Shoot + Wooden Cliff Fences!)
        place("tree_hero_buttress", 7, 15, tag="Hero Buttress Tree"),
        place("boulder_moss_pair", 8, 18, tag="Root Boulder"),
        place("undergrowth_red_shoot", 6, 17),
        place("fence_rail_u", 6, 27, tag="SW Cliff Fence 1"),
        place("fence_rail_u", 15, 27, tag="SW Cliff Fence 2"),
        place("fence_rail_v", 27, 23, tag="SE Cliff Fence"),

        # Tactical West-Central Bluff splitting NW Canopy Trail from SE Tank Cliff Road
        place("cliff_end_u", 12, 21, ox=-4.0, oy=2.0, tag="Bluff End W"),
        place("cliff_bluff_u", 14, 21, ox=4.0, oy=0.0, tag="Bluff Wall U"),
        place("cliff_outer_corner", 15, 22, ox=6.0, oy=-4.0, tag="Bluff Nose"),
        place("boulder_moss_pair", 16, 23, flip_x=True, tag="Bluff Foot Boulder"),
        place("undergrowth_fern", 13, 23),

        # Upper-Right Hillside & Cave Alcove (behind Red's open ochre staging!)
        place("cave_alcove_bluff", 24, 6, tag="NE Cave Alcove"),
        place("cliff_bluff_u", 19, 5, tag="North Ridge Wall"),
        place("cliff_end_u", 15, 5, tag="North Ridge End"),
        place("boulder_moss_pair", 27, 8),

        # Lush Woodland Border Canopy (kept out of the central & Red combat lanes!)
        place("tree_canopy_warm", 11, 9, tag="North Canopy Warm"),
        place("tree_canopy_cool", 4, 10, tag="NW Border Tree"),
        place("tree_canopy_cool", 3, 21, tag="West Woods Tree"),
        place("tree_canopy_warm", 26, 19, tag="SE Border Tree"),
        place("fallen_moss_log", 15, 8, tag="North Moss Log"),
        place("undergrowth_fern", 9, 11),
        place("undergrowth_red_shoot", 23, 25),
        place("undergrowth_fern", 26, 16),
        place("undergrowth_red_shoot", 20, 7),
    ]

    return {
        "layout_id": "layout_a",
        "display_name": "Layout A · Shelf",
        "summary": "Sunlit cliff-shelf clearing with twin NW canopy and SE cliff-road approaches.",
        "terrain_rows": rows,
        "placements": placements,
        "unit_spawns": shared_unit_spawns(),
        "camera_start_cell": (16.8, 19.4),
        "camera_poi_north": (16.0, 12.0),
        "camera_poi_east": (22.5, 14.5),
    }


def build_layout_b() -> dict:
    # Layout B: Shifted Bluff & Woodland Flank
    # EXACT same art files & RtsIsoKit catalog — ONLY terrain_rows and placements change!
    # Re-joins the cliff bluff modules into an L-shaped South-East Barrier across (19..26, 21..27)
    # sealing the former SE Tank Road, removes the West-Central Bluff, rearranges the trees,
    # and opens a broad Northern Woodland Flank (10,14 -> 16,11 -> 21,13)!
    trails = [
        [(7, 26), (10, 22), (10, 14), (16, 11), (21, 13), (18, 18)],
        [(10, 23), (14, 19), (18, 18)],
        [(18, 18), (22, 14), (25, 11)],
    ]
    rows = make_grid(trails, clearing_center=(18.0, 18.0), clearing_r=4.0, shelf_max_u=27, shelf_max_v=28)

    valley_tint = (0.38, 0.58, 0.72, 0.72)
    placements = [
        place("tree_canopy_cool", 8, 36, tint=valley_tint, valley_below=True),
        place("tree_canopy_cool", 18, 37, flip_x=True, tint=valley_tint, valley_below=True),
        place("tree_canopy_cool", 35, 26, tint=valley_tint, valley_below=True),
        place("tree_canopy_cool", 35, 16, flip_x=True, tint=valley_tint, valley_below=True),

        # Foreground exposed cliff drop-off rims adjusted cleanly to 27x28 shelf
        place("shelf_rim_u", 4, 28, tag="SW Rim 0"),
        place("shelf_rim_u", 9, 28, tag="SW Rim 1"),
        place("shelf_rim_u", 14, 28, tag="SW Rim 2"),
        place("shelf_rim_u", 19, 28, tag="SW Rim 3"),
        place("shelf_rim_u", 23, 28, tag="SW Rim 4"),
        place("shelf_rim_corner_s", 27, 28, tag="South Cliff Point"),
        place("shelf_rim_v", 27, 24, tag="SE Rim 1"),
        place("shelf_rim_v", 27, 19, tag="SE Rim 2"),
        place("shelf_rim_v", 27, 14, tag="SE Rim 3"),
        place("shelf_rim_v", 27, 9, tag="SE Rim 4"),
        place("shelf_rim_v", 27, 4, tag="SE Rim 0"),

        # Ground decals along the newly opened Northern Woodland Flank
        place("clearing_stone_arc", 17, 16, tag="Clearing Ring"),
        place("step_slabs_moss", 10, 16),
        place("step_slabs_moss", 16, 11, flip_x=True),
        place("step_slabs_moss", 21, 14),

        # Central Objective at (18, 18) — unobstructed in Layout B!
        place("orichalcum_outcrop", 18, 18, tag="Orichalcum Vein"),

        # RECONFIGURED L-SHAPED CLIFF BLUFF BARRIER: Seals the former SE Tank Road cleanly south of Orichalcum!
        place("fallen_moss_log", 19, 20, tag="Moved Log Choke"),
        place("cliff_end_v", 19, 23, ox=0.0, oy=-4.0, tag="Moved Bluff End N"),
        place("cliff_bluff_v", 19, 25, ox=0.0, oy=2.0, tag="Moved Bluff Wall V"),
        place("cliff_inner_corner", 19, 27, ox=4.0, oy=-4.0, tag="Moved Bluff Elbow"),
        place("cliff_bluff_u", 22, 27, ox=2.0, oy=-2.0, tag="Moved Bluff Wall U"),
        place("cliff_end_u", 25, 27, ox=4.0, oy=0.0, tag="Moved Bluff End E"),
        place("boulder_moss_pair", 17, 27, tag="Moved Seam Boulder"),

        # REARRANGED TREES framing the new Northern Flank
        place("tree_hero_buttress", 6, 19, tag="Moved Hero Tree"),
        place("tree_canopy_warm", 14, 22, tag="Moved Center Canopy"),
        place("tree_canopy_cool", 6, 10, tag="Moved NW Flank Tree"),
        place("tree_canopy_warm", 14, 6, tag="Moved North Flank Tree"),
        place("tree_canopy_cool", 25, 18, tag="Moved East Border Tree"),

        # Upper-Right Hillside & Fences
        place("cave_alcove_bluff", 24, 6, tag="NE Cave Alcove"),
        place("boulder_moss_pair", 8, 14, flip_x=True),
        place("boulder_moss_pair", 26, 8),
        place("fence_rail_u", 9, 27, tag="SW Cliff Fence"),
        place("fence_rail_v", 26, 21, tag="SE Cliff Fence"),
        place("undergrowth_fern", 13, 23),
        place("undergrowth_red_shoot", 7, 22),
        place("undergrowth_fern", 12, 7),
        place("undergrowth_red_shoot", 19, 7),
        place("undergrowth_fern", 25, 15),
    ]

    return {
        "layout_id": "layout_b",
        "display_name": "Layout B · Flank",
        "summary": "Reconfigured cliff bluff seals the SE shelf road and opens a wide Northern woodland flank.",
        "terrain_rows": rows,
        "placements": placements,
        "unit_spawns": shared_unit_spawns(),
        "camera_start_cell": (16.8, 19.2),
        "camera_poi_north": (16.0, 12.0),
        "camera_poi_east": (21.0, 23.0),
    }


def serialize_layout_tres(data: dict) -> str:
    lines = [
        '[gd_resource type="Resource" script_class="RtsIsoLayoutData" format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/rts_iso_carbon/rts_iso_layout_data.gd" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        f'layout_id = "{data["layout_id"]}"',
        f'display_name = "{data["display_name"]}"',
        f'summary = "{data["summary"]}"',
    ]
    rows_str = ", ".join(f'"{r}"' for r in data["terrain_rows"])
    lines.append(f"terrain_rows = PackedStringArray({rows_str})")

    pl_items: list[str] = []
    for p in data["placements"]:
        u, v = p["cell"]
        ox, oy = p["offset"]
        fx = "true" if p["flip_x"] else "false"
        vb = "true" if p["valley_below"] else "false"
        tr, tg, tb, ta = p["tint"]
        pl_items.append(
            f'{{"id": "{p["id"]}", "cell": Vector2i({u}, {v}), "offset": Vector2({ox:.1f}, {oy:.1f}), "flip_x": {fx}, "tag": "{p["tag"]}", "tint": Color({tr:.2f}, {tg:.2f}, {tb:.2f}, {ta:.2f}), "valley_below": {vb}}}'
        )
    lines.append("placements = [\n\t" + ",\n\t".join(pl_items) + "\n]")

    sp_items: list[str] = []
    for s in data["unit_spawns"]:
        u, v = s["cell"]
        sp_items.append(
            f'{{"node_name": "{s["node_name"]}", "team": {s["team"]}, "role": {s["role"]}, "cell": Vector2i({u}, {v})}}'
        )
    lines.append("unit_spawns = [\n\t" + ",\n\t".join(sp_items) + "\n]")

    cs = data["camera_start_cell"]
    cn = data["camera_poi_north"]
    ce = data["camera_poi_east"]
    lines.append(f"camera_start_cell = Vector2({cs[0]:.1f}, {cs[1]:.1f})")
    lines.append(f"camera_poi_north = Vector2({cn[0]:.1f}, {cn[1]:.1f})")
    lines.append(f"camera_poi_east = Vector2({ce[0]:.1f}, {ce[1]:.1f})")
    lines.append("")
    return "\n".join(lines)


def write_scenes() -> None:
    tscn_a = """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/rts_iso_carbon/rts_iso_battlefield.gd" id="1"]
[ext_resource type="Resource" path="res://scenes/rts_iso_carbon/layout_a_shelf_clearing.tres" id="2"]
[ext_resource type="Resource" path="res://scenes/rts_iso_carbon/layout_b_split_bluff.tres" id="3"]

[node name="RtsIsometric2ForestClaimCarbon" type="Node2D"]
script = ExtResource("1")
layouts = Array[Resource]([ExtResource("2"), ExtResource("3")])
initial_layout_index = 0
"""
    tscn_b = """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/rts_iso_carbon/rts_iso_battlefield.gd" id="1"]
[ext_resource type="Resource" path="res://scenes/rts_iso_carbon/layout_a_shelf_clearing.tres" id="2"]
[ext_resource type="Resource" path="res://scenes/rts_iso_carbon/layout_b_split_bluff.tres" id="3"]

[node name="RtsIsometric2ForestClaimCarbonLayoutB" type="Node2D"]
script = ExtResource("1")
layouts = Array[Resource]([ExtResource("2"), ExtResource("3")])
initial_layout_index = 1
"""
    MAP_DIR.mkdir(parents=True, exist_ok=True)
    (MAP_DIR / "rts_isometric_2_forest_claim_carbon.tscn").write_text(tscn_a, encoding="utf-8")
    (MAP_DIR / "rts_isometric_2_forest_claim_carbon_layout_b.tscn").write_text(tscn_b, encoding="utf-8")


def main() -> None:
    LAYOUT_DIR.mkdir(parents=True, exist_ok=True)
    la = build_layout_a()
    lb = build_layout_b()
    (LAYOUT_DIR / "layout_a_shelf_clearing.tres").write_text(serialize_layout_tres(la), encoding="utf-8")
    (LAYOUT_DIR / "layout_b_split_bluff.tres").write_text(serialize_layout_tres(lb), encoding="utf-8")
    write_scenes()
    print("Generated layout_a_shelf_clearing.tres, layout_b_split_bluff.tres, and launchable .tscn scenes.")


if __name__ == "__main__":
    main()
