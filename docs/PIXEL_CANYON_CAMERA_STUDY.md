# Pixel Canyon · Camera and Depth

Open **Pixel Canyon · Camera and Depth** on the Developers Page in [Balance.exe](../builds/Balance.exe), or run the [Godot scene](../scenes/pixel_canyon/pixel_canyon_camera.tscn). Press **1** for A (current game), **2** for B (depth calibrated to the paving), or **3** for C (calibrated depth with uphill camera follow). You can switch while standing in the same spot. Move with arrows or WASD and fire with Space. F1 shows controls, F2 toggles the original painting, F11 toggles fullscreen, and Esc returns to the Developers Page. The original [Two-Room Study](PIXEL_CANYON_STUDY.md) is available from its own card.

## What to compare

Start with A and B at the upper road and gate. In B, the commander fits the smaller paving and curb better, and her boots and rifle remain distinct at 1080p. Her face carries less detail at the gate. Prepared 89- and 65-pixel samples softened the face and rifle, so the playable pass keeps the sharper nearest-neighbour version. The scout draws from the same scale as the commander at the scout's own boot position. [Prepared sizes](../render_captures/pixel_canyon_camera/prepared_size_check.png) · [Scout and commander at the same depth](../render_captures/pixel_canyon_camera/scout_scale_check.png)

Codex's review favored B for the first room. Calibrated scale delivered most of the depth improvement on its own. In C, the drift keeps the commander a little lower on screen as she approaches the bend, and more of the distant cliffs and sky come into view. The bend stays visible in both. The scale and framing are open for review. C uses provisional artwork at the top of the view.

| Boot point (X, Y) | Typical cobble width | A height above boots | B/C draft height | C camera travel |
| --- | ---: | ---: | ---: | ---: |
| Near paving (545, 425) | ~29 px | 133 px | 146 px | 0 px |
| Original spot (511, 325) | ~24 px | 125 px | 125 px | 0 px |
| Upper road (514, 217) | ~17 px | 105 px | 89 px | 14 px |
| Before the gate (575, 165) | ~12 px | 95 px | 65 px | 23 px |

The widths are approximate medians from five ordinary stones across each stretch of road. The width ratios suggested about 151, 125, 89 and 63 art pixels. The curb and nearby walls helped settle on 146, 125, 89 and 65 for this pass. Between marks the height changes steadily with the boots' position in the room. Walking speed, rifle muzzle and shadows use the same local scale. Arch Overlook uses its existing framing and scale in all three modes.

## Standing frames

Each row has the same boot point and facing across A, B and C.

| View | Side by side | Full 1080p captures |
| --- | --- | --- |
| Near paving | [Y 425](../render_captures/pixel_canyon_camera/standing_y425.png) | [A](../render_captures/pixel_canyon_camera/A_y425.png) · [B](../render_captures/pixel_canyon_camera/B_y425.png) · [C](../render_captures/pixel_canyon_camera/C_y425.png) |
| Original spot | [Y 325](../render_captures/pixel_canyon_camera/standing_y325.png) | [A](../render_captures/pixel_canyon_camera/A_y325.png) · [B](../render_captures/pixel_canyon_camera/B_y325.png) · [C](../render_captures/pixel_canyon_camera/C_y325.png) |
| Upper road | [Y 217](../render_captures/pixel_canyon_camera/standing_y217.png) | [A](../render_captures/pixel_canyon_camera/A_y217.png) · [B](../render_captures/pixel_canyon_camera/B_y217.png) · [C](../render_captures/pixel_canyon_camera/C_y217.png) |
| Gate | [Y 165](../render_captures/pixel_canyon_camera/standing_y165.png) | [A](../render_captures/pixel_canyon_camera/A_y165.png) · [B](../render_captures/pixel_canyon_camera/B_y165.png) · [C](../render_captures/pixel_canyon_camera/C_y165.png) |

[Maximum follow](../render_captures/pixel_canyon_camera/C_maximum_pan.png) · [F2 original painting](../render_captures/pixel_canyon_camera/C_reference.png) · [Restored gameplay](../render_captures/pixel_canyon_camera/C_restored_pan.png)

## Recordings

[A · Current game](../render_captures/pixel_canyon_camera/A.mp4) · [B · Calibrated depth](../render_captures/pixel_canyon_camera/B.mp4) · [C · Depth and follow](../render_captures/pixel_canyon_camera/C.mp4)

The 1080p, 30 fps clips run at game speed. Use the matching chapter names or the times below to compare at the same stretch of road.

| Action | A | B and C |
| --- | ---: | ---: |
| Behind / in front of shrub | 3.53 / 6.67 s | 3.43 / 6.33 s |
| Near paving stop | 8.83 s | 8.33 s |
| Miss / hit | 11.33 / 12.97 s | 10.67 / 12.23 s |
| Upper road stop | 17.47 s | 17.10 s |
| Downhill / uphill reversal | 18.07 / 18.87 s | 17.70 / 18.60 s |
| Gate stop | 22.00 s | 22.63 s |
| Arch Overlook / return | 22.63 / 36.10 s | 23.27 / 36.73 s |

## Checks

- Captured the Godot Forward+ viewport in a 1376×768 window and doubled its 960×540 game image. A matches the original live stance pixel for pixel. The calibrated commander at spawn keeps the same size and stance. F2 matches the supplied 1080p preview pixel for pixel and returns to the same gameplay image.
- At full follow, the 24 art rows fill the top of the screen with no exposed edge. B and C match pixel for pixel across their shared area after accounting for the whole-pixel camera offset.
- All three routes crossed the shrub from both sides, missed off-lane, hit on-lane, entered the overlook, returned, and fired left. The first rendered frame in Arch Overlook uses the fixed camera. The first frame back at the bend uses the follow position for (569, 184), a 19-pixel shift. Stops and reversals follow the same ground point without an extra camera step.

## Implementation

The comparison adds a camera to the original study's 960×540 game viewport. The view starts moving uphill near boot Y 300 at one art pixel per six pixels of boot travel, rounded to whole pixels and capped at 24. The same view moves the room painting, characters, shrub, shadows and shots. The controls and the F2 painting have their own fixed drawing layer. Room geometry, foreground overlap and shot lanes stay in room coordinates. [Comparison scene](../scenes/pixel_canyon/pixel_canyon_camera.tscn) · [Room and camera code](../scripts/pixel_canyon/pixel_study.gd) · [Commander scaling](../scripts/pixel_canyon/pixel_commander.gd) · [Walk and capture test](../tests/test_pixel_canyon_study.gd)

## Extension and source

[960×564 layered working copy](../assets/source_inputs/pixel_canyon/road_to_the_arch_camera.ora) · [24-row game texture](../assets/textures/pixel_canyon/road_to_the_arch_top.png)

The OpenRaster working copy has the original room, the cobble repair, the shrub, and the provisional extension on separate layers. Open it in Krita. The study draws the extension at room Y −24. The extension was made with built-in ImageGen, aligned and blended into the top edge. The first room's original artwork starts at row 24 of the working copy.

### ImageGen prompt

> Outpaint this original game background UPWARD by exactly 24 of its 960x540 original art pixels (4.44% of original height), with absolutely no additions on the sides or bottom. Final reference geometry 960x564, image lower 540 rows must sit in same position and proportions as in source. This is for a short vertical camera pan. Continue the cut-off warm orange stepped rocks and dark shadow at left, the middle hazy canyon cliffs and peach-lavender sky, the bright diagonal sunbeams and the edge rocks on right directly above each existing top-edge feature. Match the dense sharp hand-placed pixel clusters and palette and lighting. No characters, text, new focal point, margins or border. Keep the exact landscape alignment at the original top edge. The only useful part of the output is the narrow new paint just beyond the original top edge, so prioritize seam alignment.

## Reproduce

Run from the project directory with Godot 4.7.2 and FFmpeg.

```powershell
$studyGodot = 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force render_captures/pixel_canyon_camera, tmp/pixel_canyon_camera | Out-Null
foreach ($variant in 'A', 'B', 'C') {
    & $studyGodot --headless --path . --fixed-fps 60 --script tests/test_pixel_canyon_study.gd -- --clean "--camera=$variant"
    & $studyGodot --path . --resolution 1376x768 --fixed-fps 30 --script tests/test_pixel_canyon_study.gd -- --clean --record "--camera=$variant"
}
& $studyGodot --headless --path . --script tests/test_pixel_canyon_study.gd -- --camera=C --catalog
```

The windowed test saves the standing PNGs and writes 960×540 RGB frames to `tmp/pixel_canyon_camera`. To recreate the clips, pass each frame file to FFmpeg. For chapters, use the logged frame numbers as start times in units of 1/30 second. The captures and Windows build are local outputs.

```powershell
foreach ($variant in 'A', 'B', 'C') {
    & 'C:/ffmpeg/bin/ffmpeg.exe' -f rawvideo -pixel_format rgb24 -video_size 960x540 -framerate 30 -i "tmp/pixel_canyon_camera/$variant.rgb" -vf 'scale=1920:1080:flags=neighbor,format=yuv420p' -c:v libx264 -crf 16 -movflags +faststart "render_captures/pixel_canyon_camera/$variant.mp4"
}
```
