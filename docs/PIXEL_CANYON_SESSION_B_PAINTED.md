# Pixel Canyon · Painted Bend

Play [Painted Bend](../scenes/rpg_2d/canyon_session_b_painted.tscn) in Godot or choose **Developers Page → Canyon builds → Pixel Canyon · Painted Bend** in [Balance.exe](../builds/Balance.exe). Walk with arrows or WASD. F11 switches fullscreen. Esc returns to the Developers Page. [Session B](PIXEL_CANYON_SESSION_B.md) is available beside it.

[19.2-second walk](../render_captures/canyon_session_b_painted/painted_bend_round_trip.mp4) · [Three paintings at 960×540](../render_captures/canyon_session_b_painted/candidate_comparison.png) · [Overlook beside the original painting](../render_captures/canyon_session_b_painted/overlook_side_by_side.png) · [Layered Krita source](../assets/source_inputs/rpg_2d/session_b_painted/painted_bend.kra)

The recordings, screenshots and review sheets live in the local `render_captures` folder. The repository includes the playable scenes, original candidate images and layered painting.

## The art comparison

ChatGPT Images received the same three inputs for every candidate. The [1584×1408 guide](../render_captures/canyon_session_b_painted/session_b_layout_guide.png) set the camera angle, road edges, near-wall outline and foot, stair landing, terrace and arch feet. [Road to the Arch](../assets/textures/pixel_canyon/road_to_the_arch.png) supplied the orange sandstone and sheltered approach. [Arch Overlook](../assets/textures/pixel_canyon/arch_overlook.png) set the target for the lit stair treads, terrace masonry and vista.

| Painting | At the three stops |
| --- | --- |
| [A · Sculpted sandstone](../assets/source_inputs/rpg_2d/session_b_painted/a_sculpted_sandstone.png) | Split rock shelves give the entrance weight. The stairs and arch share the spotlight with a brighter rim and more busy paving. |
| [B · Warm and cool light](../assets/source_inputs/rpg_2d/session_b_painted/b_warm_and_cool_light.png) | The entrance has a quieter approach. The violet drop opens out at the bend and frames the pale stair edges and arch at the overlook. This was the most inviting view to walk toward. |
| [C · Weathered masonry](../assets/source_inputs/rpg_2d/session_b_painted/c_weathered_masonry.png) | The terrace has the most legible blockwork. Strong light on the surrounding cliffs competes with the arch at the overlook. |

The comparison sheet crops all three original paintings at the entrance, bend and overlook camera positions, with the game sprite at one pixel scale. It draws the figure over each candidate before fitting the foreground. The [exact Session B map](../render_captures/canyon_session_b_painted/session_b_map_exact.png) and the individual outline checks show where the curb and the foreground crossed the guide differently. [A outline](../render_captures/canyon_session_b_painted/a_alignment.png) · [B outline](../render_captures/canyon_session_b_painted/b_alignment.png) · [C outline](../render_captures/canyon_session_b_painted/c_alignment.png)

## Fitting the painting

B originally exposed most of the cobbles at the bend. The art pass fitted both curbs, the terrace, the stair landing and the arch against the guide. The ground painting extends paving and verge behind the wall. The foreground uses Session B's exact transparency mask at (655, 468). A separate paint layer cools the light on the near wall beside the overlook. The Krita file retains the guide and the full candidate as hidden layers. Godot uses the ground and foreground PNGs at a single scale with no blur.

The [final road, collisions and wall overlay](../render_captures/canyon_session_b_painted/painted_alignment.png) shows the fit. In the plaza the collision edge stays in front of the arch and meets the stair as in Session B. The [matched screenshots](../render_captures/canyon_session_b_painted/matched_session_b.png) show the original and painted scenes at the same camera points.

## The walk

| Stop | Boots | Camera centre | Commander covered |
| --- | --- | --- | --- |
| Entrance | (500.0, 1140.0) | (522, 1051) | 0% |
| Bend pause | (754.8, 771.3) | (765, 691) | 63.0% |
| Bend reversal | (730.4, 782.3) | (764, 691) | 10.5% |
| Overlook | (1108.4, 654.4) | (1104, 574) | 0% |
| Bend home | (756.4, 769.7) | (790, 672) | 61.3% |

The original movement checks passed against the painted scene. The commander returned within 3 pixels of spawn, crossed 116 pixels sideways at the overlook and stayed against both road edges in the collision checks. The stair crop matched pixel for pixel on the return. The separate Play card and Esc return passed with the Windows export.

The 576-frame clip records the 1376×768 Forward+ window with its centred 960×540 game image. At about 4 seconds she pauses behind the wall, then reverses, emerges at the overlook, crosses sideways and walks home. [Viewport still](../render_captures/canyon_session_b_painted/forward_plus_viewport.png) · [Windowed run](../render_captures/canyon_session_b_painted/run.log) · [Headless checks](../render_captures/canyon_session_b_painted/headless.log) · [Exported catalog check](../render_captures/canyon_session_b_painted/exported_catalog.log)

## Art verdict

The **overlook** is strongest. The light on the stair treads leads up to the twin arch, and the violet valley reads through both openings. The **bend** is weakest. The near cap dominates the walking frame. Its sandstone detail softens around the fitted crest, and the commander is hard to see for a short stretch.

Keep this as a playable art study. The overlook shows that the fixed-angle walk can carry the mood of the paintings. The original Arch Overlook still has finer stonework and a clearer sweep from the foreground road to the arch. The new bend falls short as the visual master for future maps.

## Reproduce the capture

Run from the repository in PowerShell after importing the PNGs in Godot. Omit `--painted` to run the checks against the original Session B.

```powershell
$sessionGodot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force render_captures/canyon_session_b_painted, tmp/canyon_session_b_painted | Out-Null
Set-Content -Path render_captures/canyon_session_b_painted/.gdignore -Value ''
& $sessionGodot --headless --editor --import --path .
& $sessionGodot --headless --path . --fixed-fps 60 --script tests/test_canyon_session_b.gd -- --painted
& $sessionGodot --path . --rendering-method forward_plus --resolution 1376x768 --fixed-fps 30 --script tests/test_canyon_session_b.gd -- --painted --record
& 'C:/ffmpeg/bin/ffmpeg.exe' -f rawvideo -pixel_format rgb24 -video_size 1376x768 -framerate 30 -i tmp/canyon_session_b_painted/round_trip_window.rgb -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart render_captures/canyon_session_b_painted/painted_bend_round_trip.mp4
```
