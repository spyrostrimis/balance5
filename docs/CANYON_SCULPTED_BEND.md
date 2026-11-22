# 3D Canyon · Sculpted Bend

**Play** from the Developers Page. Use WASD or arrows to walk both ways, **R** for raised or flat stones, **V** for the painted or modeled valley and **Esc** to return. The study uses the existing Blue Commander with her original sprite, movement and animation.

[Three-study comparison](../render_captures/sculpted_bend/three_studies.jpg) · [Round trip](../render_captures/sculpted_bend/round_trip.mp4) · [3D Kit Canyon control](../render_captures/sculpted_bend/control_comparison.jpg) · [Raised vs. flat cobbles](../render_captures/sculpted_bend/raised_flat.jpg) · [Modeled vs. painted distance](../render_captures/sculpted_bend/distance_comparison.jpg)

## What changed through the passes

1. Captured the 3D Kit Canyon as it stood in the working tree, then checked Painted Bend's near-wall overlap and twin-arch reveal, Approach 2 Modular's connected road and curbs, and the warm directional light of the RPG goal image.
2. Opened the provisional kit in Forward+ from several angles. Namaqualand Cliff 02 had the right fractures, with a thin rear edge visible where the raw scan turned away. Rock Face 01 provided the lower shelf. The first bend exposed the rear of the tall scan and put the camera inside it at the original exit stop. Seated both scans in stepped solid rock and moved the camera along the curve at its own depth. Captured both before and after. One warm sun casts the inside wall's shadow across the path.
3. Dressed one entrance stretch first. All five Namaqualand stones read as separate shapes, with about 3–5 cm of exposed relief at the tallest points. The first lighting pass gave sunlit crowns harsh contrast. A narrower stone palette and softer cool fill kept the crowns readable in shade. Rock 07 became the longer curb, with a turned worn corner, a partly buried block and intentional sandy gaps. The three Cheiridopsis forms hold up as 3D clusters with cutout leaf edges and cast shadows. Bare stretches separate the plant and gravel pockets. Captured these before extending the layout.
4. Widened the path at the overlook and added a low stone rim. The modeled valley and solid arch read clearly in motion but have broad angular faces. The painted distance gives the arch an eroded shape, stronger sunlight and overlapping ridges. It sits on a fixed plane well beyond the 3D foreground. It is the default for the study. V restores the modeled valley for the same camera. The foreground, collision, route, light and framing stay paired.

[Near-wall pass](../render_captures/sculpted_bend/reveal_2.png) · [Foreground pass](../render_captures/sculpted_bend/foreground_0.png) · [Entrance](../render_captures/sculpted_bend/entrance.png) · [Middle](../render_captures/sculpted_bend/middle.png) · [Exit](../render_captures/sculpted_bend/exit.png) · [Return](../render_captures/sculpted_bend/return.png)

## Verification

Godot 4.7.2 Forward+ with Vulkan on the RTX 4060 Ti. The full-size gameplay frames and 467-frame recording came directly from the 1376 × 768 viewport. The comparison board aligns the entrance, bend and overlook or upper pass by their role in each study and preserves each study's own camera. The 2D Approaches use their 960 × 540 art canvas inside the 1376 × 768 window.

| Stop | Commander position in metres | Grounded |
| --- | --- | --- |
| Entrance | (−1.150, 0.000, 6.000) | Yes |
| Middle stop | (0.469, 0.000, −3.433) | Yes |
| Side step | (1.144, 0.000, −3.433) | Yes |
| Reversal | (0.386, 0.000, −1.883) | Yes |
| Overlook | (6.169, 0.000, −17.583) | Yes |
| Return | (−1.147, 0.000, 5.956) | Yes |

The 15.57-second round trip sampled 719 moving physics ticks with zero airborne ticks. The commander stopped, stepped 0.675 m sideways and briefly reversed before continuing around the wall. The exit signal entered once and reset on the return. The headless drive touched both sides at +2.172 and −2.183 m and both ends at Z +7.500 and −18.500 m. The navigation query returned a 17-point, 24.76 m route clear of blockers. A request outside projected inside the canyon after the navigation bake was restricted to a road-shaped floor strip. R preserved the exact camera and stone colours in the matched pair and kept foot contact during the short flat walk.

[Walk and recording log](../render_captures/sculpted_bend/walk.log) · [Headless checks](../render_captures/sculpted_bend/physics.log) · [Road switch log](../render_captures/sculpted_bend/road.log) · [Vista switch log](../render_captures/sculpted_bend/vistas.log)

Launched the study through the source project's Developers Page and returned with Esc. Ran the scene from the Godot editor and saw all three landmarks. Exported the Windows Desktop preset to `builds/Balance.exe`. Opened that executable, used the card, inspected all three landmarks and switched the vista, and returned to the Developers Page with Esc.

[Editor play](../render_captures/sculpted_bend/editor_play_landmarks.png) · [Windows landmarks](../render_captures/sculpted_bend/exported_landmarks.png) · [Windows Esc return](../render_captures/sculpted_bend/exported_esc_return.png)

## Asset sources

The two layered boulders are the existing Trellis assets using their ChatGPT sandstone materials. Austin Beaulier's **Grand Canyon Rock (photogrammetry)** is the pale landmark. The publisher metadata identifies it as **Free Standard**. Sculpted Bend uses the owner workspace's shared `assets/models/way1b_free_3d/grand_canyon_rock.glb` and its photo texture. Its GLB has the same SHA-256 as the Free Packs conversion. The Windows executable embeds both imported resources through direct scene dependencies. The preset continues to exclude `assets/models/packs_local/`. The gravel scan was a separate download. [Source and credits](../assets/models/sculpted_bend/LICENSE_SOURCES.txt) · [Publisher record](https://api.sketchfab.com/v3/models/bc98301459854d57984c5a40525d536f) · [Sketchfab license](https://sketchfab.com/licenses)

The five retouched asset sets are from Poly Haven under CC0. ChatGPT Images created the matte painting using the built-in image tool. [Poly Haven license](https://polyhaven.com/license) · [Painting](../assets/textures/canyon_layers/sculpted_bend_painted_vista.webp)

> Paint a distant warm fantasy canyon basin from a ledge, with a weathered natural sandstone arch, overlapping violet mesas, a dry wash and apricot late-afternoon light from the upper right. Use confident painterly brush strokes and horizontal strata. Keep the nearest detail soft enough to sit behind real 3D paving and rock. Keep the full landscape clear of foreground cliffs, roads, figures, structures and lettering.

## Verdict

Painted Bend has the strongest RPG image as a whole. Its foreground overlap, colour and twin-arch terrace are composed together, and the reveal shows the reward before the commander arrives. Approach 2 Modular puts the best connection between soil, curb, masonry and plants on screen. Sculpted Bend's strongest reason to use 3D is how the wall passes the camera and the same ground holds up on the return walk. Its stone height earns visible highlights near the boots. The shelf still reads as several large rock pieces, the sand is comparatively empty, and the curbs and plants feel less integrated. The painting makes the strongest 3D overlook of the two versions here. My choice for the RPG interludes would still be Painted Bend, with the 3D study available for a movement comparison. The direction decision stays open.

## Reproduce

```powershell
$godot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
$test = 'res://tests/test_sculpted_bend.gd'
& $godot --path . --headless --fixed-fps 60 --script $test
& $godot --path . --resolution 1376x768 --fixed-fps 30 --script $test -- --record
& $godot --path . --resolution 1376x768 --fixed-fps 30 --script $test -- --road-pair
& $godot --path . --resolution 1376x768 --fixed-fps 30 --script $test -- --vista-pair
& $godot --path . --resolution 1376x768 --script $test -- --catalog
& $godot --path . --headless --export-release 'Windows Desktop' builds/Balance.exe
```

The recorder writes RGB frames to `tmp/sculpted_round_trip.rgb`. Encode at 1376 × 768, 30 fps with FFmpeg using the `rawvideo` input format and `rgb24` pixel format.
