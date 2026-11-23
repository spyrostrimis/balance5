# Vertical slice with real art

Open [camera_slice_codex.tscn](camera_slice_codex.tscn) and use **Run Current Scene** (F6). To reproduce the capture size, run this from the Balance project root.

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1376x768 res://experiments/camera_slice_codex/camera_slice_codex.tscn
```

**WASD** walks at 3 m/s, **1** and **2** switch profiles, **P** saves the active profile to `shots/A.png` or `shots/B.png`, and **Esc** quits. The scene starts on A.

| Profile | Downward pitch | Vertical field of view | Distance to target | Spawn capture |
| --- | ---: | ---: | ---: | --- |
| A | 25° | 30° | 16.700927 m | [A.png](shots/A.png) |
| B | 30° | 45° | 10.803606 m | [B.png](shots/B.png) |

## Art and files

| Files | Contents |
| --- | --- |
| `camera_slice_codex.tscn`, `camera_slice_codex.gd` | Playable scene, cliff blocks, art loading, movement, camera, and screenshot controls |
| `camera_profiles.json`, `props.json` | Camera settings, prop categories, and heights |
| `assets/sand_topdown.png`, `road_topdown.png`, `cliff_front.png`, `cliff_top.png` | Four supplied painted surfaces, included as supplied |
| `assets/prop_.png` | Supplied magenta-backed source sheet |
| `assets/prop_01.png` through `prop_12.png` | 12 cutouts made from the sheet, with 8 pixels of transparent padding |
| `assets/hero_clean.png` | Cleaned copy of `assets/textures/units/blue_commander_rpg.png` from the project. The green tint was reduced on 5,674 visible edge pixels and the original transparency was preserved. |
| `tools/cut_sheet_codex.py` | Prop sheet cutter using Pillow, NumPy, and SciPy |
| `shots/A.png`, `shots/B.png` | Screenshots saved with **P** at the same spawn position |
| `assets/.gdignore`, `shots/.gdignore` | Keep runtime PNGs and screenshots out of the editor's texture importer. The scene reads art directly and makes the smaller texture copies used for distant rendering. |
| `REPORT.md` | Run instructions, art inventory, assumptions, and verification |

All requested art was available. The delivered scene uses zero flat placeholders.

Run these commands from the Balance project root to cut the sheet again.

```powershell
python -m pip install Pillow numpy scipy
python experiments/camera_slice_codex/tools/cut_sheet_codex.py experiments/camera_slice_codex/assets/prop_.png
```

## Assumptions

- The hero spawns at `(0, 0, 0)` and moves with the existing idle pose. Movement stays at Y 0 and allows walking through scenery and past the last cliff blocks.
- Both ground strips run from Z +20 to −280 m. Each listed cliff Z is its front face, so the last blocks extend from −90 to −95 m.
- The 5 m inner faces use 5/8 of the 8 m front painting. The 5 m tops repeat the first metre of the 4 m top painting. The three faces produce visible joints where adjoining blocks have different offsets.
- Each side gets its own cliff jitter. Props use a separate random generator with the same seed. Their visible widths fit between the road and the nearest cliff face at their placement Z. The 40 placements sample 11 of the 12 cutouts. Extra `prop_*.png` files default to the rock height unless assigned a type in `props.json`.
- The cutter numbers groups by the first visible row and then the left edge. It groups nearby loose petals, grass tips, and pebbles with the main cutout when their gaps are at most about 10 pixels. Tiny groups below 24 visible pixels are treated as specks.

## Verification

- Godot 4.7.2 passed the headless checks for the 46 three-face cliff blocks, 40 props, 4 m ground tiles, filter settings, hero and prop foot heights, camera centering, and 3 m/s movement including diagonals.
- In the real 1376 × 768 Forward+ viewport, profile switching, screenshot saves, and Esc worked. Both profiles were reviewed at spawn and at Z +6, −3.5, −14, and −89 m, with the hero's feet at Y 0. At spawn, A shows more cliff top and B gives more of the frame to the nearby walls.
- A separate launch with all art omitted used a flat placeholder for each of the 17 missing files, covering the four surfaces, 12 prop files, and hero. The cutter also passed a pure-magenta test for separation, soft edges, color spill removal, and exact padding, including cutouts touching the sheet boundary.
