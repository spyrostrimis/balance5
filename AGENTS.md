# Balance5

Balance is a Godot 4 Forward+ RTS/RPG prototype. Running the project opens `scenes/ui/opening_screen.tscn`. The design reference is `assets/textures/maps/desert_approach_rpg_albedo.png`. Judge the bend at the commander's walking height and again at the exit.

## Developers Page

- Add a standalone scene to the opening scene's **Builds** array with its title, scene path, AI credit and **Milestone UTC** (`YYYY-MM-DD HH:MM`). For a published playable build choose **Play**. The main button selects the newest dated, listed, available Play entry regardless of array order. Use **View** for static previews. A local study can be played from its card with the milestone blank until publication.
- The Windows Desktop preset produces `builds/Balance.exe`. Re-export after changing the catalog to refresh the executable.
- Uncheck **Listed** to retire an entry. Missing scenes are skipped. Tests A, B and C1 are retired. The Early 3D Canyon Walk is unlisted because its Forward+ view is severely overexposed. Check new entries by launching them from the page and returning with Esc.

## Canyon baseline

- Commit `6576387` records D4b. The left wall has continuous stepped courses, warm dark slate faces, irregular horizontal sandstone bedding, recessed coves and a tall gateway bluff. Its accepted framing is visible in the D4b start, midway and exit captures. The right side still uses painted wings.
- For comparable captures, use the existing commander, path bounds and exit signal. Keep the follow camera at 30° FOV, −13° pitch and offset (0, 3.8, 12.6). See `GEMINI.md` for the shared baseline values. Apply a requested experimental setting to the test scene first.
- Preserve sharp source art. D4b uses a canvas blur based on screen height. A camera-depth comparison belongs in an isolated lens test with each blur method enabled separately.

## Working with the level

- Inspect the working tree first. The D4b assembler loads named meshes from `assets/models/canyon_kit_test_d.glb` and packs them into `scenes/maps/desert_canyon_true_3d.tscn`. Running `scripts/assemble_cinematic_canyon.gd` rewrites that scene. For a new module, prefer a separate imported GLB instanced in a Godot wrapper that owns the material and simple blocker.
- Use metres and a foot-level pivot for new modules or actors. Preserve the rock material's vertex channels: red selects slate, green carries AO, and blue at 1 selects the ochre boulder material. The local art notes document the calibrated D4b colors.
- For a visual change, render from the actual Forward+ viewport. Inspect start (Z ≈ +6), midway (−3.5) and exit (−14) at 1376×768. Record actual positions, floor contact and exit signal. The walk harness defaults to the D4b scene. Give experiments their own scene target and output names.

## Handoffs

The detailed rubric, experiment history, art guide, pipeline and `docs/CANYON_BEND_SESSIONS.md` are tracked under `docs/`. Their capture links point into `render_captures/`, which stays local to the primary workspace along with `tmp/` and `builds/`. In a fresh clone, consult the primary copy for the evidence images.

Commit `8e05e40` completed the buttress and playable bend. Use `scenes/maps/desert_canyon_bend.tscn` as the comparison build. It has a reimportable blocker and shadow caster, a 4 m road tile, and native camera DOF (near 10 m, far 16.5 m, amount 0.014). The glint is occluded at spawn and visible by midway.

Session 3 (`3093d36`) is the 4 m hand-laid road control. The 2048px procedural road (`88f25da`) resolved the edges but reads as heavily outlined. Use the 1024px ChatGPT cobbles at 3.2 m (`1c23695`) for the full-road candidate. Editable Krita, Aseprite and Tiled sources arrived in `e4e0c7e`. The nine-stone scene is a local close-detail study with three switchable treatments.

The latest integrated canyon is `scenes/maps/desert_canyon_chatgpt_boulder_test.tscn` (`246e989`). It adds two Trellis boulders with shared sandstone to the 3.2 m road. The native-material control is `desert_canyon_ai_boulder_test.tscn` (`b2f0f26`). The local Composition test (`scenes/maps/desert_canyon_composition_test.tscn`) inherits it with a 2 m S-curve route, a stone right wall and gateway, a −21° camera, a backlit sun and exponential fog off. Its runtime script re-lays the D4b modules and keeps C/V/B toggles for the original camera, atmosphere and sun. Pending acceptance, next inherit the integrated scene for one right gateway outcrop. At the original camera, compare the far road end at spawn, its reveal by midway, and a clear grounded route to the exit. Follow with a separately measured atmosphere pass, then a single-unit tactical handoff.
