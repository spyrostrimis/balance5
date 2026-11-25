# RTS Isometric — Forest Claim

Open **Developers Page → Forest RTS builds** in [Balance.exe](../builds/Balance.exe). **RTS Isometric — Forest Claim** opens A, and **RTS Isometric — Forest Claim · Layout B** opens B. Both sides field a commander, a four-person squad and a tank. Red advances on the Orichalcum field. Hold it uncontested for 30 seconds or eliminate Red.

Click or box-select Blue. Right-click ground to move or a Red unit to attack. Left-click the [minimap](GLOSSARY.md#minimap) to pan and right-click it to move. Use the arrows or middle drag to pan, wheel or **Z** to zoom, **E** to Mend, **T** to hold, **S** to stop, **R** to restart and **Esc** to return. A cross marks an order on a visible cliff face or outside the playable shelf. An order close to a blocked edge moves to the centre of the clicked cell if the unit needs more clearance.

## Review at command zoom

The two forces face each other across a warm clearing. The amber outcrop reads against the shaded forest, and the rooted tree and boulder frame Blue's entrance. In the matched close capture, four soldiers pass the foot of the large tree. A tree draws from its ground contact, and its canopy fades while it covers selected troops. Their selection chevron stays above the foliage. [Forest Claim beside the original Fight 4 gameplay](../render_captures/forest_claim/command_vs_fight4.jpg) · [Close squad pass](../render_captures/forest_claim/a_close.png) · [Nine-second gameplay clip](../render_captures/forest_claim/gameplay.mp4)

The long front rim still shows regular stair steps and repeated vertical stone streaks. The repeating broad crowns are easiest to spot along the foreground treeline and in the mist below the shelf. On A, the high route reads less clearly than the sunlit low road when seen at command zoom. The owner's choice about the look remains open.

## Move the pieces

Both Play scenes use the same battlefield scene, art and [terrain modules](GLOSSARY.md#terrain-module). Edit A and B in their own [layout resources](GLOSSARY.md#resource).

| Layout | Edit | Verified tank route |
| --- | --- | --- |
| A · Sunlit Shelf | [layout_a.tres](../scenes/rts/forest_claim/layout_a.tres) | South through row 13. The infantry can take a separate path over the north end. |
| B · High Flank | [layout_b.tres](../scenes/rts/forest_claim/layout_b.tres) | North through row 10. The moved ridge joins the foreground drop and closes the southern passage. |

Rows count from zero. In the terrain rows, `.` is ochre earth, `m` is forest floor, `#` is a raised cliff and `~` is ravine. Adjacent height changes draw the wall and automatically join the straight faces, inside and outside turns, and ends. In the scenery array, change `at` to move a piece in cells and `scale` to resize its painting. Half values such as `8.5` lie at cell centres. Each piece owns its sprite pivot and [blocked footprint](GLOSSARY.md#blocked-footprint). Terrain and these placements determine where units can walk and what the minimap shows. [Shared definitions](../scripts/rts_forest_claim/forest_claim_kit.gd)

The leaning tree marked in the comparison moves from `(8.55, 8.8)` to `(8.55, 13.8)`. The cyan line records the live Blue tank in each layout. Both minimap orders landed at cell `(11, 10)`, inside the field on the far side of the rebuilt cliff. [Matched layouts and routes](../render_captures/forest_claim/layouts_and_tank_routes.jpg)

## Verification

Godot 4.7.2 Forward+ rendered the study at 1376 × 768. The focused suite checked the four view corners and ground beside a cliff at both zoom stops, constant apparent scale from near to far, box selection, move and attack, Hold and Stop, Mend and cooldown, canopy overlap, contested hold and both end conditions. It drove the tank from the minimap in both layouts and checked Play and Esc for both cards in the source project and the embedded Windows export. The six headless RTS suites and the windowed Carbon Miasaki suite passed. The older test-map capture harness also ran. Its scripted attack still printed MOVE while the headless test-map suite verified damage and elimination.

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . --headless --fixed-fps 60 --script res://tests/test_forest_claim.gd
& $godot --path . --resolution 1376x768 --fixed-fps 60 --script res://tests/capture_forest_claim.gd
& $godot --headless --path . --export-release 'Windows Desktop' 'builds/Balance.exe'
& $godot --headless --main-pack builds/Balance.exe --fixed-fps 60 --script res://tests/test_forest_claim.gd
```

Capture frames are written to `tmp/forest_claim_clip` for encoding at 60 fps. Stills and recorded route points are under `render_captures/forest_claim`. The reference is the original Fight 4 gameplay capture from its documented Forward+ scene. The art uses two built-in ImageGen sheets and the Carbon unit and portrait art. [Art sources and prompts](../assets/source_inputs/forest_claim/IMAGEGEN_PROMPTS.md) · [Fight 4 capture instructions](FOREST_FIGHT_4.md)
