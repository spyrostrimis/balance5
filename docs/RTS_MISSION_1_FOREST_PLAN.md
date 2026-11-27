# RTS Mission 1 – Forest: plan and session prompt

Blue's first mission, *The First Claim*, on a tropical forest planet. It is the mirror of **RTS Mission 1 – Desert** (Red's): same units, buildings, Orichalcum rock, HUD, rules and camera, with a new **forest kit** for the map. Reference goal: [`references/rts_mission1_forest_blue.webp`](references/rts_mission1_forest_blue.webp). Paste the prompt below into a new session. **Built 2026-11-27 with stand-in art:** [RTS_MISSION_1_FOREST.md](RTS_MISSION_1_FOREST.md).

---

## Session prompt

> **Build RTS Mission 1 – Forest for Balance**
>
> Work in `D:\Games\Balance5` on `main`. Create **RTS Mission 1 – Forest**, Blue's first mission, as a new playable scene built the way **RTS Mission 1 – Desert** is built. Add it to the Developers Page (section *Forest RTS builds*), export it, and verify Play and Esc in the Windows export.
>
> **Read first:** `AGENTS.md`, `docs/GAME_DESIGN.md`, `docs/RTS_ART_RULES.md`, `docs/RTS_MISSION_1_DESERT.md` (how the desert map, kit, planet skins, HUD styles and hills work), `docs/PIPELINES.md` (*Make or change an RTS map from the desert kit*, *Add a planet skin*), and the decisions of 2026-11-27 in `docs/DECISIONS.md`. Look at the reference goal `docs/references/rts_mission1_forest_blue.webp` and at the desert map running (`scenes/maps/rts_mission_1_desert.tscn`, captures in `render_captures/rts_mission_1/`).
>
> **What stays the same as the desert.** Use `RtsMissionBattlefield` and `RtsMissionHud` unchanged where possible (all four HUD styles, Mockup E default). Keep Carbon's camera, Command and Close zooms, 44 × 28 cells of 32 px, Detailed/Pixel switch, selection, orders, combat, Mend, hold timer, tank tracks, minimap and canopy fade. Use the same Blue and Red units (`assets/textures/rts/desert_kit/` unit sheets and portraits), the Orichalcum outcrop, outpost pads and the Blue Field HQ from `scenes/rts/desert_kit/pieces/`. The player commands **Blue**. Keep the encounter numbers from the desert map. Balancing is a separate experiment.
>
> **What is new: a forest kit.** Make `scenes/rts/forest_kit/` (pieces, groups, kit preview) and `assets/textures/rts/forest_kit/`, the same way as the desert kit: one scene per painted piece, carrying its Detailed and Pixel art, [blocked footprint](GLOSSARY.md#blocked-footprint), shadow, lee shade, relief and `tags` metadata. Every piece must appear in the Kit Palette dock. Pieces to cover the reference:
> - **Ground:** a seamless grass tile (the map's base, in place of sand) and a dirt road strip for the paths. Treat these as the forest's ground and road art; the battlefield already loads `sand_tile` and `road_strip` from the art folders. Add dirt clearing patches (the plaza around the Orichalcum and smaller patches), gravel pads (Blue's base pad and the empty field to the south-east), and small grass details (flowers, stones) as flat ground decals.
> - **Forest masses:** several tree-cluster pieces at different sizes (dark conifers and broadleaf mixed), each blocking only its trunks' core, plus single trees for edges. Canopies overhang their blocked ground and fade over selected troops like the desert's oasis tree. Add a forest-edge or verge piece so clusters don't end in hard cut-outs.
> - **River:** a river that crosses the north-west corner and blocks movement, with banks and at least one ford or bridge where infantry and the tank can cross. It may be a chain of water pieces or a new path-following piece. Whatever you choose, the visible water and the blocked ground must agree, and bending it must not mean repainting it.
> - **Rocks and logs:** a few mossy boulders and a fallen log for cover and silhouette.
>
> **More room than the reference.** In the reference the units are boxed in by trees. Keep the reference's composition, with the river NW, Blue's base SW, Red's approach from the E, the central Orichalcum clearing and the gravel field SE, but make the playable ground open. Forests should frame the map and form a few flanking woods, not corridors. Main lanes at least **4 cells** wide, every route the tank needs at least **3 cells**, and a central clearing big enough for both sides' full forces to fight around the plaza. Check this with F1 and a scripted path test for the tank and a squad on each route.
>
> **Art method.** Use original HD painted art at **Carbon's camera** (near-overhead, upper-left sun, same scale as the desert units and pieces). The older forest studies (`assets/textures/rts/forest_claim/`, `forest_carbon/`, Forest Fight) use an isometric camera, so treat their art as stand-ins or palette references only. First write ChatGPT Images prompts for every missing painting into `assets/source_inputs/forest_kit/PROMPTS.md`, with exact file names and the reference images to attach (stage `refs/` with a desert-mission capture for camera and scale, a crop of the forest reference, and a unit lineup). Tell me which folder to save them in, then stop and wait for me. While I generate them, build the map and mechanics with stand-in art. Then cut the paintings into kit pieces with a Python tool, keep sources and prompts with the project, and swap them in.
>
> **Engine changes allowed** (keep the desert and the older builds unchanged, and switch new behaviour on per scene): per-piece minimap colour (forest blocks should be dark green on the minimap, not rock brown), a river/water piece that blocks along its shape, and anything the forest needs in `RtsMissionBattlefield`. Don't copy the battlefield into a new script. If the desert map needs the same feature later, it should be a switch, not a fork.
>
> **Checks and evidence.** Write `tests/test_rts_mission_1_forest.gd` like the desert test: every placed piece comes from a kit; blocked ground matches the visible pieces; lane widths; tank and squad routes on each path; the ford works and the river blocks elsewhere; canopy fade; Mend; hold; reset; all HUD styles keep scale and take clicks; Developers Page Play and Esc. Run it headless and at **1920 × 1080 fullscreen** Forward+ with captures (opening, each lane, the ford, Blue's base, the plaza fight, Pixel), plus a 12-second moving clip with both sides crossing the map. Run the desert and older RTS checks too. Look at every image before reporting.
>
> **Project memory.** Write `docs/RTS_MISSION_1_FOREST.md` (how to play, how to edit, the kit, the evidence), and update `ROADMAP`, `DECISIONS`, `PIPELINES`, `GLOSSARY`, the rubric and the experiment log. Leave art approval to me. Commit and push to `main` when done, staging only your own files.
>
> When you finish, tell me where to click, show me the opening and a lane capture, and tell me which file to open to move my first forest piece.

---

## Why this order

1. **Prompts first, then build with stand-ins.** Painting takes the owner's time; mechanics (river blocking, lanes, minimap colours) don't need final art.
2. **Same battlefield, new kit.** The desert proved that a kit plus `RtsMissionBattlefield` makes maps without new code. The forest should only add what a forest needs: river, tree masses and minimap colours.
3. **Space before beauty.** Lane widths are checked by test, so the reference's crowded feel can't creep back while dressing the map.

## Open questions for the owner

- **Planet name** for Blue's forest world (`docs/GAME_DESIGN.md` lists planet names as open).
- **Bridge or ford?** A wooden bridge adds a landmark; a shallow ford keeps the river natural. The prompt asks for at least one crossing; either works.
