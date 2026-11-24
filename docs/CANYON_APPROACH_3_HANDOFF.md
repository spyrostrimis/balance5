# Approach 3 · A clearer commander in a painted canyon

**Handoff to Sol, 22 November 2026.** Deliver a standalone, playable 2D canyon study. Use Approach 1 for the continuous landscape and Approach 2 for the few pieces the commander can walk behind. Start with her artwork. A single standing pose has already demonstrated a substantial gain at the existing screen height. Animation, the new canyon and the final lighting still need to earn that result in motion.

## Independent assessment

**Approach 1 · the continuous painting.** At the entrance my eye follows the broken curb into the bend. The shrubs grow out of the sandy verge, and a cliff shelf can cast shadow across several stones. At the middle stop, the larger shoulder boulder and the sunlit right wall give the bend a shape of its own. This is the more convincing place to walk. Its weakest area is around the commander. The small bright cobbles compete with her scarf and rifle. By the upper pass the road is telling much the same visual story again. At the actual north barrier the camera has stopped scrolling, her head is cropped, and the road still appears to lead out of the frame. [Entrance](../render_captures/approach3_assessment/a1_entrance.png) · [Bend](../render_captures/approach3_assessment/a1_bend.png) · [North barrier](../render_captures/approach3_assessment/a1_end.png)

**Approach 2 · the modular canyon.** The curbs, sandy shoulders and cut stone are easy to distinguish. The arch and staircase on the left give the entrance an immediate point of interest, and the open sand gives the individual plants room to read. The drawback becomes clear when walking north. At the middle and upper stops the same left-hand arch, stairs and band of right-hand cliff reappear in almost the same arrangement. The kit places the arch three times, and the road strip repeats every 337 world pixels. The last screen reads like another stretch of road. This kit is strongest when an individual piece has a particular job, such as hiding the boots for a moment or marking a destination. [Entrance](../render_captures/approach3_assessment/a2_entrance.png) · [Bend](../render_captures/approach3_assessment/a2_bend.png) · [North barrier](../render_captures/approach3_assessment/a2_end.png)

## Comparison

The Developers Page has two doors into the same experiment. **Approach 1 vs 2** opens on the painting. **Approach 2 Modular** opens on the kit. Tab or M switches either one. Both use the same hero art, camera, lighting code and 960 × 540 default. Comparing their saved scenes after resolving resource IDs found differences only in the starting mode, visibility, active collision layer and spawn positions. [Scene builder](../tools/godot/build_rpg_2d_canyon_scene.gd) · [Runtime switching](../scripts/rpg_2d/canyon_2d_study.gd)

| What I would keep | Stronger example | How to use it in Approach 3 |
| --- | --- | --- |
| A road that belongs to the landscape | Approach 1 | Paint the bend, cliff toes, verge and broad shadow together. |
| A readable edge to the walking lane | Approach 2 | Keep the distinct curb stones and small pockets of open sand. Reduce bright joints immediately behind the hero. |
| A landmark and a sense of arrival | Approach 2 supplies the arch shape. Both need a stronger finish. | Place one recognisable ruin at the far opening. Hide part at the bend and show the whole shape at the end. |
| A readable Blue Commander | Both show the same weakness | Give her a separate colour palette, a properly drawn back view, and enough screen pixels to read her gear. |

[Four matched views, including the upper pass and the actual end](../render_captures/approach3_assessment/walk-comparison.jpg)

## Why she looks fuzzy

The south idle pose in the animation source occupies **67 × 126 visible pixels**. The build reduces a 128 × 144 frame to 104 × 120 and fits it to a palette sampled mostly from canyon art. In the shipped study texture that pose occupies **55 × 105 visible pixels** and uses **100 distinct opaque colours**, down from **255** in the source pose. Both have hard transparency at the silhouette. The face and rifle lose definition inside that silhouette. The north view also inherits a flipped front pose with patched hair and armour, which matters because her back faces us for much of the walk. [Source sheet](../assets/textures/pixel_canyon/blue_commander.png) · [Sprite builder](../tools/python/build_rpg_2d_canyon_assets.py) · [Source, game frame and lighting close-ups](../render_captures/approach3_assessment/commander-detail.png)

The game already uses nearest-pixel sampling on the hero and world display. Its sprite import is lossless with mipmaps off. At 768 pixels of window height, 540 rows of art fill the picture at about 1.42×. That gives individual art pixels uneven screen widths. It cannot restore the facial features discarded earlier. For this 2D scene, the practical measure is **visible character pixels at the same framing**. Her 105 pixels occupy 19.4% of a 540-pixel picture. At 765 pixels high we can give her 149 real pixels and keep her the same apparent size. [Texture filtering](GLOSSARY.md#texture-filtering) · [Texels per metre](GLOSSARY.md#texels-per-metre)

### One-pose experiment

Four live Godot renders used the modular entrance, an identical idle facing, the same camera centre and flat lighting with rays off. The left column uses the game sprite. The right uses the project's transparent 555 × 1126 commander illustration, reduced directly to the target height with its original colours. The top row uses the existing 960 × 540 render. The bottom uses 1360 × 765 drawn one-to-one inside a 1376 × 768 window. For the latter, camera zoom is 765/540 so the road and hero keep their framing. The figure contains unscaled crops of the window captures. [Four-way visual proof](../render_captures/approach3_assessment/idle-proof.png) · [Full frame of the clearest candidate](../render_captures/approach3_assessment/proof_765_reference.png)

The art change makes the largest difference. Even in the upper-right image I can separate the cream scarf from the face and follow the dark barrel to its tip. Raising the resolution with the current sheet leaves the face and chest mottled. Using both changes gives the clearest face, blue shoulder plate and cyan gauntlet. This proves a static pose on one background. It compares the complete art treatments, so it does not assign separate shares of the gain to the redraw, palette or resizing.

## Implementation plan for Sol

1. **Build a separate study and reproduce the proof.** Read `AGENTS.md`, `README.md`, `docs/GAME_DESIGN.md`, the visual rubric and experiment log. Use the RPG canyon image for light, stone and atmosphere, and the Blue Commander image for identity. Create `scenes/rpg_2d/canyon_approach3.tscn` and keep new assets under `assets/textures/rpg_2d/approach3/`. Give the study its own root script. The existing root restricts its approach ID to 1 or 2. Reuse movement and camera behaviour where compatible, and keep the old builds available for comparison. First output is a matched pair at the modular entrance with the original and reference-derived idle at the same height. [Canyon goal](references/rpg_canyon_goal.jpg) · [Commander reference](references/blue_commander_pixel.webp) · [Transparent source](../assets/textures/units/blue_commander_rpg.png)

2. **Make the display and art agree on scale.** Keep the current logical 960 × 540 view and 960 × 1967 map coordinates for movement, colliders, foot anchors and road width. For the reference window, render the world at 1360 × 765, centre it on whole screen pixels, and present it one-to-one. Use a scene-local display policy and restore window settings on exit. Fit other window sizes using the largest whole 16:9 rectangle that fits, e.g. 1280 × 720 at that window size. Scale camera zoom by render height / 540. For artwork authored for the 765-high target, use 765/540 source pixels per logical unit and the reciprocal scale on its drawing node. Measure the visible figure after transparent padding. Target 149 pixels at 765, 140 at 720. Check a resize and an out-and-back walk for edge crawl. If the snapped camera steps unevenly, snap the final drawing transform in render pixels while retaining fractional movement for physics. [Existing camera](../scripts/rpg_2d/pixel_camera_2d.gd) · [Example of scene-local display sizing](../scripts/pixel_canyon/pixel_display.gd)

3. **Finish the commander before expanding the map.** Start with front idle, an authored back idle and a side aim. Use the existing illustration to establish the pale scarf, cool blue plates, dark rifle, separate boots and small cyan cross. Give the profile a rifle silhouette that still reads against bright stone. Use her own colours. Touch up face and hands at final drawing size. Build four walk frames each for front, back and side, then profile idle, two combat steps and recoil. The existing controller expects four columns and four rows and mirrors left/right. Keep that interface or supply an explicit mapping. Align every frame at the planted boot, register the gun flash to the barrel in both directions and preserve free movement in depth with horizontal fire. Inspect the full northbound walk and both mirrored profiles. Deliver a looping walk and front/back/side crops on light stone and in shade. [Movement, facing and weapon code](../scripts/rpg_2d/hero_2d_controller.gd)

4. **Build one bend at final drawing size.** Paint a continuous stretch with an inside wall, a curb that turns behind it, and one glimpse of the exit ruin. Draw wider original plates or overlapping sections at the chosen density. The existing Approach 1 source plates are only 682 pixels wide before their side extensions. Enlarging the finished canvas is a useful control. For the candidate, give new detail to the curb lips and cliff edges, leave quieter stones in the walking lane, and group shrubs where the wall meets sand. Add a few separately drawn foreground pieces, each anchored where it touches the ground. Walk past the same boulder from both directions and check that the correct part of the hero disappears. Extend to entrance and exit only after the bend reads clearly at normal play size. [Existing art inputs](../assets/source_inputs/rpg_2d) · [Depth sorting by foot position](GLOSSARY.md#y-sort)

5. **Compose an ending and then light it.** Give the entrance, bend and exit distinct silhouettes. At the upper pass the ruin should be identifiable. At the north barrier show the full commander, some headroom and the revealed destination. Add painted space beyond the playable cap or move the cap and camera limits together. Check the first frame after reversing. Begin with broad painted light and a small contact shadow under the feet. Reintroduce surface lighting and sun shafts separately. Keep a setting only if the face, blue armour and rifle still read in the lit and shaded captures. A softer distant opening can give depth while the hero and nearby curb stay sharp. [Lighting controls](../scripts/rpg_2d/canyon_2d_study.gd)

6. **Verify and deliver.** Capture Approach 3 at the same logical Y positions as the baseline below. Supply full-size PNGs, matched-size hero crops and a short real-time round trip including a stop, reversal, strafe and shot in each direction. Compare first against Approach 1 for composition, then Approach 2 for curb clarity and walk-behind behaviour. Check 1280 × 720 and the 1376 × 768 reference window. Measure frame time on the same machine and route with lighting on and off. Add a standalone **Play** card, launch through the Developers Page, return with Esc, and re-export the Windows build after the catalog change. Log verified results and update the roadmap and rubric. Keep animation readability and the owner's overall visual preference open until reviewed.

**Completion checks**

- [x] At normal window size, face, scarf, blue armour, gauntlet and rifle are distinguishable at the entrance. The rear view reads as her back. Both boots and the muzzle stay registered through a walk, stop and shot.
- [x] The new idle remains about 19.4% of picture height. At 1376 × 768 the 149-pixel candidate and original are compared at equal apparent height, with matched lighting and pose.
- [x] Entrance, bend and exit are recognisable from the landscape alone. The ruin appears once. The commander stays fully framed at the north end.
- [x] In both directions the foreground boulder briefly covers the appropriate part of her, with clean edges, stable ground contact and a clear route around it.
- [x] New and baseline tests pass. The playable scene, short recording, evidence and exported Play/Esc round trip are available for the owner to judge.

## Baseline and reproduction

Godot 4.7.2 Forward+, RTX 4060 Ti, 1376 × 768 capture, HUD hidden. Baseline images use normal lighting and shafts. Posed comparisons use the same facing and relative road-centre offset in each mode. The independent headless walk drove the road centre from spawn to the north cap and back using the hero controller. These two scenes use 2D foot colliders and a north barrier. They have no 3D floor-contact or exit-signal measurement.

| Stop | Approach 1 boot position | Approach 2 boot position | Facing |
| --- | --- | --- | --- |
| Entrance | (416, 1560) | (487.2, 1560) | South |
| Bend | (509.5, 1010) | (494.25, 1010) | North |
| Upper pass | (414, 360) | (493, 360) | North |
| North barrier after collision settles | (398.7, 88.1) | (453.4, 88.1) | North |

The headless road-centre round trips ended at Y 1719.5 and 1720.2 respectively, against a spawn of 1720. The repository logic test also passed both wall checks, camera follow, fixed scale, eight explore directions and switching. Re-run it from the repository root with the first command below. The second runs the existing visual harness, whose upper modular pose deliberately steps behind a boulder. For a matched baseline use the four positions above. The exact review captures are local to the primary workspace under `render_captures/approach3_assessment/`.

```powershell
& "C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_rpg_2d_canyon_logic.gd
& "C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1376x768 --script res://tests/capture_rpg_2d_canyon.gd
```

## Implementation and verification

**Play** opens **2D Painted Canyon · Approach 3** in the Developers Page. Walk with WASD or the arrow keys, press C for rifle stance, and fire with Space, J or left click. Up and down in rifle stance move through depth while the rifle keeps its horizontal direction. L and G compare live surface light and added shafts. Esc returns to the library.

The 149-pixel front idle in the modular proof matches the handoff’s commander crop pixel for pixel. The new scene draws at 1360 × 765 in a 1376 × 768 window and uses a separate 140-pixel idle at 1280 × 720. Both use the same ground coordinates and foot collider. The camera and drawing origin align to final picture pixels. The sprites keep their own colour palette. The north pose has a drawn backplate and braid, with four walking frames in each of the three exploration facings. The recoil barrel tip registers the flash and projectile in both directions. [Matched modular proof](../render_captures/approach3/proof-pair.png) · [Front, back and both rifle profiles](../render_captures/approach3/commander-poses.png) · [Walk loop](../render_captures/approach3/commander-walk.gif) · [Window size check](../render_captures/approach3/resize.jpg)

**Against Approach 1.** The road, terraces and cliff shelf share one 838 × 1877 painting, fitted and sharpened to the 1360 × 3044 drawing surface. The entrance has a low overhang and an open sandy apron. The left wall projects into the bend and shades the grey lane in one broad shape. The single ruin comes into view on the upper pass as the camera looks uphill, then fits in the same view as the whole commander at the north barrier. Its crown is outside the middle bend frame. [Three studies at four matched stops](../render_captures/approach3/comparison.jpg)

**Against Approach 2.** The lighter curb separates the walking lane from the sand without the repeating modular arch. The raised boulder and bend rocks share pixels with the painting. Boot depth determines which draws in front, with the boulder’s small floor footprint blocking movement and room to pass to its left. The boulder masks the boots and lower legs in the behind poses. [Boulder from both directions](../render_captures/approach3/boulder-pass.png)

| Stop | Approach 3 boots | Camera Y | Arrived |
| --- | --- | ---: | --- |
| Entrance | (485, 1560) | 1560.4 | No |
| Bend | (539, 1010) | 1009.8 | No |
| Upper pass | (502, 360) | 179.6 | No |
| North barrier | (474.6, 88.1) | 87.9 | Yes |

The controller-driven recording stopped at (475.3, 88.076), strafed, fired horizontally both ways, and returned to (495.1, 1719.4). The 2D foot collider stays on the painted corridor and the gate event fires once. [28-second round trip](../render_captures/approach3/roundtrip.mp4)

Forward+ timing on the RTX 4060 Ti used the same walk from Y=1200 to Y=780 with shafts off and vertical sync disabled. Full-window frame time was 0.361 ms median and 2.725 ms at the 95th percentile with surface lighting, compared with 0.350 ms and 1.984 ms with it off. GPU time for the canyon view was 0.036/0.063 ms with lighting and 0.019/0.039 ms with it off. These are local measurements for this short route. The shallow surface light stays on by default. The opening keeps the shafts in the painting, with the added shafts off. [Lighting comparison](../render_captures/approach3/lighting.jpg)

The Windows Desktop release was re-exported. The Approach 3 Play card opened the study in the release window. The catalog test loaded the resources from the same executable, opened the Play card and sent Esc through the game input to verify the return. Both Approach 3 and the Approach 1/2 logic suite passed.

The overall look and in-motion read remain open for owner review. Original generated paintings and exact prompts are in [Approach 3 source art](../assets/source_inputs/rpg_2d/approach3/PROMPTS.md).

```powershell
$godot = "C:/Godot/Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --fixed-fps 60 --script res://tests/test_canyon_approach3.gd
& $godot --path . --resolution 1376x768 --script res://tests/capture_approach3_proof.gd
& $godot --path . --resolution 1376x768 --script res://tests/capture_approach3.gd
& $godot --path . --resolution 1376x768 --script res://tests/capture_approach3.gd -- --walk-cycle
& $godot --path . --resolution 1376x768 --script res://tests/capture_approach3.gd -- --timing
& $godot --path . --resolution 1280x720 --write-movie tmp/approach3.avi --fixed-fps 60 --disable-vsync --script res://tests/capture_approach3.gd -- --record
& $godot --headless --path . --export-release "Windows Desktop" builds/Balance.exe
```
