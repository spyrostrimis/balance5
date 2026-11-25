# Painted tropical forest walk

**24 November 2026 · Balance5 · `art/forest-scene` · Godot 4.7.2 Forward+**

## Play

Open **Developers Page → Forest builds → 2D Painted Forest Walk → Play**. Esc returns to the Developers Page when launched there. The direct launch below exits on Esc.

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe' --path 'D:\Games\Balance5' --rendering-method forward_plus --resolution 1376x768 res://assets/scenes/forest_test/forest_walk.tscn
```

**WASD or arrows** walk in either direction and across the trail. **R** resets to the opening. **G** shows the boot limits, the three boundaries and a size readout. **F2** switches between the painting and the plain trail with equal-size markers. Both guides and markers are hidden in the opening painted view. Add `-- --rough` to start on the plain trail.

## Walk and measurements

The camera travels with her at fixed zoom. It gives her 38 pixels of forward and back leeway and 45 pixels sideways before catching up. Two changes in size are tied to the boots' position on the route. Each boundary has a 96-pixel blend band. Both changes retrace when she turns around. Walking speed and the distance between poses shrink with her, and the shadow shares the boot anchor.

Heights are idle measurements at 1376 × 768. The whole-pixel values count rows where the rendered pose changes the underlying image. The decimal values come from the pose's 149-pixel visible height in the sprite sheet and the scale applied in game. Adjacent stretches share their sampled boundary.

| Stretch | Boot Y on the painting | Visible height at start → end | Settled boot Y on screen | Clean still |
| --- | --- | --- | --- | --- |
| Perspective entrance | 1720 → 1380 | 154 → 133 px (153.60 → 131.51) | 538 → 402 px | [Buttress roots](captures/01-entrance.png) |
| Parallel fern grove | 1380 → 1070 | 133 → 131 px (131.51 → 129.91) | 402 → 395 px | [Three limestone stones](captures/02-fern-grove.png) |
| Perspective rise | 1070 → 730 | 131 → 115 px (129.91 → 112.78) | 395 → 311 px | [Tall reddish trunks](captures/03-rise.png) |
| Parallel clearing | 730 → 440 | 115 → 114 px (112.78 → 112.13) | 311 → 308 px | [Sunlit boulder and turnaround](captures/04-clearing.png) |

The opening boots sit at **70%** of the frame and the idle figure starts at **20%** of the frame height. The final idle figure is about **14.6%**. Outside the blend bands the parallel sections hold their size. The last 242 pixels of northward travel are at the final size.

[21.7-second real-time walk and return](captures/forest-walk.mp4) · [Rough entrance](captures/rough-01-entrance.png) · [Rough grove](captures/rough-02-fern-grove.png) · [Rough rise](captures/rough-03-rise.png) · [Rough clearing](captures/rough-04-clearing.png)

## Paintings and fit

All three original **1086 × 1448** PNGs came from the built-in image generation tool. Each used the same 1536 × 2048 route layout and the arch painting as the finish reference. Each is one continuous painting. The scene draws A at 1536 × 2048, preserving its proportions. [Image input guide](guides/trail-art-guide.png) · [Annotated layout](guides/trail-annotated.png) · [Plan against fitted verge](guides/paint-fit.png)

| Candidate | What it offers | Exact prompt |
| --- | --- | --- |
| [A · Buttress Light](a-buttress-light.png) | **Provisional pick.** It keeps the four landmarks distinct and the earth quiet behind the blue armour. Its grove edges and narrowing rise fit the tested changes in size most closely. | [A prompt](art/a-buttress-light.prompt.txt) |
| [B · Fern and Limestone](art/b-fern-and-limestone.png) | Stronger fern silhouettes and more humid shade. The narrowing reads more continuously through the grove into the rise. | [B prompt](art/b-fern-and-limestone.prompt.txt) |
| [C · Gold Canopy](art/c-gold-canopy.png) | Brightest foliage and clearing light. Its grove narrows earlier and the pale stones read as a pair. | [C prompt](art/c-gold-canopy.prompt.txt) |

In A, the entrance tapers from 477 to 383 canvas pixels against the planned 474 to 344. The grove then widens slightly to 401, and its right edge bends around the limestone. The rise narrows from 401 to 271. The clearing stays roughly that wide and bends farther left around the boulder, with its trail centre 56 pixels left of the plan at the turnaround. The painted verge was traced by hand. The game keeps the boots inside that trace by a small margin that scales with her. [Fit overlay](guides/paint-fit.png)

## Verification and remaining visual questions

- The plain route was playable and passed a rendered round trip before painting. The painted run in Godot 4.7.2 Forward+ on Vulkan repeated the full route, stopped in every stretch, touched both sides in each and reversed inside all three blend bands on both passes. The camera stayed over the painting and kept the Commander fully framed. A 26-pixel reversal fell within its leeway. The largest measured change from depth in one physics tick was 0.22 pixels of idle height. Size stayed fixed at stops even while the camera settled.
- The four clean stills and the guide-free tour were checked for the landmarks, artwork continuity and finish framing. A single plate avoids panel joins. The tour was captured from the running viewport over 21.68 wall-clock seconds and encoded at 30 fps. It includes a short reversal before the rise and a full return from the clearing.
- The Developers Page Play card opens the forest and Esc returns to the catalog with its window settings restored. The check passed in the source project and against the resources embedded in the rebuilt Windows executable.
- The four existing walking drawings still have discrete footfalls and some sole travel within a held drawing. Distance-based cadence limits the size-related drift. Individual soles do not lock to the ground as they would with a rigged walk.
- The owner will choose the art and judge whether all four stretches read strongly enough in motion. The painting, existing Approach 3 Commander atlas and contact shadow are scene resources included in the Windows export.

## Files and references

- [Playable scene](forest_walk.tscn) contains the fitted verge and selects the painting. [Walk script](forest_walk.gd) handles input, foot placement, pose selection and the rough view. [Route](forest_route.gd) owns the guide and size curve. [Camera](forest_camera.gd) owns the follow leeway and painting bounds.
- [Verification script](tests/verify_walk.gd) accepts `-- --rough` for the plain route, `-- --stills` for windowed checks and captures, `-- --catalog` for the Play and Esc check, or `-- --tour --live-record` for a timed recording into `captures/live_frames/`. Run it with Godot's console executable and `--script res://assets/scenes/forest_test/tests/verify_walk.gd`. The [guide generator](guides/draw_layout.py) regenerates the guide and fit overlay with Pillow.
- Approach 3 supplied the camera feel and the front, rear and profile walking drawings. The atlas and shadow are read from their existing paths. [Approach 3 scene](../../../scenes/rpg_2d/canyon_approach3.tscn) · [Camera reference](../../../scripts/rpg_2d/approach3_camera.gd) · [Commander reference](../../../scripts/rpg_2d/approach3_commander.gd) · [Atlas](../../textures/rpg_2d/approach3/commander_765.png) · [Shadow](../../textures/rpg_2d/sprites/contact_shadow.png)
- Painted Perspective Walk supplied the 20% opening scale, boot anchoring and speed calibration. [Reference report](../../../experiments/scene_walk/REPORT.md) · [Reference scene](../../../experiments/scene_walk/scene_walk.tscn) · [Arch painting](../../../experiments/scene_walk/art/approach3_arch.png)
- Project direction and visual checks came from the [working rules](../../../AGENTS.md), [overview](../../../README.md), [game design](../../../docs/GAME_DESIGN.md), [visual rubric](../../../docs/HD2D_CHECKLIST_AND_RUBRIC.md) and [experiment log](../../../docs/EXPERIMENT_LOG_AND_LESSONS.md).
