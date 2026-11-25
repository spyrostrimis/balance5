# RTS Desert Crossing — Terrain and Motion

Open **Developers Page → Desert RTS builds → RTS Desert Crossing — Terrain and Motion**. The scene opens in **Painted HD**. **V** switches looks and **R** resets the trial. **Esc** returns to the Developers Page. [Windows build](../builds/Balance.exe)

## Painted terrain reference pass

The reference places long dune fields around an open centre, a stepped terrace above a small spring, and an amber outcrop framed by an oval of stone paving. The updated battlefield uses those relationships. The northeast cliff now comes from one reusable terraced cutout, with the pool placed separately at its foot. The low crossing dune, broad swells and wind ripples use two different pieces. Sand, stone and small verge rocks bridge the gaps between those landmarks. The road follows the bend around the new, larger Orichalcum outcrop. Carbon's road strip and plaza supply the smaller, crisp flagstones.

The same starting camera and HUD show both versions. The first proof's build, capture and source evidence now live in the primary checkout. [Reference composition](../assets/source_inputs/rts/desert_proof/concept.png) · [Matched before and after](../render_captures/rts_desert_reference_pass/comparison.png) · [1376 × 768 review window](../render_captures/rts_desert_reference_pass/05-review-1376-painted.png)

The new cutouts were generated with the built-in image tool from the owner's attached reference, which matched the saved concept pixel for pixel. The extraction script slices the cutouts and softens the dune edges into the flat sand. The placed art still uses authored height, shadow and blocking data. [Terrace prompt](../assets/source_inputs/rts/desert_reference_pass/terraces.prompt.txt) · [Dune prompt](../assets/source_inputs/rts/desert_reference_pass/dunes.prompt.txt) · [Landmarks prompt](../assets/source_inputs/rts/desert_reference_pass/landmarks.prompt.txt) · [Source sheets](../assets/source_inputs/rts/desert_reference_pass/) · [Extraction tool](../tools/python/make_rts_desert_reference_pass.py)

## The crossing

1. Turn on **Show crossing targets** in the sidebar. The starting Blue squad is already selected. Right-click the gold **Squad** ring. Watch its first steps on the incline and the change in colour beneath the cliff.
2. Select the Blue tank below the squad's starting point. Right-click the pale blue **Tank** ring. Watch the bright dune crests break under its two treads, then press **V** while it is driving.
3. Right-click a Red unit to start a skirmish. Press **R** to do the comparison again in the current look.

The outpost gives the player a building-sized reference. The minimap shows the active field and current unit positions. The opening field covers **15 × 10½ movement cells** alongside the HUD. The 1080p game picture uses a **1440 × 1008** field in Painted HD and an exactly doubled **720 × 504** field in Pixel art. Both cameras show the same world area at the same zoom. The HUD keeps its own drawing size.

## What to judge

- **Painted HD.** The calmer sand gives the infantry and tank space. The layered rock shelf, amber deposit and teal pool locate the player across the view. The approach is paved from a reusable texture along a path, with separately placed stone patches under the landmarks.
- **Pixel art.** The dune faces, water, and rock ledges group into fewer colours. The frame keeps the same landmarks and unit proportions. Terrain textures use material-specific colour ramps, with stepped shadow edges and nearest-neighbour display.
- **Motion.** The uphill squad covered about 71% of its flat speed on the steepest part of the test route and advanced its walking cycle about 1.50 times as fast per world pixel. The lee changes its light multiplier to about 0.71, a modest difference on the small sprites. The tank stamps a shared map of tread contact where it crosses dunes. That map removes part of the drawn ripples along the two lanes for the rest of the trial. The slope remains in place so the pass is repeatable.

## First proof assets and layout

- The concept sets the composition. Individual sprites from the generated kit form the playable terrain. The base sand tiles repeat, paving follows the editor path, cliffs and dunes can be placed more than once, and independent footprints control walkability. The existing Units in Motion actor sheets supply the troop poses and tanks. [Composition guide](../assets/source_inputs/rts/desert_proof/layout-guide.png) · [Whole-scene concept](../assets/source_inputs/rts/desert_proof/concept.png) · [Original module sheet](../assets/source_inputs/rts/desert_proof/terrain_kit.png) · [Original sand](../assets/source_inputs/rts/desert_proof/sand.png)
- Built-in ChatGPT Image generated the concept, module sheet and sand. The extraction tool makes the painted sprites, pixel reductions, repeat material and shadow textures. The playfield scene defines placement, outline, slope and shadow for each module. [Concept prompt](../assets/source_inputs/rts/desert_proof/concept.prompt.txt) · [Module prompt](../assets/source_inputs/rts/desert_proof/terrain_kit.prompt.txt) · [Sand prompt](../assets/source_inputs/rts/desert_proof/sand.prompt.txt) · [Extraction tool](../tools/python/make_rts_desert_proof.py) · [Editable playfield](../scenes/maps/rts_desert_crossing_field.tscn)

## Verification

- Headless checks cover the opening frame, cliff, outpost and crystal footprints, dune crossing, slower uphill travel, shorter step spacing, shade, two distinct tread lanes, live look continuity, and restart. The existing RTS test map and Units in Motion headless checks passed.
- Forward+ matched stills cover the opening, the squad crossing, the tank cutting tracks, and both units in the shadow. The windowed test verifies right-click movement, the **M** mark comparison, attack damage and mouse alignment after resizing. The existing RTS test map windowed capture also passed.
- The reference pass preserves the crossing and attack, including the paired tread lanes and cursor after a resize. Both Desert Crossing and Carbon were checked through Play and Esc from the project and Windows export. [Painted opening](../render_captures/rts_desert_reference_pass/01-opening-painted.png) · [Crossing targets](../render_captures/rts_desert_reference_pass/00-crossing-targets.png) · [Tank tracks](../render_captures/rts_desert_reference_pass/04-lee-painted.png) · [Tracks hidden](../render_captures/rts_desert_reference_pass/04-lee-marks-off.png) · [Live clip](../render_captures/rts_desert_reference_pass/desert-crossing.mp4)

Run the checks with Godot 4.7.2 using `--script res://tests/test_rts_desert_crossing.gd`. Use `--headless` for mechanics, or `-- --stills`, `-- --record`, and `-- --catalog` in a window. The capture outputs are local to this checkout.
