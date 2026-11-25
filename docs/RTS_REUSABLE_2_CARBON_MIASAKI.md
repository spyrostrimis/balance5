# RTS Reusable 2 Carbon — Miasaki

Open **Developers Page → Desert RTS builds → RTS Reusable 2 Carbon — Miasaki → Play**. The original Carbon card is in the same section. Press **2** for the northeast cliff, **Z** for Command or Close, **V** for the live Pixel comparison, and **Esc** to return to the list. All [Carbon controls](RTS_REUSABLE_2_CARBON.md#controls--one-minute-playtest) apply.

## Matched northeast frames

These are 1376 × 768 Forward+ captures from Carbon's key **2** camera position. The Blue tank is at (848, 380), with the four Red soldiers at their usual northeast spawn, in every frame.

| Zoom | Original Carbon | Miasaki |
| --- | --- | --- |
| Command | [Original](../render_captures/rts_carbon_miasaki/carbon_northeast_command.png) | [Miasaki](../render_captures/rts_carbon_miasaki/miasaki_northeast_command.png) |
| Close | [Original](../render_captures/rts_carbon_miasaki/carbon_northeast_close.png) | [Miasaki](../render_captures/rts_carbon_miasaki/miasaki_northeast_close.png) |

[Shared Pixel frame](../render_captures/rts_carbon_miasaki/miasaki_northeast_close_pixel.png) · [Cliff with the blocked tiles showing](../render_captures/rts_carbon_miasaki/miasaki_northeast_blocking.png) · [Opening with the Blue Commander and Orichalcum](../render_captures/rts_carbon_miasaki/miasaki_opening_command.png)

The spring is the closest match to the forest. Warm light catches the limestone rims, cool lavender-grey shadows separate the tiers and turquoise bounces onto the stone at the waterline. The open desert uses broader and quieter brushwork than the forest trail so the soldiers remain visible. At Command zoom all four Red heads and bodies are countable on peach sand. The dark cliff faces and rubble mark the main barrier, while Carbon's existing 32-pixel grid leaves some shallow water and loose rubble passable at the edge. Close zoom shows the paint strokes in the slabs and under the outpost roof. The pale scarf still identifies the Blue Commander in a squad-sized view, and the amber crystal is the strongest highlight at the centre.

The first northeast pass exposed straight seams in Carbon's sand lighting that the original grain had hidden. Miasaki's Detailed ground and dunes use the same continuous wind lighting, with lower contrast by the road and objective. The revised northeast frames were reviewed before the treatment went across the map.

## Playtest route

[20-second Forward+ recording](../render_captures/rts_carbon_miasaki/miasaki-playtest.mp4)

The Blue tank starts on the southeast road, crosses the east dune under a battlefield order, and turns north into cliff shade under a minimap order. The squad goes around the south side of the Orichalcum rock with all four soldiers fit. In both versions the tank reached (1224, 548) and then (1178, 231), the squad reached (776, 432), and two dark tracks cut through the bright crests with a clear gap between them. The tank's painted sprite darkens as it reaches the cliff. The tile grid, objective, minimap and layering come from the same Carbon scene.

## Build and verification

The standalone playable scene uses Carbon's battlefield and selects a Detailed art directory. The [runtime pieces](../assets/textures/rts/carbon_miasaki/) preserve the original sprite dimensions and transparency. The three mirrored rocks get their own paint so the light still comes from upper left. The infantry paint uses Carbon's existing poses and feet, and the tank hulls and turrets keep their centres across all eight headings. [ImageGen sources and prompts](../assets/source_inputs/rts_carbon_miasaki/PROMPTS.md)

The original and Miasaki Carbon regressions passed, including combat, squad casualties, Mend, the hold timer, slope and shade. The route gave identical destinations and track data in both scenes. The matched Pixel frames also matched pixel for pixel. Both Play cards, the loaded painted art, and Esc back to the Developers Page were verified in the project and against the game data embedded in the [Windows build](../builds/Balance.exe).

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
C:/Python312/python.exe tools/python/make_rts_carbon_miasaki.py
& $godot --headless --editor --import --path .
& $godot --headless --path . --script res://tests/test_rts_reusable_2_carbon.gd
& $godot --headless --path . --script res://tests/test_rts_reusable_2_carbon.gd -- --miasaki
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_carbon_miasaki.gd -- --review
& $godot --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_carbon_miasaki.gd -- --clip
C:/ffmpeg/bin/ffmpeg.exe -y -framerate 30 -i 'tmp/carbon_miasaki/frames/%05d.jpg' -frames:v 614 -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart 'render_captures/rts_carbon_miasaki/miasaki-playtest.mp4'
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack builds/Balance.exe --script res://tests/test_rts_carbon_miasaki.gd -- --catalog
```
