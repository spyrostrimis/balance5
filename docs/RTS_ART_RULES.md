# RTS art rules

The rules every RTS tile, texture and sprite follows, so the battlefield reads as one picture. The target is `docs/references/rts_mission1_desert_red.webp` (and the HUD version `rts_mission1_hud_goal.webp`). Status: **Trying** (set 2026-11-20 from measurements of the reference and the first style test). Change a rule on purpose, with a before/after capture, and record it in `docs/DECISIONS.md`.

## 1. Scale

| Rule | Value | How it was measured |
| --- | --- | --- |
| Art pixel | 1 art pixel = 2 pixels of the 1308 px reference = **2 screen pixels at 1920×1080** | Soldiers, tanks and stone sizes in the reference halve cleanly. |
| Camera | Zoom **4/3** in our 1280×720 viewport (shows 960×540 art pixels) | 1080p gives exactly 2 screen pixels per art pixel; 4K gives 4. At 720p pixels are uneven (1.33); 1440p gives 2.67. |
| Tile (game grid) | **32 art pixels** | One reference road width, one tank, one squad of four soldiers. A screen shows 30×17 tiles. |
| Soldier | about **7×11** art pixels plus a 1 px outline | Reference soldiers are about 22 px tall. |
| Squad | four soldiers inside one 32 px tile | The reference card reads "Squad 4 of 4". |
| Commander | about **9×13** plus outline | A little larger than a soldier, with a pale scarf (Blue) or gold trim (Red). |
| Tank | about **30×20** | The Balance4 blue tank halved. |
| Cliff front wall | **8–11** art pixels tall; low rocks **4–5** | Visible south faces in the reference. |

The **art does not have to follow the tile grid**. Pathfinding uses 32 px tiles; ground, dunes, rocks and road are drawn as large shapes and textures so no grid shows.

## 2. Palette

- **48 colours** in `assets/textures/rts/palette_desert.json` (swatches: `palette_desert.png`), clustered from the reference by `tools/python/rts_palette.py`. Redrawn with only these colours, the reference loses nothing visible (`render_captures/rts_style/reference_palette_check.png`).
- Every layer is mapped onto the palette as the last step, so all pieces belong to the same picture. The forest map will get its own palette, made the same way from `rts_mission1_forest_blue.webp`.
- Measured materials: sand (228, 135, 40), dune crest (255, 196, 71), dune trough (169, 84, 22), road (210, 160, 117), rock top (92, 72, 62), cliff wall (96, 60, 32).

## 3. Light

- **From the top-left, a little above.** In tools: direction (−0.5, −0.7, 0.75) with x right, y down, z towards the viewer.
- Tops and slopes facing up-left are lit. Faces pointing down-right are dark. Cliffs show their **south (front) wall**.
- Cast shadows fall **down-right**: offset (5, 4) art pixels for cliffs, (3, 3) for low rocks, a small ellipse under each unit.
- Rocks and units get a **1 px dark outline** (34, 24, 20).

## 4. Layers, bottom to top

1. **Sand**: large seamless ground, fine grain and swirls, gentle tone changes over hundreds of pixels.
2. **Dunes**: ripple fields laid over the sand, with flat sand between them.
3. **Road**: flagstone path and the plaza round the Orichalcum rock, soft edges, a dotted ring of marker stones.
4. **Rocks**: cliffs and mesas with top, front wall, outline and cast shadow; the Orichalcum rock with crystals and a gravel skirt.
5. **Scatter**: pebbles, scrub, small stones, each with a tiny shadow.
6. **Units**: sorted by height on screen (Y-sort) so lower units cover higher ones.
7. **Effects and HUD**.

## 5. How art is made

- **Shapes, walls, shadows, outlines and the palette**: our tools (`tools/python/make_rts_style_test.py`). They are exact, repeatable and follow the rules above.
- **Surface detail** (sand grain, rock tops, flagstones, dune patterns): **detailed painted textures** from an image generator, reduced to art pixels and mapped onto the palette by our tools. Do not ask generators for "pixel art": in the canyon tests, AI pixel art looked fake, and painted sources made pixel-sized by us looked real (`docs/EXPERIMENT_LOG_AND_LESSONS.md` §15).
- **Units**: drawn or generated per unit, 8 directions, outlined, on the shared palette (later step).
- **Hand tools.** Scripts make and measure the pieces, because every test must be exactly repeatable. Hand tools come in where a person's eye works better:
  - **Tiled** or Godot's tile painter, to lay out the real Mission 1 map from the pieces (the kitbash example in `assets/textures/source/tiled/` already does this).
  - **Krita**, to paint fixes onto a texture or a whole map.
  - **Aseprite**, to clean up unit sprites pixel by pixel.

  The tools can export layers in formats these programs open (`.ora`, `.tmx`).

## 6. Style test 1 (2026-11-20): what the rules give with procedural surfaces only

`scenes/maps/rts_style_test.tscn` (Developers Page → Desert RTS builds → RTS Style Test). Keys: **1** dunes, **2** road, **3** rocks, **4** scatter, **5** units, **R** reference on top at the same scale, **G** tile grid, **Z** zoom. Captures: `render_captures/rts_style/style_test.png`, `style_reference.png`.

**Right already:**
- **Scale.** Squads, the tank and the road width match the reference one to one.
- **Palette and warmth.**
- **Height.** Front walls and down-right shadows lift the cliffs off the sand, which the flat kitbash mini-map never did.
- **Unit contrast.** Blue reads strongly on sand. Red reads less strongly, as in the reference.

**Gaps, largest first:**
1. **Dunes.** Ours are long, even, continuous lines. The reference has short, broken crests in layered fields, with brighter, grainier sand.
2. **Rock tops.** Ours read as paving (even polygon slabs). The reference has fine crack networks, lumps and jagged ledges along the rim.
3. **Road.** Our stones are too contrasty. The reference has large flat flagstones with faint joints.
4. **Orichalcum rock.** Ours is a flat oval. The reference is jagged and taller, with clustered glowing crystals.

**Verdict:** the procedural method is right for structure: shapes, walls, shadows, outlines, palette and scale. It is weak for surfaces. Next: replace the four surfaces with painted textures (prompts below), keep everything else, and compare again.

## 6b. Style test 2 (2026-11-20): painted surfaces plus tool fixes

Same scene; **T** switches between test 1 and test 2. Inputs: the owner's eight ChatGPT images in `assets/source_inputs/rts/` (prompts in §7). Captures: `render_captures/rts_style/style_test.png`, `t2_side_by_side.png`, close-ups `t2_cmp_*.png`.

**How each surface is made now:**

| Surface | Source | Shrink (source px per art px) | Then |
| --- | --- | --- | --- |
| Sand | `sand.png` | 3.2 (grain ≈ 1 art px) | Colour-matched to the reference sand, tiled, gentle large-scale tone changes. |
| Dune fields | tool | n/a | Ripples 15 px apart. Each one has a lit face that brightens up to a sharp crest, then a dark lee face just below it that slowly recovers. Crests break off and fork. Fields with flat sand between. |
| Small ripple packs | `dunes.png` | 1 (ripples ≈ 13 px apart, like the reference) | Only the crests are traced, plus a short shadow under each. Shrunk further, its ripples became blobs. |
| Rock tops | `rock_top.png` + `rock_top_height.png` | 5.5 (slabs ≈ 60 art px) | Colour-matched; relit gently from the top-left using the height map; cracks from the height map darkened to near-black. |
| Cliff walls | `cliff_wall.png` | 9 (columns ≈ 7–10 art px) | Colour-matched to a lighter brown than the tops, sampled by depth, a lit lip at the top, a slightly jagged foot, loose stones below. |
| Road | `road.png` + `road_height.png` | 10 (plates ≈ 25 art px) | Colour-matched; hairline cracks from the height map, drawn faint; sand blown over the edges; light marker stones. |
| Orichalcum rock | `rock_top.png`, `cliff_wall.png` | as above | A pile of slabs, each raised 2–9 px (highest in the middle) with its own darker front face, drawn back to front. |
| Crystals | tool | n/a | 55 small faceted crystals lit top-left, densest in the middle, warm glow. The painted `crystals.png` became an orange smear at 44 px. It may suit a portrait or icon later. |

**Better than test 1:**
- **Sand** has the reference's grain.
- **Road** is now close to the reference: pale plates with faint cracks.
- **Rock tops** look like real rock rather than paving.
- **Cliff walls** are visible.
- **Dunes** read as waves with volume.
- **The Orichalcum rock** reads as a raised pile with crystals.

**Remaining gaps, largest first:**
1. **Dune fields.** They are long sweeping arcs. The reference has more, shorter rows with deeper shadows and more variety between fields.
2. **Rock outlines.** Ours are a hard black line. The reference has a softer dark edge plus a contact shadow, so ours look more cartoon-like.
3. **Orichalcum rock.** Its crystals are smaller and dimmer than the reference's, and the slab faces show only faintly.
4. **Scatter.** The reference has more pebbles and green scrub.
5. **Rock-top bumps.** The reference's evenly spread small bumps are fewer and larger in ours.

**Verdict:** the hybrid method works. Painted textures give the surfaces; our tools give shape, light and the palette. The remaining gaps are tuning, not method.

## 6c. Style test 3 (2026-11-20): the sand's constant rise and fall

**T** now cycles tests 1, 2 and 3. Captures: `render_captures/rts_style/style_test.png`, `t3_side_by_side.png`, `t3_cmp_*.png`.

**What the owner saw, measured.** In the reference, sand looks like it constantly rises and dips, with ever-changing colour, and seems more vibrant. Measured on the sand of each image at art scale:

| | Brightness | Saturation | Light change at 1–2 px | 2–5 px | 5–12 px | 12–30 px | Colour variety |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reference | 223 | 202 | 8.4 | 9.4 | 7.3 | 8.0 | 2.0 |
| Test 2 | 223 | 207 | 7.9 | 6.5 | 3.1 | 1.9 | 1.4 |
| Test 3 | 223 | 206 | 5.6 | 8.4 | 6.6 | 5.5 | 1.7 |

The average brightness and saturation were already equal. "Vibrant" came from **variation**: the reference changes light 2–4 times more over medium and large distances, and its colour wanders more. Lesson: compare variation, not averages.

**What changed in test 3:**
- **Ground:** the owner's `dunes2.png`, a dense ripple field (shrink 2.3, ripples ≈ 15 art px apart), contrast-matched to the whole reference sand. It is bent by smooth offsets so the rows curve and repeats hide. `sand.png`'s fine grain is mixed back in.
- **Rolling relief** over the whole desert, lit from the top-left, plus slow drifts between redder and yellower sand.
- **Dune fields:** a few bigger ones with deeper shadows, kept near the ground ripples' direction (crossing them looked crosshatched).
- **Cliff walls:** `cliff_wall2.png`, with warm brown columns.
- **Crystals:** `crystals2.png`, with fewer and bigger crystals. Shrunk to 66 px, its crystals survive; only the bright ones are kept, with a glow.
- **Rock edges:** soft. A lit rim faces the top-left and a darkened (not black) edge faces down-right, replacing the black outline.
- **Scatter:** pebbles, specks and shrubs from the Desert Kitbash Mini-Map (`assets/textures/kitbash/`). Pebbles are at 60% (at full size they read as dark cannonballs), shrubs at 75%.

**Remaining gaps:**
1. **Large-scale variation:** 5.5 against 8.0. Fine grain: 5.6 against 8.4.
2. **Rock tops:** slightly too dark and even.
3. **The Orichalcum rock:** fewer crystals than the reference.
4. **The NE cliff:** reads as one large flat mass where the reference has more ledges and an oasis.

These are tuning, not method.

## 6d. Style test 4 (2026-11-20): orderly dunes

**T** cycles tests 1–4. Captures: `render_captures/rts_style/style_test.png`, `t4_side_by_side.png`, `t4_cmp_*.png`.

**What the owner saw.** Test 3 looked messy, with things thrown around, while the reference feels peaceful and orderly. Around the centre the reference has no dunes; they fill fields towards the four edges.

**Why test 3 looked messy (looking, not just measuring):**
- Measured averaged over the whole image, test 3's ripples were as aligned as the reference's (0.90 against 0.83), with similar overall variation. The numbers missed where the ripples are and how crisp they are.
- Close up, test 3's ripples were soft, smeared swells under round relief blotches. The reference's crests are crisp, evenly spaced, gently waving rows.
- The scatter was big, dark and evenly sprinkled. The reference's is small and sparse.

**Lesson:** measurements check a look; they do not replace looking at close-ups side by side.

**What changed in test 4:**
- **Placement:** calm sand in a band about 45–105 art px round the road and plaza; dune fields towards the edges, with a few calm gaps.
- **Ripples:** tool-made, 17 px apart. A broad lit face rises to a sharp crest, a sharp dark shadow below it fades out, then plain sand.
- **Rows:** long and following one wind (about −10°, turning slowly across the map). They wave gently along their length, about every 80 px, with neighbouring rows waving together. A first try without the wave looked combed; a first try with thin crests was too faint.
- **Swells:** stretched along the wind instead of round blotches.
- **Scatter:** kitbash pebbles at 45%, shrubs at 50%, about half as many, gathered near rocks and the road.
- **Rocks:** tops 15% lighter; `crystals2` larger (78 px), plus small crystals round it.

**Verdict:**
- **Order and placement** now follow the reference.
- **It is a little too graphic:**
  - Crest edges are slightly stair-stepped and the rows too continuous; they read a little like map contour lines.
  - Large-scale light variation fell (3.0 against the reference's 8.0, test 3 had 5.5).
- **The reference sits between tests 3 and 4:** test 4's order and placement, test 3's softer, more varied ripples. Next (test 5): `dunes2.png` turned to the wind, used only inside test 4's fields, with test 4's crisp shadows.
- **Still open:** NE cliff ledges.

## 6e. Style test 5 (2026-11-20): soft, orderly dunes and cliff ledges — environment look settled

**T** cycles tests 1–5. Captures: `render_captures/rts_style/style_test.png`, `t5_side_by_side.png`, `t5_cmp_*.png`.

**What changed:**
- **Ripples:** the owner's `dunes2.png` (shrink 2.4), read along the wind, so its soft natural ripples turn with the wind and neighbouring rows wave together. Only its light and shade are used, on top of test 4's sand, swells and colour drift.
- **Placement:** inside test 4's fields only. Calm sand stays within about 40–90 art px of the road and plaza; dune fields cover most of the rest. A first pass with a stricter mask left only two small fields.
- **Cliffs:** big cliffs (wall 11 px or more) get a raised inner terrace 7 px higher, with its own wall and a shadow cast down-right onto the lower level.

**Verdict:**
- Test 5 combines test 4's calm centre and orderly wind with test 3's softer, more natural ripples, and is the closest to the reference.
- Its ripples are a little bolder than the reference's.
- **The owner is confident the reference's environment look is achievable** and will refine maps by hand later. The style tests stop here; next is how the units look moving on this map.

**Recipe to keep (used by test 5):**
- **Sand:** `sand.png` grain, swells stretched along the wind, colour drift.
- **Ripples:** `dunes2.png` along the wind, in fields away from the road.
- **Road:** `road.png` with cracks from its height map.
- **Rocks:** `rock_top.png` ×1.15 with cracks from its height map; walls from `cliff_wall2.png`; soft lit and dark edges; terraces on big cliffs.
- **Orichalcum rock:** a stepped slab pile with `crystals2.png`.
- **Scatter:** kitbash pebbles, specks and shrubs, gathered near rocks and the road.
- **Finally:** the 48-colour palette.

## 7. Texture prompts (ChatGPT, one image each, 1024×1024 unless noted)

Rewritten after the close-up comparison (§6): each prompt names what the reference has and style test 1 lacked.

**Where to save.** `assets/source_inputs/rts/` (Godot ignores this folder; Git keeps the originals), with these exact names: `sand.png`, `dunes.png`, `rock_top.png` + `rock_top_height.png`, `cliff_wall.png`, `road.png` + `road_height.png`, `crystals.png`. Second versions keep the name with a 2 (`dunes2.png`, `cliff_wall2.png`, `crystals2.png`); test 3 uses those. Download the full-size image, not a screenshot. Seams and exact size do not matter; the tools fix both.

**Start every chat with:** "I need game textures for a top-down 2D strategy game. Every image: seen from directly above (no perspective, no horizon), detailed digital painting with fine grain in every pixel, NOT pixel art, no outlines, no text, no vignette, warm light from the top-left, square 1024x1024."

1. **Sand**: "Seamless tileable texture of fine orange desert sand. Dense grain everywhere: tiny bright yellow sparkles and darker specks at the scale of single grains, faint small swirls. Flat ground: no ripples, no dunes, no stones, no plants. Even brightness across the image."
2. **Dune ripples**: "Orange desert sand with packs of small wind ripples. Each ripple is a thin, sharp, bright yellow crest catching light from the top-left, with a short narrow dark shadow just below it. The ripples are short and curved; they break off, fork and split, and are stacked in rows of 4 to 8. Flat grainy sand between the packs and at the image edges. No objects."
3. **Rock plateau top**: "Seamless tileable texture of the flat top of a dark brown-grey basalt plateau. A few large slabs separated by long, mostly straight, deep near-black cracks. Gritty, rough surface with small rounded lumps and loose pebbles. Lit from the top-left, strong contrast." Then: "Now the matching greyscale height map of the same image: white high, black low, the cracks black."
4. **Cliff wall** (ask for 2048x512): "Horizontally seamless strip of a dark basalt cliff face seen from the front: tall vertical columns and broken ledges, deep vertical cracks, darker towards the bottom, the bottom edge jagged and broken with loose rubble. Lit from the top-left."
5. **Road**: "Seamless tileable texture of a pale grey-beige stone road seen from above: large flat smooth stone plates, like dried mud plates, separated by thin faint hairline cracks with a little orange sand in them. Low contrast, soft, no cobbles, no bricks." Then: "Now the matching greyscale height map: white high, black low, the cracks dark."
6. **Crystals** (optional, for the Orichalcum rock): "A dense cluster of small glowing gold and amber crystals growing from dark rock, seen from above, bright yellow-white highlights and a soft warm glow, on a plain flat black background."

**Throw an image away and regenerate if** it shows perspective or a horizon, objects that were not asked for, cartoon outlines, a pixel-art look, text or a frame, or one side much darker than the other. Two or three tries per image is normal; keep the best.

## 8. Units on the map (2026-11-20): do they look grounded?

**Scene:** `scenes/maps/rts_units_test.tscn` (Developers Page → RTS Units Test), built by `tools/python/make_rts_units_test.py` on the style test 5 map. It has stand-in squads and commanders, and the Balance4 tank (8 facings, plus a Red copy).

**Controls:**
- **P:** units patrol peacefully.
- **K:** shadows. **L:** ground light. **M:** tracks and footprints. **N:** dust.
- **F1:** shows blocked tiles.

Cliffs, mesas and the Orichalcum rock are blocked (`assets/textures/rts/units_test/walk_mask.png`, one pixel per tile). Captures: `render_captures/rts_units/*_on.png` / `*_off.png` (the same moment), and `zoom_*_off_vs_on.png`.

**Grounding cues (each on its own key):**
- **Shadow:** a soft shadow down-right, matching the rocks' light, plus a darker contact patch right at the base.
- **Ground light:** each unit is lit or shaded by the sand under it (`ground_light.png`, 128 = average), including the shadows cast by rocks.
- **Marks:** tank tracks every 3 px, fading over 8 s; footprints every 5 px, fading over 5 s.
- **Dust:** small puffs behind moving vehicles.

**Findings:**
- **With all cues off, units look like stickers floating over the sand.** Nothing ties them to the ground. With shadow and contact patch they sit on it; tracks and dust make vehicles look heavy and moving through sand. Shadow and tracks matter most. Ground light is subtle at this size.
- **The dunes do not make units look like they fly.** Seen from straight above, the ground's relief is only light and shade, and a unit crossing a ripple keeps the same height on screen, as in the reference. Grounding cues are what matter, not following the ripples.
- **The most unnatural thing now is movement, not drawing.**
  - Units walk the 32 px grid, so routes are straight lines with sharp 90° and 45° corners, and a tank turns on the spot. The tracks make this obvious: L-shaped, ruler-straight lines.
  - Next: smooth routes (go straight at any angle where nothing blocks the way), let vehicles turn gradually, and curve the tracks.
- **The stand-in sprites slide.** The squad picture has no walking frames and only mirrors left/right; the tank has 8 facings and track frames.
  - Real units need 8 facings and walk frames (art rules §1 sizes).
  - Footprints at 1 px are barely visible; real soldiers can leave a pair per step.

## 9. Units in Motion (2026-11-24)

The successor compares Painted HD and 960 × 540 Pixel art live on V. Both use the same battlefield layout and unit sizes. A 640 × 360 still shows where rifle, scarf and diagonal barrel details begin to drop out. The new battle motions are available in both looks. [Playable route, source art and matched captures](RTS_UNITS_IN_MOTION.md)

## Open questions

- **Is a "troop" a squad of four soldiers?** The reference card ("Squad 4 of 4") suggests so, and four soldiers fill one tile. The RTS test map still treats a troop as one disc.
- The forest map's palette and materials come after the desert look is accepted.
