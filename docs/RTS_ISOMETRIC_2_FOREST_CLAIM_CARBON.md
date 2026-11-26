# RTS Isometric 2— Forest Claim Carbon

Open **Developers Page → Forest RTS builds → RTS Isometric 2— Forest Claim Carbon → Play** (or launch `RTS Isometric 2— Forest Claim Carbon (Layout B)` directly from the same section).

This study brings the hand-painted look, warm upper-left sunlight, cool lavender-violet rock facets, and **`35.264°` orthographic true-isometric viewing angle** (`±30°` ground axes) of [2D Painted Forest Fight 4](FOREST_FIGHT_4.md) into a playable Mission 1 (*The First Claim*) RTS battlefield set in Blue’s tropical forest—built **100% from a modular, data-driven terrain and scenery kit** with zero whole-map backdrop paintings or hand-painted navigation masks.

## Controls & One-Minute Playtest

- **Left-click / Shift-click / Screen marquee box**: Select Blue Commander, 4-soldier Rifle Squads, and Vanguard Tank.
- **Right-click ground or enemy (or right-click the isometric Minimap)**: Smooth string-pulled move or attack order.
- **`L` (or top-bar `[L] Layout A / B` pill)**: Instant live swap between **Layout A (*Shelf Clearing*)** and **Layout B (*Shifted Bluff & Woodland Flank*)** using the exact same art kit.
- **`Z` (or top-bar `[Z]` pill) / Mouse wheel**: Switch between **Command Zoom (`1.0×`)** and **Close Inspection Zoom (`1.55×`)**. Apparent unit size stays identical at near and far edges of the screen.
- **`E` (or HUD `Mend` button)**: Cast Blue Commander’s **Mend** (`+30 HP` within `3.75` cells, restoring wounded squads back toward `4 of 4 fit`).
- **`T` (or HUD `Hold`) / `X`**: Toggle Hold Position / Stop.
- **`G` (or top-bar `[G]` pill)**: Toggle Red between **Defensive Guard** and **Active Skirmish AI**.
- **`H`**: Toggle Dune II HUD. **`1` / `2` / `3`**: Jump camera to Clearing, North Woodland Flank, or East Hillside. **`F1`**: Show isometric `32-unit` logical grid, blocked footprints, and unit tile claims. **`F2`**: Show module bounds, anchors, and piece IDs. **`R`**: Reset layout. **`Esc`**: Return to Developers Page.

## Editable Layout Files (Move Pieces Yourself)

Both layouts share the exact same `.png` textures in [`assets/textures/rts/forest_carbon/`](../assets/textures/rts/forest_carbon/) and [`kit_catalog.json`](../assets/textures/rts/forest_carbon/kit_catalog.json). Changing terrain characters (`.` = misty abyss, `F` = forest turf, `M` = moss verge, `O` = sunlit ochre clearing, `T` = worn trail) or `placements` cells automatically updates the ground shader, foreground valley mist, `AStarGrid2D` walkability, canopy shade, and isometric minimap:

- **Layout A (*Sunlit Shelf Clearing*)**: [`scenes/rts_iso_carbon/layout_a_shelf_clearing.tres`](../scenes/rts_iso_carbon/layout_a_shelf_clearing.tres) (launched by [`scenes/maps/rts_isometric_2_forest_claim_carbon.tscn`](../scenes/maps/rts_isometric_2_forest_claim_carbon.tscn))
- **Layout B (*Shifted Bluff & Woodland Flank*)**: [`scenes/rts_iso_carbon/layout_b_split_bluff.tres`](../scenes/rts_iso_carbon/layout_b_split_bluff.tres) (launched by [`scenes/maps/rts_isometric_2_forest_claim_carbon_layout_b.tscn`](../scenes/maps/rts_isometric_2_forest_claim_carbon_layout_b.tscn) or `L` in-game)
- **Layout generator**: [`tools/python/build_rts_iso_forest_layouts.py`](../tools/python/build_rts_iso_forest_layouts.py)
- **Source sheets & prompts**: [`assets/source_inputs/rts_forest_carbon/PROMPTS.md`](../assets/source_inputs/rts_forest_carbon/PROMPTS.md)

## Forward+ Evidence (`1376 × 768`)

- **Command View beside Fight 4 + Close Canopy/Cliff View**: [`render_captures/rts_iso_forest_carbon/handoff_01_command_vs_fight4_and_close.png`](../render_captures/rts_iso_forest_carbon/handoff_01_command_vs_fight4_and_close.png)
- **Layouts A & B Side-by-Side Modularity & Tank Reroute**: [`render_captures/rts_iso_forest_carbon/handoff_02_layouts_a_and_b_modularity.png`](../render_captures/rts_iso_forest_carbon/handoff_02_layouts_a_and_b_modularity.png)
- **Live Gameplay Clip (`11.0 s`, `30 fps`)**: [`render_captures/rts_iso_forest_carbon/forest_claim_carbon_playtest.mp4`](../render_captures/rts_iso_forest_carbon/forest_claim_carbon_playtest.mp4)
- **Individual Stills & Footprint Overlays**: [`01_layout_a_command_hud.png`](../render_captures/rts_iso_forest_carbon/01_layout_a_command_hud.png) · [`02_layout_a_close_squad_tree_cliff.png`](../render_captures/rts_iso_forest_carbon/02_layout_a_close_squad_tree_cliff.png) · [`03_layout_a_footprints_and_pieces.png`](../render_captures/rts_iso_forest_carbon/03_layout_a_footprints_and_pieces.png) · [`04_layout_b_command_hud.png`](../render_captures/rts_iso_forest_carbon/04_layout_b_command_hud.png) · [`05_layout_b_footprints_and_pieces.png`](../render_captures/rts_iso_forest_carbon/05_layout_b_footprints_and_pieces.png)

## Honest Assessment: Where Modular Joins & Repeated Silhouettes Still Show

1. **Foreground shelf drop-off rims (`shelf_rim_u` and `shelf_rim_v`)**: Along the straight `24-cell` SW and SE cliff rims, repeating a single `-30°` and single `+30°` rim module 5 times creates a subtle rhythm in the hanging vine tendrils and jagged lower cliff teeth when inspected closely. Adding a second `B` variant per straight rim (without long vines) would break that cadence completely.
2. **Raised cliff bluff seams (`cliff_bluff_v` into `cliff_inner_corner` in Layout B)**: At Close zoom (`1.55×`), where a straight cliff top rim overlaps into the inner elbow or tapered end-cap, the lit moss cap steps slightly in brightness where one stone block ends and the next begins. Placing `boulder_moss_pair` or `undergrowth_fern` at the foot hides the lower seam well, while the top moss rim join remains mildly visible up close.
3. **Medium border trees (`tree_canopy_warm` and `tree_canopy_cool`)**: Having one giant hero tree plus two medium silhouettes works cleanly across one screen, though the recessed misty lower-valley crowns reuse `tree_canopy_cool_crown` (mirrored and mist-tinted). One dedicated wide multi-crown forest border cluster would reduce repetition along larger maps.

## Reproduce & Verify

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
C:/Python312/python.exe tools/python/make_rts_iso_forest_carbon.py
C:/Python312/python.exe tools/python/build_rts_iso_forest_layouts.py
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_test_map.gd
& $godot --headless --path . --script res://tests/test_rts_reusable_2_carbon.gd
& $godot --headless --path . --script res://tests/test_rts_iso_forest_carbon.gd
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_iso_forest_carbon.gd -- --stills
C:/Python312/python.exe tools/python/make_rts_iso_handoff_sheets.py
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_iso_forest_carbon.gd -- --clip
C:/ffmpeg/bin/ffmpeg.exe -y -framerate 30 -i 'tmp/rts_iso_forest_carbon/frames/%05d.jpg' -frames:v 330 -vf 'pad=1376:768:(ow-iw)/2:0:color=black' -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart 'render_captures/rts_iso_forest_carbon/forest_claim_carbon_playtest.mp4'
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack 'builds/Balance.exe' --script res://tests/test_rts_iso_forest_carbon.gd -- --catalog
```
