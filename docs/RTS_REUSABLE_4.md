# RTS Reusable 4

Open [Balance.exe](../builds/Balance.exe) and click **Developers Page → Desert RTS builds → RTS Reusable 4 → Play** (or press the main **Play** button on the opening screen, which selects the newest listed build). The original **RTS Reusable 2 Carbon** card stays in the same section for direct comparison. Open **RTS Reusable 4 — Desert Kit → View** to inspect both editable oasis arrangements and both modular Orichalcum crystal deposits side by side at Command scale (`V` switches Detailed and Pixel; `Esc` returns).

![Matched Command-zoom unit comparison](../render_captures/rts_reusable_4/matched_unit_comparison.png)

## Controls & Camera Jumps

- **Left-click / Shift-click / Drag box**: Select Blue Commander, 4-soldier Rifle Squads, and Vanguard Tank.
- **Right-click ground or enemy (or right-click the Minimap)**: Smooth move or attack order.
- **`1` / `2` / `3` / `4`**: Jump camera to **1** Opening & Blue Headquarters, **2** Northeast Sheltered Spring & Outpost, **3** Southeast Roadside Pool, Road Fork & Tank Passage, or **4** Southwest Forked Dune Field.
- **`V`**: Live switch between **Detailed Painted (`2×` HD)** and **`960 × 540` Pixel (`1×`)**.
- **`Z`**: Switch between **Command (`21 × 14` cells)** and **Close (`15 × 10` cells)** zoom.
- **`E`** (or HUD `Mend`): Blue Commander’s **Mend** (`+30 HP`, restoring wounded squads back up to `4 of 4`).
- **`G`**: Toggle Red between **Guard** (default for art/route inspection) and **Active** skirmish AI.
- **`F1`**: Show `32 px` grid and blocked ground cells. **`R`**: Reset encounter. **`Esc`**: Return to Developers Page.

## Move Your First Oasis Piece

Open [`scenes/rts/reusable_4/roadside_pool.tscn`](../scenes/rts/reusable_4/roadside_pool.tscn) in Godot:

1. Select **`PassCliff`** in the Scene tree and drag it left or right with the Move tool (`W`). Its painted rock buttress and its [blocked footprint](GLOSSARY.md#blocked-footprint) move together.
2. In the published layout (`PassCliff` at `(-212, 8)`), two full `32 px` grid columns (`cx = 31..32`) stay clear between `PassCliff` and `Water`, letting a tank drive straight down the fading road spur through the passage. Sliding `PassCliff` `64` units right closes that lane completely.
3. Select **`Water`** and adjust **Transform → Scale** to reshape or stretch the pool; its visible shoreline and blocked deep-water polygon scale together. Move **`SandyBank`**, **`RockyBank`**, **`WestReeds`** or **`BankTree`** independently around the shore.
4. **`BankTree`** blocks only the single cell under its rooted trunk, while its overhanging crown fades smoothly (`alpha → 0.40`) with a tactical chevron above any selected squad walking beneath it.
5. [`scenes/rts/reusable_4/sheltered_spring.tscn`](../scenes/rts/reusable_4/sheltered_spring.tscn) builds the northeast cliff spring from the exact same water, sandy bank, rocky bank, cliff end, reeds, and freestanding tree pieces plus `MainCliffLedge`. Both oases are placed as [editable groups](GLOSSARY.md#editable-group) inside [`scenes/maps/rts_reusable_4.tscn`](../scenes/maps/rts_reusable_4.tscn).
6. Edit **`RoadNetwork/MainRoad`** or **`RoadNetwork/RoadsideSpur`** in [`scenes/maps/rts_reusable_4.tscn`](../scenes/maps/rts_reusable_4.tscn) by dragging `Line2D` point handles: `RoadForkJoin` follows the start of the spur, and both the sand-fade shader and `RoadSpurEndCap` follow its final segment automatically.

## Captures & Evidence (`1376 × 768` requested, `1365 × 768` saved Forward+ viewport)

| Check | Evidence |
| --- | --- |
| Matched unit comparison (pale road, 4-of-4 sand, wounded 3-of-4 sand, brackets off) | [Carbon vs Reusable 4](../render_captures/rts_reusable_4/matched_unit_comparison.png) · [3-step colour vs spacing](../render_captures/rts_reusable_4/uniforms_only_comparison.png) · [All 8 facings walking](../render_captures/rts_reusable_4/all_eight_facings.png) |
| Opening, Blue Field HQ & seamless plaza joins | [Opening Detailed HD](../render_captures/rts_reusable_4/01_opening_command_hd.png) · [Opening Pixel](../render_captures/rts_reusable_4/01_opening_command_pixel.png) · [Squad passing HQ & tank](../render_captures/rts_reusable_4/04_blue_headquarters_and_squad_hd.png) |
| Enriched sand & twin tank tracks across forked dune | [Tracks ON](../render_captures/rts_reusable_4/05a_forked_dune_treads_on_hd.png) · [Tracks OFF](../render_captures/rts_reusable_4/05b_forked_dune_treads_off_hd.png) |
| Reusable oases, road fork & passage clearance | [Sheltered spring](../render_captures/rts_reusable_4/02_sheltered_spring_hd.png) · [Roadside pool & fork](../render_captures/rts_reusable_4/03c_roadside_pool_and_fork_hd.png) · [Narrow passage blocked](../render_captures/rts_reusable_4/03a_roadside_passage_narrow_grid.png) · [Widened passage open](../render_captures/rts_reusable_4/03b_roadside_passage_open_grid.png) · [Close Pixel fork](../render_captures/rts_reusable_4/03d_roadside_fork_close_pixel.png) |
| Desert Kit preview (2 oases + low/wide & compact/tall Orichalcum) | [Kit Detailed HD](../render_captures/rts_reusable_4/desert_kit_command_hd.png) · [Kit Pixel](../render_captures/rts_reusable_4/desert_kit_command_pixel.png) |
| Moving sequence (`12.0 s`, `360` frames at `30 fps`, `1366 × 768`) | [reusable_4_in_motion.mp4](../render_captures/rts_reusable_4/reusable_4_in_motion.mp4) |
| Source paintings & ChatGPT prompts | [assets/source_inputs/rts_reusable_4/PROMPTS.md](../assets/source_inputs/rts_reusable_4/PROMPTS.md) |

## Reproduce

```powershell
$godot = "C:/Godot/Godot_v4.7.2-stable_win64_console.exe"
C:/Python312/python.exe tools/python/make_rts_reusable_4.py
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_test_map.gd
& $godot --headless --path . --script res://tests/test_rts_reusable_2_carbon.gd
& $godot --headless --path . --script res://tests/test_rts_reusable_4.gd
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/capture_rts_reusable_4_units.gd -- --original
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/capture_rts_reusable_4_units.gd -- --color-only
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/capture_rts_reusable_4_units.gd -- --facings
C:/Python312/python.exe tools/python/make_rts_reusable_4_comparisons.py
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_reusable_4.gd -- --capture --record
C:/ffmpeg/bin/ffmpeg.exe -y -framerate 30 -i "tmp/rts_reusable_4/frames/%05d.jpg" -frames:v 360 -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart "render_captures/rts_reusable_4/reusable_4_in_motion.mp4"
& $godot --headless --path . --export-release "Windows Desktop" "builds/Balance.exe"
& $godot --headless --main-pack builds/Balance.exe --script res://tests/test_rts_reusable_4.gd
& "builds/Balance.exe" --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_reusable_4.gd -- --catalog-window
```
