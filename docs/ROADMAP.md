# Roadmap

## Painted tropical forest study

- [x] Build and export **2D Painted Forest Fight 4** with a fixed isometric camera, continuous two-way doorway and three-bat encounter. Verify full-circle fire in both settings. [Play and captures](FOREST_FIGHT_4.md)
- [ ] Owner plays Fight 4 and judges the feel of the continuous forest-to-cave view.

- [x] Walk the forest into a painted cave and clear three bats in the **2D Painted Forest Fight** Play card. Verify the mode change, rifle directions, depth lanes, replay and Esc. [Live sequence and framing](EXPERIMENT_LOG_AND_LESSONS.md#2d-painted-forest-fight--2026-11-25)
- [ ] Owner plays 2D Painted Forest Fight and reviews the doorway transition and combat framing.

- [x] Build the four-stretch Blue Commander walk, verify both directions and add it to Developers Page under **Forest builds**. [Playable study and evidence](../assets/scenes/forest_test/REPORT.md)
- [ ] Owner chooses one of the three paintings and judges how clearly the four stretches read with guides hidden. [Candidates and recording](../assets/scenes/forest_test/REPORT.md) · [Independent assessment](../output/pdf/painted-forest-walk-assessment.pdf)

## RPG canyon direction comparison

- [x] Build playable Approach 3 from the tested standing pose and verify the walk, rifle stance and painted bend through to the gate. [Matched captures and recording](CANYON_APPROACH_3_HANDOFF.md#implementation-and-verification)
- [ ] Owner reviews Approach 3’s walking poses and overall look beside both existing studies. [Illustrated comparison](../output/pdf/painted-canyon-approach-3-review.pdf)
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

### Painted forest study
- [x] Build and export both **RTS Isometric — Forest Claim** cards. Verify both tank routes, the minimap orders, camera picks and Play/Esc. [Playable layouts and route evidence](RTS_FOREST_CLAIM.md)
- [ ] Owner reviews Forest Claim beside Fight 4 at command zoom and checks the cliff joins and repeated crowns in play.

### Maps
- [x] Build the painted modular Desert Crossing proof and a matched pixel look. Verify a dune crossing, cliff shade and paired tread lanes at playing size. [Playable proof](RTS_DESERT_CROSSING.md)
- [ ] Owner reviews Desert Crossing and decides whether to extend the modular desert kit or test the whole-map painting in play. [Matched captures and route](RTS_DESERT_CROSSING.md)
- [x] Modular desert kitbash library and a playable mini-map
- [x] RTS art rules (scale, 48-colour palette, light) and style test 1 with every layer (`docs/RTS_ART_RULES.md`)
- [x] Style test 2: painted sand, dune, rock-top, cliff-wall and road textures (art rules §6b)
- [x] Style test 3: sand that rises and falls everywhere, soft rock edges, crystals2, kitbash scatter (art rules §6c)
- [x] Style test 4: orderly dunes in fields towards the edges, calm round road and plaza, sparser scatter, lighter rock tops (art rules §6d)
- [x] Style test 5: dunes2 ripples turned to the wind inside test 4's fields; cliff ledges (art rules §6e). Environment look settled
- [x] Units on the style-test map: shadows, ground light, tracks, footprints and dust, each switchable (art rules §8)
- [x] Build RTS Units Test — Units on the Map 3 (`scenes/maps/rts_units_test_v3.tscn`) alongside the original RTS Units Test with scene-local `F4` Pixel (1× integer) / HD Painted (2× smooth + NE oasis + crystal glow) switch, `1:1` tank frames (`sprite_scale = 1.0`), 4-faction team-colour mask shader, distance-driven walk/tread cadence and `F3` perf overlay (`tests/test_rts_units_test.gd`)
- [x] Units in Motion study has any-angle travel, gradual tank turns and curved tracks. Tight corner and single-lane traffic checks passed. [Playable study](RTS_UNITS_IN_MOTION.md)
- [x] Compare both factions’ eight-facing squads, commanders and tanks in Painted HD and Pixel art at the same playing size. [Matched captures and motion](RTS_UNITS_IN_MOTION.md#matched-captures)
- [x] Build playable **RTS Reusable 2 Carbon** (`scenes/maps/rts_reusable_2_carbon.tscn`) from reusable ChatGPT landmarks, dune clusters, limestone road, stone outposts, 4-soldier squads, commanders, 8-facing tanks, Mend healing, Orichalcum hold timer and Dune II HUD, with live `V` Detailed Painted / `960×540` Pixel and `Z` `21×14` / `15×10` zoom comparison ([Study](RTS_REUSABLE_2_CARBON.md))
- [x] Build and export **RTS Reusable 2 Carbon — Miasaki** as a separate Play card. Verify the northeast comparison, live Pixel, tank tracks and shade, and the squad route around Orichalcum. [Matched frames and recording](RTS_REUSABLE_2_CARBON_MIASAKI.md)
- [ ] Owner compares Miasaki with original Carbon and Forest Fight 4 at both zoom stops.
- [x] Build and export **RTS Isometric 2— Forest Claim Carbon** (`scenes/maps/rts_isometric_2_forest_claim_carbon.tscn`) in Fight 4's `35.264°` isometric view from a reusable painted forest/cliff/canopy kit across Layouts A and B, verifying 4-corner/cliff picking, canopy fade, tank rerouting, minimap cliff-side orders, Mend, hold timer and catalog loop. [Study, layouts and clip](RTS_ISOMETRIC_2_FOREST_CLAIM_CARBON.md)
- [ ] Owner reviews **RTS Isometric 2— Forest Claim Carbon** (Layouts A and B) alongside Codex's isometric study and judges the painted modular look at Command zoom.
- [x] Owner plays Units in Motion / Desert Crossing and chooses modular Painted HD 2D as the RTS art direction.
- [x] Bring Desert Crossing and Carbon into the main Developers Page. Paint the connected terraces, dune fields and Orichalcum plaza for the Desert Crossing reference pass. [Desert Crossing](RTS_DESERT_CROSSING.md)
- [ ] Compare mission-scale visibility and zoom with the modular painted terrain in play.
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
- [x] RPG fight test in the Streets of Rage 4 style (free depth, face left or right): verified in **2D Painted Forest Fight** (`scenes/rpg_2d/forest_fight.tscn`) and **2D Painted Forest Fight 2** (`scenes/forest_fight_2/forest_fight_2.tscn`, §25)
- [x] Strictly-isometric unified single-mode forest-to-cavern exploration and 360° shooting study: verified in **2D Painted Forest Fight 3** (`scenes/forest_fight_3/forest_fight_3.tscn`, §27) and **2D Painted Forest Fight 4** (`scenes/forest_fight_4/forest_fight_4.tscn`, §26)

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
