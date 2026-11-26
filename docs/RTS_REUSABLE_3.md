# RTS Reusable 3

Open [Balance.exe](../builds/Balance.exe) and choose **Developers Page → Desert RTS builds → RTS Reusable 3 → Play**. **2** jumps to the sheltered spring, **3** to the roadside pool, and **1** back to the opening. **V** switches Detailed and Pixel, **Z** switches Command and Close, **F1** shows blocked ground, and **Esc** returns to the Developers Page. The original Carbon card is in the same section. Open **RTS Reusable 3 — Desert Kit → View** for both oases and the two sample crystal deposits at Command scale.

![Carbon and Reusable 3 on road and sand](../render_captures/rts_reusable_3/matched_unit_comparison.png)

## Move your first oasis piece

Open [roadside_pool.tscn](../scenes/rts/reusable_3/roadside_pool.tscn) in Godot. Select **PassCliff** in the Scene tree and drag it left or right with the Move tool. Save the group and play Reusable 3. The painting and its blocked ground move together. The published lane is wide enough for the tank. Sliding the cliff 42 units to the right closes the straight lane through cell centre (1008, 816).

- **Water** can move or stretch using **Transform → Scale**. Scale moves the visible edge and its blocked ground together. Slide or stretch **SandyBank** and **RockyBank** to follow the shore. For a new edge drawn by hand, adjust the piece’s **Blocked Poly** points to match.
- **BankTree** can move separately. Its trunk owns the blocked ground and selected troops can show through the overhanging crown.
- [sheltered_spring.tscn](../scenes/rts/reusable_3/sheltered_spring.tscn) uses the same pool, bank, cliff end, reeds and tree paintings. Place either group under **YSortWorld** in a copy of [rts_reusable_3.tscn](../scenes/maps/rts_reusable_3.tscn) to lay out another desert map. Edit **RoadNetwork/MainRoad** or **RoadsideSpur** using the Line2D point handles. The spur’s fade follows its last segment.
- The [wide](../scenes/rts/reusable_3/orichalcum_wide.tscn) and [tall](../scenes/rts/reusable_3/orichalcum_tall.tscn) crystal groups share one bare rock base and loose gravel. The playable map uses the original Orichalcum outcrop as its sole objective.

## Captures and checks

| View | Evidence |
| --- | --- |
| Infantry on sand and pale road, no selection brackets | [Full Carbon frame](../render_captures/rts_reusable_3/carbon_command.png) · [Uniform colours only](../render_captures/rts_reusable_3/uniforms_only_comparison.png) · [Full Reusable 3 frame](../render_captures/rts_reusable_3/reusable_3_command.png) · [Eight directions with stride frames](../render_captures/rts_reusable_3/all_eight_facings.png) |
| Two dune fields and the tank’s twin tracks | [Long field](../render_captures/rts_reusable_3/long_dune_field.png) · [Tracks across the fork](../render_captures/rts_reusable_3/fork_dune_treads.png) · [Same view with tracks off](../render_captures/rts_reusable_3/fork_dune_treads_off.png) |
| Both oases and their ground clearance | [Sheltered spring](../render_captures/rts_reusable_3/sheltered_spring.png) · [Roadside pool and fork](../render_captures/rts_reusable_3/roadside_pool.png) · [Narrow passage grid](../render_captures/rts_reusable_3/roadside_narrow_grid.png) · [Open passage grid](../render_captures/rts_reusable_3/roadside_open_grid.png) |
| Headquarters and kit | [Headquarters](../render_captures/rts_reusable_3/blue_headquarters.png) · [Desert kit preview](../render_captures/rts_reusable_3/desert_kit.png) · [Close Pixel at the fork](../render_captures/rts_reusable_3/roadside_pixel_close.png) |
| Moving sequence | [12 seconds of Forward+ game frames](../render_captures/rts_reusable_3/reusable_3_in_motion.mp4) |

The first comparison used Carbon’s camera, unit size, placement and spacing and changed only the infantry and commander paint. Both factions stayed identifiable across all eight directions. Diagonal formations still packed closely, so the final build spreads the four figure positions by 18%. The formation still claims the same single tile. A wounded squad drops to three and the Blue commander’s Mend restores four. Encounter values and starting troops carry forward from original Carbon. Encounter balancing remains a separate experiment.

The window requested **1376 × 768** and the native Forward+ stills saved at **1365 × 768**. The MP4 has 361 game frames at 30 fps and one extra right-edge pixel for encoding. The tank drove the open oasis lane and both track bands visibly interrupted the forked dune. The source and embedded Windows export checks covered the new Play card, kit View card, original Carbon card and Esc returns. The final Windows executable also opened the Play card and returned to the Developers Page with Esc in the game window. Art approval remains open.

### Reproduce

```powershell
C:/Python312/python.exe tools/python/make_rts_reusable_3.py
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_reusable_3.gd
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/capture_rts_reusable_3_units.gd -- --original --facings
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/capture_rts_reusable_3_units.gd -- --color-only --facings
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/capture_rts_reusable_3_units.gd -- --facings
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_reusable_3.gd -- --capture --record
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack builds/Balance.exe --script res://tests/test_rts_reusable_3.gd
```
