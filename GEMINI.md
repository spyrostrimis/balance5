# Balance5 — HD-2D Desert Canyon Project Rules & Memory Index

> This workspace rule file is automatically loaded on every turn. Follow it strictly so we never repeat past dead ends or regress already-verified visual properties.

---

## 1. Mandatory Pre-Work & Post-Work Protocol

1. **Before modifying any geometry, texture, shader, or scene assembly script:**
   - Read [`docs/HD2D_CHECKLIST_AND_RUBRIC.md`](docs/HD2D_CHECKLIST_AND_RUBRIC.md) and [`docs/EXPERIMENT_LOG_AND_LESSONS.md`](docs/EXPERIMENT_LOG_AND_LESSONS.md).
2. **Regression Lock Rule (CRITICAL):**
   - Never un-tick a previously locked `[x]` requirement in [`docs/HD2D_CHECKLIST_AND_RUBRIC.md`](docs/HD2D_CHECKLIST_AND_RUBRIC.md) while polishing something else.
   - Example: D1 already achieved `[x]` **Structure — Blocky Stepped Terraces**; D2/D3 broke that lock by replacing cubes with cones and sheared prisms when the real problem was **height**, **continuity**, and **texture scale**. Always isolate what actually needs changing.
3. **One Variable / One Piece at a Time:**
   - Do not change Hero, Camera, ground, bushes, lighting, and canyon geometry simultaneously. Isolate one hypothesis per small test so visual before/after comparison is unambiguous.
4. **Post-Test Inspection & Memory Update:**
   - Visually inspect every captured PNG (`pos1_start`, `pos2_midway`, `pos3_exit`) using `read_file` before reporting results.
   - Never guess or extrapolate what changed—update [`docs/HD2D_CHECKLIST_AND_RUBRIC.md`](docs/HD2D_CHECKLIST_AND_RUBRIC.md) and [`docs/EXPERIMENT_LOG_AND_LESSONS.md`](docs/EXPERIMENT_LOG_AND_LESSONS.md) immediately after every verified run.

---

## 2. Hard Locks (Never Modify Without Explicit User Instruction)

| Locked Component | File | Locked Values / Behavior |
| :--- | :--- | :--- |
| **Hero Character** | [`scripts/blue_commander_3d_player.gd`](scripts/blue_commander_3d_player.gd) | `CharacterBody3D` (`BlueCommander`), `CommanderSprite` `pixel_size = 0.00118`, `y = 0.64`, spawn `Vector3(_path_cx(6.0), 0.02, 6.0)`, path clamp `x in [cx - 1.15, cx + 1.15]`, `z in [-14.5, 7.5]`, exit signal at `z <= -13.5` |
| **Camera Rig** | [`scripts/rpg_camera_3d_follow.gd`](scripts/rpg_camera_3d_follow.gd) | `Camera3D` (`CameraRig`), `fov = 30.0`, `follow_offset = Vector3(0.0, 3.8, 12.6)`, `fixed_pitch_deg = -13.0`, `x_follow_factor = 0.35`, `follow_smooth_speed = 6.5` |
| **Camera-Only Blur** | [`assets/shaders/tilt_shift_hd2d.gdshader`](assets/shaders/tilt_shift_hd2d.gdshader) | Depth-of-field tilt-shift blur lives **exclusively** in `PostProcessing/TiltShiftDof`. **NEVER** bake Gaussian/bokeh blur into 2D or 3D textures, terrain strips, or billboard cards |

---

## 3. Living Guide Directory

- **[`docs/HD2D_CHECKLIST_AND_RUBRIC.md`](docs/HD2D_CHECKLIST_AND_RUBRIC.md)** — The 8 Core Reference Checkboxes against Picture 1 + *Octopath Traveler* and the full per-test regression matrix (`A` → `Strata Wall`).
- **[`docs/EXPERIMENT_LOG_AND_LESSONS.md`](docs/EXPERIMENT_LOG_AND_LESSONS.md)** — Proven dead ends (never repeat), proven winners, shader/Blender technical gotchas, and chronological experiment log.
- **[`docs/PIPELINE_AND_TOOLS.md`](docs/PIPELINE_AND_TOOLS.md)** — Recommended multi-tool production pipeline table (`Stage | Tool | What Happens | Who Does It`), exact CLI commands (`Python`, `Blender 5.2`, `Godot 4.7.2`), and capture harness details.
- **[`docs/REFERENCE_AND_STYLE_BIBLE.md`](docs/REFERENCE_AND_STYLE_BIBLE.md)** — Architectural comparison of Img 1, *Octopath Traveler*, *Ori*, *Child of Light*, and *Hollow Knight*, the 4 shared HD-2D visual pillars, and sampled RGB palettes from `assets/textures/maps/desert_approach_rpg_albedo.png`.
