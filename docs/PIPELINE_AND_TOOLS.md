# Recommended Pipeline, Commands & Tool Gotchas

---

## 1. D4b build pipeline

| Stage | Tool | What Happens | Who Does It |
| :--- | :--- | :--- | :--- |
| **1. Concept & Palette Lock** | Img 1 (`desert_approach_rpg_albedo.png`) + Python palette sampling | Sample target shadow/mid/highlight RGB bands and inspect geometry proportions (height vs camera `Y=3.8m`, terrace step depth) | Agent + User review |
| **2. PBR Texture & Sprite Prep** | `image-generator` (sharp `f/22` material sheets) + `C:\Python312\python.exe` (PIL / OpenCV / NumPy) | Tile seamlessly (cosine wrap), flatten blotches, impress fine horizontal bedding, generate wrapped Sobel normal maps, extract crisp alpha-cut `Sprite3D` bushes (never bake DOF blur) | Agent (`tools/python/build_test_d_textures.py`) |
| **3. 3D Stepped Diorama Kit** | Blender 5.2.3 LTS | Build stepped courses, boulders and irregular curbs with vertex masks. D4b reaches 7.55 m at Course 7 and 8.15 m at the left gateway. Export `assets/models/canyon_kit_test_d.glb`. | `tools/blender/blender_build_test_d_kit.py` |
| **4. Lit Spatial Shading** | Godot 4.7 GLSL (`assets/shaders/*.gdshader`) | Triplanar / world-Y stratified mapping (`sandstone_tex`, `basalt_tex`, `boulder_tex`), normal maps, crevice AO, distance atmospheric haze | Agent (`assets/shaders/hd2d_octopath_rock.gdshader`) |
| **5. Diorama Assembly** | `C:\Godot\Godot_v4.7.2-stable_win64_console.exe` (`--headless --script`) | Place overlapping `.glb` slices along `_path_cx(z)`, crisp `Sprite3D` bushes, `DesertSun`, fog, `GodRaysOverlay`, and camera-only `TiltShiftDof` → save `res://scenes/maps/desert_canyon_true_3d.tscn` | Agent (`tools/godot/assemble_cinematic_canyon.gd`) |
| **6. Visual & Walk QA** | Godot live window (`test_true_3d_walk.gd`, `1376x768`) + `read_file` | Automated walk captures `pos1_start` (`Z=6.0`), `pos2_midway` (`Z=-3.52`), `pos3_exit` (`Z=-13.95`, `ExitSignal=true`) + post-strafe `on_floor=true`; inspect PNGs via `read_file` and update `docs/` | Agent + User sign-off |

---

### Authoring the next production modules

| Tool | Handoff | Check in Godot |
| --- | --- | --- |
| Krita | Keep layered masters for the tileable top-down cobble and side-facing sandstone. Paint base color at a chosen stone size in metres. Keep lighting, shafts and focus as scene controls. Export color and linear data maps separately. | Preview a 3×3 repeat, a metre reference and the actual walking shot. Enable terrain mipmaps and inspect grazing angles. |
| Blender | Use a ground-level origin, applied transforms and one metre per unit. Export one reusable buttress as its own GLB with stable names. Preserve the D4b cap and boulder flags when using its material. | Instance the import in a Godot wrapper. The wrapper owns collision and material overrides, the level owns placement. Re-export a silhouette notch and verify the existing instance updates. |
| Aseprite | For the later unit art pass, use a common frame canvas, foot pivot and pixels per metre. Author front, back and side poses. Keep handed equipment consistent. | Preview the commander next to two infantry at RPG and tactical zoom. Inspect foot contact, alpha edges and team colors in both sun and shade. |
| Godot 4 | Use one directional sun, then tune sky fill. For new levels, derive layout and traversable clearance from one authored route. On the test bend compare native camera DOF with the existing screen-height pass. | Toggle shadows to identify their source. Compare focus at equal screen heights and different depths. A tactical camera should keep the selected group and its destination legible. |

**Material diagnostic.** The D4b shader uses world-space projection. Editing Blender UVs alone will not change its rock pattern. For a lighting fault, start with a flat normal on the test module. Test UV-mapped tangent normals or reorient each triplanar projection into a common basis before blending. Normalize decoded vectors and supply the encoding Godot expects. Preserve the D4b color result during this check.

### Integrated road and boulder assets

For the current road, the game loads exported 1024² color, normal and packed surface maps at 3.2 m per repeat. The paired input images for `tools/python/build_chatgpt_cobble.py` and `tools/python/build_chatgpt_sandstone.py` use absolute paths into the original local uploads. The exported maps and editable cobble sources are in Git. A fresh checkout can play the scene; regenerating it from the original uploads requires locating those inputs. The Tiled sandbox is a separate authoring preview.

For roadside rocks, `tools/blender/blender_import_ai_boulders.py` welds and simplifies the meshes and sets ground-level pivots. Godot wrappers apply a shared 1.65 m triplanar sandstone material and individual box blockers. Compare the two boulder scenes from the Developers Page under identical lighting before changing the material. Anti's capture scripts explicitly set 16× anisotropy. Use the normal menu route as the final walking check.

## 2. Rebuilding the D4b launch scene

These commands describe the original primary Windows checkout. The assembler extracts meshes from a GLB and writes them into the D4b scene. New bend tests use their own scene, directly referenced module and capture names. The walk harness below loads D4b explicitly and writes fixed names under `render_captures/`.

```powershell
# 1. Regenerate seamless textures, normal maps & bush sprites
& "C:\Python312\python.exe" "d:\Games\Balance5\scripts\build_test_d_textures.py"

# 2. Build & export modular 3D GLB kit in Blender 5.2.3 LTS
& "C:\Blender\blender.exe" -b -P "d:\Games\Balance5\scripts\blender_build_test_d_kit.py"

# 3. Re-import updated GLB/PNG resources into Godot (HEADLESS OK here)
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "d:\Games\Balance5" --headless --editor --quit

# 4. Assemble and pack res://scenes/maps/desert_canyon_true_3d.tscn
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "d:\Games\Balance5" --headless --script "res://tools/godot/assemble_cinematic_canyon.gd"

# 5. Run automated walk & screenshot capture (NEVER pass --headless here!)
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "d:\Games\Balance5" --script "res://tests/test_true_3d_walk.gd" -- --resolution 1376x768
```

---

## 3. Hard-Won API & Engine Gotchas

1. **Always run Godot `--headless --editor --quit` after modifying `.glb` or `.png` assets** before running `--script assemble_cinematic_canyon.gd` or `test_true_3d_walk.gd`; otherwise Godot loads stale `.godot/imported/` caches.
2. **NEVER pass `--headless` when capturing viewport screenshots** (`get_root().get_texture().get_image()` needs the real Forward+ Vulkan renderer window).
3. **Blender 5.2 `bmesh.ops.bisect_plane`:** Does NOT accept `fill=True`. Capture `ret = bmesh.ops.bisect_plane(...)` and cap cut edges via `bmesh.ops.contextual_create(bm, geom=cut_edges)`.
4. **GLTF Vertex Color Encoding (`COLOR_0`):** Blender exports `bmesh.loops.layers.color` as sRGB `BYTE_COLOR`, which Godot converts to linear (`0.5` → `0.214`). Use exact **`0.0` or `1.0`** for discrete flags (`COLOR.b = 1.0` for boulders, `COLOR.r = 1.0` for step tops) so values are gamma-invariant.
5. **Coordinate Mapping (Blender → Godot glTF `export_yup=True`):**
   - Blender `X` → Godot `X`
   - Blender `Y` (length along trail, `-3.25..+3.25`) → Godot `-Z` / `+Z` axis
   - Blender `Z` (upward height) → Godot `Y`
