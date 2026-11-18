# Experiment Log & Hard-Won Lessons

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

- Blender master `assets/models/source/right_buttress.blend` and author/export script `scripts/blender_author_right_buttress.py`. The `ButtressMesh` object uses metre units, a foot-level origin, a matte preview material at 0.88 roughness and the `Trailward notch` vertex group. The master is saved with the 0.78 m recess. Red marks slate, green carries AO and blue is zero because this module has no ochre boulders.
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
$author = 'scripts/blender_author_right_buttress.py'
$walk = @('--path', '.', '--rendering-method', 'forward_plus', '--fixed-fps', '60', '--max-fps', '60', '--script', 'res://scripts/test_true_3d_walk.gd', '--')

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
$walk = @('--path', '.', '--rendering-method', 'forward_plus', '--fixed-fps', '60', '--max-fps', '60', '--script', 'res://scripts/test_true_3d_walk.gd', '--', '--capture-dir', $out, '--landmark', '1.73465,0.03,-22.23546')

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

- **Source.** `assets/textures/source/handlaid_sandstone.kra` is the Krita master, with separate packed joint sand, stone faces, mineral flecks and a hidden linear height layer spanning 0–40 mm. `scripts/build_handlaid_sandstone.py` generates the periodic OpenRaster layers and derives the tangent-space normal using wrapped differences of the editable height values. The two imported maps are `assets/textures/canyon_pbr/handlaid_sandstone_albedo.png` (the Krita composite) and `handlaid_sandstone_normal.png`.
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
$walk = @('--path', '.', '--rendering-method', 'forward_plus', '--fixed-fps', '60', '--max-fps', '60', '--script', 'res://scripts/test_true_3d_walk.gd', '--', '--capture-dir', $out, '--landmark', '1.73465,0.03,-22.23546', '--bend-probes')
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

The edited master is `assets/textures/source/crisp_sandstone_patch.kra`, with `crisp_sandstone_patch_albedo.png` and `crisp_sandstone_patch_normal.png` under `assets/textures/canyon_pbr/`. Use `scripts/build_handlaid_sandstone.py --crisp-patch` for the OpenRaster layers and wrapped tangent normal. The optional relief source is `assets/models/source/crisp_patch_crowns.blend` and its GLB is `assets/models/crisp_patch_crowns.glb`. The walk harness supports `--road-clip` and `--anisotropy 4|8|16`. Use `--road-patch-original-art` on the patch scene to reproduce the filtering-only runs and `--normal-pair` to capture the refined normals versus a flat normal. Use distinct capture prefixes.

## 9. Ultra-Crisp Code Road (`2048²` + ORM Cavity Shader + Camera Pitch Comparison)

Verified 18 Nov 2026 at 16:31 EET in isolated scene `res://scenes/maps/desert_canyon_ultra_crisp_test.tscn` via `scripts/test_ultra_crisp_road.gd`. Root cause of Session 2/3 blurriness diagnosed: `-13°` pitch squashes 1 vertical screen pixel to `~20.6 texels` at `512 tex/m`, so `6–12 texel` soft stone shoulders + `INTER_CUBIC` blobs + uniform matte `ROUGHNESS=0.86` + low joint/crown contrast washed stone boundaries together.

- **Implementation:** `scripts/build_ultra_crisp_cobble.py` builds `2048×2048` (`4.0 m × 4.0 m`, wrap `X=1.32×`, `Z=1.06×`) with `1.8-texel` hard edges, piecewise-linear crystal facets, angular corner chamfers, bright upper-right crown bevels against deep crevices, and `ultra_crisp_cobble_orm.png` (`R=cavity AO 0.16..1.0`, `G=roughness 0.48..0.96`). Applied in `assets/shaders/hd2d_canyon_ground_crisp.gdshader` with `mipmaps/generate=true` and `ANISOTROPY_16X`.
- **Result:** Split-patch proof at the locked `-13.0°` camera (`1_locked_cam_split_patch_pos1_start.png`) immediately eliminated the out-of-focus look right beside Session 3's soft road. Testing steeper diorama camera angles at matched `13.1 m` hero focus depth showed **`-17.5°` (`Y=4.85 m, Z=12.2 m`)** adds crisp vertical definition to both cobbles and Left Strata Wall steps while keeping distant mountains visible (`-21.0°` clips horizon mountains). Procedural stone borders still read slightly uniform/graphic compared to the concept. Captures in `render_captures/ultra_crisp_test/`.

## 10. ChatGPT Image Road (`3.2 m` Seamless + Aligned Height + Krita/Aseprite/Tiled Pack)

Verified 18 Nov 2026 at 17:21 EET in isolated scene `res://scenes/maps/desert_canyon_chatgpt_road_test.tscn` via `scripts/test_chatgpt_road.gd`.

- **Source Processing (`scripts/build_chatgpt_cobble.py`):** Processed user-generated `1024×1024` top-down ChatGPT albedo + aligned height map (`0.8145` low-frequency correlation) with `36 px` cosine edge-healing (`X wrap = 1.12×`, `Z wrap = 1.10×`, height `X = 1.10×`, `Z = 1.06×`) at **`3.2 m` tile scale**. Combined `32 mm` macro height + `8.5 mm` micro-grain albedo into `chatgpt_cobble_normal.png` and derived `chatgpt_cobble_orm.png` (`0.22` cavity AO, `0.52` crown roughness vs `0.95` joint roughness, mipmaps enabled).
- **Result — Clear Road Winner:** Eliminated the uniform graphic borders of procedural generation while preserving crisp micro-chips, ochre/salmon/olive stone diversity, and wind-blown sand grains at both `-13.0°` (`1_chatgpt_split_patch_pos1_start.png`, `2_chatgpt_full_pos1_start.png`) and `-17.5°` (`3_chatgpt_cam17_5_pos1_start.png`). Captures in `render_captures/chatgpt_road_test/`.
- **Editable Authoring Sources (`scripts/export_chatgpt_authoring.py`):** Exported native layered Krita master (`assets/textures/source/chatgpt_cobble.kra`), layered Aseprite sources (`chatgpt_cobble_1024.aseprite`, `chatgpt_cobble_pixel_256.aseprite` 48-color `32×32` grid), and a playable Tiled winding-road tileset & map (`assets/textures/source/tiled/chatgpt_road_tileset.tsx`, `canyon_road_sandbox.tmx`).

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

19 November 2026, Claude Code. Play **Developers Page → Composition test** (local study, no milestone). `res://scenes/maps/desert_canyon_composition_test.tscn` inherits the integrated ChatGPT AI Boulders scene. `scripts/canyon_composition_test.gd` changes the composition at runtime so every value stays switchable. In game, **C** restores the original camera, **V** cycles atmosphere (off → volumetric → overlay) and **B** restores the D4b sun. [Control vs test](../render_captures/composition_test/compare_final.jpg) · [All variants](../render_captures/composition_test/compare_v4.jpg) · [Haze diagnosis](../render_captures/composition_test/compare_diag.jpg)

| Change | Value | Why |
| --- | --- | --- |
| Route | `2.0 · sin(0.22 z)` from a shared `scripts/canyon_route.gd` resource (D4b 0.65) | The D4b route reads as straight. All `Roadside3DKits`, props, buttress and Trellis boulders are re-laid by Δcx(z) and re-aligned to the new heading. The ground shader and commander clamp use the same route. |
| Right wall | `RightWing_*`, `GatewayWingRight` and low `TerraceRight_*` hidden. Four left terrace meshes turned 180° at z 11.7, 5.5, −0.7, −6.4, plus `GatewayBluffLeft` turned 180° at z −15.6 | Removes the painted card blob and gives a continuous stepped right wall in shade. |
| Camera | 30° FOV, −21° pitch, offset (0, 5.5, 11.9) m, 60% route-centre follow, 45% yaw toward the road 9 m ahead | Hides the horizon at spawn and midway. The commander stays at about 13.1 m, inside the native DOF band. |
| Sun | Same 42° elevation, yaw 145°: from ahead-right instead of behind-right | The right wall casts img1's diagonal shadow across the road. |
| Air | Exponential fog off, rock `haze_strength` 0.24 → 0.10, painted road shadow 0 | See the haze diagnosis below. |

**Haze diagnosis.** The steeper camera sees more wall beyond 16 m, and the D4b exponential fog (0.0075) washed it to flat beige. Turning off glow or DOF changed little. Turning off exponential fog brought back the dark umber right wall and readable strata. Global volumetric fog at 0.008–0.018 only hazed the walls, with no visible shafts even with the backlit sun. Default atmosphere is off. Shafts need a localized `FogVolume` at a wall opening in the atmosphere pass.

**Walk (1376×768 Forward+, `scripts/test_composition_walk.gd`).** Grounded at all stops. Exit signal at the final stop. Spawn hero (1.937, 0, 6.0), camera (1.162, 5.5, 17.9) at yaw 2.9°. Midway hero (−0.250, 0, −3.525), camera (−0.437, 5.5, 8.379). Exit hero (−0.850, 0, −14.025), camera (−0.326, 5.5, −2.118). The harness only holds forward, so the commander rides the right clamp edge at midway. The crater glint is now occluded by `ButtressMesh` at spawn **and midway** and is clear at the exit. The reveal moved later, which matches the concealed far road. Re-time it if the midway reveal remains a requirement.

**Regression check.** The ground shader gained `route_amplitude/frequency/phase` with D4b defaults. The player clamp calls an overridable `_route_center_x`. The control walk is pixel-identical to the earlier integrated capture (max channel difference 1), so existing builds are unchanged. Main Play still opens ChatGPT AI Boulders. Card launch, C/V/B, a grounded walk and Esc return passed.

**Findings to carry forward.**
- The D4b assembler stores module yaw as `-atan(slope)`, so its walls turn against the curve. This was invisible at 0.65 m and matters at 2 m. The composition script corrects it.
- Rigid 6.5 m slices on a 2 m curve leave chord errors up to about 0.4 m at slice ends. No gaps show at the three stops, but curbs drift off the shader's road edge on the outside of bends. Path-driven placement (Path3D) should replace runtime re-laying before this becomes the baseline.
- The right wall reuses the left module, so both sides share a silhouette. Author dedicated right modules once the composition is accepted.
- Still open: slate caps read as flat grey, sage bushes are small, the exit vista is a flat orange plane.

Reproduce: `COMPOSITION_CAMERA=original|composition`, `COMPOSITION_ATMOSPHERE=off|volumetric|overlay`, `COMPOSITION_SUN=backlit|d4b`, plus diagnostics `COMPOSITION_FOG/GLOW/DOF=off`, with the usual walk arguments, `--script res://scripts/test_composition_walk.gd` and `--landmark 1.73465,0.03,-22.23546`.
