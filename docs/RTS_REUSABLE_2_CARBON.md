# RTS Reusable 2 Carbon

Open **Developers Page → Desert RTS builds → RTS Reusable 2 Carbon → Play**.

This study builds a `44 × 28` cell (`1408 × 896` logical unit) playable Mission 1 desert stretch entirely from **reusable ChatGPT painted landmarks and pieces** placed over continuous wind-swelled desert sand, framed inside the **Dune II HUD** (`docs/references/rts_mission1_hud_goal.webp`). Both **Detailed Painted (`2×` HD)** and **`960 × 540` Dune II Pixel (`1×`)** share identical coordinates, collision footprints, dune elevation, lee shade, unit state, and live compressed tank tracks.

## Assessment · 26 November 2026

The owner chose this original Carbon build as the model for the RTS. I agree. A player can read the road, find the gold outcrop, send a tank across the dunes and recognise where it went from the tracks alone. That relationship between the painting and the player's orders is the part worth carrying into every map.

| Keep | Improve next |
| --- | --- |
| The pale road leads the eye from Blue to the gold plaza. The dark rock gives the crystal a strong silhouette. The turquoise spring makes the northeast easy to recognise after panning. | At Command zoom the crystal is easier to find than the commander. Red infantry also fade into the orange sand. Try a larger patch of faction colour on the shoulders and a light scarf on the commander. Compare the same fight with selection brackets off. |
| The squad can lose and recover individual figures. Mend gives Blue a reason to pull wounded troops back together. The tank leaves two tracks through the dune and the squad darkens beside the boulders. | The bright dune crests repeat and the northeast outpost ends in a sharp square against bare sand. Try a quieter dune edge and a little sand over the pad corners. Judge both changes at Command zoom with troops moving past. |
| The minimap accepts orders. The unit portrait, health and four command buttons give the sidebar a clear job. | The capture boundary is faint and the result lives in small text below the progress bar. Show who holds the plaza beside the rock and give victory or defeat a clear ending. Mend also looks unavailable with only a tank selected, yet pressing it still calls the ready Blue commander. Make its appearance and action agree. |

### What happened in play

The original scene passed its existing Godot checks both headless and in Forward+. I inspected all ten frames covering the opening, Close view, tracks, oasis and fight. The capture command requested 1376 × 768 and the saved viewport images measured 1365 × 768. [Opening](../render_captures/rts_carbon/01_opening_command_21x14_hd.png) · [Tank crossing](../render_captures/rts_carbon/03_dune_treads_and_lee_shade_hd.png) · [Fight at the plaza](../render_captures/rts_carbon/05_orichalcum_combat_and_mend_hd.png)

In four additional scripted openings I started from the normal spawns, used the same random seed (1626) and let the units fight normally. The Blue order was a single group move with all five forces to the west edge of the plaza at (540, 458). Times are simulated seconds.

| Red setting | Blue stands still | Blue advances once |
| --- | --- | --- |
| Guard, the default | Plaza still empty at 90 seconds | Blue wins by holding at 31.6 seconds |
| Active | Red wins by holding at 31.6 seconds | Blue eliminates Red at 20.3 seconds |

Guard works for inspecting art. The same single order wins both encounters, even without choosing a target, retreating or casting Mend. That is a reason to tune the opening before adding armies or growing the map. These four openings establish repeatable examples. Judging difficulty and enjoyment still needs people playing.

### Proposed order of work

1. **Make the first fight worth commanding.** Build the next encounter from original Carbon. Give the player a brief introduction, then send an opponent to contest the plaza. Use the current three squads, tank and commander per side for the first comparison. Replay the single group order, a split approach and a withdrawal to Mend. Tune arrivals and report losses until at least one deliberate choice changes who survives or who holds the rock.
2. **Make battlefield decisions readable.** Test the small uniform changes, a clearer capture boundary, and an unmistakable change when the enemy steps inside. Put the art and opponent test switches in the study controls. Ask a fresh player to find the commander, identify a wounded squad and say who holds the rock at Command zoom without pausing.
3. **Finish one mission from briefing through replay.** Give the player a clear result, its cause and a retry. Check both sides winning by hold and by elimination, an interrupted hold, Mend from the sidebar, and a clean second game. Time a fresh player's first attempt and record the first confusing moment.
4. **Carry the proven encounter into both campaigns.** Use the same starts, routes and capture rules for player-controlled Red in the desert and player-controlled Blue in the tropical forest. Reuse the forest studies for scenery. In both settings check that soldiers stay visible and the tank can reach the same approaches from a minimap order. Settle the campaign troop mix and Red commander's role in play.

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
