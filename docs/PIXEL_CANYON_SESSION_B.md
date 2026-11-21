# Pixel Canyon · Session B

**Play** [Session B](../scenes/rpg_2d/canyon_session_b.tscn) in Godot or open **Developers Page → Canyon builds → Pixel Canyon · Session B** in [Balance.exe](../builds/Balance.exe). Use arrows or WASD for eight-way walking. F11 switches fullscreen. Esc goes back to the Developers Page when launched from it.

[19.2-second round trip](../render_captures/canyon_session_b/session_b_round_trip.mp4) · [Matched frames in both directions](../render_captures/canyon_session_b/matched_frames.png) · [The same stair](../render_captures/canyon_session_b/same_stair.png) · [Painting comparison](../render_captures/canyon_session_b/overlook_comparison.png)

[Painted Bend](PIXEL_CANYON_SESSION_B_PAINTED.md) uses this walk and camera for a three-painting art comparison.

## What the short bend shows

| Time | What happens |
| --- | --- |
| 0:00–0:04 | Walk up the narrow road. The terrace starts to appear ahead, with the twin arch outside the entrance frame. |
| 0:04–0:06 | Stop behind the sandstone tip and back out a few steps. The near face covers the lower part of the commander, then her boots come back into view. |
| 0:06–0:09 | Round the wall and emerge beside the terrace. Both spans of the arch enter the frame at the same scale. |
| 0:09–0:11 | Cross the plaza sideways by 116 ground pixels, keeping the same uphill position. |
| 0:11–0:19 | Pass the same stair and near wall downhill, then reach the entrance. |

The world, commander and camera keep one art pixel scale. The camera has 12 art pixels of sideways leeway and 9 in depth. The near wall is a foreground layer aligned to the same coordinates as the ground. It masks the commander on both passes. The camera brings the fixed arch into view progressively as the route turns. The near cliff, its shadow, the continuous curb, the terrace masonry and the step each stay at their own map positions. The 116×96 pixel crop around the chipped fifth step matched byte for byte on the return. [Windowed run log](../render_captures/canyon_session_b/run.log)

The movement reference was the owner's Sea of Stars screenshot and brief. Option C supplied the Blue Commander's exploration sprite rows and the model for four-axis movement with diagonal steps, a planted foot point and whole-pixel camera drawing. Road to the Arch supplied the narrow sandstone corridor, warm light and cobble palette. Arch Overlook supplied the pale twin arch, terrace railing, stairs and violet valley. The close landforms and architecture were redrawn to fit one elevated view. The painter samples small grain swatches from both Balance paintings. [Option C bend](../render_captures/rpg_2d/03_mid_bend_explore_north.png) · [Art source](../tools/python/paint_canyon_session_b.py)

## Overlook beside the painting

- **Viewing angle.** The original looks farther along the path, with a sky and a horizon. Session B looks down onto the terrace plan and cliff tops. The landforms are drawn at one angle in the map.
- **Apparent depth.** The painting tapers the road and shrinks the distant masonry. In Session B the stones hold their size. The near wall, layers of rock and shaded valley give the drop its depth. The valley reads as a nearby drop with simpler mesas than the painting's distant vista.
- **Arch size.** The original arch is 237×139 art pixels in its source cutout. The new arch is about 241×133 art pixels, including the roof and pier feet. It does not change as the commander approaches. The first span enters the frame by the wall stop, and both are visible at the overlook.
- **Art review.** The stairs, terrace, curb and wall keep their connections in the moving view. The rock caps are broader and the sunset colour quieter than in the paintings. This is evidence for the fixed-angle walk and connected layout. Approval of the visual direction is open.

[Full-size side-by-side](../render_captures/canyon_session_b/overlook_comparison.png) · [Forward+ window](../render_captures/canyon_session_b/forward_plus_viewport.png)

## Verified positions

| Stop | Boots uphill / return | Camera uphill / return | Commander covered uphill / return |
| --- | --- | --- | --- |
| Entrance | (500.0, 1140.0) / (501.6, 1138.4) | (522, 1051) / (536, 1040) | 0% / 0% |
| Near wall | (754.8, 771.3) / (756.4, 769.7) | (765, 691) / (790, 672) | 63% / 61% |
| Overlook | (1108.4, 654.4) / (1110.6, 654.4) | (1104, 574) / (1104, 574) | 0% / 0% |

The native 960×540 game image was captured in a 1376×768 Forward+ Vulkan window. The tests verified both road edges, fixed character and camera scale, the stop, an uphill-to-downhill reversal, the sideways crossing and the return within 3 pixels of spawn. The wall coverage is the share of nontransparent character pixels behind the near wall. The camera and boots held while walking input was released. [Headless checks](../render_captures/canyon_session_b/headless.log) · [Catalog check](../render_captures/canyon_session_b/catalog.log)

## Reproduce

Use Godot 4.7.2 from the repository in PowerShell. Python with Pillow and NumPy rebuilds the two map textures. The study uses a stored copy of the first three rows of Option C's `blue_commander_sheet.png`.

```powershell
$sessionGodot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force render_captures/canyon_session_b, tmp/canyon_session_b | Out-Null
python tools/python/paint_canyon_session_b.py
& $sessionGodot --headless --editor --import --path .
& $sessionGodot --headless --path . --fixed-fps 60 --script tests/test_canyon_session_b.gd
& $sessionGodot --path . --rendering-method forward_plus --resolution 1376x768 --fixed-fps 30 --script tests/test_canyon_session_b.gd -- --record
& 'C:/ffmpeg/bin/ffmpeg.exe' -f rawvideo -pixel_format rgb24 -video_size 960x540 -framerate 30 -i tmp/canyon_session_b/session_b.rgb -vf 'scale=1920:1080:flags=neighbor,format=yuv420p' -c:v libx264 -crf 17 -movflags +faststart render_captures/canyon_session_b/session_b_round_trip.mp4
```
