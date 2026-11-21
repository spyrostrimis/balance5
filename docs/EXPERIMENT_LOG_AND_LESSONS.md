# Experiment Log & Hard-Won Lessons

## Pixel Canyon · Painted Bend · 2026-11-21

Tried a full ChatGPT painting on Session B's existing map. Compared three candidates at the live camera stops and chose the warm-and-cool light pass. Its pale arch and stair edges read clearly against the violet canyon. The raw candidates moved the near wall away from its place over the road. Fitting the ground and near wall as separate Krita layers restored the original foreground overlap. The 19.2-second Forward+ round trip matched Session B's boot positions, camera centres and wall coverage at the marked stops. The overlook is the strongest view. The near wall at the bend still dominates the frame, and fitting the rock softened its finer marks. Keep the original painting as the quality target. [Paintings, walk and verdict](PIXEL_CANYON_SESSION_B_PAINTED.md)

At the same bend stop, a separate live camera comparison placed the commander's boots at the centre and then toward the lower left. The lower-left framing brought both arch openings into view earlier. The same rock still covered her boots in all three frames. This gives us a way to tune the reveal by scrolling the painting. The viewing angle is already drawn into the stair treads, arch faces and cliff tops. [Three framings at one ground point](../render_captures/painted_bend_review/framing_comparison.jpg) · [Independent round trip](../render_captures/painted_bend_review/round_trip.mp4)

## Pixel Canyon · Session B · 2026-11-21

The elevated 2D map kept the curb, cliff, stair and railing in one drawing as the camera followed the commander. A pixel crop around the marked step matched on both passes. Her sprite was 63% covered by the near wall on the way up and 61% on the way back at the matched stop, and fully visible at the overlook. The first arch span entered the frame during the wall approach. Both spans appeared without a scale change. The matched capture shows the trade-off clearly. An elevated view shows more of the terrace plan and less distance into the valley. Broad cliff tops and quieter colours give the draft a simpler look than the reference. [Session B frames and measurements](PIXEL_CANYON_SESSION_B.md)

An independent 576-frame Forward+ run reproduced the round trip and matching stair crop. Tracking wall coverage every physics tick found a peak of 95.9% along the scripted path. During the 116-pixel sideways crossing at the overlook, the camera stayed at its right map limit. An additional walk from the road up the drawn staircase hit the road boundary before reaching the terrace deck. For visual review, watch the commander between the marked stops and try walking to the landmark. [Fresh round trip](../render_captures/session_b_owner_review/round_trip.mp4)

## Pixel Canyon III · Through the Bend · 2026-11-21

Recorded the rough route in Forward+ with exact follow and 8 art pixels of leeway. The 8-pixel band held the view still on the first steps of a reversal and kept the standing commander within 121–129 art pixels. At the original (511, 325) boot point she is 125 pixels tall. Used leeway as the draft default and kept both modes playable.

The 48.2-second round trip passed the route, shot, reversal and exported catalog checks. The painted environment failed owner review. The fore- and midground cutouts scale as flat images from a single anchor. Their bases break away from the road verge, the right ruin reads as one sliding surface, and the left overlook terrace looks suspended over the valley. Moving the ruin improved character visibility and left the continuity problem intact. The result repeats the limits seen in C1/C2, even with sharp source art. Keep the playable control and its camera measurements. A new method must show one connected wall, shelf and overlook in both directions before full-route art. [Visual findings and options](PIXEL_CANYON_FOLLOW_STUDY.md#why-the-environment-failed)

## Pixel Canyon camera and depth · 2026-11-21

A uses the current stepped sprite sizes. B uses four cobble-calibrated marks with smooth changes between them and a fixed view. C adds a whole-pixel uphill follow from boot Y 300, capped at 24 art pixels. The upper-road and gate silhouettes fit the paving and curb better in B. The boots and rifle stayed distinct at 1080p. C brings the figure lower in the frame and shows more sky, with the bend still visible.

The three Forward+ runs reuse the same route, with stops and a reversal added for review. Each crossed both sides of the shrub, registered a miss and hit, and passed the bend in both directions. Camera offset was 0 on the first overlook frame and 19 on the first frame back at the bend. B and C match across their overlapping pictures when the offset is removed. At the 24-pixel limit the extension covers every new row. Switching away to F2 and back restores pixel-identical views. [Four matched views, 1080p recordings and working art](PIXEL_CANYON_CAMERA_STUDY.md)

## Standalone 2D Pixel Canyon · 2026-11-21

This study starts with the supplied 960×540 reference and uses a dedicated 2D canvas. The untouched capture and 1080p preview have zero differing RGB pixels. The repair changes 7,785 pixels around the figure and cast shadow. Matching the outlines of the borrowed stones to the road joints took the most manual work.

Verified the reference stance at (511, 325), the shrub crossing at y377 and y425, a clear miss from y384 and a hit from y354. The return from Arch Overlook leaves the encounter cleared. Tested in the actual Forward+ window and recorded 27.2 seconds of gameplay. The second room's pale twin arch and upper-right light carry through, with a wider vista and brighter foreground cobbles. [Art, review and playback](PIXEL_CANYON_STUDY.md)

> Always check **Section 1 (Proven Dead Ends)** before proposing a rendering technique, shader trick, or mesh generator.

## Integrated canyon review

Reviewed the playable scene history through `3363886`. The newest published level is **ChatGPT AI Boulders** at `246e989`. It inherits the 3.2 m image-authored road, with the original 30° FOV, −13° pitch and Session 2 native depth of field. The two boulders appear beside the commander at spawn. The nine-stone study remains a separate local comparison.

| Revision | Playable result or handoff | What to carry forward |
| --- | --- | --- |
| `93da996` | Road Crispness Test and Four-Crown Relief Test | The textured patch gained legible edges. The four rounded crowns produced no measurable cast-shadow change in the original comparison. The later nine-stone study isolated two lips that did cast small shadows. Reserve mesh relief for exposed edges that read at walking distance. |
| `88f25da` | 2048px Cobble Road, 4 m repeat | The joints survive the grazing angle, but their regular dark outlines compete with the commander. Keep this as the high-contrast control. |
| `1c23695` | ChatGPT Cobble Road, 1024px over 3.2 m | Best full-road candidate in the matched spawn views. Broken edges and sand interrupt the outline. It is still bright and repetitive toward the horizon. The tile, scale and shading all changed across the road studies. Resolution alone cannot explain the result. |
| `e4e0c7e` | Editable Krita and Aseprite sources plus Tiled sandbox | Authoring handoff for the same road. There is one Godot road build for these two commits. |
| `b2f0f26` | Trellis Boulders — Native Materials | The HF mesh has the more legible layered silhouette. The native Trellis3D.net material reads darker in the comparison. The exported meshes contain 16,969 and 11,258 triangles respectively, before any import LOD. |
| `246e989` | ChatGPT AI Boulders, shared 1.65 m sandstone and box blockers | Both boulders pick up clear horizontal bedding. The right boulder benefits most. Both are quite pink against the dark slate wall at spawn. Their positions mainly affect the foreground. |
| `3363886` | Developers Page update | Added menu references. The standalone level and its materials come from earlier commits. |

Independent checks on the exported albedo pixels gave X/Y wrap-to-neighbor ratios of 1.32/1.06 for the procedural road, 1.12/1.10 for the image-authored road, and 1.02/1.32 for the boulder sandstone. The camera trials at −17.5° and −21° change framing. Anti's harness forces 16× anisotropy. Its 3.2 m split-patch comparison also samples the Session 3 control at 3.2 m. Use the standalone 4 m Session 3 scene and a matched camera for a production comparison. [Road detail captures](../render_captures/chatgpt_road_test/comparison_chatgpt_road_detail.png)

The integrated control passed a fresh 1376 × 768 Forward+ walk. The commander was grounded at Z +6.000, −3.525 and −14.025 m. The ray to the fixed crater glint hit the buttress at spawn and cleared by midway. The exit signal fired at the final stop. The broad yellow opening and straight visible road remain at spawn. Replacing the right gateway card with one asymmetric outcrop is the next composition test. Grade the reveal at the same camera before adding shafts or switching to the tactical camera. [Three stops](../render_captures/catalog_review/integrated_walk.jpg) · [Walk log](../render_captures/catalog_review/integrated.log)

The launcher checks covered main Play, all 13 playable cards, both static previews, commander movement and the return controls. A UTC milestone on a listed Play entry makes it eligible for main Play. Cards for available local studies remain accessible. The Windows Desktop export target is `builds/Balance.exe`. [Catalog smoke log](../render_captures/catalog_review/menu.log)

---

## 1. Proven Dead Ends (Never Repeat & Why)

1. **Unprojecting / Mapping Img 1 (`desert_approach_rpg_albedo.png`) Onto Ground or 3D Frustum (`build_test_a_ground.py`, `canyon_projected.gdshader`) — FAILED (`Test A`):**
   - **Why it never works:** Concept art has **baked bokeh blur** in the upper and lower frame and **baked perspective foreshortening**. Once the Hero walks forward (`Z = +6.0` → `Z = -3.52`), the camera looks straight down at stretched, blurry, painted decals of rocks and bushes glued flat to `Y = 0.0`.
2. **Flat 90° Top-Down Ground Strips (`build_test_b_ground.py`) — FAILED (`Test B`):**
   - **Why it failed:** Solved stretching/blur at `pos2_midway`, but roadside ledges had zero 3D height (`Y = 0`), repeated every `6.25m`, left a bare sand gap to the outer cliffs, and carried dark comic-book ink outlines absent from *Octopath* / Img 1.
3. **Blurry 2.5D Diorama Cutout Wings (`build_diorama_wings.py`, `DioramaWings`) — FAILED (`Test C1`):**
   - **Why it failed:** Slicing boulders/ledges/walls out of Img 1 and standing them upright preserved Img 1's baked out-of-focus blur as floating dark silhouettes ("cave mouth" blobs on `LeftWing_*` / `RightWing_*`), with `ground_fade` creating a hazy mist band along the road verge.
4. **Repeating Deep-Focus 2.5D Ledge Cards (`build_test_c2_ledges.py`) — PARTIAL DEAD END (`Test C2`):**
   - **Why it capped out:** Deep-focus (`f/22`) cutout cards removed baked blur and comic outlines, proving that sharp foreground props matter—but repeating 2 cards per side every `3.2m` produced obvious clone stamps, flat card silhouettes when moving in Z, and could not cast real 3D sun shadows.
5. **"De-Cubing" Stepped Terraces Into Cones or Random Rubble (`blender_build_test_d_kit.py` `D2` & `D3`) — WRONG DIRECTION:**
   - **Why it hurt:** Looking closely at Img 1 (`desert_approach_rpg_albedo.png`) and *Octopath Traveler*, the canyon **IS** blocky stepped sedimentary masonry—flat horizontal tops, near-vertical faces, continuous horizontal tiers. Swapping D1's cubes for radial cones (`D2`) created barrel/stump lumps; heavily bisecting and spreading loose prisms (`D3`) created low disconnected rubble mounds well below camera eye height (`3.8m`).
6. **Storing Fractional Material Masks (`0.5`) in Blender `BYTE_COLOR` Vertex Color (`D1`) — TECHNICAL BUG:**
   - **Why it broke:** Blender exports `Col` as sRGB `BYTE_COLOR` (`COLOR_0`), and Godot converts it to linear space on sample (`0.5` → `~0.214`). Shader checks near `0.5` failed, causing `is_basalt` to leak black slate onto boulder tops.
   - **Permanent Fix:** Encode orthogonal/binary flags strictly as `0.0` or `1.0` (both invariant across sRGB ↔ linear). Boulders use `COLOR.b = 1.0`, terraces/curbs keep `COLOR.b <= 0.40`.
7. **Shader Auto-Basalt Based on `world_nrm.y > 0.58` (`D1`–`D2`) — TECHNICAL BUG:**
   - **Why it broke:** Any angled cleavage slope or tilted rock flank above ~35° turned jet-black charcoal even on vertical terracotta sandstone cliffs.
   - **Permanent Fix:** Drive `is_basalt` strictly from Blender `COLOR.r` (`smoothstep(0.45, 0.85, COLOR.r) * (1.0 - is_boulder)`), and set `face_mat = 1.0` in Blender **only** on flat horizontal shelf tops (`n.z > 0.82`) where `cap_basalt_on_top = True`.

---

## 2. Proven Winners (Keep & Build Upon)

- **True 3D Blender → `.glb` → Godot Triplanar Spatial Pipeline (`hd2d_octopath_rock.gdshader`):** Gives real depth parallax, correct Z-occlusion behind rocks as the Hero walks, and crisp real shadows from `DesertSun` (`Vector3(-42, 38, 0)`).
- **D1 Blocky Stepped Terrace Principle + Binary Vertex Color Masking:** Stacked flat-topped rectangular sedimentary courses with subtle (`0.025–0.035m`) bevels + `COLOR.r` (cap vs strata), `COLOR.g` (ambient occlusion), `COLOR.b == 1.0` (boulder isolate).
- **Hybrid 3D Terrain + 2.5D Alpha-Cut Sprites (`Sprite3D`) + Camera-Only `TiltShiftDof`:** Crisp un-haloed desert bushes and Hero sprite sit cleanly inside real 3D rock coves and stepped shelves while `PostProcessing/TiltShiftDof` handles all screen blur dynamically.

---

## 3. Untested / Open Ideas for Upcoming Pieces

- **Right wall.** The single asymmetric module passed Session 1 at the bend. Its placement and evidence are recorded below for the road and lens passes. The rest of the right wall still uses D4b cards and low terraces.
- **Road texture and depth-based focus.** Session 2 validated a metre-scaled top-down tile and selected light native camera DOF. The original cobble audit, lens controls and final playtest are recorded below.

---

## 4. Chronological Test Summary

| Test | Date | Hypothesis / Change | Outcome & Verdict |
| :--- | :--- | :--- | :--- |
| **Test A** | 2026-11-17 | Extract Img 1 ground strip onto `GroundFloorMesh` | Worked only at `pos1_start`; smeared/blurred at `pos2_midway`. **Rejected.** |
| **Test B** | 2026-11-17 | Generate sharp 90° top-down seamless ground strip | Sharp at both stops, but flat `Y=0`, cartoon ink outlines, visible repeat. **Rejected.** |
| **Test C1** | 2026-11-17 | Stand 2.5DImg 1 ledge cutouts upright beside path | True painterly colors, but carried Img 1 blur + soft mist band at base. **Superseded.** |
| **Test C2** | 2026-11-17 | Slice deep-focus (`f/22`) `image-generator` ledge cutouts | Crisp rocks/bushes, but flat-card feel & 3.2m clone repetition. **Led to 3D.** |
| **Test D1** | 2026-11-17 | First Blender 3D modular terraces + boulders + curbs | **Proved pipeline.** Real 3D sun shadows, right blocky terrace concept; too low (`2.35m`), boulder bleed bug (`0.5` sRGB), big swirled texture. |
| **Test D2** | 2026-11-17 | Cones (`sides=6..9`), `COLOR.b=1.0` boulder fix, larger bushes | Fixed boulder bleed & bush visibility cleanly, **regressed** terrace structure into drum/cone lumps + diagonal black cliff stripes. |
| **Test D3** | 2026-11-17 | Sheared prisms, remove shader `nrm.y` basalt override, clustered curbs | Fixed black stripes & barrel look & curbs, **still** read as low scattered rubble (`2.38m`) instead of high continuous canyon walls (`5.8m`). |
| **Test D4 (Strata Wall Left)** | 2026-11-18 | Left side only: continuous blocky stepped courses to `5.95m`, fine horizontal strata, warm grey-brown caps, left `DioramaWings` removed | **PROVEN BREAKTHROUGH on Left.** High continuous blocky stepped cliff frames left viewport cleanly with zero blurry wing blobs and world-Y horizontal strata; exposed 3 polish items (vertical diamond cracks, uniform stripes, top-left sky corner). |
| **Test D4b (Left Polish)** | 2026-11-18 | Left only: softer horizontal dry-stone masonry on Course 0-1, organic broken sandstone strata, `Course 7` (`7.55m`) + `GatewayBluffLeft` (`8.15m`), linear-space dark slate calibration, deepened left coves | **PASSED (`[x]` on Left).** Sealed top-left sky corner, cured chalky linear-space side colors (note: hardcoded shader vec3 `ALBEDO` is **linear**, not sRGB!), broke ruler stripes, kept Hero/Camera locked (`on_floor=true`). |
| **Bend Session 1 (One Right Buttress)** | 2026-11-18 | Place one reimportable 6.47 m right buttress into a playable D4b derivative | **PASSED.** Blender notch survived reimport, the buttress shaded a full cobblestone, and the crater glint revealed by midway on a grounded walk with a confirmed exit signal. |
| **Bend Session 2 (Ground and focus)** | 2026-11-18 | Validate a top-down cobble tile and choose focus on the same playable bend | **PASSED.** Both wrap ratios meet the 2× target, native DOF preserves the playing band and the finished walk repeats the landmark, floor, exit signal and cast-shadow checks. |
| **Ultra-Crisp Code Road & Pitch Test** | 2026-11-18 | `2048²` (`512 tex/m`) non-bicubic cobbles + `1.8-texel` hard edges + `ORM` cavity AO/roughness in `hd2d_canyon_ground_crisp.gdshader`, across `-13°`, `-17.5°`, `-21°` | **SOLVED BLUR.** Split-patch at locked `-13°` cured soft paving blur (`X=1.32×`, `Z=1.06×`). `-17.5°` (`Y=4.85m, Z=12.2m`) boosted cobble clarity while keeping mountains in frame; procedural stones still looked slightly graphic/drawn. |
| **ChatGPT Image Cobble + ORM Test** | 2026-11-18 | Process user's ChatGPT `1024²` albedo + aligned height (`r=0.8145`) into seamless `3.2 m` tile (`X=1.12×`, `Z=1.10×`) + ORM + normal + Krita/Aseprite/Tiled packs | **BEST ROAD LOOK.** Kept natural chipped weathering, ochre/salmon/olive tones & sand grains while matching boot crispness at `-13°` and reading clearly at `-17.5°`. |
| **AI Boulder Trial (`TRELLIS.2` vs `trellis3d.net`)** | 2026-11-18 | Import user's two free GLBs via Blender cleanup (`remove_doubles` + `holes_fill` before `Decimate`), foot pivot `Y=0`, `Col.b=1.0`, test native AI textures vs `right_buttress_rock.tres` in `desert_canyon_ai_boulder_test.tscn` | **HF `TRELLIS.2` WINNER.** Merging split glTF UV-seam verts (`80,172 -> 56` boundary edges) prevented overhang tears during `282k -> 16.9k` decimation. `hf_trellis2` (`2048²` PBR + sharp strata silhouette) blended naturally into the canyon; `trellis3d.net` carried baked shadow blobs (`1024²`, `metallic=1.0` default bug) cured only by shader override. Grounded walk & exit signal passed. |
| **ChatGPT Sandstone PBR on AI Boulders** | 2026-11-18 | Process ChatGPT `1024²` rock strata albedo + aligned height (`r=0.8738`) into seamless PBR/ORM (`X=1.02×`, `Y=1.32×`), apply via UDN triplanar shader (`hd2d_chatgpt_boulder.gdshader`) with palette balance (`desaturate=0.28`) on BOTH `hf_trellis2` and `trellis3d.net` in `desert_canyon_chatgpt_boulder_test.tscn` | **PROVEN UPGRADE.** Rescued the weak `trellis3d.net` mesh from a blurry dark-mud blob into crisp fractured sandstone, and upgraded both boulders with true directional micro-cracks & cavity AO matching the canyon walls. Grounded walk (`on_floor=true`) and `exit_fired=true` passed. |

## 5. Bend Session 1 — One right-hand buttress

**Play `res://scenes/maps/desert_canyon_buttress_test.tscn`.** It inherits `res://scenes/maps/desert_canyon_buttress_control.tscn`, the matched diagnostic control derived from the D4b launch scene at `6576387`. The test hides `RightWing_6`, `RightWing_7` and `RightWing_8` to put one stepped buttress across that section. The diagnostics disable `TiltShiftDof`, `GodRaysOverlay`, dust motes and the painted right road shadow in both scenes. Both use the D4b road, sun, exposure, left wall, commander, floor and path bounds. The camera ran at 30° FOV and −13° pitch with follow offset `(0, 3.8, 12.6)` m. The launch scene file matched the D4b Git blob `aedeab65135633deb2326a10761ae03cf34a3d9c` and passed a separate launch walk.

- Blender master `assets/models/source/right_buttress.blend` and author/export script `tools/blender/blender_author_right_buttress.py`. The `ButtressMesh` object uses metre units, a foot-level origin, a matte preview material at 0.88 roughness and the `Trailward notch` vertex group. The master is saved with the 0.78 m recess. Red marks slate, green carries AO and blue is zero because this module has no ochre boulders.
- GLB `assets/models/right_buttress.glb`, instanced by `scenes/maps/right_buttress.tscn`. The wrapper owns `assets/models/right_buttress_rock.tres` and an enabled static box blocker. The test level places the wrapper at `(1.2, 0, -9.3)` m. The blocker center is `(2.92, 1.2, -9.48)` m in world space and its dimensions are `(1.8, 2.4, 5.0)` m.
- Captures and raw logs are under `D:/Games/Balance5/render_captures/session1_buttress/`. The renderer was Godot 4.7.2 Forward+ on Vulkan. All full-size Session 1 images are 1376×768. The harness now applies that exact viewport ratio, checks PNG saves and floor contact, and fails on a missed stop or exit signal. Its default scene and filename pattern still target the launch walk.

### 1. Blender notch and reimport — PASS

Captured the placed module with a 0.10 m notch, moved the eight vertices in the Blender group's two rings another 0.68 m on X and saved the same `.blend`. Exported the same GLB path and ran Godot's asset importer. Both the test scene and the wrapper had identical SHA-256 hashes before and after. The imported mesh's vertex count changed from 1,572 to 1,592 and vertex hash from `775732972` to `761024751`. The placement basis and origin, material override and enabled blocker matched in both runtime logs. The level assembler was never run.

The recess opens a visible gap above the exposed shelf in the matched exit views. At original pixel `(925, 238)`, RGB changes from `(116, 77, 53)` on the sandstone face to `(255, 205, 123)` on the exposed vista. [Before](../render_captures/session1_buttress/notch_shallow_pos3_exit.png) · [After](../render_captures/session1_buttress/notch_deep_pos3_exit.png) · [Matched crop comparison](../render_captures/session1_buttress/notch_comparison.png)

The matching data are in `notch_shallow.log`, `notch_deep.log`, `hashes_shallow.txt`, `hashes_deep.txt`, `export_shallow.log`, `export_deep.log`, `import_shallow.log` and `import_deep.log`.

### 2. Real shadow across the road — PASS

At the exit the harness froze the camera and commander pose and toggled only shadow casting on `RightButtress/Rock/ButtressMesh`. Both frames used camera origin `(0.175001, 3.8, -1.417919)` m and the same exposure. The shadow extends from the right wall over the central cobbles and recedes when the caster is disabled. The outlined stone is fully covered in the on frame. Across its 467 marked pixels, mean RGB is `(146.33, 127.32, 102.86)` with the shadow and `(226.59, 179.49, 128.33)` without it on a 0–255 scale. The mean brightness difference averaged across channels is 52.63 levels. The crops use the same pixel rectangle with top left `(500, 467)` and exclusive bottom right `(821, 645)`. [Shadow on full frame](../render_captures/session1_buttress/notch_deep_shadow_on.png) · [Shadow off full frame](../render_captures/session1_buttress/notch_deep_shadow_off.png) · [On crop](../render_captures/session1_buttress/shadow_on_crop.png) · [Off crop](../render_captures/session1_buttress/shadow_off_crop.png) · [Marked stone](../render_captures/session1_buttress/shadow_comparison.png)

### 3. Fixed landmark and grounded walk — PASS

Before placing the buttress, selected the glint on the crater's right-hand lobe on `OrichalcumCraterGround` at world `(1.73465, 0.03, -22.23546)` m. It is centered on texel `(149, 71)` of `orichalcum_crater.png`. The glint was visible in the D4b control at spawn. In the test at spawn, the camera-to-glint segment intersects an actual buttress mesh triangle at `(1.311536, 1.083407, -10.82528)` m. The line clears the module at midway, with the glint at the wall's edge, and by exit it sits well inside the vista. The crater and glint stay fixed in world space. [Matched landmark crops](../render_captures/session1_buttress/landmark_comparison.png) · [Control walk](../render_captures/session1_buttress/control_contact_sheet.png) · [Buttress walk](../render_captures/session1_buttress/walk_contact_sheet.png)

| Stop | Commander XYZ in metres | Camera XYZ in metres | On floor | Exit signal received | Landmark pixel and visibility |
| --- | --- | --- | --- | --- | --- |
| [Spawn](../render_captures/session1_buttress/notch_deep_pos1_start.png) | `(0.629665, 0.000137, 6.000000)` | `(0.220383, 3.8, 18.600000)` | Yes | No | `(741.40, 189.59)` occluded |
| [Midway](../render_captures/session1_buttress/notch_deep_pos2_midway.png) | `(0.629665, 0.000137, -3.524998)` | `(0.220383, 3.8, 9.078979)` | Yes | No | `(757.20, 229.96)` revealed |
| [Exit](../render_captures/session1_buttress/notch_deep_pos3_exit.png) | `(0.500004, 0.000137, -14.024970)` | `(0.175001, 3.8, -1.417919)` | Yes | Yes | `(793.77, 315.54)` revealed |

The matched control used the same three poses, with full-size files `d4b_control_pos1_start.png`, `d4b_control_pos2_midway.png` and `d4b_control_pos3_exit.png`. The control and test logs have the measured positions and projection. The test scene also opened directly with Godot outside the harness.

### Reproduce from `D:/Games/Balance5`

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
$blender = 'C:/Blender/blender.exe'
$control = 'res://scenes/maps/desert_canyon_buttress_control.tscn'
$test = 'res://scenes/maps/desert_canyon_buttress_test.tscn'
$out = 'res://render_captures/session1_buttress'
$landmark = '1.73465,0.03,-22.23546'
$master = 'assets/models/source/right_buttress.blend'
$author = 'tools/blender/blender_author_right_buttress.py'
$walk = @('--path', '.', '--rendering-method', 'forward_plus', '--fixed-fps', '60', '--max-fps', '60', '--script', 'res://tests/test_true_3d_walk.gd', '--')

New-Item -ItemType Directory -Force render_captures/session1_buttress | Out-Null
New-Item -ItemType File -Force render_captures/session1_buttress/.gdignore | Out-Null
& $godot @walk --scene $control --capture-dir $out --prefix d4b_control --landmark $landmark

# Optional A/B reproduction. End with the deep source and GLB for Session 2.
& $blender -b $master --python-exit-code 1 -P $author -- --notch shallow
& $godot --path . --headless --editor --import
& $godot @walk --scene $test --capture-dir $out --prefix notch_shallow --landmark $landmark

& $blender -b $master --python-exit-code 1 -P $author -- --notch deep
& $godot --path . --headless --editor --import
& $godot @walk --scene $test --capture-dir $out --prefix notch_deep --landmark $landmark --shadow-pair

# Open the test for manual play.
& $godot --path . $test
```

For a repeat walk in the delivered deep state, run the final `@walk` command alone. For a new Blender edit, use the `Trailward notch` group or edit the mesh directly, save the `.blend`, then invoke the same Blender command with no arguments after `-P $author` to export the saved mesh as-is. Keep exit crops tied to identical camera coordinates.

### Remaining visual work

The retained foreground and gateway cards still show soft painted silhouettes, and some overlap the new rock in projection. The original road has obvious tile seams and variable stone scale, especially at the exit. The deep-focus diagnostic makes both defects easy to see. The reveal is local to the crater's right-hand glint at spawn, while much of the crater is visible in the distance. Session 2 can start from the deep module and this exact placement to compare the road and focus passes.

## 6. Bend Session 2 — Ground and focus

### Pass A — Ground — PASS

The new playable derivative `res://scenes/maps/desert_canyon_bend.tscn` instances the exact Session 1 test, including the deep-notch buttress and D4b commander, sun, terrain and camera. The Session 1 scene and GLB matched their recorded hashes. The road control is Session 1 with the same effects-off setup and the original cobble. The new tile is a warm sandstone sett pattern with packed sand joints. Periodic stone and grain layers were composed in Krita 5.3.4.1. The editable `assets/textures/source/bend_cobble.kra` contains the joint bed, stone faces, two mineral layers and the hidden height source. `assets/textures/canyon_pbr/bend_cobble_albedo.png` is the Krita merged image, and `bend_cobble_normal.png` is a linear tangent-space normal derived using wrapped height differences. Both maps are 1024×1024 and Godot loaded 10 mip levels beyond the base on each. [Original 3×3](../render_captures/session2_bend/tile_original_repeat_3x3.png) · [New 3×3](../render_captures/session2_bend/tile_candidate_repeat_3x3.png)

Mean absolute RGB differences on a 0–255 scale use opposing edge pixels and the ordinary one-pixel differences on the same axis. The terrain uses the texture's vertical axis along world Z.

| Map | X adjacent | X wrap | X ratio | Z adjacent | Z wrap | Z ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Original 512² D4b | 1.1019 | 33.4453 | 30.3518× | 4.3068 | 19.4355 | 4.5127× |
| New 1024² bend | 2.6586 | 2.4935 | **0.9379×** | 2.6181 | 3.9889 | **1.5236×** |

One repeat spans 4.0 × 4.0 m using the same X and Z scale. The reference stone chord is 83.71 texels or **0.327 m** at 256 texels per metre. At spawn the 1 m reference projects to `(598.04, 540.19)`–`(722.92, 540.19)` and the stone chord near the commander's boots projects to `(719.64, 512.51)`–`(758.19, 513.24)`. Curb footprints and the capsule's radius at the actual curb height leave at least 0.419 m, 0.068 m and 2.024 m clearance at the three stops. The repeat preview and the three lit views show continuous joints across tile boundaries. The D4b road ran with two anisotropically stretched samples, which showed conspicuous vertical wrap lines. [Matched spawn before](../render_captures/session2_bend/ground_before_pos1_start.png) · [Matched spawn after](../render_captures/session2_bend/ground_after_pos1_start.png)

[Ground A/B crop](../render_captures/session2_bend/ground_comparison.png) · [Metre reference beside the commander](../render_captures/session2_bend/ground_scale_reference.png) · [Geometry audit log](../render_captures/session2_bend/geometry_audit.log)

### Pass B — Focus — PASS

Compared three modes on the same 4 m road at identical poses, 30° FOV, −13° pitch and offset `(0, 3.8, 12.6)` m. Sun, world exposure and all ground settings matched. Effects-off has both blur methods disabled. Screen-height uses the D4b shader's `0.60` focus Y, `0.28` width and `1.25` amount with a neutral tint and zero vignette for the comparison. Native uses only `CameraAttributesPractical` on `CameraRig`, fixed exposure multiplier 1 and auto exposure off. Session 1's ray, dust and painted-shadow controls carry through. [Matched spawn crops](../render_captures/session2_bend/focus_spawn_comparison.png) · [Matched exit crops](../render_captures/session2_bend/focus_exit_comparison.png)

**Selected native settings.** Near blur starts at 10.0 m with a 4.0 m transition. Far blur starts at 16.5 m with a 5.0 m transition. Amount is `0.014`. Measured camera-space depth of the sprite center is 12.987–12.996 m at the three stops and 13.658–13.661 m in the sampled motion frames. The feet are 13.132–13.139 m at the stops. Paving 1 m on either side along the walk ranges from 12.158–14.113 m at rest and 12.832–14.781 m in motion.

The spawn distant ledge (`TerraceLeft_2`) intersects the camera ray around `(576, 346)` at **18.59 m**, sharing screen row 346 with the commander's face. In the table, edge strength is the average of horizontal and vertical mean absolute adjacent-pixel RGB differences in the same registered crop. The selected native setting reduced the ledge metric by 19% and the face metric by 2%. Both boot and nearby paving crops were pixel-identical across all three modes. Hair, scarf and weapon edges kept their silhouette in two frames at 4.5 m/s, four frames apart. [Motion sample](../render_captures/session2_bend/focus_motion_comparison.png) · [Motion follow-up](../render_captures/session2_bend/focus_motion_followup_comparison.png)

| Crop | Effects off | Screen height | Selected native |
| --- | ---: | ---: | ---: |
| Distant ledge at face height | 6.430 | 5.981 | 5.182 |
| Face at the same height | 18.975 | 16.184 | 18.562 |
| Boots | 9.561 | 9.561 | 9.561 |
| Paving near boots | 4.105 | 4.105 | 4.105 |
| Moving silhouette | 14.166 | 13.727 | 13.941 |

The first native run kept the boots readable at `0.10` amount with near/far thresholds of 10/17 m, but blurred the selected glint into the crater. A second run at `0.025` and 10/16.5 m still left the glint only about 9 luma levels brighter than its 7×7-pixel neighborhood at exit. The selected `0.014` run kept that local contrast at about 27 levels at exit, with a visible glint by midway. Trial captures use prefixes `focus_scene`, `focus_native` and `focus_native_low`. [First native trial](../render_captures/session2_bend/focus_scene_walk.png) · [Tuning comparison](../render_captures/session2_bend/native_tuning_comparison.png) · [Godot camera attributes](https://docs.godotengine.org/en/stable/classes/class_cameraattributespractical.html)

### Final walk and milestone — PASS

**Play `res://scenes/maps/desert_canyon_bend.tscn`.** Tested its built-in native focus at 1376×768 in Godot 4.7.2 Forward+ and opened the scene directly. The buttress transform, GLB, wrapper material and blocker match Session 1. The ray to the crater glint at world `(1.73465, 0.03, -22.23546)` intersects the buttress at spawn and clears by midway. At the exit, a frozen on/off pair isolates the same buttress caster. The outlined stone near pixel `(672.4, 532.1)` changes by **44.52 RGB levels on average** across its 354 pixels. The two raw shadow crops use the same source rectangle `(500, 467, 821, 645)`. [Landmark](../render_captures/session2_bend/milestone_landmark_comparison.png) · [Shadow A/B](../render_captures/session2_bend/milestone_shadow_comparison.png) · [Final walk](../render_captures/session2_bend/milestone_walk.png)

| Stop | Commander XYZ in metres | Camera XYZ in metres | Floor contact | Landmark | Exit signal |
| --- | --- | --- | --- | --- | --- |
| [Spawn](../render_captures/session2_bend/milestone_pos1_start.png) | `(0.629665, 0.000137, 6.0)` | `(0.220383, 3.8, 18.6)` | Yes | Occluded | No |
| [Midway](../render_captures/session2_bend/milestone_pos2_midway.png) | `(0.629665, 0.000137, -3.524998)` | `(0.220383, 3.8, 9.078979)` | Yes | Revealed | No |
| [Exit](../render_captures/session2_bend/milestone_pos3_exit.png) | `(0.500004, 0.000137, -14.02497)` | `(0.175001, 3.8, -1.417919)` | Yes | Revealed | Yes |

Against D4b, the pavers read at a consistent scale and the real shadow crosses the rebuilt road. The warm pavers, shaded bend and softness of the distant terrain track the concept. The concept has a tighter S-curve, a more continuous right wall and stronger light shafts. The retained cards still overlap some of the right rock from spawn and midway, and the new stone shapes have a more regular rhythm than the weathered concept pavers. The selected lens softens the crater while retaining the reveal. These are the remaining visual differences for the one-bend milestone.

### Reproduce from `D:/Games/Balance5`

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
$bend = 'res://scenes/maps/desert_canyon_bend.tscn'
$session1 = 'res://scenes/maps/desert_canyon_buttress_test.tscn'
$out = 'res://render_captures/session2_bend'
$walk = @('--path', '.', '--rendering-method', 'forward_plus', '--fixed-fps', '60', '--max-fps', '60', '--script', 'res://tests/test_true_3d_walk.gd', '--', '--capture-dir', $out, '--landmark', '1.73465,0.03,-22.23546')

New-Item -ItemType Directory -Force render_captures/session2_bend | Out-Null
New-Item -ItemType File -Force render_captures/session2_bend/.gdignore | Out-Null
& $godot --path . --headless --editor --import
& $godot @walk --scene $session1 --prefix ground_before
& $godot @walk --scene $bend --prefix ground_after --focus off --bend-probes
& $godot @walk --scene $bend --prefix focus_off --focus off --bend-probes
& $godot @walk --scene $bend --prefix focus_screen --focus screen --bend-probes
& $godot @walk --scene $bend --prefix milestone --bend-probes --shadow-pair
& $godot --path . $bend
```

The capture directory contains the full-size PNGs, comparisons, and `ground_before.log`, `ground_after.log`, `focus_off.log`, `focus_screen.log` and `milestone.log`. The local geometry audit can be rerun with `--headless --script res://render_captures/session2_bend/audit_geometry.gd`. The authored maps and level are in the project tree. Evidence and this log are local to the primary workspace.

## 7. Bend Session 3 — Hand-laid sandstone

Verified 18 Nov 2026 at 15:29 EET by OpenAI Codex. Open **Developers Page → Session 3** to play `res://scenes/maps/desert_canyon_handlaid_sandstone.tscn`. At the time of Session 3, Session 2 was featured as the comparison. The new scene inherits it and overrides the ground material with `assets/materials/handlaid_sandstone_road.tres`. The control and candidate use the same sun, exposure, camera (30°, −13°, offset `(0, 3.8, 12.6)` m), terrain geometry, atmosphere and native DOF (10/16.5 m, amount `0.014`). The isolated ground variant uses the original road mask with localized pockets of sand in the outer verge, starting at 0.76 m off center.

- **Source.** `assets/textures/source/handlaid_sandstone.kra` is the Krita master, with separate packed joint sand, stone faces, mineral flecks and a hidden linear height layer spanning 0–40 mm. `tools/python/build_handlaid_sandstone.py` generates the periodic OpenRaster layers and derives the tangent-space normal using wrapped differences of the editable height values. The two imported maps are `assets/textures/canyon_pbr/handlaid_sandstone_albedo.png` (the Krita composite) and `handlaid_sandstone_normal.png`.
- **Engineering — PASS.** Both maps are 1024² at 4 × 4 m in world X/Z (256 texels/m), and Godot loaded all 10 mip levels beyond the base. One stone measured across the diffuse footprint is 98 texels or 0.383 m. Its endpoints are projected beside the commander and a marked 1 m reference. Ground geometry and curb positions carry through from Session 2. [Metre reference](../render_captures/session3_sandstone/metre_reference.png)
- **Visual — PASS for this road pass.** Eighteen short transverse courses and warm, recessed joints read at walking height. The setts have rounded ends and chipped shoulders, with 19 strongly tapered wedges among 207 stones. Individual wedges are easiest to see near the boots. Sand covers occasional outer stones and breaks the road boundary while leaving the center legible. At the frozen spawn pose, substituting a flat tangent normal reduced the directional highlights. A slightly deeper second crown pass brought the mean absolute RGB difference in the sunlit crop `(570, 470, 804, 575)` from 3.34 to 3.81 levels. Relief remains gentler and the courses more regular than in the concept, especially in shade and at the far end of the road. [Concept and spawn boot crop](../render_captures/session3_sandstone/pos1_start_Boots_and_verge.png) · [Midway crop](../render_captures/session3_sandstone/pos2_midway_Boots_and_verge.png) · [Exit crop](../render_captures/session3_sandstone/pos3_exit_Boots_and_verge.png) · [Frozen normal toggle](../render_captures/session3_sandstone/relief_normal_toggle.png)

Measured absolute RGB differences in the 0–255 source maps. Compare opposing edge pixels with ordinary adjacent pixels on that axis. Neither candidate map exceeds 2×, and the raw 3×3 repeat and lit walk show no straight tile joints. [Albedo repeat](../render_captures/session3_sandstone/handlaid_sandstone_albedo_repeat_3x3.png) · [Seam metrics](../render_captures/session3_sandstone/seam_metrics.log)

| Source map | X adjacent | X wrap | X ratio | Z adjacent | Z wrap | Z ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Session 2 albedo | 2.659 | 2.494 | 0.94× | 2.618 | 3.989 | 1.52× |
| Session 3 albedo | 3.980 | 4.150 | 1.04× | 4.208 | 4.382 | 1.04× |
| Session 3 normal | 2.854 | 2.217 | 0.78× | 3.610 | 4.002 | 1.11× |

The 1376×768 Forward+ walks matched at all stops. The commander stayed grounded. The fixed crater sightline intersected the buttress at spawn and cleared midway. The glint is faint under the current shared texture imports. Its sampled patch matched the freshly rendered control at each stop. The frozen exit shadow toggle covered the marked stone and changed its 183 pixels by 53.10 RGB levels on average. The exit signal fired on both runs. Session 3 launched from its menu card and returned with Esc. [Two full walks](../render_captures/session3_sandstone/full_frame_comparison.png) · [Landmark comparison](../render_captures/session3_sandstone/landmark_comparison.png) · [Shadow comparison](../render_captures/session3_sandstone/shadow_comparison.png) · [Menu smoke log](../render_captures/session3_sandstone/launcher.log)

| Stop | Commander XYZ in metres | Camera XYZ in metres | Floor | Glint | Exit signal |
| --- | --- | --- | --- | --- | --- |
| Spawn [control](../render_captures/session3_sandstone/control_pos1_start.png) / [candidate](../render_captures/session3_sandstone/candidate_pos1_start.png) | `(0.629665, 0.000137, 6)` | `(0.220383, 3.8, 18.6)` | Yes | Occluded | No |
| Midway [control](../render_captures/session3_sandstone/control_pos2_midway.png) / [candidate](../render_captures/session3_sandstone/candidate_pos2_midway.png) | `(0.629665, 0.000137, -3.524998)` | `(0.220383, 3.8, 9.078979)` | Yes | Revealed | No |
| Exit [control](../render_captures/session3_sandstone/control_pos3_exit.png) / [candidate](../render_captures/session3_sandstone/candidate_pos3_exit.png) | `(0.500004, 0.000137, -14.02497)` | `(0.175001, 3.8, -1.417919)` | Yes | Revealed | Yes |

### Reproduce from `D:/Games/Balance5`

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
$out = 'res://render_captures/session3_sandstone'
$walk = @('--path', '.', '--rendering-method', 'forward_plus', '--fixed-fps', '60', '--max-fps', '60', '--script', 'res://tests/test_true_3d_walk.gd', '--', '--capture-dir', $out, '--landmark', '1.73465,0.03,-22.23546', '--bend-probes')
New-Item -ItemType Directory -Force render_captures/session3_sandstone | Out-Null
New-Item -ItemType File -Force render_captures/session3_sandstone/.gdignore | Out-Null
& $godot --path . --headless --editor --import
& $godot @walk --scene res://scenes/maps/desert_canyon_bend.tscn --prefix control
& $godot @walk --scene res://scenes/maps/desert_canyon_handlaid_sandstone.tscn --prefix candidate --normal-pair --shadow-pair
```

### Follow-on passes

Session 3 served as the control for the subsequent road comparisons. First test the right gateway silhouette with a standalone reimportable outcrop and matched views. Once the gateway is verified, test localized atmosphere through that opening with its own control and GPU frame-time measurements. Keep the glint reveal and native lens as comparison points for each pass.

## 8. Road crispness — One patch at spawn

Verified 18 Nov 2026 at 16:05 EET by OpenAI Codex. Play **Developers Page → Road Crispness Test**, `res://scenes/maps/desert_canyon_crisp_road_patch.tscn`. The 1.0 × 1.5 m patch is centered at world `(0.28, 0, 6.91)` m with a 0.14 m inward feather. Session 3 is the control. The patch inherits its geometry, exposure, lights, fog, 4 m mapping and native DOF. Regular filtering remains outside the patch. The render uses 1376×768 Forward+, 30° FOV, −13° pitch, and the `(0, 3.8, 12.6)` m follow offset.

**Filtering verdict — PASS.** With the existing Session 3 maps bound to both paths, 4× anisotropic sampling gave cleaner stone edges and revealed some cracks previously averaged away. Mean absolute RGB steps in the spawn interior crop `(649, 489, 741, 530)` rose from 2.420 to 3.635 on screen X and from 9.546 to 11.387 on Y. These are image-contrast measures at fixed resolution. The 8× and 16× crops were identical to one another and averaged only 0.133 RGB levels from 4× at spawn. Across 24 moving crops that difference averaged 0.006 levels. Kept 4×. [Filter comparison](../render_captures/road_crispness/filter_levels.png) · [Godot viewport filter settings](https://docs.godotengine.org/en/4.7/classes/class_viewport.html)

**Material verdict — PASS for the isolated patch.** Retained the stone layout and added paler broad sandstone faces, tighter joints, patchy warm sand fill and larger angular spalls on a separate paint layer. The normal-map toggle gives a 5.23-level mean difference in the test crop, and the shaded shoulders and a few chips read at gameplay size during the sampled walk. The refined crop measures 4.459/13.700 RGB steps on X/Y. A slightly lighter patch is visible in the full spawn frame. The concept still has stronger small-scale relief and occlusion. Two 1024² maps retain 10 mip levels each. The albedo wrap-to-neighbor ratios are 0.99× X and 0.93× Z. The normal's are 0.77× X and 0.98× Z. [Native-pixel comparison](../render_captures/road_crispness/boots_comparison_native_pixels.png) · [Enlarged comparison](../render_captures/road_crispness/boots_comparison.png) · [Normal toggle](../render_captures/road_crispness/normal_toggle.png) · [Walking comparison](../render_captures/road_crispness/walking_comparison.mp4)

**Shallow geometry trial — Rejected for this patch.** Four approximately 4 cm tall crowns followed the underlying stone footprints in `res://scenes/maps/desert_canyon_crisp_road_relief_test.tscn`. The rounded sidewalls looked more raised than the reference. The identical camera crops were pixel-identical with the four casters on and off under the locked sun and shadow settings. The exposed sides changed the shading, but the trial showed no improvement from real joint shadows. The refined material and four-crown control now have separate comparison cards. [Geometry comparison](../render_captures/road_crispness/geometry_comparison.png)

The matched run grounded the commander at Z = `6.000000`, `-3.524998`, and `-14.024970` m with the exit signal at the final stop. The original buttress still cast across the exit road, and the glint crops match the control exactly at all three stops. The menu launch and Esc return passed. [Full spawn](../render_captures/road_crispness/refined_pos1_start.png) · [Full walk comparison](../render_captures/road_crispness/walk_full_framing.png) · [Diagnostics](../render_captures/road_crispness/refined_verified.log)

The edited master is `assets/textures/source/crisp_sandstone_patch.kra`, with `crisp_sandstone_patch_albedo.png` and `crisp_sandstone_patch_normal.png` under `assets/textures/canyon_pbr/`. Use `tools/python/build_handlaid_sandstone.py --crisp-patch` for the OpenRaster layers and wrapped tangent normal. The optional relief source is `assets/models/source/crisp_patch_crowns.blend` and its GLB is `assets/models/crisp_patch_crowns.glb`. The walk harness supports `--road-clip` and `--anisotropy 4|8|16`. Use `--road-patch-original-art` on the patch scene to reproduce the filtering-only runs and `--normal-pair` to capture the refined normals versus a flat normal. Use distinct capture prefixes.

## 9. Ultra-Crisp Code Road (`2048²` + ORM Cavity Shader + Camera Pitch Comparison)

Verified 18 Nov 2026 at 16:31 EET in isolated scene `res://scenes/maps/desert_canyon_ultra_crisp_test.tscn` via `tests/test_ultra_crisp_road.gd`. Root cause of Session 2/3 blurriness diagnosed: `-13°` pitch squashes 1 vertical screen pixel to `~20.6 texels` at `512 tex/m`, so `6–12 texel` soft stone shoulders + `INTER_CUBIC` blobs + uniform matte `ROUGHNESS=0.86` + low joint/crown contrast washed stone boundaries together.

- **Implementation:** `tools/python/build_ultra_crisp_cobble.py` builds `2048×2048` (`4.0 m × 4.0 m`, wrap `X=1.32×`, `Z=1.06×`) with `1.8-texel` hard edges, piecewise-linear crystal facets, angular corner chamfers, bright upper-right crown bevels against deep crevices, and `ultra_crisp_cobble_orm.png` (`R=cavity AO 0.16..1.0`, `G=roughness 0.48..0.96`). Applied in `assets/shaders/hd2d_canyon_ground_crisp.gdshader` with `mipmaps/generate=true` and `ANISOTROPY_16X`.
- **Result:** Split-patch proof at the locked `-13.0°` camera (`1_locked_cam_split_patch_pos1_start.png`) immediately eliminated the out-of-focus look right beside Session 3's soft road. Testing steeper diorama camera angles at matched `13.1 m` hero focus depth showed **`-17.5°` (`Y=4.85 m, Z=12.2 m`)** adds crisp vertical definition to both cobbles and Left Strata Wall steps while keeping distant mountains visible (`-21.0°` clips horizon mountains). Procedural stone borders still read slightly uniform/graphic compared to the concept. Captures in `render_captures/ultra_crisp_test/`.

## 10. ChatGPT Image Road (`3.2 m` Seamless + Aligned Height + Krita/Aseprite/Tiled Pack)

Verified 18 Nov 2026 at 17:21 EET in isolated scene `res://scenes/maps/desert_canyon_chatgpt_road_test.tscn` via `tests/test_chatgpt_road.gd`.

- **Source Processing (`tools/python/build_chatgpt_cobble.py`):** Processed user-generated `1024×1024` top-down ChatGPT albedo + aligned height map (`0.8145` low-frequency correlation) with `36 px` cosine edge-healing (`X wrap = 1.12×`, `Z wrap = 1.10×`, height `X = 1.10×`, `Z = 1.06×`) at **`3.2 m` tile scale**. Combined `32 mm` macro height + `8.5 mm` micro-grain albedo into `chatgpt_cobble_normal.png` and derived `chatgpt_cobble_orm.png` (`0.22` cavity AO, `0.52` crown roughness vs `0.95` joint roughness, mipmaps enabled).
- **Result — Clear Road Winner:** Eliminated the uniform graphic borders of procedural generation while preserving crisp micro-chips, ochre/salmon/olive stone diversity, and wind-blown sand grains at both `-13.0°` (`1_chatgpt_split_patch_pos1_start.png`, `2_chatgpt_full_pos1_start.png`) and `-17.5°` (`3_chatgpt_cam17_5_pos1_start.png`). Captures in `render_captures/chatgpt_road_test/`.
- **Editable Authoring Sources (`tools/python/export_chatgpt_authoring.py`):** Exported native layered Krita master (`assets/textures/source/chatgpt_cobble.kra`), layered Aseprite sources (`chatgpt_cobble_1024.aseprite`, `chatgpt_cobble_pixel_256.aseprite` 48-color `32×32` grid), and a playable Tiled winding-road tileset & map (`assets/textures/source/tiled/chatgpt_road_tileset.tsx`, `canyon_road_sandbox.tmx`).

## Nine-stone road study at spawn

18 November 2026, 20:03 EET. Launch **Nine-stone road study** from the Developers Page. Keys **1**, **2** and **3** select the Session 3 control, a flat painted sample with crown normals, and the same paint over shallow geometry with grain normals. Esc returns to the page. The study opens on 3.

The 1.2 × 1.0 m insert is centred at world (0.52, 0, 6.95). Nine individual footprints form three short courses. The flat and raised variants share the same 768 × 640 paint, sun, lens and floor collider. Two chipped lips in the raised mesh project over the sand. The layered Krita composite matches the game albedo pixel for pixel. [Playable scene](../scenes/maps/desert_canyon_sett_study.tscn) · [Blender source](../assets/models/source/sett_study.blend) · [Krita source](../assets/textures/source/sett_study.kra)

At 1376 × 768, 30° FOV, −13° pitch and the original follow offset, the patch occupies approximately 147 × 37 screen pixels at spawn. The table gives mean absolute channel differences between adjacent pixels in 134 × 31 native crops on a 0–255 scale. The concept crop is a separate image of different stones. These values describe visible edge contrast in each direction, without establishing a perceptual match.

| Crop | Horizontal | Vertical | Shadow-toggle pixels darkened by >3 |
| --- | ---: | ---: | ---: |
| Concept | 9.03 | 19.10 | n/a |
| 1 · Session 3 | 2.46 | 9.34 | 0 |
| 2 · Flat paint and normals | 4.80 | 14.28 | 0 |
| 3 · Shallow geometry | 7.64 | 13.20 | 26 |

Individual chips and broken shoulders read most clearly on 3. Its strongest cast-shadow difference was 31 levels. The concept still has darker sand pockets and better separation between successive rows. The raised sample looks lumpier and its bright faces draw attention at the boundary with the surrounding Session 3 material. This comparison supports selective local relief. A continuous road and its performance cost were outside this test.

All three runs kept floor contact at Z +6.000, −3.525 and −14.025 and fired the exit signal at the last stop. The buttress occluded the glint at spawn and cleared it by midway. The separate short crossing stayed grounded over the insert. Catalog launch, all three keys and Esc return passed in Forward+. [Native crops](../render_captures/stone_study/native_comparison.png) · [Matched walk](../render_captures/stone_study/patch_walk.mp4) · [Measurements](../render_captures/stone_study/measurements.json)

## 11. Composition test — route, right wall, camera, sun and air

19 November 2026, Claude Code. Play **Developers Page → Composition test** (local study, no milestone). `res://scenes/maps/desert_canyon_composition_test.tscn` inherits the integrated ChatGPT AI Boulders scene. `scripts/canyon/canyon_composition_test.gd` changes the composition at runtime so every value stays switchable. In game, **C** restores the original camera, **V** cycles atmosphere (off → volumetric → overlay) and **B** restores the D4b sun. [Control vs test](../render_captures/composition_test/compare_final.jpg) · [All variants](../render_captures/composition_test/compare_v4.jpg) · [Haze diagnosis](../render_captures/composition_test/compare_diag.jpg)

| Change | Value | Why |
| --- | --- | --- |
| Route | `2.0 · sin(0.22 z)` from a shared `scripts/canyon/canyon_route.gd` resource (D4b 0.65) | The D4b route reads as straight. All `Roadside3DKits`, props, buttress and Trellis boulders are re-laid by Δcx(z) and re-aligned to the new heading. The ground shader and commander clamp use the same route. |
| Right wall | `RightWing_*`, `GatewayWingRight` and low `TerraceRight_*` hidden. Four left terrace meshes turned 180° at z 11.7, 5.5, −0.7, −6.4, plus `GatewayBluffLeft` turned 180° at z −15.6 | Removes the painted card blob and gives a continuous stepped right wall in shade. |
| Camera | 30° FOV, −21° pitch, offset (0, 5.5, 11.9) m, 60% route-centre follow, 45% yaw toward the road 9 m ahead | Hides the horizon at spawn and midway. The commander stays at about 13.1 m, inside the native DOF band. |
| Sun | Same 42° elevation, yaw 145°: from ahead-right instead of behind-right | The right wall casts img1's diagonal shadow across the road. |
| Air | Exponential fog off, rock `haze_strength` 0.24 → 0.10, painted road shadow 0 | See the haze diagnosis below. |

**Haze diagnosis.** The steeper camera sees more wall beyond 16 m, and the D4b exponential fog (0.0075) washed it to flat beige. Turning off glow or DOF changed little. Turning off exponential fog brought back the dark umber right wall and readable strata. Global volumetric fog at 0.008–0.018 only hazed the walls, with no visible shafts even with the backlit sun. Default atmosphere is off. Shafts need a localized `FogVolume` at a wall opening in the atmosphere pass.

**Walk (1376×768 Forward+, `tests/test_composition_walk.gd`).** Grounded at all stops. Exit signal at the final stop. Spawn hero (1.937, 0, 6.0), camera (1.162, 5.5, 17.9) at yaw 2.9°. Midway hero (−0.250, 0, −3.525), camera (−0.437, 5.5, 8.379). Exit hero (−0.850, 0, −14.025), camera (−0.326, 5.5, −2.118). The harness only holds forward, so the commander rides the right clamp edge at midway. The crater glint is now occluded by `ButtressMesh` at spawn **and midway** and is clear at the exit. The reveal moved later, which matches the concealed far road. Re-time it if the midway reveal remains a requirement.

**Regression check.** The ground shader gained `route_amplitude/frequency/phase` with D4b defaults. The player clamp calls an overridable `_route_center_x`. The control walk is pixel-identical to the earlier integrated capture (max channel difference 1), so existing builds are unchanged. Main Play still opens ChatGPT AI Boulders. Card launch, C/V/B, a grounded walk and Esc return passed.

**Findings to carry forward.**
- The D4b assembler stores module yaw as `-atan(slope)`, so its walls turn against the curve. This was invisible at 0.65 m and matters at 2 m. The composition script corrects it.
- Rigid 6.5 m slices on a 2 m curve leave chord errors up to about 0.4 m at slice ends. No gaps show at the three stops, but curbs drift off the shader's road edge on the outside of bends. Path-driven placement (Path3D) should replace runtime re-laying before this becomes the baseline.
- The right wall reuses the left module, so both sides share a silhouette. Author dedicated right modules once the composition is accepted.
- Still open: slate caps read as flat grey, sage bushes are small, the exit vista is a flat orange plane.

Reproduce: `COMPOSITION_CAMERA=original|composition`, `COMPOSITION_ATMOSPHERE=off|volumetric|overlay`, `COMPOSITION_SUN=backlit|d4b`, plus diagnostics `COMPOSITION_FOG/GLOW/DOF=off`, with the usual walk arguments, `--script res://tests/test_composition_walk.gd` and `--landmark 1.73465,0.03,-22.23546`.

## 12. Foundations — flat canyon v2, route node, module wrappers, repo layout

19 November 2026, Claude Code. Play **Developers Page → Canyon v2** (local study). `res://scenes/maps/canyon_v2.tscn` replaces the six-level inheritance chain (D4b → buttress control → buttress test → bend → road → boulders → composition) with one 5 KB scene. The D4b chain stays untouched as the comparison set.

| Piece | File | Role |
| --- | --- | --- |
| Route | `scripts/canyon/canyon_route_path.gd` on a `Path3D` | Authored Bezier curve. `center_x(z)`, `heading(z)`, `half_width`. Writes a 64-sample lookup into the road shader (`route_mode = 1`; mode 0 keeps the D4b sine). |
| Layout | `scripts/canyon/canyon_layout.gd` + `scenes/canyon/canyon_v2_layout.tres` | 42 route-relative placements (z, lateral, yaw offset, scale, sprite tint and flip). Unsaved children rebuild on route or data edits, in the editor too. |
| Modules | `scenes/canyon/modules/*.tscn` | Seven rock wrappers on `assets/materials/canyon_rock.tres` and two bush sprites. Kit meshes come from `canyon_kit_test_d.glb` import `save_to_file` (`assets/models/canyon_kit/*.res`), so a Blender re-export updates them. |
| Actors | `scenes/actors/blue_commander_3d.tscn`, `canyon_camera.tscn` | The commander script takes an optional `route` and exports Z limits and exit threshold (D4b defaults). The camera is the former composition camera. |
| Shared look | `assets/materials/canyon_road_chatgpt.tres`, `assets/environments/canyon_clear_air.tres`, `canyon_lens.tres` | Extracted from the D4b chain with the composition-test values. |

`tools/godot/build_canyon_v2.gd` bootstrapped these files from the composition test. Assembler modules kept their offset from the D4b `-heading` yaw and are re-aligned with the correct sign.

**Verification (1376×768 Forward+).** Canyon v2 against the composition test with atmosphere off: mean absolute difference 0.4–1.2 RGB levels per channel. The residual comes from the Bezier route versus the sine. Positions match to 3 mm, and the glint is occluded by `ButtressMesh` at spawn and midway and clear at the exit. Commander grounded at all stops and exit signal fired. After the edits, the integrated control and the composition test both matched their earlier captures (max channel difference 1). The scene opens in the editor without errors. The card launch, grounded walk and Esc return passed. [v2 vs composition](../render_captures/canyon_v2/compare_v2.jpg)

**Repository layout.** Runtime scripts stay in `scripts/` (canyon systems in `scripts/canyon/`). Harnesses moved to `tests/`, Godot tools to `tools/godot/`, Blender scripts to `tools/blender/` (project root now `parents[2]`), image tools to `tools/python/`, and superseded map-cleaning and debug one-offs to `tools/legacy/`. References in scenes, scripts and docs were rewritten, and no stale paths remain. The walks ran unchanged from the new locations. `AGENTS.md` is now the single source of truth. `GEMINI.md` and `CLAUDE.md` point to it.

## 13. Architecture follow-up — collision corridor, navigation, guards and paths

19 November 2026, Claude Code. This closes the open items from the architecture review.

- **Physics instead of a position clamp.** `scripts/canyon/canyon_corridor.gd` on the `Corridor` node of canyon v2 builds one continuous double-sided `ConcavePolygonShape3D` ribbon per route edge (inner face at half width + 0.28 m capsule radius), plus box end caps. Separate rotated wall boxes left seams on the curve that trapped the capsule at Z −1.18. The ribbon slides cleanly. `clamp_to_route` is off in v2 and stays on for the D4b chain.
- **Navigation.** The corridor bakes a `NavigationMesh` at 0.1 m cells from the floor, walls and Layout blockers (group `canyon_navigation_source`), then drops polygons above 0.5 m so blocker tops are not walkable islands. `tests/test_canyon_corridor.gd` (headless) passes. Walls stop the commander at ±1.148 m with the clamp off, end caps hold at Z −14.5 and +7.5, and the exit signal fires. Navigation finds a 20.4 m, 17-point spawn-to-exit path clear of all three module blockers, and snaps an off-corridor target back inside.
- **Walk.** The forward-only harness stays grounded through all three stops on canyon v2 with the exit signal. Midway and exit now stop 2–5 cm from the clamp version (−0.264/−3.524 and −0.848/−13.973), so the framing matches with a tiny camera shift. [Comparison](../render_captures/canyon_v2/compare_corridor.jpg)
- **Shared route contract.** `hd2d_canyon_ground.gdshader` gained the same `route_*` uniforms and `route_center()` as the crisp shader. The Session 2 bend rendered pixel-identical with and without the change (max channel difference 1). The integrated control and composition test also stay identical.
- **Generator guard.** `tools/godot/tool_guard.gd` makes the D4b assembler, the seven older scene generators and `build_canyon_v2.gd` refuse to overwrite committed outputs without `-- --force`. Verified: the assembler exits 1 and leaves `desert_canyon_true_3d.tscn` untouched.
- **Repository-relative paths.** All `D:/Games/Balance5` paths in scripts, tests and tools now resolve from the repository root. GDScript uses `res://`. Python and Blender use `PROJECT_ROOT` / `Path(__file__).parents[2]`. The 12 AI-generated inputs (19.9 MB) that lived only in the Antigravity brain folder were copied to `assets/source_inputs/` (with `.gdignore` and a README), and every tool now points there.
- **Stale worktree.** `D:/Games/Balance5-road-detail-study` (detached at `3093d36`) was removed with `git worktree remove`. Its one unique source, `assets/textures/source/sett_study_v2.kra`, is now committed. Its 218 evidence files that were missing from or differed in the primary checkout were copied to `render_captures/_archive/road_detail_study_worktree/` first.

Still deliberate: the D4b inheritance chain keeps its index-based overrides and the assembler keeps its −heading yaw, because both are frozen baselines behind the guard. Rigid 6.5 m modules still show small chord errors on the 2 m curve.

## 14. HD-2D pixel A/B — surface treatment on canyon v2

19 November 2026, Claude Code. Play **Developers Page → HD-2D Pixel A/B** (`scenes/maps/canyon_v2_pixel_ab.tscn`, local study). Keys **1/2/3** switch live between:

- **A** — the current realistic materials.
- **B32** — pixel-art surfaces at 32 texels per metre.
- **B64** — pixel-art surfaces at 64 texels per metre.

Geometry, route, camera, sun, lens and commander are identical in all three. The test asks whether Octopath-style pixel surfaces, rather than higher-fidelity realistic assets, are the way to close the gap to the RPG goal.

**How B is made.** `tools/python/build_pixel_textures.py` area-downsamples every canyon texture to the chosen texels per metre, using each shader's metres-per-repeat. It quantizes colour maps, without dithering, to one shared 48-colour palette sampled from the canyon goal and the source art. It gives the bushes hard alpha. Output goes to `assets/textures/pixel_ab/d32|d64/`, imported lossless with mipmaps. `tools/python/make_pixel_shader_variants.py` generates `assets/shaders/pixel/*_pixel.gdshader`, which are the rock, ground and AI-boulder shaders with nearest-mipmap samplers. `scripts/canyon/canyon_pixel_ab.gd` swaps all 44 material and sprite slots at runtime, matching any texture by filename. The commander keeps her art but switches to nearest filtering in B.

**Captures** (1376×768 Forward+, `PIXEL_AB_MODE=A|B32|B64`). All three walks stayed grounded with the exit signal; positions match section 13. [Full frames](../render_captures/pixel_ab/compare_ab.jpg) · [Spawn crops](../render_captures/pixel_ab/crop_spawn.png) · [Midway crops](../render_captures/pixel_ab/crop_midway.png)

**Reading.**
- Road: B reads as pixel cobbles and sits better with the pixel-art commander than A. B64 is closest to her pixel scale, while B32 is chunkier.
- Walls: strata change little between A and B. The slate tops stay flat grey in every mode, which is a material problem, not a filtering one.
- Bushes: B32 is too coarse next to the commander; B64 holds up.
- Overall: converting existing art mechanically makes the frame crunchier and more coherent, but it does not make it look like Octopath. Octopath's surfaces are designed pixel art: deliberate highlight edges, dark joint lines, clustered shapes and short colour ramps. A palette-reduced photo texture has none of that.

**Conclusion.** The mechanics work and cost nothing: filtering, density, palette and the per-file swap. Filtering and density alone are not the lever. The deciding test is one **hand-authored** pixel set (wall strata, slate top, cobble) at about 48–64 texels per metre, made in Aseprite or with a pixel-art generator. Drop the files into `assets/textures/pixel_ab/d64/` under the same names, then press 3.

### 14a. Authored pixel set tooling (mode 4)

Same day. The A/B scene gained mode **4 = authored set**. It reads `assets/textures/pixel_ab/art/` and its `manifest.json`, and falls back to B64 for roles not authored yet. The pixel shader variants now expose their repeat scales as uniforms whose defaults equal the source shaders. That lets authored art of any size map at its exact density. B64 re-renders identically (spawn and exit max channel difference 0, midway 3).

- `tools/python/pixel_snap.py` turns AI "fake pixel art" into a true grid. It scores each candidate grid by how much excess edge energy its lines capture, assumes square pixels when one axis has long flat runs, and samples the median at each cell centre. It then applies k-means-refined colour reduction or a supplied palette, keys sprite backgrounds, derives normal and ORM maps, writes lossless import stubs and records the size in metres.
- `tests/test_pixel_snap.py` passes. From synthetic art at 7.37 px per cell (blurred, JPEG, noise) it recovered 64 × 32 cells with 100% of colours within 24 levels. A 9.1 px sprite on green recovered all 293 of 293 opaque cells.
- End to end: a disguised B64 strata (5× upscale, blur) came back as exactly 188 × 89 cells (2.94 × 1.39 m). Godot accepted the stub import (lossless, mipmaps), and mode 4 rendered within 3–4 levels of B64; the remaining difference is the luminance-derived normal map. The test art was then removed.
- `docs/PIXEL_TEXTURE_PROMPTS.md` has the workflow, sizes per role at 64 texels per metre, palette ramps, prompts for each role, an acceptance check and troubleshooting.

### 14b. Gemini authored set, and the two procedures side by side (mode 5)

**Gemini round.** The owner generated strata, slate, cobble, sand, dune and boulder with Gemini, and the sage bush with ChatGPT, then snapped them (`art_gemini`). Verdict: **mode 4 looked awful, except the bush.**

- **Correction to the first diagnosis.** Gemini's images were *not* painted: they sit on clean grids of 100 or 200 cells per image (5.12, 5.74 or 10.24 source pixels per cell). A new grid-fit measure shows 99–100% flat cell interiors, against 56% for Antigravity's painted ChatGPT cobble. The snap was faithful.
- **Real causes.**
  - *Content:* the strata prompt ("a lit edge on top of each bed and a dark joint underneath") was drawn as bricks and mortar, so the cliffs read as brick buildings, and the cobbles came out as a regular brick-row pavement.
  - *Scale:* Gemini picks its own grid, so one repeat covered 3.75 m of strata and 3.1 m of slate at 64/m, against the intended 2 m and 1 m.
  - *Style:* the images are flat cartoon fills.
- **The bush worked.** It was real pixel art on a 15 px grid with a sprite silhouette, the case pixel art suits best.
- **Gemini's height maps** line up with their albedos (edge correlation +0.90 to +0.96), except one slate height from another generation (+0.06).

**Changes.**
- `pixel_snap.py`:
  - reports the grid fit and warns below 85% ("not pixel art, only a resample");
  - reports the area one repeat covers against each role's intended area, and warns when the two differ by more than 1.6×;
  - takes `--height` (snapped on the same grid, with an alignment check) to drive the normal and ORM maps;
  - accepts named sets (`--set art_*`).
- New `tools/python/smooth_texture.py` generalises Antigravity's ChatGPT cobble and boulder processing (`build_chatgpt_cobble.py`, `build_chatgpt_sandstone.py`) to every texture role: 1024 px Lanczos, 36 px cosine wrap on both axes, normal map from height (30 mm) plus high-passed luminance (8 mm), and ORM for cobble and boulder. It writes `hr_*` sets and by default reuses the metres of the pixel version of the same source.
- `make_pixel_shader_variants.py` now also writes `*_smooth.gdshader`, with source filtering and the same scale uniforms.
- The A/B scene lists every `art*` folder (key 4, press again to cycle) and every `hr*` folder (key 5). `PIXEL_AB_MODE` accepts `ART`, `HR` or a folder name.
- The prompt pack's strata and cobble prompts now forbid bricks, blocks and mortar. It adds a ChatGPT height-map prompt and Perchance prompts with anti-descriptions. Gemini is retired as a generator.

**Captures** (1376×768, `V2_*`). All walks were grounded and the exit signal fired. B64 is unchanged at spawn (mean channel difference 0.06; midway and exit differ only by the harness's run-to-run camera drift). [A / art_gemini / hr_gemini](../render_captures/pixel_ab/compare_procedures_gemini.jpg) · [Spawn road crop, pixel vs smooth](../render_captures/pixel_ab/crop_procedures_gemini.png). On Gemini's pixel-art cobbles, the smooth procedure keeps the staircase edges (the source is pixel art) but loses the crisp pixel colours to linear filtering. It is a pipeline check, not a verdict: the real comparison is on ChatGPT and Perchance images.

`tests/test_pixel_snap.py` now also checks that a painted image is flagged and that a height ramp drives the normal map. It passes.

## 14c. ChatGPT vs Perchance strata and cobble, both procedures (2026-11-20)

**Sources.** ChatGPT: strata 1536×1024 and cobble 1254² with height edits. Perchance: strata 768×512 and cobble 768², no height. Same prompts as `docs/PIXEL_TEXTURE_PROMPTS.md`.

**Tool readings.**
- ChatGPT: grid fit 95% (strata) and 96% (cobble), so it is real pixel art. One repeat covers 3.72 × 2.55 m (strata) and 2.44 m (cobble). Height alignment is +0.64 (strata) and +0.48 (cobble); the cobble height is a re-drawn layout, not a true edit, so its relief only roughly matches the stones.
- Perchance: grid fit 41% (strata) and 63% (cobble), so it is not on a clean grid. Its detected cells (17 × 26 px and 18 × 8 px) are wrong, so both sets map far too small (0.69 × 0.31 m strata, 0.67 × 1.47 m cobble). The pixel version breaks the cobble into stretched blocks, and the smooth version, which inherits the same metres, tiles the strata as a fine repeating pattern.

**Captures** (1376×768, `V2_A`, `V2_art_gpt`, `V2_hr_gpt`, `V2_art_perchance`, `V2_hr_perchance`; all grounded, exit signal fired). [Sheet](../render_captures/pixel_ab/compare_gpt_perchance.jpg) · [Spawn crops](../render_captures/pixel_ab/crop_gpt_perchance.png).

**Result.** ChatGPT's strata is the first authored wall that reads as wavy layered rock with no bricks, and its cobble reads as a road. At play distance the pixel and smooth procedures differ only slightly: pixel_snap keeps crisp texels and flatter colour; smooth is softer and gets a little more relief from the height map. Perchance is not usable as is. It needs `--metres` set by hand (role size) to be judged fairly, and pixel_snap should not trust a grid below 85% fit.

**Fix and re-run (same day).** When the grid fit is below 85%, `pixel_snap.py` now ignores the detected cell (it is noise) for texture roles and uses square cells that make one repeat cover the role's intended width. This is a plain downsample to 64/m. Perchance now maps at 2 × 1.33 m (strata) and 3 × 3 m (cobble), and `smooth_texture.py` inherits those metres. Recaptured `V2_art_perchance` and `V2_hr_perchance` (grounded, exit signal fired; sheet and crops above updated). At a fair scale, Perchance's cobble works as a road, with darker, heavier gaps than ChatGPT's. Its strata reads as broken lumpy rock rather than horizontal beds and is darker and more purple. ChatGPT stays the better source for both roles; pixel_snap vs smooth is still a small difference at play distance. The self-test still passes.

## 14d. Raised stones along the whole road, and two free packs (2026-11-20)

**Why.** The owner found every cobble version fake and flat. The nine-stone study (raised stones cast real shadows, 26 px) and the four-crown test (4 cm crowns, no visible shadow) both tested geometry on a patch. This test raises every stone of the road.

**Method.** `tools/python/relief_height.py` makes `chatgpt_cobble_height.png` for a set. It starts from ChatGPT's height image, cuts the stones apart at the painted dark joints (so raised edges sit on painted edges even though the ChatGPT height was redrawn slightly, alignment +0.48), then gives each stone 7 px shoulders and a gentle dome. The A/B scene (key **R**, `PIXEL_AB_RELIEF=1`, depth `PIXEL_AB_RELIEF_DEPTH`) adds a dense strip along the route (1.5 cm vertex spacing, 2.9 m wide, Z +10 to -16; 195 x 1735 vertices, 673k triangles). Its material is the floor's own material for the current set, with `relief_depth` set. The vertex stage lifts each vertex by the height, masked like the painted road (path edge, verge wear, dune fade), and recomputes the normal. Shadows come free because the shadow pass runs the same vertex stage. The generated ground shader variants gain `relief_depth` (default 0 = unchanged) and `relief_side_shade` (darkens steep stone sides, 0.55). The first captures were wrong: the strip's triangles faced down, so only the flat floor and a few folds showed. The fix is clockwise winding; those captures were deleted.

**Result** (`V2R35_*`, `V2R6_*`, grounded, exit signal fired). [Crops: flat / 3.5 cm / 6 cm](../render_captures/pixel_ab/crop_relief_depths.png) · [Full frames, flat vs 6 cm](../render_captures/pixel_ab/compare_relief.jpg). This is the first road where the stones look raised at play distance. Each stone has a shaded front, a lit back shoulder, and it overlaps the stone behind it. Mean change at spawn is about 4 RGB levels at 3.5 cm and 6 at 6 cm, with 75-86k pixels darker by more than 8 levels (the nine-stone patch: 26). 6 cm reads most clearly, but the owner judged it too high: stones a person would hop between, not walk on. The default is now 2 cm (real cobbles sit 1-3 cm proud); Phase 0 tunes it. The painted dark joints mostly disappear behind the stones at -21 degrees, because a 6 cm stone hides about 13 cm of ground behind it; the shaded fronts take their place. The commander's feet stand on the flat floor between stones (collision is unchanged). Small slabs lying on the road are partly buried.

**Cost** (`tests/test_relief_cost.gd`, RTX 4060 Ti, 1376x768, spawn): GPU 0.96 -> 1.77 ms (hr_gpt) and 0.94 -> 1.49 ms (art_gpt); CPU unchanged. Affordable. The strip should cover only what the camera can see, and get coarser farther away, before it becomes the baseline.

**Free packs** (`scenes/maps/canyon_v2_packs.tscn`, key **P**, `PIXEL_AB_PACKS`). `tools/blender/convert_pack_model.py` turns FBX/OBJ into GLB at a set height in metres, with a foot pivot and the rock vertex channels (red 1 on flat tops = slate caps, green = height-based occlusion). Tried:
- craftpix low-poly desert mountains (licence `craftpix.net/file-licenses`, link kept in `assets/models/packs/craftpix_desert/`): a 14 m mesa and a bluff beyond the exit and a pinnacle group behind the right wall, all wearing `canyon_rock.tres`. They take the strata and slate caps naturally and add a distant mesa silhouette at the exit, but the canyon walls hide most of them at walking height. Better uses: the RTS map and RPG horizons.
- Grand Canyon rock photo scan (1,000 triangles, no licence found; kept in the git-ignored `assets/models/packs_local/`): with its own photo texture it is grey-white and realistic, and it clashes with the painted canyon. With the canyon rock material it fits. Photo textures from packs need repainting or our material.
[Packs off / on](../render_captures/packs/compare_packs.jpg) · [Scan at spawn](../render_captures/packs/crop_scans.png)

## 15. RPG canyon Phase 0: lock the look (2026-11-20)

**Why B64 beat the authored sets.** B64 (`tools/python/build_pixel_textures.py`) starts from detailed painted art (Anti's ChatGPT road: many small stones, varied colours, chips, sand grains), area-averages it to 64 texels per metre, and maps every surface onto one 48-colour palette taken from the RPG goal image. The authored `art_gpt` set starts from an image the AI drew as cartoon pixel art (outlines, flat fills) with its own 24 colours. The detail and the shared palette are what make B64 read as real; the cartoon source is what reads as fake. **Rule from now on: ask the generator for a detailed painted texture, and make the pixels ourselves.**

**Tool.** `pixel_snap.py --painted` is that recipe for any image: area-average to `--density` at the role's size (or `--metres`), optional cosine wrap (`--wrap`), goal palette (`palette_preview.png`) by default, normal and ORM from `--height`. `relief_height.py` now drops dark specks smaller than 80 px (pits inside a stone are not joints). Self-test passes.

**Candidates** (`scenes/maps/canyon_v2_packs.tscn`, packs on, captures `render_captures/phase0/P0_*`, all grounded with the exit signal):
- `P0_B64`: B64 as it was, flat road.
- `P0_A15`, `P0_A25`: look A = set `art_look_a` (Anti's road through `--painted`, 3.2 m, with its height) raised 1.5 and 2.5 cm; every other surface falls back to B64.
- `P0_B20`: look B = set `art_look_b`, the same road raised 2 cm plus the ChatGPT strata (`art_gpt`'s) on the walls.

[All looks](../render_captures/phase0/phase0_looks.jpg) · [Road crops at spawn](../render_captures/phase0/phase0_road_crops.png)

**Reading.** At 1.5 to 2.5 cm the small stones get real edges and look walkable, not stepping stones. The road turns darker and browner than flat B64, because the side shading (`relief_side_shade` 0.55) covers a large share of these small stones; this is tunable. The ChatGPT strata gives warmer, livelier walls than B64's grainy derived strata. The photo-textured scan still stands out grey-white in every look. The owner chooses.

## 16. 2D Parallel-Projection RPG Canyon — Approach 1 (Uncut) vs Approach 2 (Modular Stitched) (2026-11-21)

**Why the first procedural tile attempt failed (~20–25% match) and how parallel-projection ChatGPT art solved it (~95–98% match).**
- The initial procedural Python brick/tile generator (`ImageDraw.rectangle` + repeated `184×120` rectangular terrace stamps on a `32×32` grid) looked like boxy 1990s programmer art, and Image 9's 1-point vanishing point could not scroll under a locked camera without scaling the hero or distorting cutouts.
- Pairing a *Sea of Stars* parallel-projection reference (`Ref1_Camera_Projection_SeaOfStars.jpg`) with a horizon-cropped Image 9 style reference (`Ref2_Style_Palette_Image9_NoHorizon.png`) eliminated ChatGPT's vanishing-point habit while preserving 100% of Image 9's terracotta sandstone, stepped dry-stone masonry, rounded cobblestone road with rectangular curbs, olive sagebushes, and upper-right golden sunbeams.

**Two 100% 2D parallel-projection workflows built & compared (`tools/python/build_rpg_2d_canyon_assets.py`, `tools/godot/build_rpg_2d_canyon_scene.gd`):**
1. **Approach 1 — Continuous Uncut 2D Artwork (`scenes/rpg_2d/canyon_approach1_uncut.tscn`, mode 1 in `canyon_orthographic_study.tscn`):**
   - Stitched `approach1_plate_top.jpg` (`682×1024`) and `approach1_plate_bottom.jpg` (`682×1024`) across their exact 81-pixel vertical overlap (`row 943`, `dx = 0`, mean absolute difference `6.45 / 255`) into a seamless `682×1967` uncut canyon painting (`5.1×` the height of a 384p frame), and extended the outer `139 px` left/right cliff rims to full `960×1967` widescreen using dynamic-programming minimum-error graph cuts (`approach1_uncut_canvas.png` + Laigter normal map `approach1_uncut_canvas_n.png`).
   - Extracted 8 in-place road-side boulder and olive-bush cutouts (`a1_cutout_00`..`07` + Laigter normals) anchored at their ground-contact bases inside `YSortWorld` so the commander's boots pass naturally behind road-edge boulders and bushes.
2. **Approach 2 — Modular Stitched & Y-Sorted 2D Kit (`scenes/rpg_2d/canyon_approach2_modular.tscn`, mode 2 in `canyon_orthographic_study.tscn`):**
   - Quilted a seamless `960×1967` desert floor from interior sub-crops of `approach2_ground_road_sheet.jpg` Band 1 (sand) and stitched a `1967`-pixel-tall winding constant-width S-curve cobblestone road from Band 3 across its exact `337 px` period (`dx = 1 px`) at `0.72×` scale (`140 px` road width, matching Approach 1 and the cliff masonry courses) using dynamic-programming graph cuts (`approach2_ground_road_canvas.png` + Laigter normal map).
   - Extracted all **6 modular stepped dry-stone & terracotta cliff formations** from `approach2_cliffs_sheet.jpg` (`cliff_left_large`, `cliff_corner_mid`, `cliff_right_large`, `cliff_stair_ruin`, `cliff_outcrop_wide`, `cliff_buttress_right`) and **12 modular props** from `approach2_props_sheet.jpg` (4 olive sagebushes, 3 grass tufts, 4 faceted terracotta boulders, and the 3/4 dry-stone `ruined_archway`) via exterior-perimeter flood-fill keying, premultiplied Lanczos scaling, dark-umber silhouette outliners, directional drop shadows, and batch Laigter normal maps (`--no-gui --normal -d`).
   - Placed 22 modular cliff/staircase formations, 3 weathered dry-stone ruined archways, and 40 boulders/bushes/grass tufts as individual Y-sorted `Sprite2D` nodes in Godot (`YSortWorld`).
3. **8-Directional Blue Commander & Shared 192-Colour Palette:**
   - Quantized all diffuse canvases, modular cliffs, props, and the `104×120`-cell Blue Commander sheet (`assets/textures/rpg_2d/sprites/blue_commander_sheet.png`, built from `assets/textures/pixel_canyon/blue_commander.png` with organic back-hair clusters on Row 1) to the shared **192-colour master palette** (`palette_192.png`).

**Verification (`1376×768` Forward+ & Headless Logic):**
- `tests/test_rpg_2d_canyon_logic.gd` (headless): PASS — verified all 3 scenes load, `960×540 ↔ 640×360` resolution toggle (`1/2/V`), framing zoom (`Z`), all 8 Explore facings (`N, NE, E, SE, S, SW, W, NW`), locked pixel-snapped camera follow across vertical travel with constant `1:1` hero scale, curved left/right terrace wall collision stops in both approaches, live `Tab`/`M` toggle between Approach 1 and Approach 2 preserving road offset, and Developers Page catalog availability.
- Windowed Forward+ captures (`tests/capture_rpg_2d_canyon.gd`):
  - Approach 1: [Start 960×540 HUD](../render_captures/rpg_2d/a1_01_start_960x540_hud.png) · [Start 960×540 Clean](../render_captures/rpg_2d/a1_02_start_960x540_clean.png) · [Mid-Canyon North](../render_captures/rpg_2d/a1_03_mid_canyon_north.png) · [Upper Canyon Sunbeams](../render_captures/rpg_2d/a1_04_upper_canyon_sunbeams.png) · [Start 640×360 Toggle](../render_captures/rpg_2d/a1_05_start_640x360_toggle.png)
  - Approach 2: [Start 960×540 HUD](../render_captures/rpg_2d/a2_01_start_960x540_hud.png) · [Start 960×540 Clean](../render_captures/rpg_2d/a2_02_start_960x540_clean.png) · [Mid-Canyon Arch & Stairs](../render_captures/rpg_2d/a2_03_mid_canyon_arch_stairs.png) · [Upper Canyon Y-Sort Behind Boulder](../render_captures/rpg_2d/a2_04_upper_canyon_ysort_behind_boulder.png)

## 17. 3D kit study, step 1: real curb blocks (2026-11-21)

**Direction.** The owner chose Option 2 for the 3D canyon: real modelled pieces with pixel textures (B64 or art_gpt colours), sprites only for plants. The two Trellis boulders and the white scan rock stay; the commander is out of scope for now. Scene: `scenes/maps/canyon_v3_kit.tscn` (built on the free-packs scene, all A/B keys work; **K** toggles the curbs, `KIT_CURBS=0` starts without them).

**Pipeline.**
1. ChatGPT drew one sheet of six curb stones, top views and side views, in the style of the Approach 2 road (`assets/source_inputs/curb_faces_gpt.webp`).
2. `tools/python/build_curb_atlas.py` keys the background, refills the rounded corners from the stone (the 3D bevel rounds them), resamples each top to 25 x 46 texels, each side to 46 x 14 and an end slice to 25 x 14 (block 0.72 x 0.39 x 0.22 m at 64 texels per metre), and packs everything into one atlas with 2-texel edge padding. Two colour versions: `gpt` (the sheet's own 24 colours) and `goal` (the sheet's colours mapped one-to-one onto the goal palette, so no speckling), each with a normal map. The side faces are squashed vertically to 0.63 of the drawing to fit a low curb.
3. `tools/blender/build_curb_blocks.py` builds six blocks from the atlas layout: foot pivot, 3 cm buried, a slightly narrower and tilted top per block, a 2-segment 2.2 cm bevel on the visible edges, UVs on that stone's faces. Export `assets/models/curbs/curb_blocks.glb`.
4. `scripts/canyon/canyon_curbs.gd` walks both road edges (1.25 m from the route centre, where the paint ends) by arc length and lays a random block every 0.74-0.78 m: random end facing, up to 3 degrees of yaw and 2.5 degrees of lean, up to 3 cm sink, 5% missing. One box collider per block. 61 blocks from Z +10 to -12.4. The atlas follows the surface set (art* -> gpt, otherwise goal).

**Result** (`render_captures/kit/K1_*`, all grounded, exit signal fired). [Four looks x three stops](../render_captures/kit/kit_curbs.jpg) · [Spawn and midway crops](../render_captures/kit/kit_curbs_crops.png). The real curbs are the biggest single improvement so far. The road now has a raised, hand-laid border that follows the S-curve, casts shadows on the sand and reads at every stop, like the goal image's curb rows. Both colour versions work; on the art_gpt road the curbs match the cobble colours more closely, while on B64 they read paler than the road. The commander's forward-only harness walk now meets the curbs at midway and slides along them (hero X -0.63 against -0.26 without curbs); she stays on the floor and reaches the exit. Open points: the curbs are a little bright in full sun; a few blocks touch the right-hand boulder and the left kitbash slate pieces; the side faces are squashed from the drawing.

## 18. 3D kit study, step 4 (first pass): stepped sandstone cliffs (2026-11-21)

**Inputs.** Two ChatGPT sheets made with the Approach 2 cliffs image as the style reference: six rounded sandstone blocks (tops above, fronts below; `assets/source_inputs/cliff_blocks_gpt.webp`) and two tiles, a dry-stone wall face and a paved terrace top (`cliff_masonry_gpt.webp`).

**Pipeline.**
1. `tools/python/build_cliff_atlas.py` cuts each block, takes its **3D footprint from the outline of its drawn top** (40-point polygon; 1 sheet pixel = 5 mm, so the blocks are 0.9-1.7 m across and 0.7-0.95 m tall), resamples tops and fronts to 64 texels per metre into one atlas, and the two tiles to 2 m repeats. `gpt` and `goal` colour versions plus normal maps, as for the curbs. The wall tile repeats cleanly along its length (seam 0.81) but not vertically (2.33), so it is only used on risers lower than one repeat.
2. `tools/blender/build_cliff_blocks.py` extrudes each outline: a buried base, a 3.5% bulge at mid-height, a shoulder and a pulled-in top ring for a rounded rim, a gently domed top cap. The sides wear the drawn front (front half left to right, back half mirrored), the top wears the drawn top. `assets/models/cliffs/cliff_blocks.glb`.
3. `scripts/canyon/canyon_cliffs.gd` builds each side from the road outward: a 0.55 m dry-stone retaining wall at 1.58 m from the route centre, a 0.5 m paved terrace, then 3-5 rows of blocks (row count varies along the canyon and drops toward the exit vista), each row 0.62 m further back and 0.7 m higher, over a stepped dry-stone core with a paved plateau on top. Blocks vary in size (0.8-1.3, larger higher up), height (0.7-1.3), spacing, yaw (+-25 degrees) and depth; 30% get a smaller fallen piece or a cap. 276 blocks. Core faces take their tile projection from the way they face, so cross faces are not stretched.
4. In `canyon_v3_kit.tscn`, **W** swaps the new cliffs and the old kitbash walls (Terrace, Gateway and RightButtress modules); `KIT_CLIFFS=0` starts with the old walls. The collision corridor still holds the commander, unchanged.

**Result** (`render_captures/kit/K2_*` against `K1_*_curbs`, all grounded, exit signal fired). [Old walls vs new cliffs, both looks, three stops](../render_captures/kit/kit_cliffs.jpg). The cliffs now read as stacked rounded sandstone, as in the 2D kit and the goal image, with real overlaps and shadows between blocks; the low dry-stone wall and terrace give the road a built edge. Against the goal image they are too bright and evenly orange: the shade sides and dark slate courses that gave the old walls contrast are missing, and the rows of similar blocks look lumpy ("loaves") rather than like cliff faces. The two colour versions differ little here (mean 6.6 levels), because both sheets are orange. Next: darker shade and a cooler shadow tone, fewer and larger blocks with some flat vertical faces between rows, and rubble at the wall foot.

### 18b. Second pass: darker, fewer and larger blocks, strata faces, rubble (2026-11-21)

**Changes** (one deliberate group; first-pass captures `K2_*` are the control).
- New shader `assets/shaders/canyon_kit_rock.gdshader` for the cliff kit: nearest-filtered pixel textures at 0.74 brightness, a violet fill (0.34, 0.22, 0.42) on faces the sun does not reach, and darker block bases (each block's own height, an instance uniform), so rows read as separate stones.
- `canyon_cliffs.gd`: 2-4 rows (was 3-5), 0.85 m rise and 0.8 m setback, blocks 1.1-1.55 x and flatter (height 0.55-0.8), spaced 0.75-1.15 of their width so the faces behind show; 15% capped. The faces between rows now wear the look's strata texture (`art_gpt` ChatGPT strata or the B64 strata); the retaining wall keeps the dry-stone tile, treads the paving. 148 rubble pieces lie at the wall foot and on each tread. 112 blocks.

**Result** (`render_captures/kit/K3_*`, all grounded, exit signal fired). [First vs second pass, both looks, three stops](../render_captures/kit/kit_cliffs_pass2.jpg). Calmer and darker: the walls now read as stepped terraces with sandstone boulders on the ledges and layered rock faces between them, closer to the 2D kit's cliff pieces. The violet shade is subtle with the sun behind the camera's right. The trade-off is height: with fewer rows the walls are lower and the canyon reads more open, like a stepped valley, and the paved terraces take a large share of the frame. Options for a third pass: taller strata faces (fewer, higher steps) for a true canyon wall, paving only on the lowest terrace with sand above, and bushes on the ledges (step 3).

### 18c. More room between road and cliffs (2026-11-21)

The owner found the second pass claustrophobic around the commander. The retaining wall moved from 1.58 m to 2.7 m from the route centre (`wall_front`), leaving about 1.25 m of open sand between the curbs' outer edge (1.45 m) and the cliffs, for sand and bushes later. Captures `render_captures/kit/K4_*` (all grounded, exit signal fired): [1.6 m vs 2.7 m, both looks, three stops](../render_captures/kit/kit_cliffs_wider.jpg). The road now sits in an open sandy floor with the boulders, scan rock and existing bushes beside it, and the cliffs frame the edges of the screen instead of closing in at the curbs. The painted ledge shading in the floor shader (`cliff_ao`, strongest from 1.35 to 2.65 m) now darkens this sand strip slightly toward the walls.
