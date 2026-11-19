# Decisions

What we decided, when and why, newest first. Balance Studio shows this file on its **Decisions** page. Open questions live in `docs/GAME_DESIGN.md` §9 and in the roadmap.

**For agents:** add an entry when the owner accepts or rejects a direction, or when a test settles a question. Use the format below. **Status** is *Decided*, *Trying* (provisional, being tested) or *Reversed* (say what replaced it). Do not delete reversed decisions; they stop us repeating mistakes.

```
### YYYY-MM-DD · Short title
Area: Game | RTS | Canyon | Art | Tech | Workflow · Status: Decided | Trying | Reversed
Why, in one to three sentences. Where the evidence is.
```

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
