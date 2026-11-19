# Roadmap

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
- [ ] Desert tileset with height drawn in: cliff walls, curving road edges, shaded dunes (light from the top-left)
- [ ] Mission 1 desert map (Red's version) built from tiles
- [ ] Mission 1 tropical forest map (Blue's version) from the same layout
- [ ] Fog of war

## Next — RPG canyon (secondary)

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
