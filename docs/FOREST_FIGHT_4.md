# 2D Painted Forest Fight 4

Open **Developers Page → Forest builds → 2D Painted Forest Fight 4 → Play** from Godot or `builds/Balance.exe`. Move with WASD or the arrow keys. Aim with the mouse and click or hold the left button to fire. Press R to restart and Esc to return to the Developers Page.

The trail and cave share one [isometric view](GLOSSARY.md#isometric-projection), walking surface, and Commander. The forest opening uses the owner's painting as its composition reference. The widescreen view keeps the cliff and mist under the path and introduces a conspicuous cave mouth in the upper right. That opening pulls the eye farther right than the reference's tighter composition.

The three bats circle, cue their dive and break away from contact with an armour spark. Their shadows mark the ground below them. One hit to the visible body brings a bat down during a low pass. Rock stops shots. After the third kill the player can walk back outside.

## Forward+ evidence

| Standing measurement | Crown to soles | Share of frame |
| --- | ---: | ---: |
| Near forest | 130 px | 16.93% |
| Far forest | 130 px | 16.93% |
| Cave | 130 px | 16.93% |

The three measurements use the east-facing standing pose at 1376 × 768. The test compares consecutive captures with and without the body drawing to isolate the crown and soles. The cave uses the same zoom as the opening. The evidence folder contains the [matched forest comparison](../render_captures/forest_fight_4/forest_vs_reference.png), [doorway overlap](../render_captures/forest_fight_4/doorway.png), [cave still](../render_captures/forest_fight_4/cave.png) and [uninterrupted clip](../render_captures/forest_fight_4/forest_fight_4.mp4). The clip runs 8.67 seconds at 30 fps and shows the diagonal shot outside, the matching shot inside and the three kills while strafing.

## Checks and reproduction

The Fight 4 suite verifies equal ground travel per tick, eight principal firing directions and two angles between them, continuity across pose changes, reversible doorway movement while firing, WASD and arrow input, the fence, lip and boulder passing in front, solid cliff and wall boundaries, a boulder stopping a shot, a clean miss, harmless bat contact, three one-shot kills, restart and catalog Play/Esc. The standalone Forest Walk, Forest Fight, Forest Fight 2, Approach 3 and RTS test-map suites passed. Fight 4's gameplay and catalog checks also ran from the embedded Windows export.

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . --headless --fixed-fps 60 --script res://tests/test_forest_fight_4.gd
& $godot --path . --max-fps 60 --script res://tests/test_forest_fight_4.gd -- --stills
& $godot --path . --max-fps 60 --script res://tests/capture_forest_fight_4.gd
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack builds/Balance.exe --fixed-fps 60 --script res://tests/test_forest_fight_4.gd
```

The recording harness writes numbered images under `tmp/forest_fight_4/clip/` and prints its frame count. Encode that many frames from the latest run at 30 fps. G toggles the development grid. F2 toggles the blockout. Both are hidden in the playable views and evidence.

## Art

The current environment and Commander art use the built-in ImageGen tool. The forest and cave keep their original landmarks where the path was traced, with registered paintings beyond the edges for camera travel. The tree, fence, cave lip and boulder use cutouts from their ground paintings. The Commander uses five painted poses mirrored to eight directions, with a separately pivoting rifle so the flash and bolt follow the pointer between poses. The bat wing cycle, rifle cutout and effects use Fight 2 art. [Source paintings and final prompts](../assets/source_inputs/forest_fight_4/IMAGEGEN_PROMPTS.md)

A separate local Fight 3 appeared during the work. Its staged entrance and poses with the rifle already painted into them were reviewed. Fight 4 uses its own connected floor and independently aimed rifle. The Windows delivery was exported from the Fight 4 commit with the released Forest Walk, Fight and Fight 2 cards.
