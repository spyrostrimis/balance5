# Pipelines

How each kind of thing gets made in Balance, step by step: what tool, who does it (you or an agent), and how you know it worked. Balance Studio shows this file on its **Pipelines** page, with a copy button for each agent brief.

**Status** is one of *In use* (proven, we use it now), *Planned* (agreed, not yet built) or *Retired* (kept for history). **For agents:** when you prove, change or retire a way of making something, update its entry here. Keep steps short, name real files, and explain new terms in [GLOSSARY.md](GLOSSARY.md).

## Run a work session with an agent
Area: Workflow · Status: In use · Tools: Balance Studio, Claude Code / Codex / Antigravity, Godot, Git
The loop every piece of work follows, whichever agent you use. The same rules apply to all agents because they all read `AGENTS.md`.

### Steps
1. **Pick the task** in Studio → Plan. RTS work comes first.
2. **Copy the brief** (the button on the task) and paste it into the agent. It tells the agent what to read and what to update afterwards.
3. **The agent works** in the Balance5 folder: reads `AGENTS.md` and `docs/GAME_DESIGN.md`, makes the change in its own test scene when it is an experiment, and captures or tests it.
4. **The agent records** results in `docs/EXPERIMENT_LOG_AND_LESSONS.md`, ticks `docs/ROADMAP.md`, adds decisions to `docs/DECISIONS.md` and new words to `docs/GLOSSARY.md`.
5. **You check it**: play it from the Developers Page (Esc returns), or look at the capture images in Studio → Builds.
6. **Decide**: accept, ask for changes, or reject. Record the decision (Studio → Decisions, or ask the agent).
7. **Commit and push** when you are happy. Agents share one branch (`main`), so commit one finished piece at a time.

### Done when
- The roadmap item is ticked, the decision is written down and the commit is pushed.
- Another agent could pick up from the docs alone, without this chat.

### Ask an agent
```text
In D:\Games\Balance5, read AGENTS.md and docs/GAME_DESIGN.md first. Task: <describe the task>.
Work in a separate test scene if this is an experiment. Verify it (play it or capture it) and look at every image before reporting.
When done: log the result in docs/EXPERIMENT_LOG_AND_LESSONS.md, tick or add the item in docs/ROADMAP.md, record any decision in docs/DECISIONS.md, and add any new technical term to docs/GLOSSARY.md in plain language. Explain what you did in simple terms; I am new to game development.
```

## Texture from an AI image (pixel or smooth)
Area: Art · Status: In use · Tools: ChatGPT, Perchance, Python, Aseprite, Godot
Turn a generated image into a game texture for one surface role (cliff strata, slate tops, road cobble, sand, dune, boulder, bush). Two procedures exist: **pixel snap** makes true pixel art, the **smooth procedure** makes a high-resolution tiling texture. Full prompts and palettes are in `docs/PIXEL_TEXTURE_PROMPTS.md`.

### Steps
1. **Generate** the image with ChatGPT or Perchance using the prompt for its role in `docs/PIXEL_TEXTURE_PROMPTS.md`. For ChatGPT, also ask for the matching height map. (Gemini is out: it draws brickwork.)
2. **Save** the image somewhere on disk and note its path.
3. **Preferred: the painted recipe.** Ask for a detailed *painted* texture (not pixel art), then:
   `C:/Python312/python.exe tools/python/pixel_snap.py cobble "C:\path\image.png" --painted --height "C:\path\height.png" --set art_look`
   It shrinks the image to 64 texels per metre at the role's size and uses the shared goal palette, like B64.
4. **Only for images drawn as real pixel art: run pixel snap** (or ask an agent to):
   `C:/Python312/python.exe tools/python/pixel_snap.py strata "C:\path\image.png" --height "C:\path\height.png" --set art_gpt`
4. **Run the smooth procedure** on the same image:
   `C:/Python312/python.exe tools/python/smooth_texture.py strata "C:\path\image.png" --height "C:\path\height.png" --set hr_gpt`
5. **Read the console**: grid fit above 85%, the repeat covers about the intended metres, height alignment above +0.30, seam ratio below about 1.5.
6. **Fix seams** if needed in Aseprite (*View → Tiled Mode*).
7. **Compare in game**: Developers Page → HD-2D Pixel A/B. Key 4 cycles pixel sets, 5 cycles smooth sets, 1 is the realistic control.

### Done when
- The set shows in the A/B scene, the repeat is not visible, and stones or rock beds look the right size next to the commander.
- The verdict is written in the experiment log.

### Ask an agent
```text
In D:\Games\Balance5, read AGENTS.md and docs/PIXEL_TEXTURE_PROMPTS.md. I generated <role> textures with <generator> at: <paths>. Run both pixel_snap.py (set art_<name>) and smooth_texture.py (set hr_<name>), report grid fit, covered metres, height alignment and seam ratio in plain words, and capture the HD-2D Pixel A/B scene at start, midway and exit in modes 1, 4 and 5. Show me the images side by side and log the verdict.
```

### Files
- `tools/python/pixel_snap.py`, `tools/python/smooth_texture.py`
- `assets/textures/pixel_ab/art_*`, `assets/textures/pixel_ab/hr_*`
- `scenes/maps/canyon_v2_pixel_ab.tscn`

## Compare scale and camera in a painted 2D room
Area: Canyon · Status: In use · Tools: Godot, Krita, FFmpeg

1. Put the comparison in its own playable scene. Keep the boots, road, foreground draw order and shot lanes in room coordinates. Keep controls and the reference painting in screen space.
2. Measure several ordinary paving stones across the road at each stop. Draft heights from the width ratios and judge the figures against the curb and masonry. Reuse the same local scale for travel speed, muzzle and shadow.
3. Extend the layered painting by the camera's maximum travel. Put the original rows at their original room coordinates and use their exact pixels at spawn.
4. Run the same input route in each mode. Capture the exact standing marks and record at game speed, with chapters at matched boot positions. Check the top edge at the travel limit, F2 restoration, stops, reversals and both room transitions.

[Pixel Canyon study, source and reproduction steps](PIXEL_CANYON_CAMERA_STUDY.md)

## Project a continuous 2D road with foreground cutouts
Area: Canyon · Status: Retired · Tools: Godot, Python with Pillow and NumPy, FFmpeg

Through the Bend proved the shared ground coordinates for the road, boots, roots and shots, with exact follow and follow with leeway. It also showed that large scenery cut from fixed-view paintings separates visibly from the ground as the camera goes past. Judge wall-to-ground contact, consistent lighting, and newly visible cliff faces in a short moving test before authoring a full route again.

[Through the Bend notes and commands](PIXEL_CANYON_FOLLOW_STUDY.md)

## Draw a connected scrolling 2D junction
Area: Canyon · Status: Trying · Tools: Python with Pillow and NumPy, Godot, FFmpeg

1. Draw the path, curb, cliff faces, bases and stair contacts at the same angle and art pixel size. Keep the rock silhouette that crosses in front of the player on a registered foreground layer.
2. Reuse the exploration sprite and move the whole view by pixels. Keep the road edges on the same map as the curb.
3. Run the same route uphill and downhill. Stop with the character partly covered and check that the same stair is visible on the way back. Compare the overlook at native size with the original painting.

[Session B source and reproduction commands](PIXEL_CANYON_SESSION_B.md)

## Fit a painting to a playable 2D bend
Area: Canyon · Status: Trying · Tools: ChatGPT Images, Krita, Godot, FFmpeg

1. Export the existing map without the character. Mark the road edges, near wall, stairs, deck and arch feet on a separate copy. Send that guide and the two style paintings with every candidate.
2. Review at the same camera positions with the gameplay sprite at native size. Check the road and wall outlines separately from how the paintings look.
3. Fit the chosen painting to the map points. Keep the near wall and the ground behind it on aligned Krita layers. Export the opaque ground and the transparent foreground at the original pixel scale.
4. Run the existing round trip on the painted scene. Check the reversal by the wall, the stair on both passes and the in-game overlook beside the original painting.

[Painted Bend source, captures and fit](PIXEL_CANYON_SESSION_B_PAINTED.md)

## 3D rock module (Blender to Godot)
Area: 3D · Status: In use · Tools: Blender, Godot
Make a reusable rock piece for the canyon and place it along the route.

### Steps
1. **Model** in Blender at real size (1 unit = 1 m), with the pivot at the foot and transforms applied. Paint vertex-colour flags only as 0 or 1 (red = slate, blue = ochre boulder).
2. **Export** as `.glb` into `assets/models/`. Agents usually do steps 1–2 with a script in `tools/blender/`.
3. **Re-import**: open Godot (or run it headless with `--editor --quit`) so it picks up the new file.
4. **Wrap** it: make a small scene in `scenes/canyon/modules/` that holds the mesh, the shared material `assets/materials/canyon_rock.tres` and a simple box blocker for collision.
5. **Place** it: add an entry to `scenes/canyon/canyon_v2_layout.tres` (z, lateral, yaw offset, scale). The layout rebuilds live in the editor.
6. **Test**: run the walk capture and the corridor test.

### Done when
- The module shows at the three walk stops, casts a real shadow, and the commander cannot walk through it.
- Changing the Blender file and re-exporting updates every placed copy without editing the scene.

### Ask an agent
```text
In D:\Games\Balance5, read AGENTS.md, docs/HD2D_CHECKLIST_AND_RUBRIC.md and docs/EXPERIMENT_LOG_AND_LESSONS.md. Author a new canyon module in Blender: <describe shape, size, which side>. Use a foot-level pivot, metres, binary vertex-colour flags. Export a GLB, wrap it in scenes/canyon/modules/ with canyon_rock.tres and a box blocker, place it in canyon_v2_layout.tres, then run tests/test_true_3d_walk.gd and tests/test_canyon_corridor.gd and show me start, midway and exit.
```

### Files
- `tools/blender/`, `assets/models/canyon_kit/`, `scenes/canyon/modules/`, `scenes/canyon/canyon_v2_layout.tres`

## Shape the canyon (route and placements)
Area: 3D · Status: In use · Tools: Godot
Bend the road or move rocks in canyon v2 by hand in the Godot editor, without code.

### Steps
1. Open `scenes/maps/canyon_v2.tscn` in Godot.
2. **To bend the road**: select the `Route` node (a Path3D) and drag its curve points. Keep the route always moving towards −Z.
3. **To move a rock**: open `scenes/canyon/canyon_v2_layout.tres` in the Inspector and change that placement's `z` (along the road), `lateral` (sideways), `yaw_offset_deg` (turn) or `scale`.
4. Watch the scene rebuild live, then press F6 to play the scene.

### Done when
- The commander walks start to exit without getting stuck and the exit signal fires (ask an agent to run the corridor test).

## AI image to 3D boulder
Area: 3D · Status: In use · Tools: ChatGPT, TRELLIS.2, Blender, Godot
Turn a generated image of a rock into a 3D boulder that matches the canyon.

### Steps
1. Generate a clean image of one rock on a plain background.
2. Convert it to a GLB with an image-to-3D tool (TRELLIS.2 on Hugging Face won our test).
3. Clean it in Blender with `tools/blender/blender_import_ai_boulders.py`: weld seams, fill holes, reduce triangles, set the foot pivot.
4. Give it the shared sandstone material (`hd2d_chatgpt_boulder.gdshader`) so it matches the walls, and a box blocker.
5. Place it and compare it at spawn in a matched capture.

### Done when
- The boulder reads as the same rock as the walls, has no holes or dark baked blobs, and stays under about 20,000 triangles.

## Raised road stones from a cobble texture
Area: Art · Status: Trying · Tools: Python, Godot
Lift every stone of a cobble set so it has real edges and casts real shadows.

### Steps
1. Make the cobble set as usual (ChatGPT texture plus height, both procedures).
2. Build its displacement height: `C:/Python312/python.exe tools/python/relief_height.py "C:\path\cobble.png" --height "C:\path\cobble_height.png" --sets art_gpt hr_gpt`. Check `tmp/relief_height/cobble_height_check.jpg`: white stones should sit exactly on the painted stones.
3. In the HD-2D Pixel A/B scene, pick the set (4 or 5) and press **R**. Capture with `PIXEL_AB_RELIEF=1` (and `PIXEL_AB_RELIEF_DEPTH=0.06`).
4. Measure the cost with `tests/test_relief_cost.gd`.

### Done when
- The stones look raised at spawn and midway, no floor shows through, and the GPU cost is logged.

## Free pack model into the canyon
Area: 3D · Status: Trying · Tools: Blender, Godot
Use a downloaded model (FBX or OBJ) as a wall piece, landmark or boulder.

### Steps
1. Check the licence first. No licence found → keep it in `assets/models/packs_local/` (ignored by git) for tests only.
2. Convert: `C:/Blender/blender.exe -b --factory-startup --disable-autoexec --python tools/blender/convert_pack_model.py -- in.fbx out.glb --height 9` (add `--keep-material` to keep a photo texture).
3. Place it in `scripts/canyon/canyon_packs_test.gd` (z, offset from the road, yaw, scale) with `canyon_rock.tres`, and capture `scenes/maps/canyon_v2_packs.tscn` with packs on and off.

### Done when
- It reads as the same rock as the walls in a matched capture, and its licence is recorded next to it.

## Add a build to the Developers Page
Area: Workflow · Status: In use · Tools: Godot
Make a new scene playable from the in-game menu so you can try it.

### Steps
1. Open `scenes/ui/opening_screen.tscn` and select the root node.
2. In the Inspector, append an entry to the **Builds** array with its title, description, scene path, AI credit and section.
3. Choose **Play** for playable scenes, **View** for static previews.
4. The opening button features the newest available entry, including local studies. The scene file's last saved time supplies the date when both date fields are blank. Set **Built UTC** (`YYYY-MM-DD HH:MM[:SS]`) to record a fixed build time and use **Milestone UTC** to record publication. For older entries with only a milestone, the catalog uses that date.
5. Launch it from the page and return with Esc.
6. Re-export (*Project → Export → Windows Desktop*) to update `builds/Balance.exe`.

### Done when
- The card launches, Esc returns, and Studio → Builds lists it after **Refresh**.
- In the game, use **Newest first** or **Oldest first** for date order. Drag a card within its section or drag a section heading to save a manual order. Choose **Edit** on a card to save a title and description on this computer. Shared edits go in the **Builds** array.

## Capture and compare a scene
Area: Testing · Status: In use · Tools: Godot, Balance Studio
Prove a visual change with matched screenshots instead of opinions.

### Steps
1. Keep a **control** (the unchanged scene) and make the change in a separate test scene.
2. Run the walk capture in a real window (never headless), at 1376×768:
   `C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_true_3d_walk.gd -- --scene <scene> --capture-dir <dir> --prefix <name>`
3. For canyon v2, also run `tests/test_canyon_corridor.gd` headless (walls, end caps, exit signal, navigation).
4. Look at start (Z +6), midway (Z −3.5) and exit (Z −14) side by side. Studio → Builds → Canyon review compares indexed walks.
5. Log the result with image links in the experiment log and update the rubric.

### Done when
- Every image was looked at, positions and floor contact are recorded, and the verdict is in the log.

## RTS map from tiles
Area: RTS · Status: Planned · Tools: Tiled, Aseprite, Godot TileMap
Build Mission 1's battlefield from reusable tiles rather than one painted picture, so maps, fog of war and pathfinding scale. The desert kitbash library is the starting point; Blue's forest uses the same layout.

### Steps
1. Grid size is decided: 32 px tiles (DECISIONS.md, 2026-11-20). The test map is 48 × 30 tiles.
2. Build or generate the tile set: sand, dunes, rock, road, Orichalcum outcrop (start from `assets/textures/kitbash/` and the Tiled pack in `assets/textures/source/tiled/`). Draw height in with the light from the top-left: lit tops, visible front walls of cliffs, shadows falling down-right.
3. Lay out the Mission 1 map in a Godot `TileMapLayer` following `docs/references/rts_mission1_desert_red.webp`. `scenes/maps/rts_test_map.tscn` shows the node layout.
4. Give every tile the `walkable` custom data flag (on for sand and road, off for rock). The `RtsGrid` node reads it, so pathfinding updates when you repaint. Press F1 in game to see blocked tiles.
5. Make the forest version from the same layout with forest tiles.

### Done when
- Units can path across the map around rocks, the map matches the reference layout, and the forest version shares it.

## RTS art style test
Area: Art · Status: In use · Tools: Python, Godot, ChatGPT
Judge a change to the RTS look on one screen that has every layer, next to the reference at the same scale. Rules: `docs/RTS_ART_RULES.md`.

### Steps
1. (Once per map type) Extract the palette: `C:/Python312/python.exe tools/python/rts_palette.py`. Check `render_captures/rts_style/reference_palette_check.png` looks like the reference.
2. Change one layer at a time: a new painted texture, a tool setting or a shape in `tools/python/make_rts_style_test.py`. Painted inputs go in `assets/source_inputs/rts/` under the names in the art rules §7; the `SHRINK` and `TARGETS` tables in the tool set how much each is shrunk and which reference colours it is matched to.
3. Regenerate: `C:/Python312/python.exe tools/python/make_rts_style_test.py`, then `Godot --path . --headless --import`.
4. Capture: `Godot --path . --script res://tests/capture_rts_style_test.gd` writes `render_captures/rts_style/style_test.png` and `style_reference.png`.
5. Or look in game: Developers Page → RTS Style Test. **T** switches test 1 / test 2, keys 1–5 toggle layers, **R** lays the reference on top, **G** shows the 32 px tiles.
6. Measure the sand against the reference (light variation at 1–2, 2–5, 5–12 and 12–30 px, and colour variety; art rules §6c) as well as looking.
7. Write the verdict (right, gaps largest first) in the art rules §6, and a decision if a rule changes.

### Done when
- Both captures were looked at, the gaps are listed, and the next change targets the largest gap.

### Ask an agent
> Run the RTS art style test pipeline with these new textures (paths …) for the sand / dunes / rock top / cliff wall / road, compare against the reference and list the remaining gaps.

## RTS unit type
Area: RTS · Status: In use · Tools: Godot
Add a new kind of unit, or change an existing one's numbers.

### Steps
1. In Godot's FileSystem, duplicate a file in `scenes/rts/units/` (for example `blue_troop.tres`) and rename it.
2. Open it in the Inspector and set name, faction, kind, health, attack, armour, range, cooldown, guard range and speed. Leave **Sprite** empty for the placeholder disc, or pick a picture.
3. To put one on a map: drag `scenes/actors/rts_unit.tscn` under the map's `Units` node, move it onto a walkable tile, and drag the `.tres` file into its **Stats** slot.
4. Run `tests/test_rts_test_map.gd` headless, then play the map from the Developers Page.

### Done when
- The unit selects, moves and fights with its new numbers, and the test still passes.

### Ask an agent
> Add an RTS unit type called X for faction Y with these numbers (…). Follow PIPELINES.md → RTS unit type, place two on `rts_test_map`, and rerun the RTS test.

## Unit or character sprite
Area: Art · Status: Planned · Tools: ChatGPT, Aseprite, Python
Make a pixel-art unit with all its facing directions and animations.

### Steps
1. Agree sprite size, pixels per metre and number of directions (the blue tank uses 8) for RTS units; record it in DECISIONS.md.
2. Generate or draw the unit; clean with `tools/python/clean_blue_tank_sprite.py`-style processing or by hand in Aseprite.
3. Keep a common canvas, foot pivot and team colours.
4. Export the sprite sheet to `assets/textures/units/`.
5. Check it next to other units at RTS zoom, in sun and shade.

### Done when
- The unit reads at game zoom, faces the right way when moving, and its team is obvious.

## Storyboard briefing panel
Area: Story · Status: Planned · Tools: ChatGPT, Krita, Godot
Illustrated story panels between missions, in the manner of Dune II's mentat briefings.

### Steps
1. Write the panel text and speaker (Studio → Story → add a story panel).
2. Generate or paint the portrait and the framed illustration; keep everything original.
3. Lay out portrait, picture and text in a Godot UI scene.
4. Link it before or after a mission.

### Done when
- The briefing plays before Mission 1 and the text fits the story in `docs/GAME_DESIGN.md`.

## Fixed-screen 2D RPG room

1. Check the untouched 960×540 master in the study's viewport against the supplied 2× preview. Keep the original file.
2. Use a layered art file for the master, cobble repair and any foreground cutout. Export the ground plate with no actor painted into it. Export a foreground cutout at the original full-canvas coordinates.
3. In Godot, trace the walkable edge in the room's collision polygon and add a separate blocker for the roots or base of the foreground object. Place its drawing point at the roots so that the commander's feet determine whether it draws in front.
4. Keep the commander's cells at 128×144 with pivot (64, 135). Export the tagged animation in seven columns and keep the walk cel spacing tied to the planted boot's travel.
5. Capture the reference position, a shrub crossing and a depth test before reviewing a new room. Use the same light and road scale, with one recognizable landmark across the transition.

[Editable art, capture commands and test](PIXEL_CANYON_STUDY.md)

## 2D Parallel-Projection Canyon — Approach 1 (Uncut) & Approach 2 (Modular Kit)
Area: Art · Status: Trying · Tools: ChatGPT, Python, Laigter, Krita, Aseprite, Godot 2D
Build a constant-scale scrolling 2D RPG canyon (960×540 with 640×360 toggle, 192-colour palette, Laigter normal maps, locked follow camera) using either a continuous uncut 2D canvas (Approach 1) or modular cliff/road/prop sheets stitched and Y-sorted in Godot 2D (Approach 2).

### Steps
1. **Prompt ChatGPT with horizon-cropped references** (`tmp/chatgpt_refs/Ref1_Camera_Projection_SeaOfStars.jpg` for parallel 3/4 camera angle + `Ref2_Style_Palette_Image9_NoHorizon.png` for material palette without vanishing point). Save uncut plates or `#3A003A`-background modular sheets into `assets/source_inputs/rpg_2d/`.
2. **Stitch, slice, quantize to 192 colours, and generate Laigter normal maps**:
   `C:/Python312/python.exe tools/python/build_rpg_2d_canyon_assets.py`
   Uses dynamic-programming minimum-error graph cuts (`dp_horizontal_seam`, `dp_vertical_seam`) for seamless canvas/road stitching, exterior perimeter flood-fill for `#3A003A` magenta cutouts without eroding interior rock crevices, and `C:\Laigter\laigter.exe --no-gui --normal -d` for normal maps.
3. **Import and build the three Godot scenes**:
   `C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`
   `C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/godot/build_rpg_2d_canyon_scene.gd`
   Produces `canyon_orthographic_study.tscn` (`Tab`/`M` live A/B toggle), `canyon_approach1_uncut.tscn`, and `canyon_approach2_modular.tscn`.
4. **Verify logic & Forward+ captures**:
   Run `tests/test_rpg_2d_canyon_logic.gd` headless and `tests/capture_rpg_2d_canyon.gd` windowed (`1376×768`), then inspect `render_captures/rpg_2d/a1_*.png` and `a2_*.png`.

### Done when
- Both approaches scroll smoothly with zero seams, constant hero size, clean Y-sort depth occlusion behind boulders/bushes/archways, 192-colour palette compliance, and passing headless/windowed tests.

## Record a decision or a new term
Area: Workflow · Status: In use · Tools: Balance Studio, any agent
Keep the project's memory in the repository instead of in chat histories.

### Steps
1. **Decision**: add an entry to `docs/DECISIONS.md` (date, title, area, status, why). Or save a local note in Studio and ask an agent to move it into the file.
2. **New word**: add it to `docs/GLOSSARY.md` in plain language.
3. **Plan change**: add or tick the item in `docs/ROADMAP.md`. Studio can tick boxes directly.
4. Commit with the work it belongs to.

### Done when
- Studio shows it after **Refresh**, and any agent reading the docs knows it.
