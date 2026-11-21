# Pixel Canyon III · Through the Bend

The walk and camera passed their gameplay checks. **The environment failed visual review.** The study is kept as a playable comparison. The review below records why the scenery breaks apart and which methods could support the same walk.

Open **Developers Page → Canyon builds → Pixel Canyon III · Through the Bend → Play** in [Balance.exe](../builds/Balance.exe), or run [the study scene](../scenes/pixel_canyon/pixel_canyon_follow.tscn) in Godot.

- **Arrows / WASD** move across the road or uphill and downhill. **Space** fires in the last horizontal direction. Align the commander's boots with the scout's boots to clear the bend.
- **1** selects exact follow. **2** selects the 8-art-pixel leeway used by default. Stop or reverse inside the bend to feel the difference.
- **F1** shows controls, **F2** shows the original painting, **F3** switches to rough art, and **F11** toggles fullscreen. **Esc** returns to the Developers Page when you launch from it.

[Two-Room Study](PIXEL_CANYON_STUDY.md) and [Camera and Depth](PIXEL_CANYON_CAMERA_STUDY.md) remain playable comparisons.

## Round trip and camera comparison

[Painted round trip, 48.2 s at 30 fps](../render_captures/pixel_canyon_follow/through_the_bend.mp4) · [Rough exact follow](../render_captures/pixel_canyon_follow/rough_exact.mp4) · [Rough follow with leeway](../render_captures/pixel_canyon_follow/rough_leeway.mp4) · [Matched frames](../render_captures/pixel_canyon_follow/leeway_sheet.jpg) · [Full Forward+ window](../render_captures/pixel_canyon_follow/leeway_viewport.png)

| Time | What to watch |
| --- | --- |
| 0:00–0:07 | Original stance, then a crossing on each side of the shrub |
| 0:11–0:15 | Scout blocks the bend. The first shot misses, and the second clears the road |
| 0:18–0:21 | Stop inside the bend, back out partway, then continue uphill |
| 0:23–0:27 | The left view opens past the rock wall. The twin arch grows as the commander approaches |
| 0:29–0:48 | Return around the same bend, past the cleared scout and both sides of the shrub, to the starting ground point |

The study uses 8 pixels of [camera leeway](GLOSSARY.md#camera-leeway) as its provisional default. Exact follow holds the boots at Y 325. With leeway, the boots take roughly one-third of a second to cross the band on a full reversal before the scenery starts moving the other way. On release, the camera stops immediately.

## Standing measurements

Ground position is `(sideways, uphill)`. Camera position is `(road centre, uphill)`. The stills use the same ground points in each direction. Leeway puts the camera on opposite sides of the band at several points, which accounts for the differences in boot height and sprite size.

| Stop | Ground | Camera out / back | Boot Y out / back | Standing height out / back |
| --- | --- | --- | --- | --- |
| Spawn | (0, 0) | (0.00, 0.00) / (−0.23, −14.05) | 325 / 317 | 125 / 121 |
| Behind shrub | (−97.5, −72.5) | (−4.20, −61.90) / (−7.87, −86.55) | 331 / 317 | 129 / 121 |
| In front of shrub | (−97.5, −118.75) | (−11.33, −105.65) / (−11.33, −105.65) | 333 / 333 | 129 / 129 |
| Scout's lane | (−45, 148.75) | (51.94, 161.85) / (51.94, 161.85) | 333 / 333 | 129 / 129 |
| Inside bend | (0, 385) | (172.15, 370.95) / (176.65, 398.10) | 317 / 333 | 121 / 129 |
| Overlook | (0, 690) | (58.28, 675.95) / (50.49, 703.10) | 317 / 333 | 121 / 129 |
| Twin arch turn | (0, 825) | (57.72, 810.95) | 317 | 121 |

[Painted run log](../render_captures/pixel_canyon_follow/leeway.log) · [Exact follow log](../render_captures/pixel_canyon_follow/rough_exact.log) · [Rough leeway log](../render_captures/pixel_canyon_follow/rough_leeway.log)

## What the study verified

The projected road uses cobble samples from both paintings, with nearby stones around 24 art pixels across. The stones and curb return to the same positions on the way back. The twin arch's projected size at the turnaround is 2.8 times its size at spawn. [Art source tool](../tools/python/build_pixel_canyon_follow_art.py) · [Route and measurements](../scripts/pixel_canyon/pixel_follow_route.gd)

The existing walk and fire poses share the original boot point. The shrub changes draw order as the commander crosses its roots, and its roots block a straight approach. The headless tests exercised both road edges and endpoints, a blocked bend, an off-lane miss, an on-lane hit, a left-facing shot, a reversal and a return to the cleared scout. The two-room and all three earlier camera variants also passed. [Test code](../tests/test_pixel_canyon_follow.gd) · [Leeway checks](../render_captures/pixel_canyon_follow/headless_leeway.log) · [Exact checks](../render_captures/pixel_canyon_follow/headless_exact.log)

The 1376×768 Forward+ Vulkan capture shows the 960×540 game view at native size. The original side-walk animation carries into uphill and downhill movement. The Play card launched and Esc returned to the Developers Page using the exported package. [Exported catalog check](../render_captures/pixel_canyon_follow/exported_catalog.log)

## Why the environment failed

| Evidence | What breaks the illusion |
| --- | --- |
| [Spawn](../render_captures/pixel_canyon_follow/leeway_out_spawn.png) | The left stair and wall end abruptly at the dirt. Detached bright rocks line both shoulders, with few shadows or rock courses joining them to the cliffs. |
| [Bend in both directions, 17–19 and 34–37 seconds](../render_captures/pixel_canyon_follow/bend_motion.jpg) | The ruin on the right sweeps and enlarges as a whole image. Its facade, archway and steps move together. Inside the bend, repeated orange rock shapes on both sides bring different ledge angles to the same stretch of road. |
| [First overlook view](../render_captures/pixel_canyon_follow/leeway_out_overlook.png) and [twin arch](../render_captures/pixel_canyon_follow/leeway_twin_arch.png) | The terrace has a distinct lower edge with valley haze behind it, so it looks hung over the rim. In the [original overlook painting](../assets/textures/pixel_canyon/arch_overlook.png), the stair, wall, cliff and paving connect. The new composition loses that connection as the camera moves. |

The shader draws the road and shoulders on one flat ground plane. A separately scrolling painting supplies the valley. Each large cutout has one anchor and one depth, even where the source depicts a wall several steps deep. The whole shape grows by the same factor as the camera approaches. The cutouts retain lighting, surface angles and overlaps from their original paintings. Mirroring repeats those forms and can reverse their lighting cues. The shader darkens part of the bend with a painted band, so the wall's shape never determines where its shadow meets the road. [Placement and projection](../scripts/pixel_canyon/pixel_follow_art.gd#L88) · [Ground and shadow](../assets/shaders/pixel_canyon/ground.gdshader#L66) · [How the wall was cropped and extended](../tools/python/build_pixel_canyon_follow_art.py#L103)

I over-weighted the continuous walk, readable character and camera measurements at handoff. Moving one ruin out of the camera's path fixed a conspicuous obstruction and left the underlying problem intact. The rough comparison could test follow behaviour because its scenery was intentionally abstract. It could never establish whether two finished paintings would hold up as moving foreground. Earlier canyon tests C1 and C2 had already flagged exposed silhouettes, obvious repetition and missing shadows on cutout cliffs. [Earlier cutout tests](EXPERIMENT_LOG_AND_LESSONS.md#1-proven-dead-ends-never-repeat--why)

## Is this method viable?

The camera, route, paving and character scale are viable. The near-environment method is a dead end for the full-length, low-angle walk with these two finished paintings. The camera must see newly exposed surfaces and changes in the relationship between the top, side and base of each wall. The source art has no record of those newly exposed surfaces. More accurate masks or less camera leeway would leave that missing information in place. Finished paintings still work for distant scenery or a short move with layered, purpose-painted artwork and painted-in areas behind each layer. [Layered Depth Images](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/Shade-SG98.pdf)

## Options for the next comparison

| Method | What it can deliver | Main trade-off |
| --- | --- | --- |
| **Continuous 3D canyon with the 2D commander** | Connected cliffs, curb and terrace with visible tops and sides, shared sunlight, and a perspective camera that can follow the whole bend. Use Canyon v2 for route, wall and camera behaviour. Use the two paintings as targets for material, light and composition. | The environment needs a style pass. Canyon v2 is evidence for structure and reveal only. The pixel scale, low camera and painted texture treatment still need to match the target. [Canyon v2 evidence](../render_captures/canyon_v2/compare_v2.jpg) · [Godot Sprite3D](https://docs.godotengine.org/en/stable/classes/class_sprite3d.html) |
| **Authored scrolling 2D map** | One continuous backdrop of connected cliff tops, faces, bases, contact shadows and a canyon rim, built as tiles or larger connected shapes. Option C is a starting point for this layout. | A fixed-scale view gives up the same low-angle perspective and natural growth of the arch. Composition and reveal would do more of the work of showing progress. [Option C bend](../render_captures/rpg_2d/03_mid_bend_explore_north.png) |
| **Purpose-painted layers or pre-rendered views** | The strongest control over how closely each view matches the painted target. Author the entire bend from a common layout and supply the surfaces that appear behind the near wall. A short camera move can use a few layers. A longer one could use frames rendered along a prescribed track, with depth masks for character overlap. | New art across the whole move, a tightly constrained camera and extra work for convincing stops, reversals and overlap. Short painted rooms with modest pans are the lower-cost version. [Camera and Depth](PIXEL_CANYON_CAMERA_STUDY.md) |

If the low-angle approach, close commander and growing arch are priorities, use the first method for a **short comparison only**. In a future pass, test one bend section with joined rock courses, a single opening, one arch and the existing sprite, using a small palette and one upper-right light. Capture before the bend, beside the wall and beyond it in both directions. The shelf must visibly support the terrace, the near wall must slide past as a solid volume, and its shadow must meet the ground. The same curb should lead home, and the commander should remain easy to read. Judge those together in moving footage before texturing the full route. If the project needs to stay entirely 2D, use the second method as the comparison and judge the different framing explicitly.

## Reproduce

Run from the repository in PowerShell. The capture and Windows executable are local outputs. Python with Pillow and NumPy regenerates the art from the existing paintings if needed.

```powershell
$followGodot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force render_captures/pixel_canyon_follow, tmp/pixel_canyon_follow | Out-Null
& $followGodot --headless --path . --fixed-fps 60 --script tests/test_pixel_canyon_follow.gd -- --clean
& $followGodot --headless --path . --fixed-fps 60 --script tests/test_pixel_canyon_follow.gd -- --clean --exact
& $followGodot --headless --path . --script tests/test_pixel_canyon_follow.gd -- --catalog
& $followGodot --path . --rendering-method forward_plus --resolution 1376x768 --fixed-fps 30 --script tests/test_pixel_canyon_follow.gd -- --clean --record
& 'C:/ffmpeg/bin/ffmpeg.exe' -f rawvideo -pixel_format rgb24 -video_size 960x540 -framerate 30 -i tmp/pixel_canyon_follow/leeway.rgb -vf 'scale=1920:1080:flags=neighbor,format=yuv420p' -c:v libx264 -crf 17 -movflags +faststart render_captures/pixel_canyon_follow/through_the_bend.mp4
& $followGodot --headless --path . --export-release 'Windows Desktop' builds/Balance.exe
```

For the rough runs, add `--rough` and repeat with `--rough --exact`. The capture harness names those frame files and raw recordings `rough_leeway` and `rough_exact`.
