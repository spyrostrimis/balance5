# Balance dictionary

Plain-language meanings of the words we use while building Balance. Written for the owner, who knows some programming but is new to game development. Balance Studio shows this file as the **Dictionary** and underlines these terms wherever they appear in other documents.

**For agents:** when you use a technical term the owner may not know, add it here in the same format (a `###` heading, an `Area:` line, two to four plain sentences, and an *In Balance* line when it helps). Keep definitions short and concrete. Prefer an everyday comparison over jargon.

## The big picture

**How a Godot game is put together.** A game is a set of **scenes**. A scene is a tree of **nodes**: a camera node, a light node, a character node, a rock node. Each node does one job. **Scripts** (GDScript, similar to Python) give nodes behaviour, such as "move when the player presses W". The opening screen, each canyon test and each RTS map are separate scenes.

**How a 3D picture is made, every frame.**

1. **Shapes.** Every rock, wall and road is a **mesh**: a hollow surface made of small triangles, built in Blender and saved as a `.glb` file.
2. **Paint.** A **material** says what the surface looks like. It holds **textures** (flat 2D images) and a **shader** (a small program on the graphics card that decides the colour of every pixel). Textures are wrapped around the mesh like wallpaper. One texture pixel is a **texel**.
3. **Light.** A **directional light** acts as the sun. It shades each surface by its angle and casts **shadows**.
4. **Camera.** The camera decides what is seen: its position, its tilt (**pitch**) and how wide it sees (**FOV**).
5. **Finishing.** **Post-processing** effects such as **depth of field** blur, fog and glow are applied to the finished image.

Godot does all of this about 60 times a second. The **renderer** we use is called **Forward+**.

**How 2D fits in.** Characters, bushes and RTS units are **sprites**: flat 2D images, often pixel art, placed in the world. **HD-2D** is the style that mixes pixel-art sprites with a real 3D world, lit and blurred like a miniature diorama.

## Terms

### Game engine
Area: Basics
The program that runs a game and gives you tools to build it: drawing, physics, sound, input. We use **Godot**. Unity and Unreal are other engines.

### Godot
Area: Basics
The free, open-source game engine Balance is built in, version 4.7.2. You open the project folder in the Godot editor, edit scenes and press Play (F5) to run.
*In Balance:* the executable lives at `C:\Godot\Godot_v4.7.2-stable_win64.exe`.

### Scene
Area: Basics
A saved arrangement of nodes, stored as a `.tscn` file. A level, a character or a menu can each be a scene, and scenes can contain other scenes.
*In Balance:* `scenes/maps/canyon_v2.tscn` is the canyon; `scenes/ui/opening_screen.tscn` is the first screen.

### Node
Area: Basics
One building block inside a scene, with one job: `Camera3D`, `DirectionalLight3D`, `Sprite3D`, `CharacterBody3D` and so on. Nodes form a tree, and moving a parent moves its children.

### Script
Area: Basics
Code attached to a node to give it behaviour. Godot's language is **GDScript** (`.gd` files), which reads much like Python.
*In Balance:* runtime scripts live in `scripts/`; editor tools in `tools/godot/`.

### Resource
Area: Basics
Reusable data saved as its own file, usually `.tres` or `.res`: a material, an environment, a layout list. Several scenes can share one resource, so changing it changes all of them.
*Also:* .tres

### Inspector
Area: Basics
The panel on the right of the Godot editor that lists the settings of the selected node. Most tuning (camera angle, light strength, fog) happens here.

### Export
Area: Basics
Turning the project into a program that runs without Godot.
*In Balance:* the *Windows Desktop* preset writes `builds/Balance.exe`. Re-export after changing the Developers Page catalog.
*Also:* build, Balance.exe

### Headless
Area: Basics
Running Godot without opening a window. Fast and fine for checks and file generation, but it cannot take screenshots, because nothing is drawn.
*In Balance:* never capture images headless; the corridor test runs headless.

### Forward+
Area: Rendering
Godot's highest-quality 3D renderer, which draws through the graphics card with Vulkan. Balance uses it. The alternatives (Mobile, Compatibility) are simpler and look different.

### Frame
Area: Rendering
One finished picture. Games draw about 60 frames per second (FPS). **GPU frame time** is how many milliseconds the graphics card needs per frame; 16.7 ms is the budget for 60 FPS.
*Also:* FPS, GPU frame time

### Mesh
Area: 3D
The 3D shape of an object: a hollow skin of small triangles (**polygons**) joined at corner points (**vertices**). It has no colour by itself; a material gives it one.
*Also:* polygon, triangle, vertex, vertices

### GLB
Area: 3D
The file format we use to move 3D models from Blender into Godot (the binary form of **glTF**). When you re-export a `.glb`, Godot re-imports it and every scene that uses it updates.
*Also:* glTF, .glb

### Displacement
Area: Rendering
Moving the actual surface points of a mesh up or down by a height map, so bumps are real geometry: they have true edges, hide what is behind them and cast shadows. A normal map only fakes the light. It needs many small triangles, which costs GPU time.
*Also:* vertex displacement, raised stones, relief

### Photogrammetry
Area: 3D
Making a 3D model from many photos of a real object. Scans look realistic, which is why they clash with a painted style unless we give them our own material.
*Also:* photo scan, scan

### Low-poly
Area: 3D
A model built from few, large, flat triangles, so it looks faceted. Cheap to draw and easy to restyle with our own textures.
*Also:* low poly

### Triangle winding
Area: 3D
The order in which a triangle's three corners are listed. It decides which side is the front. Godot draws only fronts by default, so a mesh listed the wrong way round is invisible from above.
*Also:* winding order, face direction

### Blender
Area: Tools
Free 3D modelling program. We build rock modules, buttresses and clean up AI-made boulders in it, then export `.glb` files. Agents usually drive it with Python scripts in `tools/blender/`.

### Pivot
Area: 3D
The point an object is positioned and rotated around, also called the origin. We put it at the **foot** (ground level) so objects stand on the floor when placed at height 0.
*Also:* origin, foot-level pivot

### Transform
Area: 3D
An object's position, rotation and scale. "Applied transforms" in Blender means the shape's real size is baked in, so 1 unit really is 1 metre in Godot.

### Metre units
Area: 3D
We treat one Godot unit as one metre, so sizes are real-world: a 2 m rock is 2 units tall, and the canyon camera sits 5.5 m above the ground.

### X, Y, Z axes
Area: 3D
The three directions in 3D. In Godot, **X** is left–right, **Y** is up, **Z** is towards/away from the camera. The canyon walk goes along **−Z** (from Z +6 at the start to Z −14 at the exit). Blender uses Z for up, which the export converts.
*Also:* −Z, world axes

### UV mapping
Area: 3D
Instructions stored in a mesh saying which part of a texture lands on which triangle, like unfolding a cardboard box flat to paint it. Our rock shader mostly ignores UVs and uses **triplanar mapping** instead.
*Also:* UV, UVs

### Triplanar mapping
Area: Shaders
A way to put texture on a mesh without UVs: the shader projects the texture from three directions (top, front, side) using world position and blends them. It keeps rock layers horizontal and the same size on every module, wherever it is placed.

### World space
Area: Shaders
Coordinates measured in the whole scene rather than on one object. "World-Y strata" means the rock layers follow real height, so beds line up across neighbouring modules.
*Also:* world-Y

### Vertex colour
Area: 3D
A colour stored at each corner of a mesh. We do not show it directly; the shader reads it as hidden flags. Red picks slate, green carries shading (AO), blue at 1 marks ochre boulders. Flags must be exactly 0 or 1 because of **sRGB** conversion.
*Also:* vertex color, COLOR_0, vertex channels

### sRGB and linear
Area: Rendering
Two ways of storing brightness. Images are saved in sRGB (tuned for human eyes); lighting maths happens in linear. A value of 0.5 in sRGB becomes about 0.21 in linear, which once broke our rock flags. Colour images are sRGB; data images (normal, height, ORM) are linear.
*Also:* gamma, linear space

### Texture
Area: Textures
A flat 2D image wrapped onto a 3D surface to give it colour or detail. One surface usually uses several textures together: colour (**albedo**), bumps (**normal map**), and surface data (**ORM**).
*Also:* texture map

### Texel
Area: Textures
One pixel of a texture. We say "texel" to keep it apart from a pixel on your screen, because one texel can cover several screen pixels (close up) or less than one (far away).
*Also:* texture pixel

### Texels per metre
Area: Textures
How many texture pixels cover one metre of surface in the game world: the **density** of detail. At 64 texels per metre, a 1 m stretch of wall shows 64 texture pixels across. Higher means finer detail; lower means chunkier.
*In Balance:* the pixel-art test uses 48–64 texels per metre. At the walking camera, 64 per metre is about 2 screen pixels per texel, which reads as crisp pixel art one step chunkier than the commander sprite (about 170 per metre).
*Also:* texel density, 64 texels per metre, 48–64 texels per metre

### Resolution
Area: Textures
The size of an image in pixels, such as 1024 × 1024 (written 1024²). Bigger is not automatically better: what matters on screen is **texels per metre**.
*Also:* 1024², 2048²

### Repeat
Area: Textures
The real-world size one copy of a tiling texture covers before it repeats, such as "3.2 m per repeat" for the road. Together with resolution it sets texels per metre (1024 px over 3.2 m = 320 per metre).
*Also:* metres per repeat, m per repeat

### Seamless
Area: Textures
A texture whose left edge matches its right edge and top matches bottom, so copies laid side by side show no visible join (a **seam**).
*Also:* tileable, seam

### Wrap ratio
Area: Textures
Our measure of how visible a seam is: the colour jump across the tile's edge divided by the normal jump between neighbouring pixels. Near 1× means invisible; we aim below 2× (pixel tools warn above about 1.5).
*Also:* seam ratio, wrap-to-neighbor ratio

### Albedo
Area: Textures
The plain colour of a surface, with no lighting or shadow painted in. The scene's sun adds light and shade. Painting shadows into albedo makes them wrong when the light moves.
*Also:* base colour, base color, diffuse

### Normal map
Area: Textures
A purple-blue texture that fakes small bumps. Each texel stores which way the surface "faces", so light catches stone crowns and cracks without extra triangles.
*Also:* normal

### Height map
Area: Textures
A greyscale image where white is high and black is low. We use it to make the normal map, and to know where joints (low) and crowns (high) are.
*Also:* height, heightmap, displacement

### ORM
Area: Textures
One texture packing three data maps into its colour channels: **O**cclusion (red), **R**oughness (green), **M**etallic (blue). Saves memory and keeps the three aligned.
*Also:* ORM map

### Ambient occlusion
Area: Rendering
Darkening in creases and corners where light struggles to reach. It makes joints and cracks feel deep. Abbreviated AO.
*Also:* AO, cavity AO

### Roughness
Area: Rendering
How matte or shiny a surface is. Rough (1.0) scatters light evenly like chalk; smooth (0.0) shows sharp reflections like glass. Our stone is mostly rough.

### Material
Area: Rendering
The "paint job" assigned to a mesh: which shader to use plus its settings and textures. Saved as a `.tres` resource.
*In Balance:* `assets/materials/canyon_rock.tres` paints all canyon rock modules.

### Shader
Area: Shaders
A small program that runs on the graphics card for every pixel (and every vertex) to decide its final colour. Ours mix textures, apply triplanar mapping, read vertex-colour flags and add haze. Files end in `.gdshader`.
*Also:* gdshader, GLSL

### Shader variant
Area: Shaders
A copy of a shader with one difference, generated by a tool so we can compare. `*_pixel.gdshader` uses nearest filtering for pixel art; `*_smooth.gdshader` uses smooth filtering.

### PBR
Area: Rendering
Physically Based Rendering: describing surfaces with real-world properties (albedo, roughness, metallic, normal) so they react believably to any light. Most modern texture sets are PBR sets.

### Mipmaps
Area: Textures
Smaller pre-shrunk copies of a texture (half size, quarter size, ...) that the GPU uses for distant surfaces. Without them, far textures shimmer and sparkle.
*Also:* mip levels, mipmap

### Texture filtering
Area: Textures
How the GPU picks a colour between texels. **Nearest** takes the closest texel, giving hard square pixels (pixel art). **Linear** blends neighbours, giving smooth images (photo-like art).
*Also:* nearest filtering, linear filtering

### Anisotropic filtering
Area: Textures
A sharper way to sample textures seen at a slant, like a road stretching away. 4× or 16× keeps distant cobbles crisp.
*Also:* anisotropy

### Palette
Area: Art
The fixed list of colours an image may use. A **colour ramp** is a short run of shades of one material from darkest to lightest. Pixel art keeps palettes small (4–7 colours per material).
*In Balance:* the **goal palette** (`assets/textures/pixel_ab/palette_preview.png`) is 48 colours taken from the RPG goal image; B64 and `pixel_snap.py --painted` map every surface onto it, so they all belong to the same picture.
*Also:* colour ramp, color ramp, ramp, goal palette

### Pixel art
Area: Art
Art drawn on a visible grid of square pixels with a small palette, where each pixel is placed on purpose. Good pixel art has clustered shapes, deliberate highlights and dark outlines on joints. Shrinking a photo does not make pixel art.

### Pixel set
Area: Art
A set of textures drawn as real pixel art, one for each surface **role** (cliff strata, slate tops, road cobble, sand, dune, boulders, bushes). A "hand-made" set is designed on purpose (in Aseprite, or generated then snapped onto a true grid) rather than produced by shrinking existing art. These 2D images are then wrapped onto the 3D canyon blocks.
*In Balance:* sets live in `assets/textures/pixel_ab/art_*`; key 4 in the Pixel A/B scene cycles them.
*Also:* hand-made pixel set, authored pixel set, authored set, art set

### Pixel snap
Area: Tools
Our tool (`tools/python/pixel_snap.py`) that turns an AI "pixel-art-looking" image into true pixel art: it finds the drawn grid, keeps one colour per cell and reduces the palette. A **grid fit** above 85% means the image really was on a grid.
*Also:* pixel_snap.py, grid fit

### Smooth procedure
Area: Tools
Our other texture tool (`tools/python/smooth_texture.py`): keeps the image at 1024 px, blends its edges so it tiles, and builds normal and ORM maps. It made the ChatGPT road. Outputs go to `hr_*` sets (key 5).
*Also:* smooth_texture.py, hr set, hr_

### Sprite
Area: Art
A flat 2D image used as a character, unit, prop or effect. A **sprite sheet** packs all poses or frames of one character into one image.
*Also:* sprite sheet

### Sprite3D
Area: Rendering
A Godot node that places a flat 2D sprite inside the 3D world, usually turned to face the camera (a **billboard**). Our commander and sage bushes are Sprite3D nodes.
*Also:* billboard

### Alpha
Area: Textures
The transparency channel of an image. **Alpha cut** (alpha scissor) makes each pixel fully see-through or fully solid, giving crisp edges for bushes and sprites with no soft halo.
*Also:* alpha cut, alpha scissor, transparency

### Directional light
Area: Lighting
A light with only a direction, no position, like the sun: every ray is parallel. We use one called `DesertSun`. **Backlit** means the sun is ahead of the camera, so shadows fall towards the viewer.
*Also:* sun, DesertSun, backlit

### Shadow
Area: Lighting
A **cast shadow** is the dark shape an object throws onto other surfaces. Real cast shadows from the walls onto the road are one of our visual goals, and we prove them by toggling shadow casting on and off.
*Also:* cast shadow

### Fog
Area: Lighting
Haze that fades distant things towards a colour. **Exponential fog** applies everywhere; **volumetric fog** fills space and can show light shafts; a **FogVolume** is a fog box placed in one spot. Global fog washed our steep view to beige, so it is off.
*Also:* exponential fog, volumetric fog, FogVolume

### Haze
Area: Lighting
Our rock shader's own distance tint (`haze_strength`), separate from Godot fog. Canyon v2 uses 0.10.

### Light shafts
Area: Lighting
Visible beams of sunlight through dusty air, also called god rays. Planned for the atmosphere pass with a local FogVolume at a wall opening.
*Also:* god rays, shafts

### Environment
Area: Lighting
Godot's scene-wide settings for sky, ambient light, fog, glow and colour grading, saved as a `.tres`.
*In Balance:* `assets/environments/canyon_clear_air.tres`.

### Camera
Area: Camera
The viewpoint the frame is drawn from. Its main settings are position (**offset** from the player), **pitch**, **yaw** and **FOV**. It can **follow** the player smoothly.
*Also:* Camera3D, follow camera

### FOV
Area: Camera
Field of view: how wide the camera sees, in degrees. A narrow FOV (we use 30°) is like a telephoto lens: flatter, more miniature-looking, less distortion.
*Also:* field of view

### Pitch
Area: Camera
How much the camera tilts down. −13° shows the horizon; −21° (canyon v2) looks down more and hides the sky, like the RPG goal image. **Yaw** is turning left/right; **roll** is tilting sideways.
*Also:* yaw, roll

### Camera offset
Area: Camera
Where the camera sits relative to the player, in metres (X, Y, Z). Canyon v2 uses (0, 5.5, 11.9): centred, 5.5 m up and 11.9 m behind.
*Also:* offset

### Depth of field
Area: Camera
Blur for things nearer or farther than the focus distance, like a real lens. It sells the "miniature diorama" feel. We use Godot's **native** camera DOF: sharp between about 10 and 16.5 m, blur amount 0.014.
*Also:* DOF, native DOF, focus

### Tilt-shift
Area: Camera
A photo trick that blurs the top and bottom of the image so real scenes look like tiny models. Our older builds faked it with a **screen-height blur**; newer ones use real depth of field.
*Also:* TiltShiftDof, screen-height blur

### Post-processing
Area: Rendering
Effects applied to the finished frame: blur, glow (**bloom**), colour grading, **vignette** (darkened corners). Kept as scene controls, never painted into the art.
*Also:* bloom, glow, vignette, colour grading

### Exposure
Area: Rendering
Overall brightness of the camera image, like a camera's exposure setting. Held fixed during A/B tests so only the tested change differs.

### HD-2D
Area: Style
The look of *Octopath Traveler*: pixel-art characters and textures in a real 3D world with modern lighting, shadows and depth-of-field blur, so it looks like a lit miniature diorama. Our RPG canyon aims for it.
*Also:* Octopath style

### Diorama
Area: Style
A small model scene in a box. In our talk, the HD-2D feeling that the world is a crafted miniature: blocky shapes, crisp textures, strong light and blurred edges.

### 2.5D
Area: Style
Mixing 2D and 3D: flat images placed at different depths in a 3D space, or 3D seen from a fixed angle so it reads as 2D. Our early canyon used painted 2.5D cards; now walls are real 3D.

### Card
Area: Style
A flat painted image standing upright in a 3D scene, like stage scenery. Our early "wings" and "ledge cards" were cards; they looked flat and blurry and were replaced by 3D rock.
*Also:* painted card, wings, DioramaWings

### Parallax
Area: Style
Layers that move at different speeds as the camera moves (near fast, far slow), giving a sense of depth. Real 3D gives parallax automatically.

### Strata
Area: Canyon
The horizontal layers in sedimentary rock, like the stripes in a red-rock canyon. Our cliff faces are "terracotta strata".
*Also:* bedding, beds, sedimentary

### Terrace
Area: Canyon
A stepped course of rock: a flat top with a near-vertical face. Our canyon walls are stacks of blocky terraces, which is what the RPG goal image and Octopath show.
*Also:* course, stepped terraces, courses

### Slate cap
Area: Canyon
The dark grey-brown stone on the flat tops of terraces and the lower courses. Should be warm grey-brown, not black. Still reads too flat (open).
*Also:* slate, ledge tops, cap

### Buttress
Area: Canyon
A large rock mass jutting out from the wall. The right-hand buttress at the bend hides the crater until you walk past it.

### Cobble
Area: Canyon
Rounded paving stones of the road. A **sett** is a more rectangular cut paving stone.
*Also:* cobblestone, cobbles, sett

### Curb
Area: Canyon
The low stones along the road edge.
*Also:* curbs, kerb

### Landmark
Area: Canyon
A fixed point we use to test what the camera can see. Ours is the **crater glint** at the canyon's end: hidden at the start, revealed later as you walk.
*Also:* crater glint, glint

### Img 1
Area: Project
Our shorthand for the main art references. **Img 1** is the overall feeling (concept world, Blue vs Red); **Img 2** is the RTS goal with the HUD; **Img 3** is the RPG canyon goal. Older canyon docs call the canyon picture "Img 1" too.
*Also:* Img 2, Img 3, Picture 1

### Canyon v2
Area: Project
The current RPG canyon scene (`scenes/maps/canyon_v2.tscn`): one flat scene driven by an editable **route**, with rocks placed from a layout list. Replaced a chain of six inherited test scenes.

### D4b
Area: Project
An earlier canyon build (commit `6576387`) that first got the left wall right. Kept frozen as a comparison baseline. "D" builds were the 3D tests D1–D4b.
*Also:* D4, D1, Test D

### Bend
Area: Project
The canyon tests (Sessions 1–3) that added a curve, the right buttress, a new road and camera blur. "The bend" usually means `desert_canyon_bend.tscn`.
*Also:* bend session

### Route
Area: Project
The editable curve the canyon follows (a `Path3D` node). Change the curve in the editor and the road, rocks and walls follow it.
*Also:* Path3D, route curve

### Layout
Area: Project
The list of rock and bush placements along the route (`canyon_v2_layout.tres`): each says how far along (`z`), how far to the side (`lateral`), turn, scale. Edit placements to move rocks.
*Also:* placements, placement

### Module
Area: Project
A reusable piece of the canyon: one rock mesh wrapped in a small scene with its material and collision. Placed many times by the layout.
*Also:* wrapper, module wrapper, kit

### Collision
Area: Physics
Invisible simple shapes that stop things passing through each other. The visible mesh is for looks; the collision shape is for physics. A **blocker** is a simple box collision around a rock.
*Also:* collision shape, blocker, collider

### Corridor
Area: Physics
In canyon v2, the invisible walls along both road edges plus end caps that keep the commander inside, built automatically from the route.

### Navmesh
Area: Physics
Navigation mesh: a map of walkable floor that lets characters find a path around obstacles (**pathfinding**). The canyon bakes one; RTS units will need one or a grid.
*Also:* navigation mesh, NavigationMesh, pathfinding, NavigationAgent3D

### CharacterBody
Area: Physics
The Godot node type for a character you control: it moves, slides along walls and knows whether it stands on the floor (`on_floor`).
*Also:* CharacterBody3D, on_floor, grounded

### Walk capture
Area: Testing
Our standard visual test: a script walks the commander through the canyon and saves screenshots at three stops: **start** (Z +6), **midway** (Z −3.5) and **exit** (Z −14), at 1376×768, with position, floor contact and exit signal logged.
*Also:* walk test, start/midway/exit, pos1_start

### Exit signal
Area: Testing
A message the canyon sends when the commander reaches its end. Tests check it fires, proving the level can be finished.

### A/B test
Area: Testing
Comparing two versions that differ in exactly one thing (A and B), with everything else identical, so you know what caused the difference. Our scenes often have keys to switch live.
*Also:* A/B, matched captures

### Control
Area: Testing
The unchanged version in an A/B test, used as the reference. A **baseline** is a saved build we compare against.
*Also:* baseline, control scene

### Rubric
Area: Testing
Our checklist of visual goals for the canyon (`docs/HD2D_CHECKLIST_AND_RUBRIC.md`). `[x]` means met, `[~]` partial, `[ ]` not yet.
*Also:* checklist

### Experiment log
Area: Testing
`docs/EXPERIMENT_LOG_AND_LESSONS.md`: every test we ran, what it showed and what failed (the **dead ends**), so nobody repeats them.
*Also:* dead ends, lessons

### Pixel A/B
Area: Testing
The canyon scene that switches surfaces live: **1** realistic, **2** B32 (32 texels per metre, converted), **3** B64 (64 per metre, converted), **4** cycles hand-made pixel sets (`art_*`), **5** cycles smooth sets (`hr_*`).
*Also:* B32, B64, mode 4, mode 5

### Developers Page
Area: Project
The in-game menu listing every playable build and study. Open it from the opening screen; Esc returns. The Studio's **Builds** page reads the same list.
*Also:* build catalog, Builds array

### Milestone UTC
Area: Project
The publication date and time on a Developers Page entry (`YYYY-MM-DD HH:MM`). Older entries use it as their build date when they have no separate build date.
*Also:* milestone

### Build date
Area: Project
The date and time the Developers Page uses to sort builds and choose the opening button. A build can use its recorded **Built UTC** time, its publication date, or the last time its scene file was saved. UTC is the same time reference on every computer.
*Also:* Built UTC

### Play and View
Area: Project
Developers Page actions: **Play** launches a playable scene; **View** shows a static preview.

### Kitbash
Area: Art
Building scenes by combining a library of reusable parts, like Lego. Our RTS desert kitbash is a set of sand, dune, rock and road pieces (`assets/textures/kitbash/`).
*Also:* kitbash library

### Tiles
Area: Art
Small square images laid on a grid to build a map. **Tiled** is a free map editor for this; **Godot TileMap** does the same inside Godot. RTS maps use 32 px tiles so maps, fog and pathfinding scale.
*Also:* tilemap, Tiled, tileset, TileMap

### TileMapLayer
Area: RTS
The Godot node that holds a painted grid of tiles. Select it in the editor and paint with the tile brush. Its **tile set** says which pictures exist and what each one means.
*In Balance:* the `Ground` node in `scenes/maps/rts_test_map.tscn`, using `scenes/rts/rts_placeholder_tiles.tres`.
*Also:* tile set, TileSet

### Custom data
Area: RTS
Extra information stored on each tile in a tile set, like a label on the back of a Lego brick. Our tiles carry a **walkable** yes/no flag, so painting a rock tile automatically blocks units.
*Also:* walkable flag, custom data layer

### Grid
Area: RTS
The map seen as a chessboard of equal squares (tiles). Each square is walkable or blocked, and each unit stands on exactly one. Dune II worked this way.
*Also:* tile grid, cell

### Pathfinding
Area: RTS
Working out the route a unit walks to reach a click, going around rocks instead of through them.
*Also:* routing, path

### A*
Area: RTS
("A-star") The classic pathfinding method: it searches from the start towards the goal, always trying the most promising square first, and returns the shortest route. Godot's **AStarGrid2D** does A* on a grid for us.
*Also:* A-star, AStarGrid2D

### Tile claim
Area: RTS
A unit's reservation of the tile it stands on and the one it is stepping into. A tile has one claim at most, which is why units queue or walk around each other instead of overlapping. F1 in the RTS test map shows claims as white squares.
*Also:* occupancy, reserved tile

### Unit stats
Area: RTS
A small file (`.tres`, a **Resource**) holding one unit type's numbers: health, attack, armour, range, cooldown, guard range, speed and picture. Change the numbers in the Inspector and every unit of that type changes.
*In Balance:* `scenes/rts/units/blue_troop.tres` and its three siblings.
*Also:* UnitStats, unit data

### Armour
Area: RTS
Taken off every hit a unit receives. A hit of 12 against armour 4 does 8 damage; a hit always does at least 1.

### Cooldown
Area: RTS
The waiting time between two attacks of the same unit, in seconds.

### Guard range
Area: RTS
How close an enemy must come before an idle unit goes after it, in tiles. Units always shoot enemies already within their attack range.

### Drag box
Area: RTS
Holding the left mouse button and dragging draws a rectangle; every friendly unit inside it is selected when you let go.
*Also:* box select, rubber band

### Camera2D
Area: RTS
Godot's camera for 2D scenes. It shows a window onto the flat map and can scroll and zoom; it cannot tilt.

### Y-sort
Area: RTS
Drawing things lower on the screen in front of things higher up, so a unit walking below a cliff covers it and one above it is hidden behind it.

### Placeholder art
Area: Art
Simple stand-in graphics (coloured discs, flat tiles) used to test how something plays before the real art exists. They are swapped out later without changing the code.
*Also:* placeholder

### Art pixel
Area: Art
One pixel of the artwork as drawn, before the game enlarges it. In the RTS, one art pixel shows as 2×2 screen pixels at 1920×1080, which gives the chunky pixel-art look.
*In Balance:* `docs/RTS_ART_RULES.md` §1.

### Style test
Area: Art
One screen that contains every kind of art (ground, rocks, road, scatter, units) at the real scale, used to judge the overall look against the reference before making all the art.
*In Balance:* `scenes/maps/rts_style_test.tscn`; **R** lays the reference on top.

### Procedural
Area: Art
Made by a program from rules and random numbers instead of drawn by hand. Good for exact, repeatable things (shapes, shadows, outlines); weaker for rich surfaces, which tend to look machine-made.
*Also:* procedurally generated

### Relief
Area: Art
The rises and dips of a surface. On a flat top-down map, relief is shown only by light: slopes facing the light are brighter, slopes facing away are darker. The reference sand has relief everywhere, not only in its dunes.
*Also:* rolling relief, undulation

### Variation by size
Area: Art
How much the light changes across small, medium and large distances in a picture (for example 1–2, 5–12 and 12–30 pixels). Two pictures can have the same average colour but very different variation; more variation reads as livelier and more "vibrant".
*Also:* band-pass, frequency bands

### Colour matching
Area: Art
Shifting a texture's colours so its average colour and contrast equal a target, here the same material in the reference. It makes textures from different sources look like one picture before the palette is applied.
*Also:* colour transfer, color matching

### Front wall
Area: Art
The side of a cliff or rock that faces the viewer (south), drawn below its top surface. It is what makes a flat top-down map show height.
*Also:* south face, cliff face

### Outline
Area: Art
A one-pixel dark line around a sprite or rock so it separates from the ground. All RTS rocks and units have one.

### Squad
Area: RTS
A small group of soldiers that moves and fights as one unit. In the Mission 1 reference a squad of four fills one 32 px tile.

### Aseprite
Area: Tools
A pixel-art editor for sprites, animations and tiles. *View → Tiled Mode* shows a texture repeating so you can fix seams.

### Krita
Area: Tools
A free painting program. We keep layered texture masters in it (`.kra` files in `assets/textures/source/`).

### Trellis
Area: Tools
An AI image-to-3D generator. We turned images into boulders with TRELLIS.2 (Hugging Face) and trellis3d.net, then cleaned them in Blender.
*Also:* TRELLIS.2, image-to-3D

### Perchance
Area: Tools
A free online AI pixel-art image generator (`perchance.org/ai-pixel-art-generator`), one of the two we use for textures with ChatGPT.

### Coding agent
Area: Workflow
An AI that edits the project directly: **Claude Code**, **Codex** and **Antigravity** (Gemini). All of them read `AGENTS.md` first.
*Also:* agent, Claude Code, Codex, Antigravity

### AGENTS.md
Area: Workflow
The single instruction file every coding agent reads: how the project is built, the working rules and the next steps. `CLAUDE.md` and `GEMINI.md` only point to it.

### Commit
Area: Workflow
A saved snapshot of the project in Git with a message. **Push** uploads commits to GitHub (`spyrostrimis/balance5`). Each commit has a short id like `70f01c4`.
*Also:* push, git, commit hash

### Vertical slice
Area: Production
A small but complete piece of the game, playable from start to end with real-quality systems: here, RTS Mission 1. It proves the game works before building the rest.

### Prototype
Area: Production
A quick rough version made to test an idea. Throwaway code is fine in a prototype.

### RTS
Area: Game
Real-time strategy: you command armies from above in real time (Dune II, Command & Conquer, Warcraft). Balance's main mode.
*Also:* real-time strategy

### RPG sequence
Area: Game
Balance's walking and fighting interludes: the commander walks through HD-2D places such as the canyon, and fights *Streets of Rage 4* style (free movement in depth, facing left or right only).
*Also:* RPG, RPG canyon

### HUD
Area: Game
Heads-up display: the on-screen interface. The RTS HUD has a top bar, minimap, unit card, command buttons (Move, Attack, Hold, Mend) and an objective panel.
*Also:* UI, interface

### Minimap
Area: Game
A small overview map in a corner of the HUD showing the whole battlefield and unit positions.

### Fog of war
Area: Game
Hiding the parts of the map your units cannot currently see.

### Control point
Area: Game
An area you must hold to win or gain something. In Mission 1 it is the area around the central Orichalcum rock: hold it uncontested for a short time to win.
*Also:* hold timer, capture point

### Field commander
Area: Game
A hero unit leading a side's troops on the map, with special abilities. Blue's is the Blue Commander (ability: **Mend**, healing).
*Also:* commander, hero unit, Blue Commander

### Mend
Area: Game
The Blue Commander's first active ability: healing nearby units. Fits Blue's protect-and-repair style.

### Orichalcum
Area: Game
Balance's only resource: a scarce crystal mined from rock formations that pays for every army.

### Harvester
Area: Game
The unit that mines Orichalcum: drives as a truck, transforms into a humanoid robot at a deposit, mines, transforms back and returns to the refinery.
*Also:* refinery

### Storyboard briefing
Area: Game
Illustrated story panels between missions, as in Dune II's mentat briefings: a character portrait beside a framed picture, with text.
*Also:* briefing, storyboard, mentat
