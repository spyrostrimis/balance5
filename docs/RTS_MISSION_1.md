# RTS Mission 1 and the desert kit

**RTS Mission 1** (`scenes/maps/rts_mission_1.tscn`) is now the one canonical RTS scene. It holds original Carbon's encounter (same forces, rules, camera and HUD) on Reusable 4's layout, rebuilt entirely from a shared **desert kit**. Future RTS work, visual or gameplay, edits this scene and the kit. It does not make another "Reusable N" copy. Carbon, Miasaki, Reusable 3 and Reusable 4 stay on the Developers Page unchanged as comparison baselines.

Open **Developers Page → Desert RTS builds → RTS Mission 1 → Play** (the main **Play RTS Mission 1** button on the opening screen also starts it). **RTS Desert Kit → View** shows the kit. All Carbon controls apply. **1–4** jump to the opening, the northeast oasis, the roadside pool and the forked dunes. **V** switches Detailed/Pixel, **Z** switches Command/Close, **G** turns on Red's AI, **F1** shows blocked ground and **Esc** returns.

![Reusable 4 and Mission 1 at the same camera](../render_captures/rts_mission_1/before_after.png)

## What changed from Reusable 4

| Change | Why | Evidence |
| --- | --- | --- |
| Every rock, dune, pool, tree, building and road piece is an instance of a kit scene | Move or add a piece without copying settings. Fixing a piece fixes every map that uses it. | `test_rts_mission_1.gd`: *every placed piece comes from the kit* |
| Blue uniforms brightened toward Reusable 3's cobalt, keeping Reusable 4's painted shading | Reusable 4's navy read as dark shapes on orange sand | [Before/after, top row](../render_captures/rts_mission_1/before_after.png) |
| Seam-free sand lighting (`smooth_wind`) | The old wind lighting left long straight light seams across open sand | [Before/after, middle row](../render_captures/rts_mission_1/before_after.png) |
| HQ joined to the road with a short driveway instead of a loose oval of paving | The oval read as a puddle of road | [Before/after, bottom row](../render_captures/rts_mission_1/before_after.png) |
| **Carbon's own painted cliff oasis is back in the northeast**, in its original spot | It is the best oasis painting we have; Reusable 4 had swapped it for the modular spring | [Northeast view](../render_captures/rts_mission_1/02_sheltered_spring_hd.png) |
| The kit's modular sheltered spring got a ring of scrub and reeds at the waterline | It had lost the greenery Carbon's spring has. It stays in the kit for other maps | Kit page 1 |
| HUD text drawn with MSDF fonts (project setting) | The HUD draws small text and then scales it up, which blurred it. MSDF letters stay sharp at any scale | [HUD prompts](../assets/source_inputs/hud/PROMPTS.md) |
| Camera views are markers in the scene (`CameraViews`) | Each new map sets its own 1–9 views without code | — |
| Captures at **1920 × 1080** fullscreen | Carbon's Detailed art is painted for 1080p. At 1376 × 768 we judged everything smaller than players see it | All PNGs and the clip measure 1920 × 1080 |

**Not done yet: the HQ camera angle.** The building is still painted at the reference image's lower angle. The prompt and the script that installs the result are ready: [`assets/source_inputs/desert_kit/PROMPTS.md`](../assets/source_inputs/desert_kit/PROMPTS.md).

## Make and edit maps

**Where the art comes from.** 13 of the 33 pieces are original Carbon paintings: the central Orichalcum outcrop and plaza, every rock and ridge, the cliff oasis, the three dune clusters, the outpost and the scrub. The sand, road and tanks are Carbon's too. Reusable 4's art is used only where Carbon had nothing: the newer dune shapes, the modular oasis parts, the tree, the HQ, the small crystal deposits, road joins and pebbles, plus the infantry (for readability). The **carbon-art** tag in the Kit Palette lists Carbon's paintings.

**Kit Palette (in the Godot editor).** A dock next to FileSystem shows every piece and group as a thumbnail over sand. Click tag buttons (rock, dune, water, plants, building, crystal, road, group, carbon-art…) to filter, or type in the search box. Drag a thumbnail onto the 2D view to place it under the selected node. Double-click to open the piece's own scene. Tags are stored on each piece scene (Inspector → Metadata → `tags`); press **Reload** after changing them. If the dock doesn't appear, use **Project → Reload Current Project**, or turn on **Kit Palette** in **Project Settings → Plugins**. In the editor the pieces now draw with their real art, and dunes show as lit sand.

`builds/rts_reusable_2_carbon_pieces/` is only an exported copy of `assets/textures/rts/carbon/` (byte-identical). The game doesn't use it, and `builds/` is now excluded from the export.

**The kit** lives in `scenes/rts/desert_kit/`:

- `pieces/`: one scene per painted piece (33 so far: rocks, cliffs, dunes, water, banks, reeds, the tree, scrub, buildings, the crystal parts, road joins and ends, pebbles). Each one carries its Detailed and Pixel art, its [blocked footprint](GLOSSARY.md#blocked-footprint), shadow, lee shade and dune height.
- `groups/`: [editable groups](GLOSSARY.md#editable-group) built from those pieces: `sheltered_spring`, `roadside_pool`, `orichalcum_wide`, `orichalcum_tall`.
- `kit_preview.tscn`: the **RTS Desert Kit** card. Page 1 shows the groups; page 2 (key **2**) shows every piece with its file name. Page 2 reads the `pieces/` folder when it opens, so a new piece appears there on its own.

Art is in `assets/textures/rts/desert_kit/`. Pieces with no kit painting use original Carbon's art in `assets/textures/rts/carbon/`.

**Move something.** Open `scenes/maps/rts_mission_1.tscn`, select the piece under `YSortWorld`, `Dunes` or `GroundDecals`, and drag it. Its blocked ground moves with it. Units walk where the painting says they can. Press F1 in play to check.

**Add something.** Drag a scene from `scenes/rts/desert_kit/pieces/` (or `groups/`) onto `YSortWorld` for upright things (rocks, trees, buildings), `Dunes` for dunes, or `GroundDecals` for flat things (pebbles, road patches). Water and banks inside groups already have the right layering.

**Bend a road.** Drag the points of `RoadNetwork/MainRoad`, `RoadsideSpur` or `HQDriveway`. Any `Line2D` under `RoadNetwork` is drawn as road and counts as calm ground. The spur's fade and end cap follow its last point.

**Change a piece everywhere.** Open the piece's own scene in `pieces/` and edit it: footprint, size, shadow. Every placement updates. To change one placement only, edit it in the map. Godot stores just that difference.

**Make a new map.** Duplicate `rts_mission_1.tscn`, rearrange pieces, move the `CameraViews` markers (first marker = opening view) and the units, then add a Play card for it.

## Checks

| Check | Result |
| --- | --- |
| `tests/test_rts_mission_1.gd` headless: kit integrity, kit-only placements, blocked ground, passage close/reopen, tank tracks, Red tank through the passage, tree fade, Mend, reset, Developers Page cards and Esc | All passed |
| Same test, Forward+ fullscreen `--capture --compare --record` | All passed; stills and frames measure 1920 × 1080 |
| Same test against the exported build (`--main-pack builds/Balance.exe`), headless and in a fullscreen window | All passed; both new cards launch and Esc returns |
| `test_rts_test_map.gd`, `test_rts_reusable_2_carbon.gd` (and `--miasaki`), `test_rts_reusable_3.gd`, `test_rts_reusable_4.gd` | All passed, so the older builds are unchanged |
| `tests/capture_kit_palette.gd` (windowed): the Kit Palette loads all 37 entries with thumbnails, filters by tag and hands the 2D view a scene file to drop | Passed. Dropping into the real editor still needs a manual check |

Captures: [opening](../render_captures/rts_mission_1/01_opening_command_hd.png) · [opening Pixel](../render_captures/rts_mission_1/01_opening_command_pixel.png) · [spring](../render_captures/rts_mission_1/02_sheltered_spring_hd.png) · [roadside pool](../render_captures/rts_mission_1/03_roadside_pool_and_fork_hd.png) · [HQ and squad](../render_captures/rts_mission_1/04_blue_headquarters_and_squad_hd.png) · [tracks](../render_captures/rts_mission_1/05_forked_dune_treads_hd.png) · [kit page 1](../render_captures/rts_mission_1/kit_1_arrangements_hd.png) · [kit page 2](../render_captures/rts_mission_1/kit_2_pieces_hd.png) · [12 s clip](../render_captures/rts_mission_1/mission_1_in_motion.mp4)

Art approval stays with the owner.

### Reproduce

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
C:/Python312/python.exe tools/python/make_desert_kit_units.py
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_mission_1.gd
& $godot --path . --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1.gd -- --capture --compare --record
C:/ffmpeg/bin/ffmpeg.exe -y -framerate 30 -i 'tmp/rts_mission_1/frames/%05d.jpg' -frames:v 360 -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart 'render_captures/rts_mission_1/mission_1_in_motion.mp4'
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack builds/Balance.exe --script res://tests/test_rts_mission_1.gd
& $godot --main-pack builds/Balance.exe --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1.gd
```

`tools/godot/bootstrap_desert_kit.gd` made the kit and the first Mission 1 layout from Reusable 4 and Carbon. It was a one-time step. Rerunning it with `-- --force` overwrites the hand edits above.
