# RTS Desert Crossing — Terrain and Motion

Open **Developers Page → Desert RTS builds → RTS Desert Crossing — Terrain and Motion**. The scene opens in **Painted HD**. **V** switches looks and **R** resets the trial. **Esc** returns to the Developers Page. [Windows build](../builds/Balance.exe)

## The crossing

1. Turn on **Show crossing targets** in the sidebar. The starting Blue squad is already selected. Right-click the gold **Squad** ring. Watch its first steps on the incline and the change in colour beneath the cliff.
2. Select the Blue tank below the squad's starting point. Right-click the pale blue **Tank** ring. Watch the bright dune crests break under its two treads, then press **V** while it is driving.
3. Right-click a Red unit to start a skirmish. Press **R** to do the comparison again in the current look.

The outpost gives the player a building-sized reference. The minimap shows the active field and current unit positions. The opening field covers **15 × 10½ movement cells** alongside the HUD. The 1080p game picture uses a **1440 × 1008** field in Painted HD and an exactly doubled **720 × 504** field in Pixel art. Both cameras show the same world area at the same zoom. The HUD keeps its own drawing size.

## What to judge

- **Painted HD.** The calmer sand gives the infantry and tank space. The layered rock shelf, amber deposit and teal pool locate the player across the view. The approach is paved from a reusable texture along a path, with separately placed stone patches under the landmarks.
- **Pixel art.** The dune faces, water, and rock ledges group into fewer colours. The frame keeps the same landmarks and unit proportions. Terrain textures use material-specific colour ramps, with stepped shadow edges and nearest-neighbour display.
- **Motion.** The uphill squad covered about 71% of its flat speed on the steepest part of the test route and advanced its walking cycle about 1.54 times as fast per world pixel. Beneath the cliff, the shared shade changes its light multiplier to about 0.73. The tank stamps a shared map of tread contact where it crosses dunes. That map removes part of the drawn ripples along the two lanes for the rest of the trial. The slope remains in place so the pass is repeatable. The small test uses one broad dune shape and a separately authored cliff shadow.

## Assets and layout

- The concept sets the composition. Individual sprites from the generated kit form the playable terrain. The base sand tiles repeat, paving follows the editor path, cliffs and dunes can be placed more than once, and independent footprints control walkability. The existing Units in Motion actor sheets supply the troop poses and tanks. [Composition guide](../assets/source_inputs/rts/desert_proof/layout-guide.png) · [Whole-scene concept](../assets/source_inputs/rts/desert_proof/concept.png) · [Original module sheet](../assets/source_inputs/rts/desert_proof/terrain_kit.png) · [Original sand](../assets/source_inputs/rts/desert_proof/sand.png)
- Built-in ChatGPT Image generated the concept, module sheet and sand. The extraction tool makes the painted sprites, pixel reductions, repeat material and shadow textures. The playfield scene defines placement, outline, slope and shadow for each module. [Concept prompt](../assets/source_inputs/rts/desert_proof/concept.prompt.txt) · [Module prompt](../assets/source_inputs/rts/desert_proof/terrain_kit.prompt.txt) · [Sand prompt](../assets/source_inputs/rts/desert_proof/sand.prompt.txt) · [Extraction tool](../tools/python/make_rts_desert_proof.py) · [Editable playfield](../scenes/maps/rts_desert_crossing_field.tscn)

## Verification

- Headless checks cover the opening frame, cliff, outpost and crystal footprints, dune crossing, slower uphill travel, shorter step spacing, shade, two distinct tread lanes, live look continuity, and restart. The existing RTS test map and Units in Motion headless checks passed.
- Forward+ matched stills cover the opening, the squad crossing, the tank cutting tracks, and both units in the shadow. The windowed test verifies right-click movement, the **M** mark comparison, attack damage and mouse alignment after resizing. The existing RTS test map windowed capture also passed.
- Both the source project and the embedded Windows resources were checked through Play, live **V**, and **Esc**. [Painted opening](../render_captures/rts_desert_proof/01-opening-painted.png) · [Pixel opening](../render_captures/rts_desert_proof/01-opening-pixel.png) · [Crossing targets](../render_captures/rts_desert_proof/00-crossing-targets.png) · [Tank tracks](../render_captures/rts_desert_proof/04-lee-painted.png) · [Tracks hidden](../render_captures/rts_desert_proof/04-lee-marks-off.png) · [Live clip](../render_captures/rts_desert_proof/desert-crossing.mp4)

Run the checks with Godot 4.7.2 using `--script res://tests/test_rts_desert_crossing.gd`. Use `--headless` for mechanics, or `-- --stills`, `-- --record`, and `-- --catalog` in a window. The capture outputs are local to this checkout.
