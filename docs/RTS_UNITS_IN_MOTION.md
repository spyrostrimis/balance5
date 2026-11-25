# RTS Units Test 2 — Units in Motion

Open **Developers Page → Desert RTS builds → RTS Units Test 2 — Units in Motion → Play**. Press **V** while the tank is moving to compare **Painted HD** and **Pixel art**. **Esc** returns to the catalog. The first **RTS Units Test — Units on the Map** is still playable from its own card. [Windows build](../builds/Balance.exe)

## One-minute route

1. Select the Blue tank on the road at the left. Shift-click the Blue squad farther right. Right-click the open sand northwest of Orichalcum, roughly one quarter across the screen and one fifth down. Press **V** mid-drive.
2. Right-click the sand just above the northwest cliff’s right shoulder, about 15% across and close to the top edge. The tank skirts the cliff shadow. Then right-click the shadow at the Orichalcum rock’s east edge. Watch the tank and its two tracks as the group rounds the outcrop.
3. Right-click the road just southeast of the shadow. Press **S** on the way, right-click the road again, then right-click the closest Red squad to attack. Rival units can enter range during the approach.

The comparison run kept the units peaceful until the explicit attack order so that the units would arrive in the same positions for both screenshots. The playable card uses the original automatic guard behaviour.

## Matched captures

| Landmark | Original | Painted HD | Pixel art | 640 × 360 proof |
| --- | --- | --- | --- | --- |
| Opening | [Frame](../render_captures/rts_units_v2/original-01-opening.png) | [Frame](../render_captures/rts_units_v2/hd-01-opening.png) | [Frame](../render_captures/rts_units_v2/pixel-01-opening.png) | [Frame](../render_captures/rts_units_v2/pixel-640-01-opening.png) |
| Open sand | [Frame](../render_captures/rts_units_v2/original-02-open-sand.png) | [Frame](../render_captures/rts_units_v2/hd-02-open-sand.png) | [Frame](../render_captures/rts_units_v2/pixel-02-open-sand.png) | |
| Northwest cliff | [Frame](../render_captures/rts_units_v2/original-02b-cliff-shadow.png) | [Frame](../render_captures/rts_units_v2/hd-02b-cliff-shadow.png) | [Frame](../render_captures/rts_units_v2/pixel-02b-cliff-shadow.png) | |
| Orichalcum shadow | [Frame](../render_captures/rts_units_v2/original-03-rock-shadow.png) | [Frame](../render_captures/rts_units_v2/hd-03-rock-shadow.png) | [Frame](../render_captures/rts_units_v2/pixel-03-rock-shadow.png) | [Frame](../render_captures/rts_units_v2/pixel-640-03-rock-shadow.png) |
| First damage | [Frame](../render_captures/rts_units_v2/original-04-attack.png) | [Frame](../render_captures/rts_units_v2/hd-04-attack.png) | [Frame](../render_captures/rts_units_v2/pixel-04-attack.png) | |

[Native-size unit crops](../render_captures/rts_units_v2/native-unit-crops.png) · [19-second real-time clip](../render_captures/rts_units_v2/units-in-motion.mp4) · [Original as it opens at 1376 × 768](../render_captures/rts_units_v2/00-original-default.png)

At 1080p, **960 × 540 Pixel art** gives the clearest command feedback. Brackets and health bars have firm edges, the squads still resolve into four bodies, and Red has brighter uniform pixels against the sand. **Painted HD** has the smoothest movement and the best separation of helmet, rifle, pale scarf and tank barrel. The fine grain in the sand and stone is more visible there, especially at zoom. Blue loses some contrast beside the dark outcrop in both looks.

The **640 × 360** picture enlarges exactly 3× at 1080p. The four-person group, tank silhouette, straight barrel and green selection and health marks survive. The scarf and some rifles become similarly bright or dark single pixels, and the front of the barrel is less consistent on a diagonal. At turns the walking drawings still snap to one of eight facings, so a planted boot can shift. Small heel lifts are clearest in HD. The tank turns progressively between facings, with a small change of silhouette when it changes the underlying drawing.

## Art and movement

- The Blue concept sheet came from the built-in image generation tool. Its three candidates were reduced to playing size on the sand, road and shadow patch in Godot before the project drew the Red variants. The shipped infantry uses the proof’s sampled blue armour and scarf colours in original projected poses. The tank keeps the eight-facing project chassis, with a redrawn cupola and barrel. The live pixel art uses the 48-colour desert palette and explicit pixels for team colour and projecting rifle tips. [Prompt](../assets/source_inputs/rts/units_motion/blue_proof.prompt.txt) · [In-game brief](../assets/source_inputs/rts/units_motion/in_game_brief.png) · [Original generated sheet](../assets/source_inputs/rts/units_motion/blue_proof.png) · [Playing-size generated candidate](../render_captures/rts_units_v2/proof-blue-generated.png)
- Style Test 5 still determines the landforms, road, cast shadows, scatter and collision. The detailed ground, road and rock layers add samples from the original sand, dune, road, rock, cliff-wall and crystal paintings at twice the density. The map keeps its calm area around the road and the walking grid remains 32 world pixels. [Asset generator](../tools/python/make_rts_units_motion.py) · [Desert and HUD references](RTS_ART_RULES.md)
- Each squad remains one orderable unit. The four soldiers use staggered footfalls. Each unit accrues stride distance only while moving. A route can cross several grid cells in a straight line. Small arcs round tank corners when there is room, and the unit reserves the cells it stands across as it travels. A narrow passage can still require a player to order one unit aside. [Movement script](../scripts/rts/rts_motion_unit.gd)

## Verification

- Godot 4.7.2 Forward+ rendered the original and successor at 1920 × 1080. The two successor looks shared position, selection, camera, orders and ground effects at each comparison. Battlefield pixels rendered in exact 2 × 2 and 3 × 3 blocks in the 1080p proofs. The 1280 × 720 and 1376 × 768 windows use fractional enlargement. The latter has a 1365 × 768 rendered area within the project’s existing aspect fit.
- The windowed route passed click, Shift-click, drag selection, move, stop, reissue and attack. It also passed the switch and input checks during a live resize, middle-drag pan, wheel zoom and the blocked-cell overlay. Both Play cards and Esc passed in the project and with the resources embedded in the Windows executable. The game kept the catalog’s window settings.
- The headless test recorded a 106.44-pixel drive at a non-grid angle with under 0.001 pixel of sideways deviation. It passed a tight elbow, opposing traffic in a one-cell lane, recovery by giving one unit a passing bay, stable foot and tread phases at a stop, and effect continuity through the switch. The existing headless placeholder-disc test and the existing windowed captures also ran. The placeholder capture uses its default 1280 × 720 for the attack injection.

### Reproduce

    $godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
    & $godot --path . --headless --script res://tests/test_rts_units_motion.gd
    & $godot --path . --resolution 1376x768 --script res://tests/capture_rts_units_motion.gd
    & $godot --path . --script res://tests/capture_rts_units_motion.gd -- --catalog
    & $godot --path . --script res://tests/capture_rts_units_motion.gd -- --clip

The capture script writes captures and live frames to the primary workspace under `render_captures/rts_units_v2/`. The art and the scenes are included in the build. The choice of look is open.
