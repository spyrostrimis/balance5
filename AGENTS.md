# Balance5

Balance is a Godot 4 Forward+ RTS/RPG prototype. The playable canyon is `scenes/maps/desert_canyon_true_3d.tscn`. The design reference is `assets/textures/maps/desert_approach_rpg_albedo.png`. Judge the bend at the commander's walking height and again at the exit.

## Canyon baseline

- Commit `6576387` records D4b. The left wall has continuous stepped courses, warm dark slate faces, irregular horizontal sandstone bedding, recessed coves and a tall gateway bluff. Its accepted framing is visible in the D4b start, midway and exit captures. The right side still uses painted wings.
- For comparable captures, use the existing commander, path bounds and exit signal. Keep the follow camera at 30° FOV, −13° pitch and offset (0, 3.8, 12.6). See `GEMINI.md` for the shared baseline values. Apply a requested experimental setting to the test scene first.
- Preserve sharp source art. D4b uses a canvas blur based on screen height. A camera-depth comparison belongs in an isolated lens test with each blur method enabled separately.

## Working with the level

- Inspect the working tree first. The D4b assembler loads named meshes from `assets/models/canyon_kit_test_d.glb` and packs them into the launch scene. Running `scripts/assemble_cinematic_canyon.gd` rewrites that scene. For a new module, prefer a separate imported GLB instanced in a Godot wrapper that owns the material and simple blocker.
- Use metres and a foot-level pivot for new modules or actors. Preserve the rock material's vertex channels: red selects slate, green carries AO, and blue at 1 selects the ochre boulder material. The local art notes document the calibrated D4b colors.
- For a visual change, render from the actual Forward+ viewport. Inspect start (Z ≈ +6), midway (−3.5) and exit (−14) at 1376×768. Record actual positions, floor contact and exit signal. The existing walk harness targets the launch scene, writes fixed capture filenames and can advance on timeout. Give experiments their own scene target and output names.

## Handoffs

The detailed rubric, experiment history, art guide, pipeline and `docs/CANYON_BEND_SESSIONS.md` are local to the primary workspace. Git intentionally ignores `docs/`. In a fresh clone or linked worktree, consult the primary copy if available. The scene, scripts and this baseline also travel with the repository once committed.

The next small test is one right-hand buttress. Demonstrate a Blender notch surviving reimport, a real shadow crossing the road, and a fixed landmark revealed during a grounded walk. The larger milestone is the same bend with a seamless metre-scaled road and a depth-of-field comparison. A test report identifies its scene, source asset, captures and measured results so the next chat can continue from that exact state.
