# Continue Balance on another PC

The GitHub repository contains the editable project, both Mission 1 kits, unit and HUD art, source paintings, asset-building scripts, tests and project memory for these builds:

| Build | Scene |
| --- | --- |
| RTS Mission 1 – Forest | `scenes/maps/rts_mission_1_forest.tscn` |
| RTS Mission 1 – Desert | `scenes/maps/rts_mission_1_desert.tscn` |
| 2D Painted Forest Fight 4 | `scenes/forest_fight_4/forest_fight_4.tscn` |

## From GitHub

1. Install Git if needed and use Godot **4.7.2**, matching this project. Forward+ needs a compatible graphics driver/GPU.
2. Clone `https://github.com/spyrostrimis/balance5.git` into a writable folder. A GitHub source ZIP also works for editing, but cloning preserves history and makes pushing your work back straightforward.
3. Import that folder's `project.godot` in Godot. Allow the first import to finish: Godot regenerates its `.godot` cache from the included source assets.
4. Press Play and select the named build on the Developers Page. Forest and Desert are in their respective RTS sections; Fight 4 is under Forest builds. Esc returns to the page. The forest and desert kit View cards and Kit Palette editor dock are also included.

No Python, Blender or art tools are needed to play or edit the existing scenes and kit placements. Rebuilding artwork with the Python scripts additionally needs Python plus Pillow, NumPy and OpenCV (`python -m pip install pillow numpy opencv-python`). Blender is needed only for Blender authoring; FFmpeg is needed for encoding test recordings. Install Godot's matching export templates only if you want to export an executable.

Read [Forest editing](RTS_MISSION_1_FOREST.md), [Desert editing](RTS_MISSION_1_DESERT.md), [Fight 4](FOREST_FIGHT_4.md) and [AGENTS.md](../AGENTS.md) before continuing. The source paintings and prompts are included under `assets/source_inputs/`, including the forest kit and Fight 4; shared art from earlier studies is retained too.

## From the travel ZIP

Extract the entire `Balance5` folder into a writable folder and import its `project.godot`. This is the complete tracked source project, rather than a stripped selection of scenes, so shared kits, older shared resources and authoring inputs remain available. It also contains the local evidence folders `render_captures/rts_mission_1_forest`, `render_captures/rts_mission_1` and `render_captures/forest_fight_4`.

The ZIP includes `TRAVEL_MANIFEST.json`, listing file sizes and SHA-256 hashes (file fingerprints) and the source commit. Its adjacent `.zip.sha256` file fingerprints the ZIP itself. It excludes `.git` history, `.godot` caches, executables, temporary recordings, unrelated local captures, Blender backups and the unrelated unlicensed canyon test pack. None is required for these three builds. It does not transfer installed programs, account sign-ins or computer-local Developers Page ordering and preferences. GitHub also excludes the local evidence captures.

To keep using Git when travelling, clone first, then optionally copy the ZIP's `render_captures` into the clone. Work inside the clone. If using only the ZIP offline, keep your edited folder and copy your changes into a fresh clone before committing and pushing later.

Recreate the ZIP from the primary checkout with `python tools/python/make_travel_backup.py`. It writes a dated ZIP and checksum under ignored `builds/`. Commit desired new files first so they are tracked and included.

## Check the three builds

Run these commands from the extracted project or clone, replacing the Godot executable path as needed:

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --import
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_rts_mission_1_forest.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_rts_mission_1_desert.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path . --script res://tests/test_forest_fight_4.gd
```

Headless checks verify resources and gameplay without a visible game window. Judge the artwork in the Forward+ game window on the new PC: RTS at 1920 × 1080 fullscreen, Fight 4 at its documented 1376 × 768.

Verified on 2026-11-27 from a separate copy of tracked files with no existing `.godot` cache: the first import completed, and all three suites above passed with Godot 4.7.2. The full-project import reported seven unresolved saved resource IDs in the unrelated `assets/models/canyon_kit_test_d.glb.import`; the three requested scenes' tests had no such errors. This check does not measure the new computer's graphics performance.
