# Decisions

What we decided, when and why, newest first. Balance Studio shows this file on its **Decisions** page. Open questions live in `docs/GAME_DESIGN.md` §9 and in the roadmap.

**For agents:** add an entry when the owner accepts or rejects a direction, or when a test settles a question. Use the format below. **Status** is *Decided*, *Trying* (provisional, being tested) or *Reversed* (say what replaced it). Do not delete reversed decisions; they stop us repeating mistakes.

```
### YYYY-MM-DD · Short title
Area: Game | RTS | Canyon | Art | Tech | Workflow · Status: Decided | Trying | Reversed
Why, in one to three sentences. Where the evidence is.
```

### 2026-11-20 · RTS art scale: 1 art pixel = 2 screen pixels at 1080p
Area: Art · Status: Trying
Measured from the Mission 1 reference: soldiers about 11 art pixels tall, a squad of four or a tank per 32 px tile, the camera at zoom 4/3 in our 1280×720 viewport (960×540 art pixels on screen). The style test matched the reference's sizes one to one. Details: `docs/RTS_ART_RULES.md` §1.

### 2026-11-20 · One 48-colour desert palette for all RTS art
Area: Art · Status: Trying
Clustered from the reference by `tools/python/rts_palette.py`. The reference redrawn with only these colours loses nothing visible. Every layer is mapped onto it last, so pieces from different sources belong to one picture.

### 2026-11-20 · Style test 2 confirms the hybrid RTS art method
Area: Art · Status: Trying
With the owner's ChatGPT textures, colour-matched to the reference and shrunk to art scale, sand, road and rock tops came close to the reference; cliffs show walls; the Orichalcum rock reads as a raised pile. Large dune fields and crystals stay tool-made: the painted dunes and crystal images lose their shape when shrunk. Remaining gaps are tuning. Evidence: `docs/RTS_ART_RULES.md` §6b, `render_captures/rts_style/t2_*`.

### 2026-11-20 · RTS art: our tools make shapes, painted textures make surfaces
Area: Art · Status: Trying
Style test 1 (procedural only) got scale, palette, height (front walls, down-right shadows) and unit contrast right, but its dunes, rock tops and road look machine-made. Next: painted textures from ChatGPT for the surfaces, shaped, shaded and palette-mapped by our tools. Evidence: `docs/RTS_ART_RULES.md` §6, `render_captures/rts_style/`.

### 2026-11-20 · Feature the newest build or study
Area: Workflow · Status: Decided
The opening button follows the newest available build or study by build date. The Developers Page starts in date order and allows local title and description edits and a saved drag order.

### 2026-11-20 · RTS is 2D top-down; height is drawn into the art
Area: RTS · Status: Decided
The battlefield is a flat 2D map seen from above, like Dune II. Rocks, cliffs and dunes get their height from the art (lit tops, visible front walls, cast shadows), with the light from the top-left for every tile and sprite. 2D keeps selection, pathfinding and the HUD simple; the 3D canyon stays separate.

### 2026-11-20 · 32 px tile grid with A* pathfinding, one unit per tile
Area: RTS · Status: Decided
Each 32 px tile is walkable or blocked (a "walkable" flag on the tile), and Godot's AStarGrid2D finds routes around rocks. A unit claims its tile, so units never stack. A grid fits the tiles, fog of war, the control area and the minimap better than a navmesh. Evidence: `tests/test_rts_test_map.gd`.

### 2026-11-20 · RTS unit numbers live in UnitStats files
Area: RTS · Status: Decided
Each unit type is a `.tres` file in `scenes/rts/units/` (health, attack, armour, range, cooldown, guard range, speed, sprite) that the owner can edit in the Inspector. Damage per hit is attack minus armour, at least 1. All numbers are placeholders until balancing.

### 2026-11-20 · First RTS test uses placeholder discs and tiles
Area: RTS · Status: Decided
The owner chose plain team-coloured discs and flat placeholder tiles over the kitbash art for step 1, so the test is about controls, not looks. Real sprites plug in through each unit file's sprite field.

### 2026-11-20 · Idle units engage enemies within guard range
Area: RTS · Status: Trying
Without it, Red troops stood still while their neighbour was shot. Idle units shoot what is in range, chase enemies within their guard range (4–6 tiles), and hit back at whoever shoots them. A later Hold command will turn chasing off.

### 2026-11-20 · Painted sources, pixels made by us
Area: Art · Status: Trying
B64 looked more real than every AI "pixel art" set because it starts from a detailed painted image and makes the pixels itself (64 texels per metre, one palette from the goal image). From now on, generators make detailed painted textures, and `pixel_snap.py --painted` makes the pixels. Evidence: experiment log §15.

### 2026-11-20 · Pack models wear our canyon material
Area: Art · Status: Trying
Free-pack shapes (craftpix low-poly mountains) fit the canyon once they use `canyon_rock.tres`; photo-scan textures look realistic and clash with the painted style. Packs without a found licence stay local and uncommitted. Evidence: experiment log §14d.

### 2026-11-20 · ChatGPT over Perchance for surface textures
Area: Art · Status: Trying
ChatGPT's strata is the first wall that reads as layered rock without bricks, and its cobble reads as a road; Perchance is not on a pixel grid and its strata looks lumpy and purple. The owner still finds every cobble version flat, so the next test is raised (3D) stones. Evidence: experiment log §14c.

### 2026-11-19 · Repository docs are the project's memory
Area: Workflow · Status: Decided
Story, plan, decisions, pipelines and the dictionary live as Markdown in `docs/`, so every agent reads and updates the same files and Balance Studio shows them in one place. Chat histories in Antigravity, Codex and Claude Code are not a record.

### 2026-11-19 · Gemini is out as a texture generator
Area: Art · Status: Decided
Its pixel grids were clean but it drew cliffs as brickwork and cobbles as brick rows. ChatGPT and Perchance remain. Evidence: experiment log §14b.

### 2026-11-19 · Test hand-made pixel sets with two procedures
Area: Art · Status: Trying
Converting existing art to pixels made the frame crunchier but not Octopath-like. The deciding test is designed pixel art at about 64 texels per metre, run through both pixel snap (key 4) and the smooth procedure (key 5). Evidence: experiment log §14.

### 2026-11-19 · Nothing is hard-locked
Area: Workflow · Status: Decided
Camera, sun, route, fog, focus and landmark timing are tunable. Change one on purpose, with matched before/after captures, and update the rubric. A `[x]` guards against accidental regressions only.

### 2026-11-19 · Canyon v2 replaces the inherited test chain
Area: Canyon · Status: Decided
One flat scene driven by an editable route and a placement list replaced six levels of scene inheritance that were fragile to change. The old scenes stay as frozen comparison baselines.

### 2026-11-19 · Physics walls instead of a position clamp
Area: Tech · Status: Decided
Canyon v2 keeps the commander in with a collision corridor and bakes a navmesh, which later units can use for pathfinding.

### 2026-11-19 · Steeper camera, backlit sun, no global fog
Area: Canyon · Status: Trying
−21° pitch at (0, 5.5, 11.9) hides the sky like the RPG goal; the sun moved ahead-right so the right wall shades the road; global fog washed the view to beige and is off. Evidence: experiment log §11.

### 2026-11-19 · The RTS comes first
Area: Game · Status: Decided
Balance is a Dune II tribute. The RPG canyon, HD-2D look and 3D work are extras; if they fail, the RTS alone is the game. Spend short time on the RTS.

### 2026-11-19 · Mission 1 has no base building
Area: RTS · Status: Decided
"The First Claim" teaches selection, movement, attack, the commander ability and control points with four troops plus a commander per side. Base building comes after the tactical foundation.

### 2026-11-19 · Build RTS maps from tiles
Area: RTS · Status: Decided
Maps are assembled from tiles (the kitbash and Tiled work), not single painted images, so maps, fog of war and pathfinding scale.

### 2026-11-19 · RPG fights follow Streets of Rage 4
Area: Game · Status: Decided
Free movement in depth, facing and shooting left or right only. Story beats use Dune II-style storyboard briefings.

### 2026-11-19 · Everything shipped is original or licensed
Area: Game · Status: Decided
Reference games are inspiration only. Record the source and licence of any bought or downloaded asset next to it. Third-party screenshots stay out of the repository.

### 2026-11-18 · Native camera depth of field for focus
Area: Canyon · Status: Decided
Real camera DOF (sharp about 10–16.5 m, amount 0.014) replaced the older screen-height blur: boots and nearby paving stay sharp together. One blur method per capture. Evidence: experiment log §6.

### 2026-11-18 · ChatGPT image road is the best road
Area: Art · Status: Decided
The 1024 px ChatGPT cobble at 3.2 m per repeat kept natural chips, varied stone colours and sand. Procedural roads looked drawn. Evidence: experiment log §10.

### 2026-11-18 · TRELLIS.2 boulders with the shared sandstone material
Area: Art · Status: Decided
The Hugging Face TRELLIS.2 mesh had the better silhouette; the shared ChatGPT sandstone material made both AI boulders match the walls. Evidence: experiment log, AI boulder rows.

### 2026-11-18 · Real 3D walls, not painted cards
Area: Canyon · Status: Decided
Blocky stepped 3D terraces from Blender, textured with fine horizontal strata, give real depth and shadows. Painted cards, projected concept art and cone or rubble shapes all failed. Evidence: experiment log §1 (dead ends).

### 2026-11-18 · Vertex-colour flags only as 0 or 1
Area: Tech · Status: Decided
Blender stores vertex colour as sRGB, so 0.5 arrives in Godot as about 0.21. Binary values survive the conversion.

### 2026-11-16 · Godot 4.7.2 with Forward+
Area: Tech · Status: Decided
The engine and renderer for the whole project, with Git and GitHub (`spyrostrimis/balance5`).
