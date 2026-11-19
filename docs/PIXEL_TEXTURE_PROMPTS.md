# Pixel texture prompt pack — HD-2D A/B, modes 4 and 5

Goal: test whether **designed surfaces** on the canyon v2 blocks reach the Octopath-style look (experiment log §14), and which **processing procedure** serves them better. The ChatGPT → image → game pipeline stays the same as for the ChatGPT cobbles and sandstone. Each image can go through two tools:

| Procedure | Tool | Output sets | A/B key | What it does |
| --- | --- | --- | --- | --- |
| **Pixel snap** | `tools/python/pixel_snap.py` | `art*` | **4** | Finds the drawn pixel grid, keeps one colour per pixel, nearest filtering at 64 texels per metre. |
| **Smooth (Antigravity's)** | `tools/python/smooth_texture.py` | `hr*` | **5** | Keeps the image at 1024 px, cross-fades the edges so it tiles, builds normal and ORM maps from the height image, linear filtering. The same procedure made the ChatGPT road and the boulder sandstone you see in mode 1. |

Generators tested so far: **ChatGPT** and **Perchance** (`perchance.org/ai-pixel-art-generator`, free). Gemini's image generator is out: its pixel grids were clean, but the content came out as cartoon brickwork (§14b in the log).

## Workflow

1. Generate the image for a role with ChatGPT or Perchance (prompts below). For ChatGPT, also ask for the matching **height map** (see *Height maps*).
2. Run both procedures. Give each generator its own set name, so the sets sit side by side:
   ```powershell
   C:/Python312/python.exe tools/python/pixel_snap.py strata "C:\path\gpt_strata.png" --height "C:\path\gpt_strata_height.png" --set art_gpt
   ```
   ```powershell
   C:/Python312/python.exe tools/python/smooth_texture.py strata "C:\path\gpt_strata.png" --height "C:\path\gpt_strata_height.png" --set hr_gpt
   ```
   Use `art_perchance` and `hr_perchance` for Perchance images (no `--height`). `smooth_texture.py` covers the same metres as the pixel version of the same image, so the procedure is the only difference.
3. Read the console:
   - `Grid fit` should be above 85%. Below that the image is not pixel art on a grid, and the snap is only a resample. Regenerate, or use the smooth procedure only.
   - `one repeat covers ... m (intended about ...)`. A warning here means stones and beds will appear larger or smaller than designed, because the generator chose its own grid (Gemini always drew 100 or 200 cells). Check the 3×3 preview, or regenerate.
   - `Height alignment` should be well above +0.30.
   - A seam ratio above about 1.5 means the repeat will show. Fix the edges in **Aseprite** (*View → Tiled Mode*), or rely on the smooth procedure's cross-fade.
4. Play **Developers Page → HD-2D Pixel A/B**. **4** cycles the pixel sets (`art_gemini`, `art_gpt`, `art_perchance`, …) and **5** cycles the smooth sets. The label shows which set is active. Roles a set lacks fall back to B64 (key 4) or to the realistic art (key 5), so strata and cobble can be judged alone. Compare against **1** (realistic) and **3** (B64).

Previews go to `tmp/pixel_snap/` and `tmp/smooth_texture/`.

## Density and sizes

The pixel test runs at **64 texels per metre**: 64 texture pixels cover one metre of wall or road. At the spawn camera that is about 2 screen pixels per texel, which reads as crisp pixel art about one step chunkier than the commander (about 170 per metre). The tools map any size at exactly that density, but the *features* in the image (stone size, bed thickness) only look right if the image covers about the intended area:

| Role (tool name) | Painted onto | Aim for (cells) | Covers | View in the image |
| --- | --- | --- | --- | --- |
| `strata` | Terracotta cliff faces | 128 × 64 | 2 m along × 1 m up | Straight-on wall, layers horizontal |
| `slate` | Dark ledge tops and lower courses | 64 × 64 | 1 × 1 m | Straight-on / top-down |
| `cobble` | The road | 192 × 192 | 3 × 3 m | Top-down |
| `sand` | Sand verges beside the road | 128 × 128 | 2 × 2 m | Top-down |
| `dune` | Open desert past the exit | 128 × 128 | 2 × 2 m | Top-down |
| `boulder` | Small ochre boulder clusters | 64 × 64 | 1 × 1 m | Straight-on |
| `ai_boulder` | The two Trellis boulders | 96 × 96 | 1.5 × 1.5 m | Straight-on |
| `bush_sage`, `bush_cluster` | Bush sprites | about 60 × 50 | about 0.9 m wide | Side view, isolated |

Image models do not count pixels reliably. Ask for the size, then let the tool measure what you got. For a cobble image, about **12–15 stones across** the image gives roughly 20–25 cm stones over 3 m.

## Palette guidance

Keep each material to a short ramp of 4–7 colours, from dark joint to lit edge. These ramps come from the canyon goal and the shared A/B palette (`assets/textures/pixel_ab/palette_preview.png`):

| Material | Ramp, dark → light |
| --- | --- |
| Terracotta strata | `#3d2112` `#6b351d` `#8d4327` `#b1572f` `#cf6733` `#df7e2e` `#ea8d31` |
| Sandstone, cobble crowns, sand | `#4c301d` `#784b2d` `#9f7248` `#b4794a` `#ce8e56` `#e6a65f` `#e9bd86` `#ebd3b0` |
| Joints and deep shadow | `#110703` `#1e0a05` `#31150b` `#4c2514` |
| Warm slate (ledge tops) | `#20120a` `#3a2a20` `#54463a` `#6e5f50` `#8a7a68` (suggested) |
| Pale sage (bushes) | `#3c4630` `#56623f` `#76845a` `#9aa67a` `#bcc49c` (suggested) |

To force a whole set onto one palette, pass `--palette some_image.png` to `pixel_snap.py`. The tool then maps every pixel onto that image's colours.

## ChatGPT prompts

The shared rules in every prompt: *flat orthographic view, no perspective, no vignette, no lighting gradient across the image, fills the whole frame edge to edge, no border, no text, seamless tiling*. Octopath-style textures do carry small per-pixel shading. The scene's sun does the large-scale lighting.

> **Fixed after the Gemini round.** The first strata prompt asked for "a lit edge on top of each bed and a dark joint underneath". Every generator read that as bricks and mortar, and the cliffs turned into brick buildings. The strata and cobble prompts now ask for natural rock and forbid bricks, blocks and mortar.

### `strata` — terracotta cliff face (wide image, about 2:1)

> Seamless tileable pixel-art texture of a natural desert canyon cliff face: horizontal sedimentary sandstone layers, as in a red-rock canyon wall. Flat orthographic front view, no perspective, no vignette, no overall lighting gradient. HD-2D / 16-bit JRPG environment style: chunky, uniform, perfectly square pixels on a strict grid, about 128 pixels wide and 64 pixels tall, upscaled with hard edges. The layers are continuous wavy bands of uneven thickness that run across the whole width, pinch out and merge, with eroded soft edges, small overhangs, vertical hairline fractures and a few pits and chips. It is natural weathered rock: no bricks, no blocks, no rectangles, no mortar lines, no masonry. Limited palette of about 14 warm terracotta and rust colours (#3d2112 #6b351d #8d4327 #b1572f #cf6733 #df7e2e #ea8d31) with darker shadow tones (#1e0a05 #31150b) only in cracks and under overhangs. Fills the whole frame, seamless on all four edges, no text, no border.

### `slate` — dark ledge tops

> Seamless tileable pixel-art texture of weathered warm grey-brown flat stone slabs seen from directly above, the flat top surface of canyon ledges. Orthographic top-down view, no perspective, no lighting gradient. Chunky uniform square pixels on a strict grid, about 64 by 64 pixels, upscaled with hard edges. Large irregular slabs with granular grit, a few hairline cracks, darker 1-pixel joints between slabs, subtle lighter speckles. Limited palette of about 10 colours: warm slate #20120a #3a2a20 #54463a #6e5f50 #8a7a68 with a hint of rust #4c2514. Not black, not white, not blue-grey. Fills the frame, seamless on all edges, no text.

### `cobble` — the road

> Seamless tileable pixel-art texture of an old hand-laid sandstone cobblestone road seen from directly above. Orthographic top-down view, no perspective, no lighting gradient. Chunky uniform square pixels on a strict grid, about 192 by 192 pixels, upscaled with hard edges. About 12 to 15 stones across the image. Rounded, irregular, river-worn stones of different sizes and shapes, packed loosely in a random arrangement, each with a bright worn crown and a darker lower rim. Dark sand-filled gaps between stones (#31150b #4c2514), a few chipped or wedge-shaped stones, drifts of sand partly covering some gaps. Not bricks, not hexagons, not rectangles, no straight rows, no regular pattern. Limited palette of about 16 colours: sandstone #784b2d #9f7248 #b4794a #ce8e56 #e6a65f #e9bd86 #ebd3b0 plus the dark gaps. Fills the frame, seamless on all edges, no text.

### `sand` — verge sand

> Seamless tileable pixel-art texture of warm golden desert sand seen from directly above, with very subtle wind ripples, scattered tiny pebbles and a few small darker grains. Orthographic top-down view, no lighting gradient. Chunky uniform square pixels on a strict grid, about 128 by 128 pixels, upscaled with hard edges. Low contrast so it does not compete with the road. Limited palette of about 8 colours: #9f7248 #b4794a #ce8e56 #e6a65f #e9bd86 #ebd3b0. Seamless on all edges, no text.

### `dune` — open desert

Same as `sand`, with broader, softer ripple bands and no pebbles.

### `boulder` and `ai_boulder` — rock surface

> Seamless tileable pixel-art texture of fractured warm sandstone rock surface, straight-on orthographic view, no perspective, no lighting gradient. Chunky uniform square pixels on a strict grid, about 96 by 96 pixels, upscaled with hard edges. Angular fracture planes, horizontal bedding lines, 1-pixel lit edges on fractures, dark crack joints, warm ochre crowns. Limited palette of about 12 colours: #6b351d #8d4327 #b1572f #cf6733 #e6a65f #e9bd86 with joints #31150b #4c2514. Seamless on all edges, no text.

### `bush_sage` / `bush_cluster` — sprite

> Pixel-art sprite of a small pale sage-green desert shrub with silvery-green leaves and a few thin woody stems, side view as in a 16-bit JRPG, isolated on a flat solid magenta background (#ff00ff), centred, nothing else in the image. Chunky uniform square pixels on a strict grid, the shrub about 60 pixels wide and 50 pixels tall, upscaled with hard edges. Limited palette of about 10 colours: sage #3c4630 #56623f #76845a #9aa67a #bcc49c and stems #4c301d #784b2d. Light from the upper right: lighter leaf tips on the right, darker clusters at the base. No shadow on the ground, no outline glow.

Snap it with the default `--key auto`, which keys out the corner colour. Sage green is too close to a green-screen background, so use magenta.

### Optional painted variant (smooth procedure only)

Antigravity's procedure was built for painted, not pixel, images. To test it on its home ground, reuse a prompt with the pixel-art sentence ("Chunky uniform square pixels … hard edges") replaced by *"Hand-painted stylised game texture, crisp detail, 1024 × 1024"*. Run only `smooth_texture.py` on it; `pixel_snap.py` will report a low grid fit, as it should.

## Height maps

A height map is a grey image of the same picture: white is raised, black is deep. It is not used as a colour. It drives the **normal map** (how the sun catches each stone's edge) and, for cobbles and boulders, the **ORM map** (dark cavities in the joints). Without one, both tools guess the relief from brightness, which treats a dark stone as a hole and a bright crack as a ridge.

Worth making for **cobble** and **strata** with ChatGPT: in the same chat, right after the texture, ask

> Now make the matching height map of exactly this image, as an edit of it: the same composition, pixel for pixel, same size. Greyscale only: white = highest stone crowns, mid grey = stone sides and rock faces, black = deepest gaps and cracks. No colour, no lighting, no shading from the sun, no texture other than height.

and pass it with `--height`. The tools print an alignment score: Gemini's heights scored +0.90 to +0.96 except one slate height from a different generation (+0.06), which would have been rejected. Perchance cannot edit an image, so it has no height maps. Its images run on brightness alone, which is a fair handicap to note when comparing.

Height maps matter far more in the smooth procedure (1024 px of relief detail) than in the pixel one (one height per pixel).

## Perchance prompts

Perchance (`perchance.org/ai-pixel-art-generator`) produces real pixel art: the bush tests had chunky pixels on a consistent grid. Set **Art Style: Pixel Art**. Use **Shape: Landscape** for strata and **Square** for the rest. Shorter descriptions work better there, and the separate **Anti-Description** box takes the things to avoid.

| Role | Description | Anti-Description |
| --- | --- | --- |
| `strata` | seamless tileable texture, flat front view of a natural red-rock desert canyon cliff face, horizontal wavy sandstone layers of uneven thickness, eroded edges, hairline cracks, warm terracotta and rust colours, 16-bit JRPG pixel art, flat even lighting, fills the whole frame | bricks, blocks, masonry, mortar, wall, rectangles, perspective, sky, horizon, border, text, vignette, shadow gradient |
| `cobble` | seamless tileable texture, top-down view of an old sandstone cobblestone road, rounded irregular river stones of different sizes in a random arrangement, sand in the gaps, warm beige and ochre colours, 16-bit JRPG pixel art, flat even lighting, fills the whole frame | bricks, hexagons, tiles, straight rows, grid pattern, grass, perspective, horizon, border, text, vignette |
| `bush_sage` | small pale dusty sage-green desert shrub, silvery leaves, thin woody stems, side view, 16-bit JRPG pixel art sprite, isolated on a flat solid magenta background | lush, bright green, flowers, ground, pot, shadow, text, border |

Perchance's backgrounds come out muted purple rather than pure magenta, and the default `--key auto` handles that. Its first bushes were lush green: the description above asks for dusty sage.

## Acceptance check (by eye, in the A/B scene)

- Walls read as **natural rock**, not brickwork, and the road reads as **cobbles**, not a pavement.
- Pixels read as one consistent grid across walls, road and bushes (pixel sets). Nothing smears and nothing looks noisy.
- Walls, road and commander look like one game. The commander is not pasted on top.
- From spawn, midway and exit the repeat of any texture is not obvious.
- Compared with mode 1 (realistic), it's closer to the Octopath reference in spirit.
- For each image: is it better as pixels (4) or smooth (5)?

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Grid fit` below 85% | The image is painted, not pixel art on a grid. Regenerate stressing "uniform square pixels on a strict grid", or use the smooth procedure only. |
| Cell count far too small (for example 16 × 11 instead of about 128 × 64) | The detector locked onto a multiple. Measure one drawn pixel in an image viewer and pass `--cell 7.5` (source pixels per drawn pixel). |
| Scale warning, stones or beds far too large or small | The generator drew a different number of cells than asked. Regenerate, or accept it after checking the 3×3 preview. |
| Height alignment below +0.30 | The height image is from a different generation. Ask for it as an edit of the exact image, or drop `--height`. |
| Wall or road looks stretched | You used `--non-square` on art with square pixels. Drop the flag. |
| Too many colours or noisy | `--colors 12`, or `--palette` with a palette image. |
| Bush has a coloured fringe | Raise `--key-threshold` (default 70), or regenerate on a flatter background. |
| Visible repeat | Fix the edges in Aseprite's tiled mode, keep large features away from the edges, or compare with the smooth procedure, which cross-fades the edges. |

`tests/test_pixel_snap.py` checks the pixel tool on synthetic "AI pixel art" (non-integer scale, blur, JPEG, noise), a painted image (must be flagged) and a height map: run `C:/Python312/python.exe tests/test_pixel_snap.py`.
