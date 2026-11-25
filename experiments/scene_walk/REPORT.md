# Painted Perspective Walk Test

The camera holds on the Approach 3 arch while the Blue Commander gets smaller and moves more slowly as her feet travel up the road. With the default calibration, her visible height is 25.31% of the picture at the near edge, 20.00% at the start, and 15.18% at the far edge.

## Run

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe' --path 'D:\Games\Balance5' res://experiments/scene_walk/scene_walk.tscn
```

The resizable window opens at 1280 × 720. The scene scales its 1920 × 1080 canvas to fit the window and preserves the aspect ratio.

| Input | Action |
| --- | --- |
| WASD or arrows | Move. The boots slide along the walkable boundary. |
| 7 and 8 | Decrease and increase bottom scale by 0.02. |
| 9 and 0 | Decrease and increase top scale by 0.02. |
| S | Save calibration to `calib.json`. Holding S also walks down. |
| E | Edit a copy of the active polygon. E again discards the draft. |
| Left click and right click | Append a point and remove the last point in edit mode. |
| Enter | Save a valid polygon to `walk_area.json` and resume walking. |
| G | Toggle the table and outline. Entering edit mode shows both. |
| P | Save the current viewport as a PNG in `shots/`. |
| Esc | Quit. |

## Art and calibration

- The background is the full-width upper 838 × 471 pixels of the clean original Approach 3 painting. This framing includes the arch and the road in one still. The painting already contains its sunlight. The original was present as an untracked source file in the working copy. The clean crop is bundled with the scene. [Source painting](../../assets/source_inputs/rpg_2d/approach3/canyon_plate.png)
- The hero uses the full-resolution front-facing RPG pose that Approach 3 uses for its idle. The copy removes green from the outer silhouette and fills the transparent border with nearby sprite colors, so smooth texture sampling keeps the edge clean. It is cropped to the visible alpha bounds and stays front-facing while walking. [Original sprite](../../assets/textures/units/blue_commander_rpg.png)
- The trapezoid was fitted by eye inside the painted curbs at (817, 480), (1057, 480), (1172, 1060) and (856, 1060). The start is (990, 756). These are positions on the 1920 × 1080 canvas.
- Movement is 290 canvas pixels per second at the start, multiplied elsewhere by the same ratio as sprite height. The soft black contact shadow peaks at 40% opacity. Its width at the start is 108 pixels, using 1.8 m as the hero height reference for the 0.9 m look.
- The bottom and top calibration values start at 1.00 and 0.60. The raw value changes linearly with foot Y. Dividing by the raw start value keeps the hero 216 pixels tall at the start while tuning either endpoint. With an edited polygon that excludes the original start, the nearest point on its boundary becomes the start.

| Position | Boot Y | Visible height in base pixels | Picture height | Forward+ capture |
| --- | ---: | ---: | ---: | --- |
| Bottom | 1060 | 273.30 | 25.31% | [Bottom](shots/verification-bottom.png) |
| Start | 756 | 216.00 | 20.00% | [Start](shots/verification-start.png) |
| Top | 480 | 163.98 | 15.18% | [Top](shots/verification-top.png) |

## Verification and files

Godot 4.7.2 passed headless and Forward+ checks for the three heights, movement and boundary sliding, a concave edited polygon, input after resizing to 1000 × 720, defaults when no save exists, saving and reloading both JSON files, toggling the guides, saving 1280 × 720 screenshots with P, and exiting with Esc. The background pixels match across all three captures outside the hero, shadow, and table.

| New file | Contents |
| --- | --- |
| `scene_walk.tscn` | Scene and calibration overlay |
| `scene_walk.gd` | Window setup, movement, calibration, editing and captures |
| `art/approach3_arch.png` | Clean arch crop |
| `art/hero_clean.png` | Cleaned front-facing sprite |
| `art/.gdignore`, `shots/.gdignore` | Keep the raw art and captures out of Godot's automatic import |
| `shots/verification-bottom.png`, `shots/verification-start.png`, `shots/verification-top.png` | Live captures at the three measured positions |
| `.gitignore` | Excludes local calibration, polygon saves and user screenshots |
| `REPORT.md` | Run command, controls, art sources and measurements |
