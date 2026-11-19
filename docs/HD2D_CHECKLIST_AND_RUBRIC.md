# HD-2D Visual Checklist & Regression Rubric

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
- [ ] Conceal the far road end at spawn with one right-hand gateway outcrop and reveal the crater on approach. Preserve clearance, landmark timing and the grounded exit.
- [ ] Measure localized shafts against the accepted gateway control, then prove selection and a reachable move order at tactical framing.
