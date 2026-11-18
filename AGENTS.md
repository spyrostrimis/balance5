# Balance5

Balance is a Godot 4.7 Forward+ RTS/RPG prototype. Running the project opens `scenes/ui/opening_screen.tscn`. The RPG design reference is `assets/textures/maps/desert_approach_rpg_albedo.png`. Judge the canyon at the commander's walking height and again at the exit.

This file is the single source of truth for every coding agent (Codex, Claude Code, Gemini). `GEMINI.md` and `CLAUDE.md` only point here.

## Repository layout

| Path | Contents |
| --- | --- |
| `scenes/maps/` | Playable levels and studies. `canyon_v2.tscn` is the flat, route-driven canyon. The `desert_canyon_*` scenes are the earlier inherited test chain, kept for comparisons. |
| `scenes/canyon/` | Canyon module wrappers (`modules/`) and layout data (`canyon_v2_layout.tres`). |
| `scenes/actors/` | Reusable actors: `blue_commander_3d.tscn`, `canyon_camera.tscn`. |
| `scenes/ui/` | Opening screen, Developers Page and build launcher. |
| `scripts/` | Runtime GDScript only. Canyon systems live in `scripts/canyon/`. |
| `tests/` | Headless and windowed test harnesses, such as the walk captures. |
| `tools/godot/` | Editor and bootstrap scripts (assemblers, generators, `build_canyon_v2.gd`). |
| `tools/blender/`, `tools/python/` | Blender authoring and image-processing scripts. `tools/legacy/` holds superseded one-offs. |
| `assets/` | Models, textures, shaders, `materials/` and `environments/` (`.tres`). |
| `docs/` | Rubric, experiment log, pipeline, style bible and bend sessions. Their evidence images live in the untracked `render_captures/`. |

`render_captures/`, `tmp/` and `builds/` are ignored and stay local to the primary workspace.

## Canyon v2 (current foundation)

`scenes/maps/canyon_v2.tscn` is a flat scene with no inheritance:

- **Route** (`Path3D`, `scripts/canyon/canyon_route_path.gd`). Edit the curve in the editor. It provides `center_x(z)`, `heading(z)` and `half_width`, and writes a 64-sample lookup into the road shader (`route_mode = 1`). The route must run monotonically along −Z.
- **Layout** (`scripts/canyon/canyon_layout.gd`). Instances each placement in `scenes/canyon/canyon_v2_layout.tres` relative to the route: `z`, `lateral` offset, `yaw_offset_deg`, `scale`, plus `tint` and `flip_h` for sprites. Generated children are not saved. They rebuild when the route or data changes.
- **Modules** are small wrappers in `scenes/canyon/modules/` that own a mesh and `assets/materials/canyon_rock.tres`. The kit meshes are saved by the `canyon_kit_test_d.glb` import (`assets/models/canyon_kit/*.res`), so a Blender re-export updates them on reimport. Older wrappers (`right_buttress.tscn`, the ChatGPT boulders) live in `scenes/maps/`.
- **Level script** (`scripts/canyon/canyon_level.gd`) hands the route to the ground material, commander and camera.

To move rocks, edit placements. To bend the canyon, edit the curve. To add a module, make a wrapper scene and reference it from a placement. `tools/godot/build_canyon_v2.gd` was a one-time bootstrap from the composition test, and rerunning it overwrites the v2 files.

Canyon v2 reproduces the composition test: a 2 m S-curve, a stone right wall from turned left courses, a −21° camera at offset (0, 5.5, 11.9), a backlit sun at 42° elevation, exponential fog off and rock haze 0.10.

## Working rules

1. Before changing geometry, textures, shaders or layout, read `docs/HD2D_CHECKLIST_AND_RUBRIC.md` and `docs/EXPERIMENT_LOG_AND_LESSONS.md`. Never un-tick a verified `[x]` while polishing something else.
2. Change one hypothesis per test. Give experiments their own scene and capture prefix.
3. Render from the real Forward+ viewport at 1376×768. Use `tests/test_true_3d_walk.gd` (D4b default) or `tests/test_composition_walk.gd` (adds whole-scene landmark occlusion) with `--scene`, `--capture-dir` and `--prefix`. Inspect start (Z +6), midway (−3.5) and exit (−14). Record positions, floor contact and the exit signal, and look at every PNG before reporting.
4. Log verified results in `docs/EXPERIMENT_LOG_AND_LESSONS.md` and the rubric right after the run.
5. Use metres and foot-level pivots. Preserve the rock vertex channels: red selects slate, green carries AO, blue at 1 selects ochre boulders. Store binary flags only as 0 or 1 because of sRGB.
6. Keep source art sharp. Use one blur method per capture.

## Comparison baselines

| Build | Scene | Fixed values |
| --- | --- | --- |
| D4b (`6576387`) | `desert_canyon_true_3d.tscn` | 30° FOV, −13° pitch, offset (0, 3.8, 12.6), route `0.65 · sin(0.22 z)`, clamp ±1.15 m, Z ∈ [−14.5, 7.5], exit at Z ≤ −13.5, screen-height blur. Rerunning `tools/godot/assemble_cinematic_canyon.gd` rewrites this scene and can shift the index-based overrides in its children. Treat it as frozen. |
| Bend (`8e05e40`) | `desert_canyon_bend.tscn` | Right buttress, 4 m road, native DOF (near 10 m, far 16.5 m, amount 0.014). Glint occluded at spawn and visible by midway. |
| Integrated (`246e989`) | `desert_canyon_chatgpt_boulder_test.tscn` | ChatGPT 3.2 m cobbles and Trellis boulders on the bend. Atmosphere layers disabled by the inherited diagnostic control. |
| Composition test | `desert_canyon_composition_test.tscn` | Runtime re-lay of the integrated scene. C, V and B toggle the original camera, atmosphere and sun. |

The commander script defaults to D4b. With a `route` object assigned it clamps to that route, and its Z limits and exit threshold are exported. The D4b assembler stores module yaw as −heading, the opposite sign to the route. The v2 layout uses the correct sign.

## Developers Page

- Add a standalone scene to the opening scene's **Builds** array with its title, scene path, AI credit and **Milestone UTC** (`YYYY-MM-DD HH:MM`). For a published playable build choose **Play**. The main button selects the newest dated, listed, available Play entry regardless of array order. Use **View** for static previews. A local study can be played from its card with the milestone blank until publication.
- The Windows Desktop preset produces `builds/Balance.exe`. Re-export after changing the catalog.
- Uncheck **Listed** to retire an entry. Missing scenes are skipped. Check new entries by launching them from the page and returning with Esc.

## Next steps

1. Review and accept canyon v2 as the RPG baseline. The crater glint now appears only at the exit instead of by midway.
2. Author dedicated right-wall modules instead of turned left courses. Fix the slate cap material, bush scale and exit vista.
3. Atmosphere pass: a localized `FogVolume` at a wall opening, measured against v2 with GPU frame time.
4. A single-unit tactical handoff at the crater.
