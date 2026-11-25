# RTS Reusable 2 Carbon

Open **Developers Page → Desert RTS builds → RTS Reusable 2 Carbon → Play** (or click **Play** on the opening screen).

This study builds a `44 × 28` cell (`1408 × 896` logical unit) playable Mission 1 desert stretch entirely from **reusable ChatGPT painted landmarks and pieces** placed over continuous wind-swelled desert sand, framed inside the **Dune II HUD** (`docs/references/rts_mission1_hud_goal.webp`). Both **Detailed Painted (`2×` HD)** and **`960 × 540` Dune II Pixel (`1×`)** share identical coordinates, collision footprints, dune elevation, lee shade, unit state, and live compressed tank tracks.

## Controls & One-Minute Playtest

- **Left-click / Shift-click / Drag box**: Select Blue Commander, 4-soldier Rifle Squads, and Vanguard Tank.
- **Right-click ground or enemy**: Smooth string-pulled move or attack order (also works directly on the **Minimap**).
- **`V` (or top-bar button)**: Instant live switch between **Detailed Painted (`2×` HD)** and **`960 × 540` Pixel**.
- **`Z` (or top-bar button)**: Switch between **Command Framing (`~21 × 14` playable cells)** and **Close Tactical Framing (`~15 × 10` playable cells)**. Mouse wheel zooms freely.
- **`E` (or HUD `Mend` button)**: Cast Blue Commander's **Mend** ability (`+30 HP` within `3.75` cells, restoring wounded 4-man squads back up to `4 of 4 fit`).
- **`T` (or HUD `Hold` button)** / **`S`**: Toggle Hold Position / Stop.
- **`G` (or top-bar button)**: Switch Red forces between **Defensive Guard** (for repeatable movement/dune/shade tests) and **Active Skirmish AI** (Red advances to contest the Orichalcum rock).
- **`H`**: Show / hide the Dune II HUD frame. **`1` / `2` / `3`**: Jump camera to Encounter, Northeast Cliff Oasis & Outpost, or Southeast Red Approach. **`R`**: Reset encounter. **`F1`**: Show `32 px` grid & blocked cells. **`Esc`**: Return to Developers Page.

### Repeatable Ground-Interaction Route
1. Select the lower **Blue Rifle Squad** on calm sand and right-click just south-east of the weathered three-boulder cluster (`SouthPassBoulders`). Watch the four soldiers climb the golden dune ripples (`DuneWestApproach`) with a subtly tighter uphill stride and darken cleanly inside the boulders' cool lee shadow.
2. Select the **Blue Vanguard Tank** on the limestone road and drive it across `DuneWestApproach`. Watch its hull curve smoothly off the flagstones and carve **two compressed dark lanes** straight through the sunlit dune crests.
3. Press **`V`** and **`Z`** mid-drive and mid-fight around the central **Orichalcum Outcrop** (`Hold 0:30` control ring) to compare Detailed Painted vs `960 × 540` Pixel at both zoom stops.

## Matched Forward+ Captures (`1376 × 768`)

| View | Detailed Painted (`2×` HD) | `960 × 540` Pixel (`1×`) |
| --- | --- | --- |
| Opening · Command (`21 × 14` cells) | `render_captures/rts_carbon/01_opening_command_21x14_hd.png` | `render_captures/rts_carbon/01_opening_command_21x14_pixel.png` |
| Opening · Close (`15 × 10` cells) | `render_captures/rts_carbon/02_opening_close_15x10_hd.png` | `render_captures/rts_carbon/02_opening_close_15x10_pixel.png` |
| Dune Treads & Lee Shade | `render_captures/rts_carbon/03_dune_treads_and_lee_shade_hd.png` | `render_captures/rts_carbon/03_dune_treads_and_lee_shade_pixel.png` |
| NE Cliff Oasis & Stone Outpost | `render_captures/rts_carbon/04_northeast_oasis_and_outpost_hd.png` | `render_captures/rts_carbon/04_northeast_oasis_and_outpost_pixel.png` |
| Orichalcum Combat & Mend | `render_captures/rts_carbon/05_orichalcum_combat_and_mend_hd.png` | `render_captures/rts_carbon/05_orichalcum_combat_and_mend_pixel.png` |

## Reproduce

```powershell
C:/Python312/python.exe tools/python/make_rts_reusable_2_carbon.py
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_reusable_2_carbon.gd
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_reusable_2_carbon.gd -- --capture
```
