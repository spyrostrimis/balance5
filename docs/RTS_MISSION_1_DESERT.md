# RTS Mission 1 – Desert and the desert kit

**RTS Mission 1 – Desert** (`scenes/maps/rts_mission_1_desert.tscn`) is Red's first mission, in the desert. Blue's first mission is **RTS Mission 1 – Forest** ([plan](RTS_MISSION_1_FOREST_PLAN.md)). Both use the same units, buildings, Orichalcum rock, HUD and rules. The player still commands Blue here; switching this map to the Red player is on the roadmap. It is the canonical desert RTS scene. It holds original Carbon's encounter (same forces, rules, camera and HUD) on Reusable 4's layout, rebuilt entirely from a shared **desert kit**. Future RTS work, visual or gameplay, edits this scene and the kit. It does not make another "Reusable N" copy. Carbon, Miasaki, Reusable 3 and Reusable 4 stay on the Developers Page unchanged as comparison baselines.

Open **Developers Page → Desert RTS builds → RTS Mission 1 – Desert → Play**. **RTS Desert Kit → View** shows the kit. All Carbon controls apply. **1–4** jump to the opening, the northeast oasis, the roadside pool and the forked dunes. **V** switches Detailed/Pixel, **Z** switches Command/Close, **G** turns on Red's AI, **F1** shows blocked ground and **Esc** returns.

![Reusable 4 and Mission 1 at the same camera](../render_captures/rts_mission_1/before_after.png)

## What changed from Reusable 4

| Change | Why | Evidence |
| --- | --- | --- |
| Every rock, dune, pool, tree, building and road piece is an instance of a kit scene | Move or add a piece without copying settings. Fixing a piece fixes every map that uses it. | `test_rts_mission_1_desert.gd`: *every placed piece comes from the kit* |
| Blue uniforms brightened toward Reusable 3's cobalt, keeping Reusable 4's painted shading | Reusable 4's navy read as dark shapes on orange sand | [Before/after, top row](../render_captures/rts_mission_1/before_after.png) |
| Seam-free sand lighting (`smooth_wind`) | The old wind lighting left long straight light seams across open sand | [Before/after, middle row](../render_captures/rts_mission_1/before_after.png) |
| HQ joined to the road with a short driveway instead of a loose oval of paving | The oval read as a puddle of road | [Before/after, bottom row](../render_captures/rts_mission_1/before_after.png) |
| **Carbon's own painted cliff oasis is back in the northeast**, in its original spot | It is the best oasis painting we have; Reusable 4 had swapped it for the modular spring | [Northeast view](../render_captures/rts_mission_1/02_sheltered_spring_hd.png) |
| The kit's modular sheltered spring got a ring of scrub and reeds at the waterline | It had lost the greenery Carbon's spring has. It stays in the kit for other maps | Kit page 1 |
| HUD text drawn with MSDF fonts (project setting) | The HUD draws small text and then scales it up, which blurred it. MSDF letters stay sharp at any scale | [HUD prompts](../assets/source_inputs/hud/PROMPTS.md) |
| Camera views are markers in the scene (`CameraViews`) | Each new map sets its own 1–9 views without code | — |
| Captures at **1920 × 1080** fullscreen | Carbon's Detailed art is painted for 1080p. At 1376 × 768 we judged everything smaller than players see it | All PNGs and the clip measure 1920 × 1080 |

**HQ at Carbon's camera angle.** The owner's repaint (`assets/source_inputs/desert_kit/blue_field_hq_steep.png`) is installed with `make_desert_kit_hq.py`. It now matches the outpost's near-overhead view, with the roof filling the footprint and the banner on the front edge. [HQ and squad](../render_captures/rts_mission_1/04_blue_headquarters_and_squad_hd.png)

## Planet skins (P)

**P** switches the whole map between **Desert** (Carbon) and **Miasaki** (pale peach sand, lavender-shadowed rock). Only the terrain art and the minimap colours change. The layout, blocked ground, units, water, plants and the HQ stay the same. To start on Miasaki, run with `-- --skin=miasaki`.

- Miasaki's own repaints of Carbon's rocks, cliff oasis, crystal outcrop, plaza, outpost, dunes, scrub, sand and road come from `assets/textures/rts/carbon_miasaki/`.
- Kit pieces Miasaki never painted (road joins, banks, cliff pieces, pebbles, crystal rock) are recoloured by `tools/python/make_planet_skin_miasaki.py`. It learns Miasaki's palette from the matched Carbon/Miasaki pairs ([palette transfer](GLOSSARY.md#palette-transfer)) and writes `assets/textures/rts/skins/miasaki/`.
- To add a planet, put its paintings in a new folder under `assets/textures/rts/skins/` (named like the kit's, `<piece>_hd.png`) and add a name and path to `skin_names` / `skin_paths` on the Mission scene's root.
- The Pixel view keeps the desert art on every skin, because Miasaki has no Pixel paintings yet.

[Miasaki opening](../render_captures/rts_mission_1/06_miasaki_opening_hd.png) · [Miasaki northeast](../render_captures/rts_mission_1/06b_miasaki_northeast_hd.png) · [Miasaki roadside pool](../render_captures/rts_mission_1/06c_miasaki_roadside_pool_hd.png) · [palette transfer sheet](../render_captures/rts_mission_1/miasaki_skin_sheet.png)

## Sand hills: units go up and down

From Desert Crossing's painted swells, the kit now has `sand_hill` (the "small sand mountain"), `dune_swells` and `ripple_field`. `tools/python/make_desert_kit_hills.py` stores only their light and shade, so they take on whatever sand and planet skin they sit on, and tank treads flatten them like the other dunes. One sand hill replaces the west dune shoulder in this map.

Units no longer move flat over them:
- **They rise with the ground.** A unit is drawn higher by height² × `unit_lift_px` (4.5), so about 26 px on the hill's summit, about 4 px on a normal dune and nothing on flat sand. Clicking selects the raised figure.
- **Slopes light them.** On the slope facing the upper-left sun, units brighten by up to 14 %. On the far side they darken by the same amount.
- **Uphill is slower**, as before (Carbon's slope stride).

`unit_lift_px` and `slope_light` on the scene root tune both; 0 turns them off. Each piece's `relief_height`, `relief_radii` and `relief_offset` (the summit) shape its hill. [Crossing stills](../render_captures/rts_mission_1/sand_hill_crossing.png) · [8 s clip](../render_captures/rts_mission_1/sand_hill_crossing.mp4)

## HUD styles (U)

**U** cycles four HUDs. **Mockup E** is the default: your `hud_E_classic.png` itself. `tools/python/make_hud_mockup_e.py` cuts its painted frame, buttons, labels and commander portrait into `assets/textures/ui/hud_mockup_e/` and paints out only what changes; the game draws names, health, stats, Mend, counters, the hold bar and state, the minimap and the V/Z/G/U toggles live with sharp fonts. The mockup is 1672 px wide, so its painted parts show at 1.15× on a 1080p screen; a clean high-resolution repaint of the frame would sharpen them. Other units show their own portrait in the frame. [Mockup E](../render_captures/rts_mission_1/07_hud_mockup_e_hd.png)

The other three: Units stay the same size in all of them, because the camera keeps one scale.

- **Classic**, drawn in code after mockup E: a sandstone top bar with steel counters, plus a steel-and-bronze sidebar with the portrait card, Mend strip, 2×2 enamel command buttons, parchment objective and the minimap at the bottom, as in Dune II.
- **Holo**, from mockup B: no sidebar. Glass panels float over the battlefield: status strip and objective at the top, minimap bottom-left, unit card bottom-centre, commands bottom-right. You see more of the map.
- **Carbon**: the original placeholder, for comparison.

Both new HUDs are drawn by `scripts/rts_kit/rts_mission_hud.gd` with sharp [MSDF](GLOSSARY.md#msdf-font) system fonts (Bahnschrift for Classic, Segoe UI for Holo). The top toggles (V, Z, G, U), command buttons and minimap all take clicks. The Mend button and strip now show the Blue commander's Mend whatever is selected, because pressing Mend always uses her. Run with `-- --hud=holo` to start on Holo. [Classic](../render_captures/rts_mission_1/07_hud_classic_hd.png) · [Holo](../render_captures/rts_mission_1/07_hud_holo_hd.png) · [Carbon](../render_captures/rts_mission_1/07_hud_placeholder_hd.png) · mockups in `assets/source_inputs/hud/`

## Make and edit maps

**Where the art comes from.** 13 of the 33 pieces are original Carbon paintings: the central Orichalcum outcrop and plaza, every rock and ridge, the cliff oasis, the three dune clusters, the outpost and the scrub. The sand, road and tanks are Carbon's too. Reusable 4's art is used only where Carbon had nothing: the newer dune shapes, the modular oasis parts, the tree, the HQ, the small crystal deposits, road joins and pebbles, plus the infantry (for readability). The **carbon-art** tag in the Kit Palette lists Carbon's paintings.

**Kit Palette (in the Godot editor).** A dock next to FileSystem shows every piece and group as a thumbnail over sand. Click tag buttons (rock, dune, water, plants, building, crystal, road, group, carbon-art…) to filter, or type in the search box. Drag a thumbnail onto the 2D view to place it under the selected node. Double-click to open the piece's own scene. Tags are stored on each piece scene (Inspector → Metadata → `tags`); press **Reload** after changing them. If the dock doesn't appear, use **Project → Reload Current Project**, or turn on **Kit Palette** in **Project Settings → Plugins**. In the editor the pieces now draw with their real art, and dunes show as lit sand.

`builds/rts_reusable_2_carbon_pieces/` is only an exported copy of `assets/textures/rts/carbon/` (byte-identical). The game doesn't use it, and `builds/` is now excluded from the export.

**The kit** lives in `scenes/rts/desert_kit/`:

- `pieces/`: one scene per painted piece (33 so far: rocks, cliffs, dunes, water, banks, reeds, the tree, scrub, buildings, the crystal parts, road joins and ends, pebbles). Each one carries its Detailed and Pixel art, its [blocked footprint](GLOSSARY.md#blocked-footprint), shadow, lee shade and dune height.
- `groups/`: [editable groups](GLOSSARY.md#editable-group) built from those pieces: `sheltered_spring`, `roadside_pool`, `orichalcum_wide`, `orichalcum_tall`.
- `kit_preview.tscn`: the **RTS Desert Kit** card. Page 1 shows the groups; page 2 (key **2**) shows every piece with its file name. Page 2 reads the `pieces/` folder when it opens, so a new piece appears there on its own.

Art is in `assets/textures/rts/desert_kit/`. Pieces with no kit painting use original Carbon's art in `assets/textures/rts/carbon/`.

**Move something.** Open `scenes/maps/rts_mission_1_desert.tscn`, select the piece under `YSortWorld`, `Dunes` or `GroundDecals`, and drag it. Its blocked ground moves with it. Units walk where the painting says they can. Press F1 in play to check.

**Add something.** Drag a scene from `scenes/rts/desert_kit/pieces/` (or `groups/`) onto `YSortWorld` for upright things (rocks, trees, buildings), `Dunes` for dunes, or `GroundDecals` for flat things (pebbles, road patches). Water and banks inside groups already have the right layering.

**Bend a road.** Drag the points of `RoadNetwork/MainRoad`, `RoadsideSpur` or `HQDriveway`. Any `Line2D` under `RoadNetwork` is drawn as road and counts as calm ground. The spur's fade and end cap follow its last point.

**Change a piece everywhere.** Open the piece's own scene in `pieces/` and edit it: footprint, size, shadow. Every placement updates. To change one placement only, edit it in the map. Godot stores just that difference.

**Make a new map.** Duplicate `rts_mission_1_desert.tscn`, rearrange pieces, move the `CameraViews` markers (first marker = opening view) and the units, then add a Play card for it.

## Checks

| Check | Result |
| --- | --- |
| `tests/test_rts_mission_1_desert.gd` headless: kit integrity, kit-only placements, blocked ground, passage close/reopen, tank tracks, Red tank through the passage, tree fade, Mend, reset, Developers Page cards and Esc | All passed |
| Same test, Forward+ fullscreen `--capture --compare --record` | All passed; stills and frames measure 1920 × 1080 |
| Same test against the exported build (`--main-pack builds/Balance.exe`), headless and in a fullscreen window | All passed; both new cards launch and Esc returns |
| `test_rts_test_map.gd`, `test_rts_reusable_2_carbon.gd` (and `--miasaki`), `test_rts_reusable_3.gd`, `test_rts_reusable_4.gd` | All passed, so the older builds are unchanged |
| `test_rts_mission_1_desert.gd` in a window: for each HUD style, same battlefield scale, Attack click arms an attack, minimap click pans, battlefield centre stays clickable; planet skin swaps art without changing blocked ground, then restores it | All passed, also against the exported build |
| `tests/capture_kit_palette.gd` (windowed): the Kit Palette loads all 37 entries with thumbnails, filters by tag and hands the 2D view a scene file to drop | Passed. Dropping into the real editor still needs a manual check |

Captures: [opening](../render_captures/rts_mission_1/01_opening_command_hd.png) · [opening Pixel](../render_captures/rts_mission_1/01_opening_command_pixel.png) · [spring](../render_captures/rts_mission_1/02_sheltered_spring_hd.png) · [roadside pool](../render_captures/rts_mission_1/03_roadside_pool_and_fork_hd.png) · [HQ and squad](../render_captures/rts_mission_1/04_blue_headquarters_and_squad_hd.png) · [tracks](../render_captures/rts_mission_1/05_forked_dune_treads_hd.png) · [kit page 1](../render_captures/rts_mission_1/kit_1_arrangements_hd.png) · [kit page 2](../render_captures/rts_mission_1/kit_2_pieces_hd.png) · [12 s clip](../render_captures/rts_mission_1/mission_1_in_motion.mp4)

Art approval stays with the owner.

### Reproduce

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
C:/Python312/python.exe tools/python/make_desert_kit_units.py
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_mission_1_desert.gd
& $godot --path . --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1_desert.gd -- --capture --compare --record
C:/ffmpeg/bin/ffmpeg.exe -y -framerate 30 -i 'tmp/rts_mission_1/frames/%05d.jpg' -frames:v 360 -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart 'render_captures/rts_mission_1/mission_1_in_motion.mp4'
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack builds/Balance.exe --script res://tests/test_rts_mission_1_desert.gd
& $godot --main-pack builds/Balance.exe --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1_desert.gd
```

`tools/godot/bootstrap_desert_kit.gd` made the kit and the first Mission 1 layout from Reusable 4 and Carbon. It was a one-time step. Rerunning it with `-- --force` overwrites the hand edits above.
