# Pixel Canyon · Two-Room Study

For the first-room scale and camera comparison, see [Pixel Canyon · Camera and Depth](PIXEL_CANYON_CAMERA_STUDY.md).

Open **Pixel Canyon · Two-Room Study** on the Developers Page in [Balance.exe](../builds/Balance.exe), or run [the scene](../scenes/pixel_canyon/pixel_canyon.tscn) in Godot. Use arrows or WASD to move and Space to fire in the last horizontal direction. F1 shows controls, F2 toggles the untouched visual master, F11 switches fullscreen, and Esc returns to the Developers Page when launched from there.

The scout blocks the upper bend until hit. Align the commander's boots with the scout's boots, then fire. Follow the narrow road uphill to Arch Overlook. Walk off the bottom of that screen to return.

## Art review

| Question | Result |
| --- | --- |
| How close is the first room? | The untouched Godot view matched all 2,073,600 pixels in the supplied 1080p preview before the art work began. The final plate changes 7,785 native pixels around the original figure and shadow. The standing comparison shows how the runtime shadow and added scout affect the full composition. |
| Does the commander hold up in motion? | The original 125-pixel silhouette reads at middle depth. Both planted boots use the same ground point as the idle pose. The walk advances one cel per 3 art pixels of travel. The shrub crossing reads on both sides, and the camera stays still during the turn. The source's three-quarter upper body remains apparent in the side walk. Sprite height changes in small steps along the road. |
| Does Arch Overlook continue the style? | The twin arch, orange sandstone, warm cobbles and upper-right sun carry across. The second room opens into a broader panorama with brighter foreground stones. It reads as the next overlook, with wider paving and less enclosing rock. |

The most time-consuming manual correction was fitting donor cobbles beneath the scarf, rifle and long shadow without breaking the road's visible joints or shifting the verge. Donors came from neighboring stretches of the same road. The repaired patch was checked at [1×](../render_captures/pixel_canyon/repair_1x.png) and [2×](../render_captures/pixel_canyon/repair_2x.png).

The study showed that the painted background can support a short playable walk, foreground overlap, a lane-based fight and a change of rooms. The fixed framing held up during the shrub crossing. The stepped character size was the main depth issue on the upper road and became the subject of the follow-up. The two-room result is an art and gameplay experiment. [Camera and Depth findings](PIXEL_CANYON_CAMERA_STUDY.md)

## Evidence

Captures and the Windows build are local outputs. The test commands below reproduce the standing, walking and combat checks.

- [27.2-second 1080p playthrough](../render_captures/pixel_canyon/playthrough_1080p.mp4), recorded from the running Godot study with scripted controls. At 0:03 the commander goes behind the shrub. At 0:06 she crosses in front and turns back. The shots occur at 0:09 and 0:10, and Arch Overlook appears at 0:17.
- [Matched standing comparison](../render_captures/pixel_canyon/standing_comparison.png), [full source preview](../render_captures/pixel_canyon/source_1080p.png), [untouched Godot view](../render_captures/pixel_canyon/reference_game_1080p.png) and [live standing frame](../render_captures/pixel_canyon/game_standing_1080p.png).
- [Behind the shrub](../render_captures/pixel_canyon/behind_shrub.png), [in front](../render_captures/pixel_canyon/in_front_of_shrub.png), [far standing position](../render_captures/pixel_canyon/far_standing.png) and [Arch Overlook](../render_captures/pixel_canyon/overlook_walk.png).

The reference standing point is (511, 325). The foreground check at (413, 425) uses 106% sprite size and the far check near (514, 217) uses 84%. Both blocked terrain and the shrub's roots use the six-pixel circle under the boots. A shot can hit when the two ground points are within 11 vertical art pixels and the horizontal shot reaches the scout. In the recording the miss is about 30 pixels out of lane and the hit is within 1 pixel. The test also returns from the overlook, checks that the scout remains defeated, and fires left.

## Art files

- [Road to the Arch, layered Aseprite](../assets/source_inputs/pixel_canyon/road_to_the_arch.aseprite). The reference, repair and shrub are on separate layers at their original coordinates.
- [Blue Commander, layered Aseprite](../assets/source_inputs/pixel_canyon/blue_commander.aseprite) and [sprite sheet](../assets/textures/pixel_canyon/blue_commander.png). The 128×144 cells share the (64, 135) boot point. The tagged idle, 30 walk cels and two fire cels run in seven columns. Godot mirrors the poses to face left.
- [Arch Overlook, layered Krita](../assets/source_inputs/pixel_canyon/arch_overlook.kra) and [Aseprite version](../assets/source_inputs/pixel_canyon/arch_overlook.aseprite). The Krita file has the reduced illustration draft, the canyon, the playable road and the arch silhouette. The illustration uses colours sampled from the first room.

## Reproduce

From the project directory in PowerShell, with Godot 4.7.2:

```powershell
$studyGodot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force render_captures/pixel_canyon, tmp | Out-Null
& $studyGodot --headless --path . --fixed-fps 60 --script tests/test_pixel_canyon_study.gd -- --clean
& $studyGodot --headless --path . --script tests/test_pixel_canyon_study.gd -- --catalog
& $studyGodot --path . --fullscreen --resolution 1920x1080 --fixed-fps 60 --script tests/test_pixel_canyon_study.gd -- --clean
```

For the video, run the same test in a 1376×768 window with `--fixed-fps 30` and add `--record` after the separator. It writes 960×540 RGB frames to `tmp/pixel_study_frames.rgb`. Encode those frames at 30 fps with nearest-neighbour doubling:

```powershell
ffmpeg -f rawvideo -pixel_format rgb24 -video_size 960x540 -framerate 30 -i tmp/pixel_study_frames.rgb -vf "scale=1920:1080:flags=neighbor,format=yuv420p" -c:v libx264 -crf 16 -movflags +faststart render_captures/pixel_canyon/playthrough_1080p.mp4
```
