# Roadmap

## RPG canyon direction comparison

- [ ] Build Approach 3 from the tested standing pose, then verify the commander in motion and the painted bend through to its exit. [Assessment, visual proof and Sol handoff](CANYON_APPROACH_3_HANDOFF.md)
- [x] Build and export **3D Canyon · Sculpted Bend**. Verify the round trip, both road heights, both vistas and all three landmark rocks. [Study and evidence](CANYON_SCULPTED_BEND.md)
- [x] Match Sculpted Bend's camera to 2D Parallel-Projection Canyon · Approach 1 vs 2 and verify the original view on C. [Matched camera evidence](CANYON_SCULPTED_BEND.md#parallel-projection-camera)
- [ ] Owner compares Sculpted Bend with Painted Bend and Approach 2 Modular and chooses the RPG direction.

What we are building, in order. The RTS comes first (`docs/GAME_DESIGN.md` §1). Balance Studio shows this file on its **Plan** page and can tick the boxes.

**For agents:** tick an item (`- [x]`) when it is verified, not when it is started. Add new items under the right heading when work turns up. Keep each item one line, written so the owner understands it.

## Now — RTS Mission 1, "The First Claim"

The first playable vertical slice: four troops plus a field commander per side fight over the Orichalcum rock in the centre of the map (`docs/GAME_DESIGN.md` §5).

### Units and control
- [x] A Blue tank that drives on the desert map with obstacle collision
- [x] Choose the battlefield foundation: grid or navmesh, and the tile size (32 px grid, A*)
- [x] Click to select a unit, drag a box to select several (RTS test map)
- [x] Right-click to move; units path around rocks without overlapping
- [x] Attack: units fire at enemies in range and take damage
- [x] Four Blue troops and the Blue Commander on the map (placeholder discs)
- [x] Four Red troops and the Red Commander on the map (placeholder discs)
- [ ] Real unit sprites replace the placeholder discs
- [ ] First balance pass on unit numbers (Red's melee troops currently beat Blue)

### Mission rules
- [ ] Control area around the central Orichalcum rock with a hold timer
- [ ] Win by holding the rock uncontested, or by eliminating the enemy
- [ ] Lose when Blue is eliminated or Red holds the rock
- [ ] Blue Commander ability: Mend (heal nearby units)

### Opponent and interface
- [ ] Simple Red AI: advance, contest the rock, attack in range
- [ ] HUD top bar: logo, mission name, Orichalcum, squad count, objective timer, Menu
- [ ] Minimap
- [ ] Selected-unit card and the Move / Attack / Hold / Mend buttons
- [ ] Objective panel with progress bar ("Hold the Orichalcum rock")

### Maps
- [x] Modular desert kitbash library and a playable mini-map
- [x] RTS art rules (scale, 48-colour palette, light) and style test 1 with every layer (`docs/RTS_ART_RULES.md`)
- [x] Style test 2: painted sand, dune, rock-top, cliff-wall and road textures (art rules §6b)
- [x] Style test 3: sand that rises and falls everywhere, soft rock edges, crystals2, kitbash scatter (art rules §6c)
- [x] Style test 4: orderly dunes in fields towards the edges, calm round road and plaza, sparser scatter, lighter rock tops (art rules §6d)
- [x] Style test 5: dunes2 ripples turned to the wind inside test 4's fields; cliff ledges (art rules §6e). Environment look settled
- [x] Units on the style-test map: shadows, ground light, tracks, footprints and dust, each switchable (art rules §8)
- [x] Build playable **RTS Reusable 2 Carbon** (`scenes/maps/rts_reusable_2_carbon.tscn`) from reusable ChatGPT landmarks, dune clusters, limestone road, stone outposts, 4-soldier squads, commanders, 8-facing tanks, Mend healing, Orichalcum hold timer and Dune II HUD, with live `V` Detailed Painted / `960×540` Pixel and `Z` `21×14` / `15×10` zoom comparison ([Study](RTS_REUSABLE_2_CARBON.md))
- [ ] Owner compares RTS Reusable 2 Carbon alongside Codex's desert proof and chooses the RTS art and zoom direction
- [ ] Smooth unit movement: any-angle routes, vehicles turn gradually, curved tracks
- [ ] Real unit sprites: 8 facings and walk frames for squads, commanders and vehicles
- [ ] Big map pieces (whole cliff formations, dune fields, the Orichalcum rock) as placeable scenes with their blocked tiles, for laying out maps by hand
- [ ] Decide: is a troop a squad of four soldiers?
- [ ] Desert tileset with height drawn in: cliff walls, curving road edges, shaded dunes (light from the top-left)
- [ ] Mission 1 desert map (Red's version) built from tiles
- [ ] Mission 1 tropical forest map (Blue's version) from the same layout
- [ ] Fog of war

## Next — RPG canyon (secondary)

- [x] Parallel-projection 2D RPG canyon A/B study comparing Approach 1 (Continuous Uncut 2D Artwork) and Approach 2 (Modular Stitched 2D Kit) with locked follow camera, constant hero scale, 192 colours, Laigter normals, and 960×540 / 640×360 toggle (`scenes/rpg_2d/canyon_orthographic_study.tscn`)
- [x] Two-room 2D Pixel Canyon art study with matched 1080p reference, walk and foreground crossing, horizontal shot, and two-way room transition. [Study and recording](PIXEL_CANYON_STUDY.md)
- [x] Compare the first room with the original scale, calibrated depth and a small uphill camera follow. [Playable comparison and captures](PIXEL_CANYON_CAMERA_STUDY.md)
- [x] Verify the two-way walk, scout fight and follow camera on one road. The moving cutout scenery failed visual review. [Through the Bend findings](PIXEL_CANYON_FOLLOW_STUDY.md)
- [x] Verify Session B's connected 2D bend, near-wall overlap, fixed-size arch reveal and return past the same step. [Recorded comparison](PIXEL_CANYON_SESSION_B.md)
- [x] Compare three ChatGPT paintings on Session B and verify a fitted, playable art pass. [Painted Bend](PIXEL_CANYON_SESSION_B_PAINTED.md)
- [ ] Review the Painted Bend overlook beside the original painting before choosing a visual master for future canyon maps.
- [ ] Choose how to build one connected bend and overlook that hold together while the camera travels both ways. [Methods to compare](PIXEL_CANYON_FOLLOW_STUDY.md#options-for-the-next-comparison)
- [ ] Choose the first room's scale and framing after reviewing the camera and depth study.
- [ ] Review the 2D study's motion and adjoining view before choosing an RPG art workflow.

Plan agreed 2026-11-20: Phase 0 lock the look → 1 build `scenes/rpg/canyon_01.tscn` → 2 make it playable (walk, landmark, optional fight, briefing, hand-off to Mission 1) → 3 atmosphere and sound → 4 ship as a Play build.

- [x] Phase 0: why B64 looked best (painted source + shared palette) and `pixel_snap.py --painted`
- [x] Phase 0: owner prefers B64 and art_gpt, without raised stones (2026-11-21)
- [x] 3D kit step 1: real curb blocks along the road (`canyon_v3_kit.tscn`, key K, §17)
- [x] 3D kit step 2: new road and sand tiles, darker sand by the curbs (key N, §20)
- [x] Goal colours: five colour ramps from the goal image repaint every kit piece (key M, §21)
- [ ] Owner verdict on the goal-colour look; exit dunes and sky in the same colours
- [x] 3D kit step 3: pixel bushes and grass on the sand strip, wall foot and ledges (key B, §19)
- [x] 3D kit step 4, first pass: stepped sandstone cliffs from ChatGPT block outlines (key W, §18)
- [x] 3D kit step 4, second pass: darker, purple shade, fewer larger blocks, strata faces, rubble (§18b)
- [x] Cliffs moved out to 2.7 m: an open sand strip between curbs and cliffs (§18c)
- [ ] Cliffs: owner verdict; possible third pass (taller faces, sand terraces)
- [x] Audit and catalog all 61 downloaded 3D canyon assets with visual contact sheets, ratings and cleanup guide ([CANYON_ASSET_CATALOG.md](CANYON_ASSET_CATALOG.md))
- [x] Build and verify **3D Canyon · Way 1B Free 3D Modules** (`scenes/maps/canyon_way1b_free_3d.tscn`, §22) combining Namaqualand cliffs, Rock Face 01/02, Rock 07 & Boulder 03 curbs, Namaqualand Stones 01 & Moon Rock 04 3D cobbles, Cheiridopsis Succulents, Sand Rocks Small 01, Mountain 009 Arch and Canyon River Terrain with the kept Trellis boulders and white Grand Canyon rock ([Study](CANYON_WAY1B_FREE_3D.md))
- [x] Build and verify **3D Kit Canyon · v2** (`scenes/maps/canyon_v3_kit_v2.tscn`, §23): clean option-free playable study with `img1` cobbles, `art_gemini` sand, `art_road_goal` organic cliffs, `<= 32` colours per object, uniform `64 texels/m` unscaled seamless tiling, flush non-intersecting rocks, and `4× MSAA` + sharp-pixel anti-aliasing
- [ ] Compare the 3D canyon studies (Way 1B Free 3D Modules, Sculpted Bend, 3D Kit Canyon · v2) with the 2D canyons and decide the RPG direction

The HD-2D walking sequence. If it fails, the RTS alone is the game.

- [x] Flat, route-driven canyon v2 with collision corridor and navmesh
- [x] Pixel A/B scene to compare surface styles (keys 1–5)
- [ ] Review and accept canyon v2 as the RPG baseline
- [x] Compare ChatGPT and Perchance sets through both procedures (ChatGPT ahead, §14c)
- [x] Test raised 3D cobbles along the whole road (A/B key R; reads as raised, about 0.7 ms GPU, §14d)
- [x] Try free packs in the canyon (craftpix mountains fit with our rock material; photo scans clash, §14d)
- [ ] Decide the surface style (flat vs raised cobbles, pixel vs smooth)
- [ ] If raised stones are kept: strip only where the camera sees, coarser far away, commander follows the stones
- [ ] Dedicated right-wall modules instead of turned left courses
- [ ] Fix the slate cap material, bush scale and exit vista
- [ ] Atmosphere: a local FogVolume with light shafts at a wall opening, measured for GPU cost
- [ ] RPG fight test in the Streets of Rage 4 style (free depth, face left or right)

## Story and presentation

- [x] Feature the newest build on the opening screen and add date sorting, drag order and text editing to the Developers Page
- [x] Game design document: world, characters, factions, Mission 1 (`docs/GAME_DESIGN.md`)
- [ ] Name the main characters, planets and factions
- [ ] Decide who the Red Commander is
- [ ] First storyboard briefing before Mission 1
- [ ] Decide how RPG sequences and briefings connect to campaign missions

## Later

- [ ] Base building, refinery and production
- [ ] Harvester that drives, transforms and mines
- [ ] Orichalcum economy tuning (rate, renewal, deposit size)
- [ ] Wandering creatures as hazards
- [ ] Green and Palatinate mini-campaigns
- [ ] Music and sound
