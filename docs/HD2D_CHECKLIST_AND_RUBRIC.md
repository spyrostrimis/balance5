# HD-2D Visual Checklist & Regression Rubric

## 2D painted tropical forest · 2026-11-24

- [x] Verify the four connected stretches in a 1376 × 768 Forward+ viewport. The Commander fits in the clearing with its landmark visible.
- [x] Check a full round trip, both sides of the trail, stops and reversals inside all three blend bands. Size stays fixed while the camera settles at a stop.
- [ ] Owner chooses the painting and judges the guide-free motion. Some sole drift remains in the four existing walk poses.

[Matched stills, recording and fit overlay](../assets/scenes/forest_test/REPORT.md)

## 2D canyon · Approach 3 assessment · 2026-11-22

- [x] Captured both 2D baselines at the entrance, bend, upper pass and north barrier. Compared the standing commander across two art sources and two rendering sizes at matched framing.
- [x] Verified the proof-sized front, rear and mirrored rifle poses on pale stones and in shade. Kept the commander fully framed below the one gate when the north barrier stopped her.
- [x] Walked around the same foreground boulder in both directions, with its base and the edge of its shadow fixed to the painting.
- [ ] Owner reviews the walking motion and chooses how Approach 3 compares with the earlier studies.

[Matched frames and acceptance checks](CANYON_APPROACH_3_HANDOFF.md) · [Independent assessment with four matched views per study, 23 November 2026](../output/pdf/painted-canyon-approach-3-review.pdf)

## Sculpted Bend · camera comparison · 2026-11-22

- [x] Matched the commander's on-screen height to both 2D approaches, with fixed angle and scale through the 1376 × 768 walk.
- [x] Verified C in both directions at three stops. The higher view shows the path and nearby rocks. The original framing shows the arch at the overlook.
- [x] Verified the round trip, ground contact, corridor, navigation, exit signal and exported Play and Esc return.

[Matched frames and walk](CANYON_SCULPTED_BEND.md#parallel-projection-camera)

## 3D Canyon · Sculpted Bend · 2026-11-22

- [x] Captured the 3D Kit Canyon before changing the framing. The standalone study's tall inside wall partly screens the vista at the bend, and the lower shelf leaves the outside open.
- [x] Checked individual raised stones, a matched flat road, longer curb stones and three solid succulent silhouettes in Forward+. The walking floor and light stayed paired. Focus uses only a light native depth-of-field effect.
- [x] Captured the model and painting from identical entrance, bend and exit camera poses. Walked out and back, stopped, stepped sideways, reversed and reached the exit without losing floor contact.
- [x] Checked corridor sides, both end caps, navigation and the exit signal. Verified the Developers Page, Esc and three landmarks in both Godot and the Windows executable.
- [ ] Match Painted Bend's cohesive rock-to-terrace composition and Approach 2 Modular's verge detail. The 3D shelf has broader faces and the modeled distance is less articulate than the painting.

[Frames, recording and measured stops](CANYON_SCULPTED_BEND.md)

## 3D Kit Canyon · v2 · 2026-11-22

- [x] Standalone playable scene (`scenes/maps/canyon_v3_kit_v2.tscn`) with all debug HUD labels and switching hotkeys removed (`WASD`/Arrows walk, `Esc` returns).
- [x] `img1` cobble road (`28` colours), `art_gemini` sand & dunes (`24` colours each), and `art_road_goal` cliff look (`<= 29` colours per object across every rock, curb, plant, commander and crater).
- [x] Uniform `64.0 texels/m` across every surface, unscaled `1:1` metric meshes (`cliff_rock_0..5`, `rubble_0..3`, `road_boulder_0..2`, `curb_0..5`) and sprites (`40×82` Blue Commander, `384×256` Orichalcum crater), with cyclic minimum-error seam cuts (`<= 1.20`) on all tiling textures.
- [x] Organic sculpted bedrock tiers (horizontal world-Y strata, weathered sandstone shelves instead of concrete paving) with `111` cliff rocks, `42` rubble, `54` curbs, `7` boulders and `74` plants seated flush with zero interpenetration (`tests/test_canyon_v3_kit_v2.gd` `PASS`).
- [x] `-42.0°` oblique near-parallel camera (`fov = 22.0°`, offset `(0, 11.83, 12.13)`, `~17.0 m` hero distance, `42°` boot-anchored commander pitch tilt) matching `2D Parallel-Projection · Approach 1 vs 2` framing, plus flared cliff exit jaws (`Z = -24.0`) framing the full `OrichalcumCraterGround` at `Z = -18.0` (`InFrustum=true`).
- [x] `4× MSAA`, `8×` anisotropic filtering, derivative sharp-pixel AA and sprite edge AA verified in `1376×768` Forward+ captures ([KV2_pos1_start.png](../render_captures/kit_v2/KV2_pos1_start.png) · [KV2_pos2_midway.png](../render_captures/kit_v2/KV2_pos2_midway.png) · [KV2_pos3_exit.png](../render_captures/kit_v2/KV2_pos3_exit.png)).

## Pixel Canyon · Painted Bend · 2026-11-21

- [x] Compared three ChatGPT paintings at matched 960×540 camera positions with the gameplay sprite.
- [x] Fitted the curbs and stairs to the playable bend and used the original near-wall outline. Verified the stop, reversal, full twin-arch reveal, sideways crossing and return in Forward+.
- [x] Inspected the in-game overlook beside Arch Overlook at the same display size.
- [x] Compared three live framings at the same bend stop. Moving the commander toward the lower left reveals the twin arch earlier while preserving the wall overlap.
- [ ] Match the original painting's fine stone detail and clear visual lead to the arch. The fitted foreground at the bend is softer and takes up much of the view.

[Painted Bend study and evidence](PIXEL_CANYON_SESSION_B_PAINTED.md)

## Pixel Canyon · Session B · 2026-11-21

- [x] Walks both ways around one 2D bend with fixed-size cobbles and commander. The near wall masks her in both directions and the camera reveals both spans.
- [x] The curb leads up to the attached terrace steps. The marked stair and its surroundings match pixel for pixel on the return.
- [x] Recorded 19.2 seconds in a 1376×768 Forward+ window with a stop, a reversal and a sideways crossing.
- [ ] Owner reviews the elevated view and the simpler cliff tops and valley beside the original painting.
- [ ] Keep the commander readable throughout the bend. The wall covered up to 95.9% of her opaque sprite pixels between the marked stops in a follow-up run.

[Session B results](PIXEL_CANYON_SESSION_B.md)

## Pixel Canyon III · Through the Bend · 2026-11-21

- [x] Recorded the same rough route with exact follow and 8-pixel leeway. Matched stops and a reversal inside the bend in both runs.
- [x] Captured the painted round trip at the native 960×540 size in a 1376×768 window, including both directions around the bend.
- [x] Verified the 317–333 boot band, immediate camera stops, the scout block and lane checks, and both road edges. The scout stays cleared on the return.
- [x] Verified the separate Play card and Esc return with the exported Windows package.
- [ ] The rock walls connect visibly to the ground and continue around the bend. The overlook terrace sits on its cliff in both directions. The cutout pass failed this check.

[Through the Bend captures and measurements](PIXEL_CANYON_FOLLOW_STUDY.md)

## Pixel Canyon camera and depth · 2026-11-21

- [x] Captured A, B and C at four matched boot points. A preserves the original standing composition and the calibrated commander stays 125 art pixels tall there.
- [x] Inspected the boots, rifle and face at the bend. Walked both sides of the shrub and fired a miss and a hit in each mode.
- [x] C holds through the nearby fight, retraces on reversals and fills the frame at 24 art pixels of travel. F2 restores the live view and the room switch uses the new room's framing on its first frame.
- [ ] Owner chooses the first-room framing and approves the draft heights.

[Matched stills and recordings](PIXEL_CANYON_CAMERA_STUDY.md)

## Standalone 2D Pixel Canyon · 2026-11-21

- [x] Untouched 960×540 art matched the supplied 1920×1080 preview exactly in the game.
- [x] Inspected the empty cobbles at 1× and 2×. Verified original position and foreground overlap from behind and in front.
- [x] Ran the horizontal miss, hit and two-way transition in Godot. Recorded the real game at 30 fps.
- [ ] Owner reviews the walk and the adjoining view for the RPG art decision.

[Art findings and evidence](PIXEL_CANYON_STUDY.md)

---

**Target Reference:** `assets/textures/maps/desert_approach_rpg_albedo.png` (**Img 1 / Picture 1**) + *Octopath Traveler* 3D diorama camera/terrain structure.

> **Goals, not parameters.** A `[x]` records that a build met a visual goal from Img 1. It protects against *accidental* regressions while working on something else. It is not a lock. Any value in it can change on purpose (camera, sun, route, blur method, reveal timing) when the change serves Img 1 better. To make that change, name it in the test, capture matched before/after views and update the item. The numbers in "Verified in" lines are records of what passed, not requirements.

### Tunable composition parameters

Judge these against Img 1. Baselines exist for A/B comparison only.

| Parameter | D4b / bend baseline | Canyon v2 now | Notes |
| --- | --- | --- | --- |
| Camera pitch, offset, FOV | −13°, (0, 3.8, 12.6), 30° | −21°, (0, 5.5, 11.9), 30° | −13° shows the horizon in the top fifth. The ultra-crisp test found −17.5° crisper, and −21° hides the sky as Img 1 does. Retune when the route or walls change. |
| Camera follow | X × 0.35, no yaw | 60% route centre, 45% yaw to the road 9 m ahead | |
| Sun direction | Behind-right, (−42°, 38°) | Ahead-right (backlit), (−42°, 145°) | Backlight gives the right-wall shadow across the road. |
| Route curve | `0.65 · sin(0.22 z)` | 2 m S-curve, editable `Path3D` | |
| Air | Exponential fog 0.0075, rock haze 0.24 | Fog off, rock haze 0.10 | Fog washed the steeper view to beige. |
| Focus | Screen-height canvas blur | Native DOF 10 / 16.5 m, 0.014 | One method per capture. |
| Landmark reveal | Glint visible by midway | Glint revealed at the exit | A pacing choice, not a requirement. |

---

## 1. The 8 Core Reference Checkboxes

The D-series records below describe their recorded builds. For the current integrated walking control use [ChatGPT AI Boulders](../scenes/maps/desert_canyon_chatgpt_boulder_test.tscn). [Commit review, comparisons and walk evidence](EXPERIMENT_LOG_AND_LESSONS.md#integrated-canyon-review)

1. **`[x]` Structure — Blocky Stepped Sedimentary Terraces:**
   - Flat horizontal stone tops, near-vertical striated rock faces (`85°–90°`), stepped courses with crisp, subtle `0.025–0.035m` edge bevels.
   - **NEVER** use fluted radial cones (`D2`), heavily sheared triangular rubble piles (`D3`), or smoothed/blobbed boulders for terrace walls.
2. **`[x]` (Left) / `[ ]` (Right) Height & Screen Framing — Above Camera:**
   - Judge the silhouette from the 3.8 m camera height. D4 used 5.95 m high courses. D4b added taller outer courses where the upper-left sky showed through. Allow recessed openings along the bend.
   - *Verified in Strata Wall (D4b):* Left `Course 7` (`7.55m`) + `GatewayBluffLeft` (`8.15m`) frame the entire left viewport cleanly up to the top-left corner with zero sky wedge.
3. **`[x]` (Left) / `[ ]` (Right) Continuity — Long Terrace Courses Following Path:**
   - Continuous abutting/overlapping stepped rock bands following `_path_cx(z)` with deliberate recessed coves (`0.3m` overlap between `6.5m` slices) — not isolated rock islands with gaps showing the floor behind them.
   - *Verified in Strata Wall (D4b):* Left wall (`5` overlapping slices, `Z = +14.8` to `-10.0`) has zero seams or gaps, with deepened foreground coves (`0.54m`) holding boulders cleanly.
4. **`[x]` (Left) Texture Scale & Orientation — Fine Horizontal World-Y Strata:**
   - Fine horizontal sedimentary bedding lines in warm terracotta (`RGB [44,21,11]` crevice shadows, `[115,60,36]` midtones, `[209,138,91]` sunlit faces) — never large marbled wood/leather swirls or uniform ruler stripes.
   - *Verified in Strata Wall (D4b):* Horizontal rock beds vary organically across blocks (`horiz_mod` + warped world-Y `strata_rib`), and vertical sides of dark Course 0–1 use flipped horizontal dry-stone masonry instead of diamond paving cracks.
5. **`[x]` Ledge Top Color — Warm Grey-Brown Weathered Stone:**
   - Step tops and lower dark stepped courses use weathered grey-brown / warm slate (`vec3(0.024,0.017,0.013)` to `vec3(0.115,0.080,0.055)` linear on dark walls; softened granular slate tops) — not near-black coal or chalky white limestone.
   - *Verified in Strata Wall (D4b):* Fixed linear-space brightness bug cleanly; dark lower terraces frame the golden path and terracotta cliffs with strong HD-2D contrast.
6. **`[x]` (Left) / `[ ]` (Right) Blur Discipline — Camera Filter Only (No Blurry Cutout Wings):**
   - Retire painted wing cutouts as 3D geometry replaces them. Keep source art sharp. Record the focus method with each capture. D4b used `TiltShiftDof` on a canvas layer. Since the bend, the native camera DOF is preferred. Canyon v2 has no painted cards on either side.
   - *Verified in Strata Wall (D4):* `LeftWing_*` and `GatewayWingLeft` removed cleanly with zero blurry floating blobs on the left side.
7. **`[x]` Boulders & Curbs — Isolated Golden Boulders + Clustered Flagstones:**
   - Faceted warm-ochre boulders encoded with binary vertex color `COLOR.b = 1.0` (`COLOR.r = 0.0`) so zero dark cap texture leaks onto boulder crowns, placed in coves clear of the Hero (`|dx| >= 1.5m`), alongside flat clustered curb stones with sandy breaks.
8. **`[x]` Bushes & Sun Lighting — 2.5D Sagebushes + One Real `DesertSun`:**
   - The sagebushes are unshaded alpha-cut sprites with side-specific tint. One directional `DesertSun` casts real shadows across the road and walls. Its direction is a tunable composition parameter (see the table above). Verify a new wall's shadow using matched casts-on/off captures.

---

## 2. Per-Test Checkbox Matrix (Chronological Truth Table)

| Criterion | Test A | Test B | Test C1 | Test C2 | Test D1 | Test D2 | Test D3 | Strata Wall (D4) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Blocky Stepped Structure** | `[ ]` (flat) | `[ ]` (flat) | `[~]` (2.5D card) | `[~]` (2.5D card) | **`[x]`** | `[ ]` (cones) | `[ ]` (rubble) | **`[x]`** (Left) |
| **2. Wall Height (`5.0–6.0m` Above Cam)** | `[ ]` | `[ ]` | `[ ]` (`2.4m`) | `[ ]` (`2.4m`) | `[ ]` (`2.35m`) | `[ ]` (`2.38m`) | `[ ]` (`2.38m`) | **`[x]`** (`5.95m` Left) |
| **3. Continuous Path-Following Courses** | `[ ]` | `[ ]` | `[ ]` | `[~]` (clones) | `[ ]` (gaps) | `[ ]` (islands) | `[ ]` (rubble) | **`[x]`** (Left `0.3m` overlap) |
| **4. Fine Horizontal World-Y Strata** | `[~]` (blurry) | `[ ]` (inked) | `[~]` (blurry) | `[~]` (medium) | `[ ]` (swirls) | `[ ]` (swirls) | `[ ]` (swirls) | **`[x]`** |
| **5. Warm Grey-Brown Ledge Tops** | `[~]` (blurry) | `[ ]` | `[~]` (blurry) | `[x]` | `[ ]` (charcoal) | `[ ]` (charcoal) | `[ ]` (charcoal) | **`[x]`** |
| **6. Camera-Only Blur (No Wing Blobs)** | `[ ]` | `[ ]` | `[ ]` | `[ ]` | `[ ]` (wings on) | `[ ]` (wings on) | `[ ]` (wings on) | **`[x]`** (Left only) |
| **7. Clean Golden Boulders & Curbs** | `[ ]` (flat) | `[ ]` (flat) | `[ ]` (card) | `[~]` (card) | `[ ]` (bleed/close) | `[x]` (boulders) | **`[x]`** | **`[x]`** |
| **8. Bushes & Real 3D Sun Shadows** | `[ ]` | `[ ]` | `[~]` | `[~]` | `[~]` (small) | **`[x]`** | **`[x]`** | **`[x]`** |

> Legend: `[x]` verified pass · `[~]` partial · `[ ]` fail / not yet met.

The matrix above ends at D4. The numbered checks record the D4b left-wall refinements. The bend-specific proofs appear below. [Acceptance criteria](CANYON_BEND_SESSIONS.md)

## 3. Bend Session 1 — One right-hand module

| Check | Verdict | Evidence |
| --- | --- | --- |
| Blender notch survives reimport | `[x]` | Recess changed from 0.10 m to 0.78 m in the same GLB dependency. The existing placed instance showed the deeper cut with matching placement, material override and blocker. |
| Real `DesertSun` shadow on cobbles | `[x]` | Stationary exit A/B isolated the buttress caster. Its shadow covered an entire marked stone, with a mean 52.63-level RGB difference over the stone. |
| Fixed landmark reveal and playable route | `[x]` | Crater glint hidden by the mesh at spawn and visible from midway. Commander grounded at every 1376×768 stop and the exit signal fired. |

The test passed at `res://scenes/maps/desert_canyon_buttress_test.tscn`. Overall right-wall continuity and card replacement remain open beyond this single module. [Measurements, captures and reproduction](EXPERIMENT_LOG_AND_LESSONS.md#5-bend-session-1--one-right-hand-buttress)

## 4. Bend Session 2 — Ground and focus

| Check | Verdict | Evidence |
| --- | --- | --- |
| Metre-scaled, seam-controlled road | `[x]` | 4 m repeat and a 0.327 m reference stone. Wrap-to-neighbor ratios 0.94× X and 1.52× Z. Both terrain maps have 10 mip levels, and the three stops clear the curb geometry. |
| Road art quality at gameplay distance | `[ ]` | Compare the concept with matched spawn and midway crops around the boots. Look for recognizable staggered courses across the direction of travel, softly rounded worn crowns, occasional wedge stones, warm recessed joints and sand breaking up the verge. Check crown relief under directional light. The current polygon pattern and even beige faces miss these cues. |
| Camera-depth focus on the playable band | `[x]` | Matched effects-off, D4b screen height and native captures. Boots and nearby paving match the off control. A ledge at the face's screen height softened at 18.59 m, and the moving sprite kept its silhouette. Selected native range 10–16.5 m at `0.014` amount. |
| Final playable bend | `[x]` | 1376×768 Forward+ walk grounded at all three stops with confirmed exit signal. The crater glint revealed by midway and the buttress shaded a full new cobble in the matched A/B. |

The one-bend milestone passed at `res://scenes/maps/desert_canyon_bend.tscn`. The retained right cards and overall right-wall continuity remain open on the original rubric. [Session 2 results and reproduction](EXPERIMENT_LOG_AND_LESSONS.md#6-bend-session-2--ground-and-focus)

## 5. Crisp Road & ChatGPT Texture Trials (Isolated Ground Branch)

| Check | Verdict | Evidence |
| --- | --- | --- |
| Solve `-13°` soft-edge blur (`2048²` + ORM) | `[x]` | Split-patch at locked `-13°` (`1_locked_cam_split_patch_pos1_start.png`) restored sharp stone lips (`X=1.32×`, `Z=1.06×`). |
| ChatGPT Albedo + Height (`3.2 m` + ORM) | `[x]` | Matched `0.8145` correlation, `1.12×/1.10×` wrap, clear natural chipping & color variation (`desert_canyon_chatgpt_road_test.tscn`). |
| Camera angle crispness lift (`-17.5°` vs `-13°`) | `[x]` (trial) | `Y=4.85 m, Z=12.2 m` (`-17.5°`) improves stone/terrace legibility without cropping horizon mountains (`-21°` crops ridge). |
| Editable Krita / Aseprite / Tiled masters | `[x]` | Exported `chatgpt_cobble.kra`, `chatgpt_cobble_1024.aseprite`, `chatgpt_cobble_pixel_256.aseprite`, and `tiled/canyon_road_sandbox.tmx`. |

## 5. Bend Session 3 — Hand-laid sandstone

| Check | Verdict | Evidence |
| --- | --- | --- |
| Metre scale, seam control and mipmaps | `[x]` | 4 m repeat, 0.383 m reference stone, 1024² maps and 10 mip levels per map. Albedo wrap ratios 1.04× X and 1.04× Z. Normal ratios 0.78× X and 1.11× Z. |
| Road art at gameplay distance | `[x]` | Staggered transverse sandstone, warm recessed joints and local sand incursions separate the road from the curbs. Crown relief is visible in the fixed-sun normal toggle. Wedges and relief are subtler in shade. |
| Playable comparison | `[x]` | Matched grounded stops and confirmed exit signal. Original glint revealed at midway and buttress shadow covered a full sett. Launch and Esc return passed. |

`res://scenes/maps/desert_canyon_handlaid_sandstone.tscn` is the road variant. Right gateway and atmosphere are separate future passes. [Measurements and screenshots](EXPERIMENT_LOG_AND_LESSONS.md#7-bend-session-3--hand-laid-sandstone)

## 6. Road crispness — One patch

| Check | Verdict | Evidence |
| --- | --- | --- |
| Oblique road detail | `[x]` | 4× anisotropic sampling improves the registered patch edges at 1376×768. Higher tested settings add negligible detail. Mipmaps and 4 m mapping verified. |
| Readable sandstone patch | `[x]` | Pale crowns, tighter warm joints and several chips read at gameplay size and over the sampled walk. The concept has deeper small-scale shadowing. |
| Four shallow geometry crowns | `[ ]` | Rounded geometry changed form shading but drew no measurable extra cast shadow in the crop under the existing sun. Keep the textured patch for comparison. |
| Playable comparison | `[x]` | Matched grounded stops, landmark and exit signal. Menu launch and Esc return passed. |

Play `res://scenes/maps/desert_canyon_crisp_road_patch.tscn` for this experiment. [Measurements and screenshots](EXPERIMENT_LOG_AND_LESSONS.md#8-road-crispness--one-patch-at-spawn)

### Nine-stone road detail at walking distance

- [x] Compare the Session 3 surface, new flat artwork and shallow relief at identical camera, sun, sampling and native crop size. Inspect both orientations of edge contrast.
- [x] Demonstrate a real cast-shadow contribution from the small raised stones. In the matched toggle, 26 pixels darkened by more than three RGB levels. Both flat controls gave zero.
- [x] Cross the insert on foot and verify floor contact, the exit signal and Developers Page controls.
- [ ] Match the concept's separation between rows and its darker sand-filled joints across a continuous stretch of road. The nine-stone study only establishes the local detail result.

[Study results and sources](EXPERIMENT_LOG_AND_LESSONS.md#nine-stone-road-study-at-spawn)

- [x] Raise every road stone, not a patch: height-map displacement on a dense strip (A/B key R) makes the stones read as raised at play distance (6 cm is too high to look walkable; default 2 cm) for about 0.6-0.8 ms of GPU. Joints hide behind the stones at -21 degrees. [Section 14d](EXPERIMENT_LOG_AND_LESSONS.md#14d-raised-stones-along-the-whole-road-and-two-free-packs-2026-11-20)

### Integrated road and boulders

- [x] Verify the exported image-authored road at 3.2 m per repeat and compare the native and shared-material Trellis boulders at spawn. Both play from their own cards.
- [x] Ground contact at the three camera stops, blocked glint at spawn, clear glint by midway and exit signal on the integrated build.
- [x] Assemble and verify **3D Canyon · Way 1B Free 3D Modules** (`scenes/maps/canyon_way1b_free_3d.tscn`) using real photogrammetry cliffs (`Namaqualand Cliff 01/02`, `Rock Face 01/02`), 3D curb blocks (`Rock 07`, `Namaqualand Boulder 03/05`), 3D cobblestones (`Namaqualand Stones 01`, `Moon Rock 04`), 3D `Cheiridopsis Succulent` plants and `Sand Rocks Small 01` verge banks, and exit arch/gorge (`Mountain Desert 009`, `Canyon River Terrain`) alongside the kept Trellis boulders and pale Grand Canyon rock, with verified spawn occlusion (`25.94 m`) and midway/exit reveal. [Study and captures](CANYON_WAY1B_FREE_3D.md)
- [ ] Conceal the far road end at spawn with one right-hand gateway outcrop and reveal the crater on approach. Preserve clearance, landmark timing and the grounded exit.
- [ ] Measure localized shafts against the accepted gateway control, then prove selection and a reachable move order at tactical framing.
