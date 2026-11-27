# RTS Mission 1 – Forest and the forest kit

**RTS Mission 1 – Forest** (`scenes/maps/rts_mission_1_forest.tscn`) is Blue's first mission, *The First Claim*, on a tropical forest world. It is the mirror of [RTS Mission 1 – Desert](RTS_MISSION_1_DESERT.md): the same Blue and Red forces with the same numbers, the same Orichalcum rock, HQ, outposts, HUDs, camera, rules, Mend and hold timer. Only the map is new. It is built from a new **forest kit** (`scenes/rts/forest_kit/`) the same way the desert map is built from the desert kit. The plan it follows is [RTS_MISSION_1_FOREST_PLAN.md](RTS_MISSION_1_FOREST_PLAN.md).

**The art is your ChatGPT paintings** (2026-11-27), cut into kit pieces by `tools/python/make_forest_kit.py`. The prompts are in [`assets/source_inputs/forest_kit/PROMPTS.md`](../assets/source_inputs/forest_kit/PROMPTS.md). Art approval stays with you.

![Opening at Command zoom](../render_captures/rts_mission_1_forest/01_opening_command_hd.png)

## Play

Open **Developers Page → Forest RTS builds → RTS Mission 1 – Forest → Play**. **RTS Forest Kit → View** shows the kit. You command Blue. All the desert map's controls apply:

| Key | Does |
| --- | --- |
| **1–7** | Opening · river ford and bridge · north lane · south lane · Blue base · south-east gravel field · Red's road |
| **V** / **Z** | Detailed or Pixel / Command or Close zoom |
| **U** | HUD style (Mockup E, Classic, Holo, Carbon) |
| **G** | Red's AI on or off |
| **E**, **T**, **S** | Mend, hold position, stop |
| **F1** | Show the [blocked footprint](GLOSSARY.md#blocked-footprint) of every piece (red cells) |
| **Esc** | Back to the Developers Page |

## The map

The reference painting's composition, with much more room. Blue's base sits on a gravel pad in the south-west, Red comes in along a dirt road from the east, the Orichalcum rock stands in a large dirt clearing in the middle, a river cuts off the north-west corner, and an empty gravel field lies in the south-east. Forests frame the edges and form a few flanking woods: a big wood north of the clearing, a south wood, an east wood between Red's road and the gravel field, and a small copse east of the plaza that splits Red's approach in two.

![Whole map](../render_captures/rts_mission_1_forest/00_whole_map.png)

**Room, checked by the test** (one cell is 32 px, the width of the desert road):

| Check | Result |
| --- | --- |
| Main lanes (main road, north lane, south lane) carry a corridor at least **4 cells** wide end to end | All three pass |
| Every tank route (base to plaza, Red's road to the plaza, Red to the gravel field, base to the ford and the meadow) is at least **3 cells** wide | All four pass |
| Open ground within 7 cells of the rock | 136 cells, room for both forces to fight around the plaza |
| Blue tank and a Blue squad drive every main lane; Red's tank drives its road to the plaza | All arrive |

The lane widths are tested, so the reference's crowded feel cannot creep back while dressing the map.

## Your paintings in the kit

| Painting | Became | How it was fitted |
| --- | --- | --- |
| `grass_tile.png` | the forest's ground | Seam softened at the edges; one repeat now covers 16 × 16 cells instead of 8 × 8 (`ground_tile_world = 512`), so the yellow patches repeat less often |
| `dirt_road_strip.png`, `river_strip.png` | the road and the river | Cropped to the painted band, seam softened, repeated along the line. The river's blue water is 62 px (about 2 cells) wide and blocks; its banks stay walkable |
| `tree_clusters.png` | the three tree clusters | Kept their painted proportions at one shared scale (crowns about 1.2 cells). Each one's **blocked ground is measured from the painting**: its outline shrunk by half to two thirds of a cell, so crowns overhang open ground |
| `trees_single_and_verge.png` | conifer, two broadleafs, forest verge | Fitted to the pieces' sizes |
| `trees_single_and_verge_and_maple_red.png` | **`maple_tree_red`** (new piece) | The reddest tree on the sheet. Three on the map: one in the middle of the north wood, one on its south edge, one on the south wood's edge |
| `river_crossings.png` | ford and bridge | Scaled so their water matches the river's. The painted ford's stepping stones are one cell wide, too narrow for the tank, so the tool lays the stone band **three times side by side** (the middle copy mirrored) to make a 4-cell ford. The bridge is for infantry |
| `rocks_logs_details.png` | boulders, slab, log, stump, flowers, stones, ferns | Rocks and logs block their painted outline |
| `dirt_clearings.png`, `gravel_pads.png` | clearings and gravel pads | Fitted to the pieces' sizes |

The measured sizes and outlines are saved in `assets/textures/rts/forest_kit/kit_shapes.json`, which the kit's bootstrap reads. The second sheet's other trees and verge are not used yet.

![Whole map with the paintings](../render_captures/rts_mission_1_forest/00_whole_map.png)

## The river, the ford and the bridge

The river is one kit piece, `river`, that follows a path. Its child line **Course** draws the painted river strip (water in the middle, banks on both sides) along its points, and the same points decide which cells are water. So the water you see and the ground units cannot enter always agree, and **bending the river is just dragging the Course points** in the 2D view. Nothing is repainted.

Fords and bridges are separate pieces laid on the river (`river_ford`, `river_bridge`). Their footprint reopens the water under them. The ford is wide enough for the tank (4 cells; the test needs 3). The bridge is for infantry (2 cells). Both lead to a small meadow beyond the river. You asked for "a bridge or a ford"; the map has both so you can judge them in play. Delete the one you don't want.

[Ford and bridge](../render_captures/rts_mission_1_forest/02_river_ford_hd.png) · [same view with F1](../render_captures/rts_mission_1_forest/02_river_ford_f1_blocked.png)

## The forest kit

`scenes/rts/forest_kit/` holds 24 pieces, 3 groups and the kit preview. Every piece carries its Detailed and Pixel art, its blocked footprint, shadow, shade, a minimap colour and `tags`. All of them appear in the **Kit Palette** dock (filter by the **forest** tag) over grass instead of sand.

| Kind | Pieces |
| --- | --- |
| Ground (flat) | `dirt_clearing_plaza`, `dirt_patch_round`, `dirt_patch_long`, `gravel_pad_base`, `gravel_field`, `grass_flowers`, `grass_stones`, `fern_patch` |
| Forest masses | `tree_cluster_large`, `tree_cluster_medium`, `tree_cluster_small`, `conifer_tree`, `broadleaf_tree`, `broadleaf_tree_tall`, `maple_tree_red`, `forest_verge` |
| Water | `river`, `river_ford`, `river_bridge` |
| Rocks and logs | `mossy_boulder`, `mossy_boulder_pair`, `mossy_slab`, `fallen_log`, `tree_stump` |
| Groups | `woodland_copse`, `forest_corner`, `mossy_cover` |

The forest's grass and dirt road are `sand_tile_*.png` and `road_strip_*.png` in `assets/textures/rts/forest_kit/`, because the battlefield loads its ground and road under those names from the map's art folder. The HQ, outposts and Orichalcum outcrop come from the desert kit, as the plan asks.

**Tree masses block only their trunks' core.** The crowns overhang about one cell of open ground. A selected squad walking beneath a crown makes it fade, the same way the desert's oasis tree does. A tree mass's pivot sits at the bottom of its trunks, so troops south of a wood are drawn in front of it and troops north of it pass beneath the crowns.

[Kit page 1](../render_captures/rts_mission_1_forest/kit_1_arrangements_hd.png) · [kit page 2, every piece](../render_captures/rts_mission_1_forest/kit_2_pieces_hd.png) · [Kit Palette, forest tag](../render_captures/rts_mission_1_forest/kit_palette_forest.png)

## Edit the map

**Move your first forest piece.** Open `scenes/maps/rts_mission_1_forest.tscn`. In the Scene panel, open `YSortWorld` and click **EastCopse** (the small wood east of the rock). Drag it in the 2D view. Its blocked ground moves with it. Press F6 to play the scene and F1 to see the blocked cells.

**Add a piece.** Drag a thumbnail from the Kit Palette (or a scene from `scenes/rts/forest_kit/pieces/`) onto `YSortWorld` for upright things (trees, rocks, logs, buildings) or onto `GroundDecals` for flat things (clearings, gravel, flowers, fords, bridges).

**Bend the river.** Select `GroundDecals/River/Course` and drag its points. To put a ford or bridge on it, drag `river_ford` or `river_bridge` under `GroundDecals` below the River, place it on the water and turn it (Rotation) so its gravel bar or deck runs across the water.

**Bend a road.** Drag the points of `RoadNetwork/MainRoad`, `BaseDriveway` or `FordTrack`.

**Change a piece everywhere.** Open its scene in `scenes/rts/forest_kit/pieces/` and edit it there. Every placement updates.

`tools/godot/bootstrap_forest_kit.gd` made the kit and the first layout. It was a one-time step: rerunning it with `-- --force` overwrites your hand edits.

## Replace or add a painting

1. Generate the paintings in [`PROMPTS.md`](../assets/source_inputs/forest_kit/PROMPTS.md) with ChatGPT Images, attaching the images it names from `refs\`. Save them with the exact file names into `D:\Games\Balance5\assets\source_inputs\forest_kit\`.
2. Ask any agent to run `C:/Python312/python.exe tools/python/make_forest_kit.py`. It cuts each painting into its pieces (by transparency), fits them to the pieces' sizes, writes the Detailed and Pixel versions and keeps the stand-ins for anything not painted yet. It prints which pieces came from your paintings.
3. If a cluster, rock, river or crossing painting changed shape, its new size and outline are in `kit_shapes.json`. Until you hand-edit the map, an agent can rebuild the kit and map from it with `tools/godot/bootstrap_forest_kit.gd -- --force`; after you have edited the map, it should copy only the new `world_size`, `draw_offset` and `blocked_poly` into the piece scenes instead.
4. Run `tests/test_rts_mission_1_forest.gd` and check the woods with F1.

## What changed in the shared code

New behaviour is switched on per scene, so the desert map and the older builds are unchanged (their tests pass).

| Change | Where | Desert / older builds |
| --- | --- | --- |
| Per-piece **minimap colour** (`minimap_color`): woods dark green, river blue, clearings dirt, gravel grey | `rts_carbon_piece.gd`, `RtsMissionBattlefield` | Unset, so the minimap is drawn exactly as before |
| **Canopy fade** for any piece (`canopy_fade`), not only pieces named `*_tree` | same | Unset |
| **River** that blocks along its course (`RtsKitRiver`) | `scripts/rts_kit/rts_kit_river.gd` | Not used |
| **Crossings** (`layer_role = "crossing"`) reopen water under a ford or bridge | `RtsMissionBattlefield.is_point_blocked` | No crossings placed |
| Blocked-ground test moved into one overridable function `is_point_blocked` | `rts_carbon_battlefield.gd` | Same result |
| Pixel view takes the map's own ground and road (`pixel_ground_from_kit`) | `RtsMissionBattlefield` | Off |
| Minimap tint under tree crowns (`minimap_canopy_color`) | same | Off |
| Ground texture repeat size (`ground_tile_world`, shader `tile_world`) | `RtsMissionBattlefield`, `rts_carbon_ground.gdshader` | 256, as before |
| Kit Palette lists the forest kit and shows its thumbnails over grass | `addons/balance_kit_palette` | Desert entries unchanged |
| Kit preview title and painting centring (`kit_title`, `centre_paintings`) | `desert_kit_preview.gd` | Defaults keep the desert preview as it was |

## Checks

| Check | Result |
| --- | --- |
| `tests/test_rts_mission_1_forest.gd` headless: kit integrity and tags, Kit Palette folders, kit-only placements, same forces as the desert, tree cores blocked, river blocked away from crossings with walkable banks, ford and bridge, river cuts the meadow off without them, lane and tank-route widths, driven routes, minimap colours, canopy fade, Mend, hold, reset, Developers Page Play/View and Esc | All passed |
| Same test at 1920 × 1080 fullscreen Forward+ with `--capture --record`: every HUD style keeps the battlefield scale, takes clicks on Attack and the minimap, and leaves the centre clickable | All passed |
| Same test against the exported build (`--main-pack builds/Balance.exe`), headless and in a fullscreen window | All passed |
| `test_rts_mission_1_desert.gd` (headless, windowed, and against the export), `test_rts_test_map.gd`, `test_rts_reusable_2_carbon.gd` (and `--miasaki`), `test_rts_reusable_3.gd`, `test_rts_reusable_4.gd` | All passed |
| `tests/capture_kit_palette.gd`: 67 entries with thumbnails; the forest tag shows 27 | Passed |

Captures (1920 × 1080): [opening](../render_captures/rts_mission_1_forest/01_opening_command_hd.png) · [opening Pixel](../render_captures/rts_mission_1_forest/01_opening_command_pixel.png) · [opening F1](../render_captures/rts_mission_1_forest/01_opening_f1_blocked.png) · [ford and bridge](../render_captures/rts_mission_1_forest/02_river_ford_hd.png) · [ford close](../render_captures/rts_mission_1_forest/02b_river_ford_close_hd.png) · [north lane](../render_captures/rts_mission_1_forest/03_north_lane_hd.png) · [south lane](../render_captures/rts_mission_1_forest/04_south_lane_hd.png) · [Blue base](../render_captures/rts_mission_1_forest/05_blue_base_hd.png) · [plaza fight](../render_captures/rts_mission_1_forest/06_plaza_fight_hd.png) · [gravel field](../render_captures/rts_mission_1_forest/07_gravel_field_hd.png) · [Red's road](../render_captures/rts_mission_1_forest/08_red_road_hd.png) · HUDs: [Mockup E](../render_captures/rts_mission_1_forest/09_hud_mockup_e_hd.png), [Classic](../render_captures/rts_mission_1_forest/09_hud_classic_hd.png), [Holo](../render_captures/rts_mission_1_forest/09_hud_holo_hd.png), [Carbon](../render_captures/rts_mission_1_forest/09_hud_placeholder_hd.png) · [12 s clip](../render_captures/rts_mission_1_forest/mission_1_forest_in_motion.mp4)

### Reproduce

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
C:/Python312/python.exe tools/python/make_forest_kit.py
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_mission_1_forest.gd
& $godot --path . --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1_forest.gd -- --capture --record
C:/ffmpeg/bin/ffmpeg.exe -y -framerate 30 -i 'tmp/rts_mission_1_forest/frames/%05d.jpg' -frames:v 360 -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart 'render_captures/rts_mission_1_forest/mission_1_forest_in_motion.mp4'
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack builds/Balance.exe --script res://tests/test_rts_mission_1_forest.gd
& $godot --main-pack builds/Balance.exe --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1_forest.gd
```

## Open

- Your verdict on the look with your paintings. On the bright grass, the small Blue and Red squads stand out less than on sand; worth judging at Command zoom.
- Ford, bridge or both.
- A name for Blue's forest planet. The planet switch (P) only lists "Forest" for now.
- Making the player Red in the desert map is still separate work.
