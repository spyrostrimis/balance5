# Balance5

Balance is a Godot 4 Forward+ RTS/RPG prototype. Running the project opens `scenes/ui/opening_screen.tscn`. The design reference is `assets/textures/maps/desert_approach_rpg_albedo.png`. Judge the bend at the commander's walking height and again at the exit.

## Developers Page

- Edit the opening scene's **Builds** array in the Inspector to list a standalone build. Record its scene path, AI credit and a dated milestone with the time zone. Put the featured build first. Use **View** for static prototypes.
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

The detailed rubric, experiment history, art guide, pipeline and `docs/CANYON_BEND_SESSIONS.md` are local to the primary workspace. Git intentionally ignores `docs/`. In a fresh clone or linked worktree, consult the primary copy if available. The scene, scripts and this baseline also travel with the repository once committed.

Commit `8e05e40` completed the buttress and playable bend. Use `scenes/maps/desert_canyon_bend.tscn` as the comparison build. It has a reimportable blocker and shadow caster, a 4 m road tile, and native camera DOF (near 10 m, far 16.5 m, amount 0.014). The glint is occluded at spawn and visible by midway.

Session 3 is the road variant at `scenes/maps/desert_canyon_handlaid_sandstone.tscn`. It passed the 4 m scale, wrap seam, forward walk, landmark and shadow checks. Its road master is `assets/textures/source/handlaid_sandstone.kra`. Session 2 remains the featured comparison in the Developers Page. See the Session 3 experiment log for the matched concept crops and normal-map proof.

Next test the right gateway silhouette using the Session 3 road. Test light shafts through that opening in a separate atmosphere pass, then begin the tactical handoff. Record the actual scene, source maps, camera stops and evidence for each pass.
