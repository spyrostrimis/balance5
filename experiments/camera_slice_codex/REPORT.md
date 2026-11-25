# Vertical slice with real art

Open [camera_slice_codex.tscn](camera_slice_codex.tscn) and use **Run Current Scene** (F6). To reproduce the capture size, run this from the Balance project root.

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1376x768 res://experiments/camera_slice_codex/camera_slice_codex.tscn
```

**WASD** walks at 3 m/s, **1** and **2** switch profiles, **P** saves the active profile to `shots/A.png` or `shots/B.png`, and **Esc** quits. The scene starts on A.

| Profile | Downward pitch | Vertical field of view | Distance to target | Original spawn capture |
| --- | ---: | ---: | ---: | --- |
| A | 25° | 30° | 16.700927 m | [A.png](shots/A.png) |
| B | 30° | 45° | 10.803606 m | [B.png](shots/B.png) |

## Art and files

| Files | Contents |
| --- | --- |
| `camera_slice_codex.tscn`, `camera_slice_codex.gd` | Playable scene, cliff cards and their ground shadows, art loading, movement, camera, and screenshot controls |
| `camera_profiles.json`, `props.json` | Camera settings, prop categories and heights, and per-file cliff card heights |
| `assets/sand_topdown.png`, `road_topdown.png`, `cliff_front.png`, `cliff_top.png` | Supplied surface paintings. The sand and road are active, and the original cliff face and top are kept with the source art. |
| `assets/cliff_.png`, `cliff_01.png` through `cliff_06.png` | Supplied magenta-backed cliff sheet and six transparent cutouts from `experiments/camera_slice/tools/cut_sheet.py` |
| `assets/prop_.png` | Supplied magenta-backed source sheet |
| `assets/prop_01.png` through `prop_12.png` | 12 cutouts made from the sheet, with 8 pixels of transparent padding |
| `assets/hero_clean.png` | Cleaned copy of `assets/textures/units/blue_commander_rpg.png` from the project. The green tint was reduced on 5,674 visible edge pixels and the original transparency was preserved. |
| `tools/cut_sheet_codex.py` | Prop sheet cutter using Pillow, NumPy, and SciPy |
| `shots/A.png`, `shots/B.png` | Preserved spawn screenshots from the cliff block version. **P** captures the current scene. |
| `assets/.gdignore`, `shots/.gdignore` | Keep runtime PNGs and screenshots out of the editor's texture importer. The scene reads art directly and makes the smaller texture copies used for distant rendering. |
| `REPORT.md` | Run instructions, art inventory, assumptions, and verification |

All requested art was available. The delivered scene uses zero flat placeholders.

Run these commands from the Balance project root to cut the sheet again.

```powershell
python -m pip install Pillow numpy scipy
python experiments/camera_slice_codex/tools/cut_sheet_codex.py experiments/camera_slice_codex/assets/prop_.png
```

The cliff cuts used a grouping radius of 4 pixels and the cutter's default 8-pixel padding. Run this from the Balance project root to repeat the cut. The cutter names outputs `prop_01.png` through `prop_06.png`. Copy them into the slice's `assets` folder as `cliff_01.png` through `cliff_06.png`.

```powershell
python experiments/camera_slice/tools/cut_sheet.py experiments/camera_slice_codex/assets/cliff_.png --out-dir experiments/camera_slice_codex/tmp/cliff_cuts --group-radius 4
```

## Assumptions

- The hero spawns at `(0, 0, 0)` and moves with the existing idle pose. Movement stays at Y 0 and allows walking through scenery and past the last cliff cards.
- Both ground strips run from Z +20 to −280 m. Both cliff rows start at +20 m and end at the last full step, −88 m. The rows use separate lateral draws for each side, and alternate mirroring starts with the second card of each row and side.
- The six cliff cuts are 8, 6, 9, 5, 5, and 5 m high in file order, with their painted proportions and visible feet at ground level. Positions refer to the horizontal center of each card. Each shadow is centered 5 mm above the sand to keep its surface distinct from the ground plane.
- The 40 prop placements retain their original seeded verge limits. They sample 11 of the 12 prop cutouts. Extra `prop_*.png` files default to the rock height unless assigned a type in `props.json`.
- The cutter numbers groups by the first visible row and then the left edge. It groups nearby loose petals, grass tips, and pebbles with the main cutout when their gaps are at most about 10 pixels. Tiny groups below 24 visible pixels are treated as specks.

## Verification

- Godot 4.7.2 passed the headless checks for 64 cliff cards and 64 shadows, including seeded choices, positions, mirroring, height, foot alignment, and the shadow dimensions and 40% peak opacity. The 40 prop positions and sprite scales matched the cliff block build. All six cliff cutouts passed the transparent padding check.
- Matched 1376 × 768 Forward+ views were reviewed at spawn and Z +6, −3.5, −14, and −89 m with the hero's feet at Y 0. The wide cards extend into the road and hide most of the hero at spawn in both profiles.
- Profile switching, **P** saves, and **Esc** passed in a separate test copy. The preserved A and B screenshot files matched their pre-change hashes.
