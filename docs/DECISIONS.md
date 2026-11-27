# Decisions

### 2026-11-27 · Forest blocked ground comes from the paintings

Area: RTS maps · Forest kit · Status: Verified

Tree clusters and rocks block an outline measured from their painting (the canopy shrunk by about two thirds of a cell), not a hand-drawn oval, so F1 matches what the player sees. The painted ford was one cell wide; its stone band is laid three times to make a 4-cell tank ford, and the bridge stays infantry-only. The owner asked for three red maples: one inside the north wood, two on wood edges. [Paintings in the kit](RTS_MISSION_1_FOREST.md#your-paintings-in-the-kit)

### 2026-11-27 · Forest river is a path piece; fords and bridges reopen it

Area: RTS maps · Forest kit · Status: Verified

The river follows a line of points: the same points draw the painted strip and decide which cells are water, so the visible water and the blocked ground always agree and bending it needs no repainting. Fords and bridges are separate pieces whose footprint reopens the water under them. The map has a tank-wide ford and an infantry bridge until the owner picks. [Forest mission](RTS_MISSION_1_FOREST.md#the-river-the-ford-and-the-bridge)

### 2026-11-27 · Forest lanes are checked by test

Area: RTS maps · Status: Verified

Main lanes must carry a 4-cell corridor and tank routes a 3-cell one, checked by `test_rts_mission_1_forest.gd`, so dressing the forest cannot box troops in the way the reference painting does. [Room](RTS_MISSION_1_FOREST.md#the-map)

### 2026-11-27 · Forest features are switches on the shared battlefield

Area: RTS code · Status: Verified

Minimap colours per piece, canopy fade on any piece, crossings and the forest's own Pixel ground are settings on `RtsMissionBattlefield` and the kit pieces, off by default. The desert map and older builds pass their tests unchanged; no battlefield script was copied. [What changed](RTS_MISSION_1_FOREST.md#what-changed-in-the-shared-code)

### 2026-11-27 · Mission 1 has a Desert (Red) and a Forest (Blue) map

Area: RTS · Campaign · Status: Decided by owner

`RTS Mission 1 – Desert` is Red's first mission and `RTS Mission 1 – Forest` is Blue's. Both share units, buildings, the Orichalcum rock, the HUD and the rules; only the map and its kit differ. The forest map gets wider lanes than the reference painting so troops are not boxed in by trees. [Forest plan](RTS_MISSION_1_FOREST_PLAN.md)

### 2026-11-27 · Use the HUD mockup itself as a HUD style

Area: UI · Status: Trying

The owner preferred mockup E as drawn over the code-drawn Classic. Its painted chrome is cut from the mockup and only the changing values are drawn live. It is the default; Classic, Holo and Carbon stay switchable with U.

### 2026-11-27 · Units rise over hills

Area: RTS movement · Status: Verified

Units are drawn higher by the square of the terrain height and lit by the slope, so they visibly climb hills while low ripples barely move them. Ground position, pathing and blocking are unchanged; it only affects drawing and clicking. [Sand hills](RTS_MISSION_1_DESERT.md#sand-hills-units-go-up-and-down)

### 2026-11-27 · Try Classic and Holo HUDs in play

Area: UI · Status: Trying

From five ChatGPT mockups the owner picked **E (Dune II remastered)** and **B (holo-glass field tablet)**. Both are built in Mission 1, switchable with U, beside the original Carbon HUD. Every style keeps the same battlefield scale, so the choice is about reading and feel, not unit size. Classic is the default until the owner chooses.

### 2026-11-27 · Planet skins swap terrain art, not maps

Area: RTS · Art direction · Status: Verified

A planet skin is a list of art folders checked before the kit's own art. Layout, blocked ground and units stay the same, so one map can be played on several worlds. Miasaki is the first skin. Where Miasaki never painted a piece, a palette transfer learned from the matched Carbon/Miasaki pairs recolours the kit art.

### 2026-11-27 · HQ repaint matches Carbon's camera

Area: RTS art · Status: Verified

The second HQ prompt named Carbon's outpost as the exact camera target and got a near-overhead building. It is not overdone: it now reads like the outpost beside it. The trade-off is that the arched front wall is reduced to a thin band, with the banner on the roof edge.

### 2026-11-27 · Use Carbon's own paintings wherever Carbon has one

Area: RTS · Status: Decided by owner

Carbon's paintings are the quality bar. Mission 1 had inherited Reusable 4's modular spring in place of Carbon's painted cliff oasis; Carbon's oasis is back in its original spot. Reusable 4's art stays only where Carbon has no equivalent (newer dune shapes, the modular oasis parts, the tree, the HQ, the small crystal deposits, road joins) and for the more readable infantry. The `carbon-art` tag marks Carbon's paintings in the Kit Palette.

### 2026-11-27 · Keep Miasaki's palette as another world

Area: RTS · Art direction · Status: Decided by owner

Balance spans many worlds, so Dune II's hot desert is a starting point, not a rule. Miasaki's pale peach sand and lavender-shadowed rock make a convincing second planet and stay in the project. Next step: make it a switchable "planet skin" for the kit rather than a separate copy of the map.

### 2026-11-27 · Draw HUD text with MSDF fonts

Area: UI · Status: Verified

The HUD writes small text and then scales the drawing up, which blurred the letters at 1080p. Turning on MSDF for the default font (`gui/theme/default_font_multichannel_signed_distance_field`) keeps letters sharp at any scale, project-wide. The HUD layout itself is still a placeholder; five redesign directions are in `assets/source_inputs/hud/PROMPTS.md`.

### 2026-11-27 · Stop making Reusable copies; all RTS work goes into Mission 1 and the shared desert kit

Area: RTS · Status: Decided by owner

Four builds in a row copied Carbon's scene, scripts and art to change a few pieces. **RTS Mission 1** (`scenes/maps/rts_mission_1_desert.tscn`) is now the one RTS scene, built only from `scenes/rts/desert_kit/` (one scene per painted piece plus editable groups). Visual changes become edits to the kit, with a switch for A/B where needed (for example `smooth_wind`). Carbon, Miasaki, Reusable 3 and Reusable 4 stay as frozen comparison cards. [Mission 1 and the kit](RTS_MISSION_1_DESERT.md)

### 2026-11-27 · Judge the RTS at 1920 × 1080

Area: RTS · Status: Decided by owner

The 1376 × 768 capture size came from the first RPG canyon reference image (`docs/references/rpg_canyon_goal.jpg`). It never related to the RTS. Carbon's Detailed art is painted at twice 960 × 540, which is 1080p, and players will see it at that size. RTS captures now run fullscreen at 1920 × 1080, because a 1080p window does not fit inside the taskbar-reduced work area. The canyon keeps 1376 × 768 for comparison with its reference.

### 2026-11-27 · Replace value noise with gradient noise for open-sand lighting

Area: RTS terrain · Status: Verified

The wind-lighting noise in Carbon's sand shaders drew straight light seams along its grid cells, visible as long diagonals by the spring. Gradient noise with a smoother blend keeps the same swell size without seams. It is an opt-in switch (`smooth_wind`) so the older builds are unchanged. [Before/after](RTS_MISSION_1_DESERT.md#what-changed-from-reusable-4)

### 2026-11-26 · Build RTS Reusable 4 with front-and-rear unit paintings, flat-sand dune deltas and seamless road joins

Area: RTS · Status: Trying

Painted both front-SE and rear-NE poses for Blue and Red infantry and commanders so connected cobalt shoulders, the Blue Commander's broad ivory scarf, and Red's deep crimson with a brighter scarlet upper edge hold across all eight walking facings, paired with `1.20×` visual squad spacing on the same single-tile claim. Generated the four new dune shapes on flat `#E48728` sand to match Carbon's signed-delta tread shader, built `sheltered_spring.tscn` and `roadside_pool.tscn` from one modular oasis kit with verified `PassCliff` tank clearance, added the steeper-angle Blue Field Headquarters beside the road, and bridged the road fork and plaza entrances from Carbon's limestone plates. Encounter balancing and final art approval remain open for the owner. [Matched comparisons, clip and layout guide](RTS_REUSABLE_4.md)

### 2026-11-26 · Test Reusable 3 with original Carbon’s encounter

Area: RTS · Status: Decided by owner

The art comparison uses original Carbon’s camera, Detailed view and encounter. Reusable 3 adds a landmark headquarters and a desert kit. The owner will judge the art in play. Encounter balancing is a separate experiment.

### 2026-11-26 · Use wider painted squad spacing in Reusable 3

Area: RTS · Status: Verified for this build

The colour-only comparison made both factions distinct from the ground at all eight facings. Diagonal squads still touched in places. An 18% increase in drawn offsets opens gaps between the four figures while the squad uses its original movement and ground claim. [Matched comparison](RTS_REUSABLE_3.md#captures-and-checks)

### 2026-11-26 · Reuse the same oasis pieces in both arrangements

Area: RTS · Status: Verified for this build

Each blocker owns a ground outline. The roadside tank crosses with PassCliff in its published position. Moving that piece 42 units inward closes the tested straight lane. This gives the mapmaker a single visible piece to move when tuning the passage. [Two layouts and evidence](RTS_REUSABLE_3.md)

### 2026-11-26 · Use the original RTS Reusable 2 Carbon as the RTS model

Area: RTS · Status: Decided

The owner likes the original playable desert build and chose it as the reference for future RTS work. Use its battlefield, unit scale, camera and command interface as the starting point for The First Claim. The Miasaki repaint and isometric forest studies remain comparisons. The proposed encounter changes are ready for playtesting. [Assessment and plan](RTS_REUSABLE_2_CARBON.md#assessment--26-november-2026)

### 2026-11-26 · Try a reusable isometric forest battlefield

Area: RTS · Status: Trying

The owner chose Fight 4's forest as the paint reference for this study and required movable cliff and scenery pieces. Both layouts use the same [isometric projection](GLOSSARY.md#isometric-projection) for drawing and orders. Moving the ridge closes the tank's low route and changes which side it uses. The art verdict remains with the owner. [Study and matched tank routes](RTS_FOREST_CLAIM.md)

### 2026-11-25 · Compare Forest Fight 4 painting on the Carbon battlefield

Area: RTS · Status: Trying

The owner chose Forest Fight 4 for paint and light, with Carbon setting the camera, positioning and play. Put the repaint on a separate Play card and use the existing Pixel look on V. Northeast review settled quieter peach sand, cool shadows under limestone ledges and a sharp cliff foot as the colour and contrast targets. The new Detailed treatment carries them across the map. [Miasaki frames and route](RTS_REUSABLE_2_CARBON_MIASAKI.md)

### 2026-11-25 · Try continuous isometric movement and full-circle fire in Fight 4

Area: RPG · Status: Trying

The owner chose to test one camera angle, character scale and control scheme from daylight into the cavern. A joined floor lets the Commander cross in either direction while moving and firing. At the playing size she measures 130 pixels in all three sampled locations. The owner will judge the feel of the adventure after playing. [Fight 4 evidence](FOREST_FIGHT_4.md)

### 2026-11-25 · Ground the painted RTS cliffs
Area: RTS · Status: Decided

Use a tight shadow derived from the cliff silhouette and place loose rubble at the foot. Sample that same shadow for unit lighting. The broad ellipse beneath the northeast terrace made the rock look suspended. [Matched evidence](RTS_DESERT_CROSSING.md#cliff-contact-pass)

### 2026-11-25 · Choose modular Painted HD 2D for the RTS
Area: RTS · Status: Decided

The owner chose the modular painted direction after playing Desert Crossing. Match the reference through connected terrain shapes, shared warm lighting and clear landmark placement. Individual terrain pieces remain reusable across scenes. [Reference and art pass](RTS_DESERT_CROSSING.md)

### 2026-11-25 · Build RTS Reusable 2 Carbon playable slice with Dune II HUD, dual zoom stops and live Detailed vs 960×540 Pixel toggle
Area: RTS · Status: Trying
Built `scenes/maps/rts_reusable_2_carbon.tscn` (`RTS Reusable 2 Carbon`) entirely from reusable painted ChatGPT pieces (central Orichalcum outcrop, northeast cliff and turquoise spring oasis, mesas, ridge, boulders, bevelled stone outpost pads, oval flagstone plaza, desert scrub and seamless signed-delta dune clusters) over continuous calm-masked sand, paired with 4-soldier squads, commanders (`Mend`), 8-facing hull+turret tanks that flatten two lanes through dune ripples, an Orichalcum hold timer and the Dune II HUD frame. Press `V` to compare Detailed Painted (`2×` HD) against `960×540` Pixel (`1×` curated 74-colour palette with 1 px unit outlines) and `Z` to compare `21×14` Command framing against `15×10` Close framing while playing. Evidence: `docs/RTS_REUSABLE_2_CARBON.md`, `tests/test_rts_reusable_2_carbon.gd`, `render_captures/rts_carbon/`.

### 2026-11-25 · Painted terrain first for the RTS proof
Area: RTS · Status: Trying

The owner prefers painted detail alongside the RPG and wants a distinct pixel version as a second choice. Desert Crossing tests reusable terrain and units on one battlefield, with shared camera framing, relief, shade and tread positions. A whole-scene painting provides the composition and remains available for a future playable comparison. [Desert Crossing](RTS_DESERT_CROSSING.md)

### 2026-11-25 · Walk into the forest cave before raising the rifle
Area: Canyon · Status: Trying

Cross the sill at the end of the painted forest trail, then use a brief view back towards the forest before settling into a fixed side-on chamber. The close view uses Approach 3’s source drawings at twice the original picture resolution. Place one bat pass at the starting depth and two at other depths so moving across the floor matters. The Commander stays responsive through harmless contacts. [Test and capture](EXPERIMENT_LOG_AND_LESSONS.md#2d-painted-forest-fight--2026-11-25)

### 2026-11-24 · Scene-local Pixel (1x) vs HD Painted (2x) visual profile & 4-faction team-colour mask shader on RTS Units Test 3
Area: RTS · Status: Trying

Created `scenes/maps/rts_units_test_v3.tscn` ("RTS Units Test — Units on the Map 3") as a standalone build alongside the preserved original `scenes/maps/rts_units_test.tscn` ("RTS Units Test — Units on the Map"), adding a scene-local `RtsVisualProfile` (`scripts/rts/rts_visual_profile.gd`, CLI `--profile=pixel|hd_painted`, live hotkey `F4`, `F3` perf/scale overlay) that switches between `"pixel"` (`960×540` logical view, `CONTENT_SCALE_STRETCH_INTEGER`, `TEXTURE_FILTER_NEAREST`, exact `2×` at `1920×1080` and centered `1×` letterbox at `1280×720`, pixel-snapped camera/units/effects) and `"hd_painted"` (`1920×1080` `canvas_items`, `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`, 2× un-quantized painted layers `assets/textures/rts/style_test/t5_hd/*.png` with the NE cliff oasis cue, smooth movement, soft shadows/dust/tracks, warm Orichalcum crystal radial glow and vignette) on the exact same `32×32` logical tile grid (`RtsGrid` untouched) while restoring all `Window` properties in `_exit_tree()`. Replaced the `0.85` fractional tank `sprite_scale` (`30.6×30.6` pixel wobble) and raw RGB channel swap with exact `1:1` `32×32` (1×) and `64×64` (2×) neutral sheets (`sprite_scale = 1.0` in `scenes/rts/units/look_v3/*.tres`), a reusable 4-faction team-colour mask shader (`assets/shaders/rts/rts_team_color.gdshader` supporting Blue, Red, Green and Palatinate while protecting dark `#221814` outlines), and distance-driven walk/tread cadence. Evidence: `tests/test_rts_units_test.gd`, `tests/capture_rts_units_test_v3.gd`, `render_captures/rts_units/pixel_1080p_*.png`, `render_captures/rts_units/hd_painted_1080p_*.png`.

### 2026-11-24 · Match the RTS looks during live play
Area: RTS · Status: Trying

Open Units in Motion in Painted HD and switch to 960 × 540 Pixel art on V. Keep the same 32-pixel movement grid, viewport framing and live unit state. At 1080p, the 960 × 540 proof kept more of the rifles and scarf than the 640 × 360 proof, which is saved as a still. The owner will choose the direction after playing. [Matched captures and motion](RTS_UNITS_IN_MOTION.md)

## 2026-11-24 · Painted forest · Study defaults

**Verified for this study.** Use one continuous painting with two stretches where the Commander gets smaller and two where she holds her size. Tie size and stride to her position so a reversal retraces the change and camera movement at a stop leaves her size alone. Buttress Light is the provisional painting because its landmarks distinguish the stretches and its quieter ground preserves the Commander’s silhouette. Art selection and the feel of the footfalls remain open for owner review. [Measurements and alternatives](../assets/scenes/forest_test/REPORT.md)

## 2026-11-22 · RPG canyon · Standing commander comparison

**Test result.** At the same apparent height and lighting, the reference-derived commander made her features easier to read than raising the render resolution with the existing sprite. Use the 149-pixel standing pose as a benchmark for the proposed Approach 3 animation. The owner’s choice of canyon direction remains open. [Visual comparison](CANYON_APPROACH_3_HANDOFF.md#one-pose-experiment)

## 2026-11-22 · RPG canyon · Sculpted Bend camera match

The owner asked for the framing of 2D Parallel-Projection Canyon · Approach 1 vs 2. Sculpted Bend now opens with a fixed 42° downward orthographic camera. Its view gives the commander about the same on-screen height as the 2D sprite. Press C to compare the original perspective and see the distant arch. [Measured camera match](CANYON_SCULPTED_BEND.md#parallel-projection-camera)

## 2026-11-22 · RPG canyon · Sculpted Bend study defaults

**Verified for this study.** Shallow raised cobbles stay on because their lips read in direct light while the collision floor stays smooth. The painted distance opens by default because its arch and receding ridges read more clearly from the live overlook. R and V keep the matched alternatives playable. The final RPG art direction remains open. [Evidence](CANYON_SCULPTED_BEND.md)

What we decided, when and why, newest first. Balance Studio shows this file on its **Decisions** page. Open questions live in `docs/GAME_DESIGN.md` §9 and in the roadmap.

**For agents:** add an entry when the owner accepts or rejects a direction, or when a test settles a question. Use the format below. **Status** is *Decided*, *Trying* (provisional, being tested) or *Reversed* (say what replaced it). Do not delete reversed decisions; they stop us repeating mistakes.

```
### YYYY-MM-DD · Short title
Area: Game | RTS | Canyon | Art | Tech | Workflow · Status: Decided | Trying | Reversed
Why, in one to three sentences. Where the evidence is.
```

### 2026-11-22 · Match 3D Kit Canyon · v2 camera angle & distance to 2D Parallel-Projection
Area: Canyon · Status: Trying
Set `3D Kit Canyon · v2`'s `CameraRig` to `pitch = -42.0°`, `yaw_follow = 0.0`, `fov = 22.0°`, and offset `(0.0, 11.83, 12.13)` (`~17.0 m` camera-to-hero distance), paired with a `42.0°` boot-anchored shader pitch tilt on `CommanderSprite` (`-0.640625`), `12.0°` sprite tilt on plants, flared canyon exit jaws to `Z = -24.0`, and `OrichalcumCraterGround` at `(0.1, 0.015, -18.0)` so spawn/midway hero scale matches `2D Parallel-Projection · Approach 1 vs 2` (`19.4%` screen height) while framing the full glowing exit crater without cliff cutoffs. Evidence: `tmp/kit_v2_vs_2d_parallel_cam.png`, `render_captures/kit_v2/KV2_pos*.png`, `docs/EXPERIMENT_LOG_AND_LESSONS.md` §23.

### 2026-11-22 · Build 3D Kit Canyon · v2 with uniform 64 texels/m, <=32-colour palettes, organic non-intersecting cliffs and AA
Area: Canyon · Status: Trying
Created the standalone playable study `scenes/maps/canyon_v3_kit_v2.tscn` (`3D Kit Canyon · v2`) removing all debug toggles/HUD labels while combining `img1` cobbles, `art_gemini` sand/dunes, and `art_road_goal` organic sandstone cliffs. Every object uses its own <=32-colour palette, cyclic seamless tiling at exact `64.0 texels/m` without node scaling, flush flat-base meshes seated onto levelled organic cliff pads with zero overlaps, and `4× MSAA` + sharp-pixel edge anti-aliasing. Evidence: `tests/test_canyon_v3_kit_v2.gd`, `docs/EXPERIMENT_LOG_AND_LESSONS.md` §23, `render_captures/kit_v2/`.

### 2026-11-22 · Build 3D Canyon · Way 1B Free 3D Modules for the 2D vs 3D evaluation
Area: Canyon · Status: Trying
Following the 61-asset audit (`docs/CANYON_ASSET_CATALOG.md` and `Canyon Asset Catalog.html`), the owner chose Way 1B to test a full photogrammetry-and-kit 3D canyon bend (`scenes/maps/canyon_way1b_free_3d.tscn`) against the 2D builds while keeping the Blue Commander, the two ChatGPT Trellis boulders, and the pale Grand Canyon rock. Harmonizing the scans' luminance ramps (`way1b_scan_rock.gdshader`, toggleable with key `G`) unified disparate photo scans (lunar grey `Moon Rock 04`, ironstone `Namaqualand Stones 01`, mossy `Rock Face 01`, and `Namaqualand Cliff 01/02`) into one warm terracotta, slate-terrace, and sun-bleached cobblestone canyon with verified spawn landmark occlusion and midway reveal. Evidence: `docs/CANYON_WAY1B_FREE_3D.md`, `docs/EXPERIMENT_LOG_AND_LESSONS.md` §22, `render_captures/way1b_free_3d/`.

### 2026-11-21 · Keep Painted Bend as an art study
Area: Canyon · Status: Trying
The warm-and-cool candidate made the overlook the most inviting of the three paintings. Fitting it preserved the walk and gave the arch a clear reveal. The original Arch Overlook remains the quality target for crisp stonework and the sweep of the road. [Painted Bend evidence](PIXEL_CANYON_SESSION_B_PAINTED.md)

### 2026-11-21 · Try a connected elevated 2D canyon
Area: Canyon · Status: Trying
A single fixed-scale map allowed the commander to pass behind the near wall, emerge beside the terrace, cross the road and retrace the same landmarks. The owner can judge the higher viewpoint and simpler valley beside the original painting. [Session B comparison](PIXEL_CANYON_SESSION_B.md)

### 2026-11-21 · Reject foreground cutouts for the full moving canyon
Area: Canyon · Status: Decided
The owner found that the cliffs and ruins move like detached pieces. The review confirmed that each cutout has one depth, and the road, cliff and valley never meet as one surface. Keep Through the Bend as a playable comparison. The choice of a replacement method remains open. [Findings and options](PIXEL_CANYON_FOLLOW_STUDY.md#why-the-environment-failed)

### 2026-11-21 · Give the Through the Bend camera 8 art pixels of leeway
Area: Canyon · Status: Trying
The rough round trips showed that a short delay on reversal leaves time to read the commander's first step. The default lets her boots move from Y 317 to 333 and her standing height stays within 121–129 art pixels. Exact follow stays on key 1 for review. [Through the Bend comparisons](PIXEL_CANYON_FOLLOW_STUDY.md)

### 2026-11-21 · Parallel-Projection 2D Canyon: Approach 1 (Uncut) vs Approach 2 (Modular Stitched)
Area: Canyon · Status: Trying
Cropping Image 9's horizon sky (`tmp/chatgpt_refs/Ref2_Style_Palette_Image9_NoHorizon.png`) and pairing it with a *Sea of Stars* parallel-projection reference (`Ref1_Camera_Projection_SeaOfStars.jpg`) allowed ChatGPT to generate true constant-scale parallel-projection 2D canyon art with no vanishing point. Both workflows are now playable at 960×540 (with 640×360 live toggle, 192 colours, Laigter normal maps, and constant hero size under a locked following camera) and switchable live with Tab/M in `scenes/rpg_2d/canyon_orthographic_study.tscn`: Approach 1 (`canyon_approach1_uncut.tscn`) stitches two uncut vertical canyon plates across an 81-px overlap into a 1967-px tall canvas, while Approach 2 (`canyon_approach2_modular.tscn`) quilts the modular sand/road sheet and layers 6 modular cliff/staircase chunks, ruined archways, boulders, and olive bushes as Y-sorted sprites. Evidence: `docs/EXPERIMENT_LOG_AND_LESSONS.md` §16, `render_captures/rpg_2d/a1_*.png`, `render_captures/rpg_2d/a2_*.png`.

### 2026-11-21 · Standalone 2D Pixel-Art RPG Canyon Study (Option C)
Area: Canyon · Status: Trying
Built an independent 100% 2D orthographic tile-and-stamp RPG canyon (`scenes/rpg_2d/canyon_orthographic_study.tscn`) at 960×540 with a live toggle to 640×360, locked to a 192-colour palette sampled from the owner's stepped canyon target, with Laigter 2D normal maps and Tiled `.tsx`/`.tmx` sources. Explore Mode uses 8-way directional movement and facing; Combat Mode switches to Streets of Rage 4 style (free depth movement, facing and horizontal shooting strictly Left/Right). Evidence: `tests/test_rpg_2d_canyon_logic.gd`, `render_captures/rpg_2d/`, `docs/EXPERIMENT_LOG_AND_LESSONS.md` §16.

### 2026-11-20 · RTS art scale: 1 art pixel = 2 screen pixels at 1080p
Area: Art · Status: Trying
Measured from the Mission 1 reference: soldiers about 11 art pixels tall, a squad of four or a tank per 32 px tile, the camera at zoom 4/3 in our 1280×720 viewport (960×540 art pixels on screen). The style test matched the reference's sizes one to one. Details: `docs/RTS_ART_RULES.md` §1.

### 2026-11-20 · One 48-colour desert palette for all RTS art
Area: Art · Status: Trying
Clustered from the reference by `tools/python/rts_palette.py`. The reference redrawn with only these colours loses nothing visible. Every layer is mapped onto it last, so pieces from different sources belong to one picture.

### 2026-11-20 · Units never enter cliffs or big rocks; bases sit on low pads
Area: RTS · Status: Decided
Soldiers and vehicles cannot move onto cliffs, mesas or the Orichalcum rock; those tiles are blocked. Buildings will stand on low rocky or concrete pads, like the road, which units can cross.

### 2026-11-20 · Ground units with shadow, contact patch, tracks and dust
Area: Art · Status: Trying
Without them units look like floating stickers; with a soft down-right shadow, a dark contact patch, tank tracks, footprints and dust they sit on the sand. The flat painted dunes do not make units look like they fly. The most unnatural thing left is grid movement (straight lines, sharp corners). Evidence: `docs/RTS_ART_RULES.md` §8, `render_captures/rts_units/`.

### 2026-11-20 · The RTS environment look is achievable; move on to units
Area: Art · Status: Decided
After style test 5 the owner is confident the Mission 1 reference's environment can be matched closely, and will move, add and remove pieces by hand later. The style tests stop; the recipe is in `docs/RTS_ART_RULES.md` §6e. Next: how units look moving on the map.

### 2026-11-20 · Dunes in fields towards the edges, calm sand round the road
Area: Art · Status: Trying
The owner noticed the reference has no dunes round the centre: calm sand in a wide band round the road and plaza, orderly ripple fields towards the edges, all following one wind. Test 4 does this and reads as peaceful instead of messy. Evidence: `docs/RTS_ART_RULES.md` §6d.

### 2026-11-20 · Look at close-ups, not only numbers
Area: Workflow · Status: Decided
Test 3 matched the reference's averaged numbers but still looked messy; close-ups showed soft smeared ripples and big scattered debris. Measurements now back up a side-by-side look, never replace it.

### 2026-11-20 · Judge RTS art by variation, not averages
Area: Art · Status: Decided
The reference sand looked more vibrant, but its average brightness and saturation equalled ours; it changes light 2–4× more over 5–30 px and its colour wanders more. Test 3 adds rolling relief and colour drift and uses the owner's dense ripple texture (dunes2) as the ground. Style tests now measure variation by size. Evidence: `docs/RTS_ART_RULES.md` §6c.

### 2026-11-20 · Reuse the kitbash pebbles and shrubs for RTS scatter
Area: Art · Status: Trying
The Desert Kitbash Mini-Map's pebble, speck and shrub sprites (`assets/textures/kitbash/`) read better than tool-drawn ones; pebbles at 60%, shrubs at 75% to match the reference's sizes.

### 2026-11-20 · Style test 2 confirms the hybrid RTS art method
Area: Art · Status: Trying
With the owner's ChatGPT textures, colour-matched to the reference and shrunk to art scale, sand, road and rock tops came close to the reference; cliffs show walls; the Orichalcum rock reads as a raised pile. Large dune fields and crystals stay tool-made: the painted dunes and crystal images lose their shape when shrunk. Remaining gaps are tuning. Evidence: `docs/RTS_ART_RULES.md` §6b, `render_captures/rts_style/t2_*`.

### 2026-11-20 · RTS art: our tools make shapes, painted textures make surfaces
Area: Art · Status: Trying
Style test 1 (procedural only) got scale, palette, height (front walls, down-right shadows) and unit contrast right, but its dunes, rock tops and road look machine-made. Next: painted textures from ChatGPT for the surfaces, shaped, shaded and palette-mapped by our tools. Evidence: `docs/RTS_ART_RULES.md` §6, `render_captures/rts_style/`.

### 2026-11-20 · Feature the newest build or study
Area: Workflow · Status: Decided
The opening button follows the newest available build or study by build date. The Developers Page starts in date order and allows local title and description edits and a saved drag order.

### 2026-11-20 · RTS is 2D top-down; height is drawn into the art
Area: RTS · Status: Decided
The battlefield is a flat 2D map seen from above, like Dune II. Rocks, cliffs and dunes get their height from the art (lit tops, visible front walls, cast shadows), with the light from the top-left for every tile and sprite. 2D keeps selection, pathfinding and the HUD simple; the 3D canyon stays separate.

### 2026-11-20 · 32 px tile grid with A* pathfinding, one unit per tile
Area: RTS · Status: Decided
Each 32 px tile is walkable or blocked (a "walkable" flag on the tile), and Godot's AStarGrid2D finds routes around rocks. A unit claims its tile, so units never stack. A grid fits the tiles, fog of war, the control area and the minimap better than a navmesh. Evidence: `tests/test_rts_test_map.gd`.

### 2026-11-20 · RTS unit numbers live in UnitStats files
Area: RTS · Status: Decided
Each unit type is a `.tres` file in `scenes/rts/units/` (health, attack, armour, range, cooldown, guard range, speed, sprite) that the owner can edit in the Inspector. Damage per hit is attack minus armour, at least 1. All numbers are placeholders until balancing.

### 2026-11-20 · First RTS test uses placeholder discs and tiles
Area: RTS · Status: Decided
The owner chose plain team-coloured discs and flat placeholder tiles over the kitbash art for step 1, so the test is about controls, not looks. Real sprites plug in through each unit file's sprite field.

### 2026-11-20 · Idle units engage enemies within guard range
Area: RTS · Status: Trying
Without it, Red troops stood still while their neighbour was shot. Idle units shoot what is in range, chase enemies within their guard range (4–6 tiles), and hit back at whoever shoots them. A later Hold command will turn chasing off.

### 2026-11-21 · 3D canyon: real modelled pieces with pixel textures
Area: Canyon · Status: Decided
To compare against the 2D canyons, the 3D version gets real modelled curbs and cliffs wearing pixel textures (B64 or art_gpt colours); only plants are flat sprites. Projected paintings and flat cutouts break when the camera turns. The boulders and the white scan rock stay. Evidence: experiment log §17.

### 2026-11-20 · Painted sources, pixels made by us
Area: Art · Status: Trying
B64 looked more real than every AI "pixel art" set because it starts from a detailed painted image and makes the pixels itself (64 texels per metre, one palette from the goal image). From now on, generators make detailed painted textures, and `pixel_snap.py --painted` makes the pixels. Evidence: experiment log §15.

### 2026-11-20 · Pack models wear our canyon material
Area: Art · Status: Trying
Free-pack shapes (craftpix low-poly mountains) fit the canyon once they use `canyon_rock.tres`; photo-scan textures look realistic and clash with the painted style. Packs without a found licence stay local and uncommitted. Evidence: experiment log §14d.

### 2026-11-20 · ChatGPT over Perchance for surface textures
Area: Art · Status: Trying
ChatGPT's strata is the first wall that reads as layered rock without bricks, and its cobble reads as a road; Perchance is not on a pixel grid and its strata looks lumpy and purple. The owner still finds every cobble version flat, so the next test is raised (3D) stones. Evidence: experiment log §14c.

### 2026-11-19 · Repository docs are the project's memory
Area: Workflow · Status: Decided
Story, plan, decisions, pipelines and the dictionary live as Markdown in `docs/`, so every agent reads and updates the same files and Balance Studio shows them in one place. Chat histories in Antigravity, Codex and Claude Code are not a record.

### 2026-11-19 · Gemini is out as a texture generator
Area: Art · Status: Decided
Its pixel grids were clean but it drew cliffs as brickwork and cobbles as brick rows. ChatGPT and Perchance remain. Evidence: experiment log §14b.

### 2026-11-19 · Test hand-made pixel sets with two procedures
Area: Art · Status: Trying
Converting existing art to pixels made the frame crunchier but not Octopath-like. The deciding test is designed pixel art at about 64 texels per metre, run through both pixel snap (key 4) and the smooth procedure (key 5). Evidence: experiment log §14.

### 2026-11-19 · Nothing is hard-locked
Area: Workflow · Status: Decided
Camera, sun, route, fog, focus and landmark timing are tunable. Change one on purpose, with matched before/after captures, and update the rubric. A `[x]` guards against accidental regressions only.

### 2026-11-19 · Canyon v2 replaces the inherited test chain
Area: Canyon · Status: Decided
One flat scene driven by an editable route and a placement list replaced six levels of scene inheritance that were fragile to change. The old scenes stay as frozen comparison baselines.

### 2026-11-19 · Physics walls instead of a position clamp
Area: Tech · Status: Decided
Canyon v2 keeps the commander in with a collision corridor and bakes a navmesh, which later units can use for pathfinding.

### 2026-11-19 · Steeper camera, backlit sun, no global fog
Area: Canyon · Status: Trying
−21° pitch at (0, 5.5, 11.9) hides the sky like the RPG goal; the sun moved ahead-right so the right wall shades the road; global fog washed the view to beige and is off. Evidence: experiment log §11.

### 2026-11-19 · The RTS comes first
Area: Game · Status: Decided
Balance is a Dune II tribute. The RPG canyon, HD-2D look and 3D work are extras; if they fail, the RTS alone is the game. Spend short time on the RTS.

### 2026-11-19 · Mission 1 has no base building
Area: RTS · Status: Decided
"The First Claim" teaches selection, movement, attack, the commander ability and control points with four troops plus a commander per side. Base building comes after the tactical foundation.

### 2026-11-19 · Build RTS maps from tiles
Area: RTS · Status: Decided
Maps are assembled from tiles (the kitbash and Tiled work), not single painted images, so maps, fog of war and pathfinding scale.

### 2026-11-19 · RPG fights follow Streets of Rage 4
Area: Game · Status: Decided
Free movement in depth, facing and shooting left or right only. Story beats use Dune II-style storyboard briefings.

### 2026-11-19 · Everything shipped is original or licensed
Area: Game · Status: Decided
Reference games are inspiration only. Record the source and licence of any bought or downloaded asset next to it. Third-party screenshots stay out of the repository.

### 2026-11-18 · Native camera depth of field for focus
Area: Canyon · Status: Decided
Real camera DOF (sharp about 10–16.5 m, amount 0.014) replaced the older screen-height blur: boots and nearby paving stay sharp together. One blur method per capture. Evidence: experiment log §6.

### 2026-11-18 · ChatGPT image road is the best road
Area: Art · Status: Decided
The 1024 px ChatGPT cobble at 3.2 m per repeat kept natural chips, varied stone colours and sand. Procedural roads looked drawn. Evidence: experiment log §10.

### 2026-11-18 · TRELLIS.2 boulders with the shared sandstone material
Area: Art · Status: Decided
The Hugging Face TRELLIS.2 mesh had the better silhouette; the shared ChatGPT sandstone material made both AI boulders match the walls. Evidence: experiment log, AI boulder rows.

### 2026-11-18 · Real 3D walls, not painted cards
Area: Canyon · Status: Decided
Blocky stepped 3D terraces from Blender, textured with fine horizontal strata, give real depth and shadows. Painted cards, projected concept art and cone or rubble shapes all failed. Evidence: experiment log §1 (dead ends).

### 2026-11-18 · Vertex-colour flags only as 0 or 1
Area: Tech · Status: Decided
Blender stores vertex colour as sRGB, so 0.5 arrives in Godot as about 0.21. Binary values survive the conversion.

### 2026-11-16 · Godot 4.7.2 with Forward+
Area: Tech · Status: Decided
The engine and renderer for the whole project, with Git and GitHub (`spyrostrimis/balance5`).

## 2026-11-22 · Approach 3 keeps the proof’s scale and uses one painted destination
Area: RPG canyon · Status: Verified in the playable study

The modular entrance test kept the commander about one fifth of the screen high. The direct illustration reduction made the scarf, face, blue armour and rifle easier to separate. Approach 3 uses that front idle, drawn rear and profile poses, and a continuous painted road. The rock pieces that can cover her are traced from that same painting so their feet and shadows stay in place. The camera leads toward a single gate on the upper pass. The gate and the entire commander fit together when the north barrier stops her.

The gate gets its bright opening and light shafts from the painting. The shallow live surface light remains on by default. Added moving shafts are available on G for comparison. Overall look and walking style remain open for the owner’s review. [Study and matched evidence](CANYON_APPROACH_3_HANDOFF.md#implementation-and-verification)

## 2026-11-25 · 2D Painted Forest Fight 2 uses explicit 2.5D depth lanes, a foreground cave lip, and HD close-up combat art
Area: RPG 2D · Status: Verified in the playable study

At *Streets of Rage 4* close-up framing (~36% of the 768-pixel viewport, ~275 pixels tall), enlarging the 149-pixel exploration sprite nearly doubled its pixels and exposed the two-frame combat walk. **2D Painted Forest Fight 2** keeps the existing exploration sheet on the forest trail, cuts through a foreground stone-arch lip and three-beat sunlit doorway transition into the cave, and switches to a six-pose HD painted profile sheet (idle, four-frame walk with passing poses, and recoil) anchored at the boots so left/right mirroring never shifts her feet. Inside the cave, the Commander, three diving alien-mutant bats, and horizontal rifle bolts track separate ground-plane `depth_y` lanes and vertical `altitude`, keeping floor shadows grounded and ensuring horizontal shots hit only in-lane targets at barrel height. Evidence: experiment log §25.

## 2026-11-25 · 2D Painted Forest Fight 3 unifies exploration and combat in one strictly-isometric 360° mode
Area: RPG 2D · Status: Verified in the playable study

To test a single-mode alternative with no perspective-to-parallel camera shift and no exploration-vs-combat switch, **2D Painted Forest Fight 3** locks a parallel isometric camera (`zoom = 1.0`, constant `144.6 px` / `18.8%` hero height) across both a sunlit cliff-ridge forest walk and a dreamy Miyazaki pastel crystal cavern. The Blue Commander uses a normalized 8-direction isometric atlas (`SE, NE, E, S, N` + horizontal mirroring) and fires 360° bolts from frame one—letting an upside-down bat sleeping under an oak bough ambush her right on the forest trail before she dissolves into the three-bat cavern encounter. Evidence: experiment log §27.

## 2026-11-26 · RTS Isometric 2— Forest Claim Carbon proves Fight 4's 35.264° painted look on a strictly modular isometric RTS kit
Area: RTS · Status: Verified in the playable study (owner visual verdict open)

**RTS Isometric 2— Forest Claim Carbon** (`scenes/maps/rts_isometric_2_forest_claim_carbon.tscn`) carries **2D Painted Forest Fight 4**'s exact `35.264°` orthographic true-isometric basis (`±30°` ground axes) into Mission 1 on Blue's tropical forest cliff shelf without any whole-scene painted backdrop or hand-edited walk mask. A `36 × 36` logical cell grid keeps speeds, ranges, footprints and `AStarGrid2D` pathfinding isotropic while a single `RtsIsoTransform` drives ground rendering, 4-corner and cliff-edge picking at Command (`1.0×`) and Close (`1.55×`) zooms, and an isometric-aligned Dune II minimap. Separating tree sprites into exact Porter-Duff complementary trunk and crown layers keeps trunks solid blockers while overhanging boughs smoothly turn translucent (`alpha ≈ 0.40`) over squads underneath. Swapping from Layout A to Layout B (`scenes/rts_iso_carbon/layout_*.tres`) using only placement and terrain data re-joins the modular cliff bluffs across the southeast road and cleanly reroutes the Blue Vanguard Tank around a northern woodland flank. Owner visual comparison against Codex's parallel study remains **open**. [Study and matched evidence](RTS_ISOMETRIC_2_FOREST_CLAIM_CARBON.md)
