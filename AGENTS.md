# Balance5

Balance is a **real-time strategy game in tribute to Dune II (1992)**, built in Godot 4.7.2 Forward+. Its gameplay, graphics and HUD follow Dune II; its tone is warm fantasy (closer to *The Lord of the Rings* and *Star Wars*). **The RTS is the priority.** The RPG canyon, HD-2D walking sequences and 3D work are secondary: if they fail, the RTS alone is the game. Read [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) for the story, factions, Mission 1, pillars and art direction before designing anything, and [`README.md`](README.md) for the one-page overview.

Running the project opens `scenes/ui/opening_screen.tscn`. Art references live in `docs/references/`. The RPG canyon reference is `assets/textures/maps/desert_approach_rpg_albedo.png`; judge the canyon at the commander's walking height and again at the exit.

This file is the single source of truth for how the project is built, for every coding agent (Codex, Claude Code, Antigravity/Gemini); `docs/GAME_DESIGN.md` is the source of truth for what the game is. `GEMINI.md` and `CLAUDE.md` only point here.

## Repository layout

| Path | Contents |
| --- | --- |
| `scenes/maps/` | Playable levels and studies. `canyon_v2.tscn` is the flat, route-driven canyon. The `desert_canyon_*` scenes are the earlier inherited test chain, kept for comparisons. |
| `scenes/canyon/` | Canyon module wrappers (`modules/`) and layout data (`canyon_v2_layout.tres`). |
| `scenes/actors/` | Reusable actors: `blue_commander_3d.tscn`, `canyon_camera.tscn`. |
| `scenes/ui/` | Opening screen, Developers Page and build launcher. |
| `scripts/` | Runtime GDScript only. Canyon systems live in `scripts/canyon/`. |
| `tests/` | Headless and windowed test harnesses, such as the walk captures. |
| `tools/godot/` | Editor and bootstrap scripts (assemblers, generators, `build_canyon_v2.gd`). Each one that overwrites committed scenes refuses to run without `-- --force` (`tool_guard.gd`). |
| `tools/blender/`, `tools/python/` | Blender authoring and image-processing scripts. `tools/legacy/` holds superseded one-offs. |
| `assets/` | Models, textures, shaders, `materials/` and `environments/` (`.tres`). `assets/source_inputs/` holds the original AI-generated images and GLBs the tools consume (ignored by Godot). |
| `docs/` | `GAME_DESIGN.md` (the design source of truth), `references/` (the owner's art direction images), and the canyon rubric, experiment log, pipeline, style bible and bend sessions. Evidence images for the logs live in the untracked `render_captures/`. Godot ignores `docs/`. |

`render_captures/`, `tmp/` and `builds/` are ignored and stay local to the primary workspace. Tools resolve paths from the repository root, so nothing depends on `D:/Games/Balance5`.

## Canyon v2 (current foundation)

`scenes/maps/canyon_v2.tscn` is a flat scene with no inheritance:

- **Route** (`Path3D`, `scripts/canyon/canyon_route_path.gd`). Edit the curve in the editor. It provides `center_x(z)`, `heading(z)` and `half_width`, and writes a 64-sample lookup into the road shader (`route_mode = 1`). The route must run monotonically along −Z.
- **Layout** (`scripts/canyon/canyon_layout.gd`). Instances each placement in `scenes/canyon/canyon_v2_layout.tres` relative to the route: `z`, `lateral` offset, `yaw_offset_deg`, `scale`, plus `tint` and `flip_h` for sprites. Generated children are not saved. They rebuild when the route or data changes.
- **Modules** are small wrappers in `scenes/canyon/modules/` that own a mesh and `assets/materials/canyon_rock.tres`. The kit meshes are saved by the `canyon_kit_test_d.glb` import (`assets/models/canyon_kit/*.res`), so a Blender re-export updates them on reimport. Older wrappers (`right_buttress.tscn`, the ChatGPT boulders) live in `scenes/maps/`.
- **Corridor** (`scripts/canyon/canyon_corridor.gd`). Builds a continuous collision ribbon along both route edges plus end caps, and a navigation mesh baked from the floor, walls and module blockers (blocker tops removed). Physics contains the commander, so v2 turns off the legacy position clamp. Later units can path with `NavigationServer3D` or `NavigationAgent3D`.
- **Level script** (`scripts/canyon/canyon_level.gd`) hands the route to the ground material, commander and camera.

To move rocks, edit placements. To bend the canyon, edit the curve. To add a module, make a wrapper scene and reference it from a placement. `tools/godot/build_canyon_v2.gd` was a one-time bootstrap from the composition test, and rerunning it overwrites the v2 files.

Canyon v2 reproduces the composition test: a 2 m S-curve, a stone right wall from turned left courses, a −21° camera at offset (0, 5.5, 11.9), a backlit sun at 42° elevation, exponential fog off and rock haze 0.10.

## Working rules

1. Before changing geometry, textures, shaders or layout, read `docs/HD2D_CHECKLIST_AND_RUBRIC.md` and `docs/EXPERIMENT_LOG_AND_LESSONS.md`. A `[x]` guards a visual goal against *accidental* regression. It is not a lock.
2. Nothing is hard-locked. Camera pitch, offset and follow, sun direction, route curve, fog, focus method and landmark timing are tunable composition parameters (table in the rubric). Change one deliberately when it serves Img 1 better: name the change, capture matched before/after views, and update the rubric and log.
3. Test one hypothesis at a time. A deliberate group (such as the composition test) counts as one when each part keeps a toggle for A/B. Give experiments their own scene and capture prefix.
4. Render from the real Forward+ viewport at 1376×768. Use `tests/test_true_3d_walk.gd` (D4b default) or `tests/test_composition_walk.gd` (adds whole-scene landmark occlusion) with `--scene`, `--capture-dir` and `--prefix`. For canyon v2 also run `tests/test_canyon_corridor.gd` headless (walls, end caps, exit signal, obstacle-aware navigation). Inspect start (Z +6), midway (−3.5) and exit (−14). Record positions, floor contact and the exit signal, and look at every PNG before reporting.
5. Log verified results in `docs/EXPERIMENT_LOG_AND_LESSONS.md` and the rubric right after the run.
6. Use metres and foot-level pivots. Preserve the rock vertex channels: red selects slate, green carries AO, blue at 1 selects ochre boulders. Store binary flags only as 0 or 1 because of sRGB.
7. Keep source art sharp. Use one blur method per capture.

## Comparison baselines

These builds are reference points for A/B captures, not constraints on new work.

| Build | Scene | Fixed values |
| --- | --- | --- |
| D4b (`6576387`) | `desert_canyon_true_3d.tscn` | 30° FOV, −13° pitch, offset (0, 3.8, 12.6), route `0.65 · sin(0.22 z)`, clamp ±1.15 m, Z ∈ [−14.5, 7.5], exit at Z ≤ −13.5, screen-height blur. Rerunning `tools/godot/assemble_cinematic_canyon.gd` rewrites this scene and can shift the index-based overrides in its children. Treat it as frozen; the assembler now needs `-- --force`. |
| Bend (`8e05e40`) | `desert_canyon_bend.tscn` | Right buttress, 4 m road, native DOF (near 10 m, far 16.5 m, amount 0.014). Glint occluded at spawn and visible by midway. |
| Integrated (`246e989`) | `desert_canyon_chatgpt_boulder_test.tscn` | ChatGPT 3.2 m cobbles and Trellis boulders on the bend. Atmosphere layers disabled by the inherited diagnostic control. |
| Composition test | `desert_canyon_composition_test.tscn` | Runtime re-lay of the integrated scene. C, V and B toggle the original camera, atmosphere and sun. |

The commander script defaults to D4b. With a `route` object assigned it clamps to that route, `clamp_to_route = false` hands containment to collision walls, and its Z limits and exit threshold are exported. Both road shaders share the route uniforms (`route_mode` 0 = sine, 1 = lookup). The D4b assembler stores module yaw as −heading, the opposite sign to the route. The v2 layout uses the correct sign.

## Developers Page

- Add a standalone scene to the opening scene's **Builds** array with its title, scene path, AI credit and **Milestone UTC** (`YYYY-MM-DD HH:MM`). For a published playable build choose **Play**. The main button selects the newest dated, listed, available Play entry regardless of array order. Use **View** for static previews. A local study can be played from its card with the milestone blank until publication.
- The Windows Desktop preset produces `builds/Balance.exe`. Re-export after changing the catalog.
- Uncheck **Listed** to retire an entry. Missing scenes are skipped. Check new entries by launching them from the page and returning with Esc.

## Next steps

**RTS (priority)** — Mission 1, *The First Claim* (`docs/GAME_DESIGN.md` §5), as a playable vertical slice:

1. Select units (click and drag-box), move and attack with four troops plus the field commander per side, on a navigable grid or navmesh.
2. A commander active ability (Blue: Mend / healing first), the control-point hold timer around the central Orichalcum rock, and win/lose on hold or elimination.
3. A simple Red AI opponent, and the HUD from `docs/references/rts_mission1_hud_goal.webp` (top bar, minimap, unit card, Move/Attack/Hold/Mend, objective panel).
4. Both settings from one layout: Red's desert and Blue's tropical forest (`docs/references/rts_mission1_*.webp`). Build maps from tiles (the kitbash/Tiled work), not a single painted image, so maps, fog and pathfinding scale.

**RPG canyon (secondary)**

1. Review and accept canyon v2 as the RPG baseline. The crater glint now appears only at the exit instead of by midway.
2. Author dedicated right-wall modules instead of turned left courses. Fix the slate cap material, bush scale and exit vista.
3. Atmosphere pass: a localized `FogVolume` at a wall opening, measured against v2 with GPU frame time.
4. RPG fights follow *Streets of Rage 4*: free movement in depth, facing and shooting left/right only. Story beats use Dune II-style storyboard briefings.
