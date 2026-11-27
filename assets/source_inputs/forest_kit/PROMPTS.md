# Forest kit — ChatGPT Images prompts

Paintings for the forest kit of **RTS Mission 1 – Forest** (`scenes/rts/forest_kit/`). Save each result **as the exact file name given**, in this folder:

`D:\Games\Balance5\assets\source_inputs\forest_kit\`

Download the full-size PNG from ChatGPT (not a screenshot). The reference images to attach are in `refs\`. Until a painting arrives, the game uses a stand-in drawn by `tools/python/make_forest_kit.py`; when you save a painting, ask an agent to run that tool again and it swaps your painting in.

## Read this first: camera and scale (same for every prompt)

Every painting must match **Carbon's camera**, the one the desert mission uses (`refs\ref_camera_scale_desert_mission.png`):

- **Near-overhead.** Almost straight down, about 70° from the horizon. You see the tops of things: crowns of trees, tops of rocks. Only a thin sliver of the south (front) side shows. No horizon, no vanishing point, no isometric diamond grid.
- **Light from the upper left.** Tops and faces turned up-left are lit. Shadows fall **down and to the right**.
- **Scale.** One map square ("cell") is the width of the desert road, or one squad of four soldiers (`refs\ref_unit_lineup.png`). A single tree crown is about **2 cells** across; a soldier is about a fifth of a cell tall.
- **Style.** Detailed warm digital painting, like the desert pieces and the forest reference. **Not pixel art**, no black outlines, no text, no labels, no grid.
- **Palette.** The forest reference (`refs\ref_forest_goal_full.png`): sunny yellow-green grass, dark teal conifers, rounder yellow-green and emerald broadleaf crowns, warm ochre dirt, grey gravel, clear blue river with pale ripples.

The older forest studies (Forest Claim, Forest Fight) were painted at a low isometric angle. Do not attach them: they pull ChatGPT back to that angle.

---

## 1 · Grass ground — `grass_tile.png`

**Attach:** `refs\ref_forest_goal_full.png`, `refs\ref_camera_scale_desert_mission.png`

> A **seamless, tileable** square ground texture of short sunny meadow grass, seen from straight above, for a top-down strategy game. It must tile with no visible seams on all four sides. Fine grass blades about the size of a pinhead at this scale, gentle patches of lighter yellow-green and deeper green spread over the whole square, a few tiny clover leaves, no flowers, no stones, no paths, no shadows of objects. Even lighting, warm sunny afternoon, colours like the open grass in image 1. Detailed painting, not pixel art. 1024 × 1024.

## 2 · Dirt road — `dirt_road_strip.png`

**Attach:** `refs\ref_forest_goal_clearing.png`, `refs\ref_camera_scale_desert_mission.png`

> A **straight horizontal** packed-dirt road segment seen from straight above, for a top-down strategy game. The road runs left to right across the whole image and must **tile seamlessly left-to-right**. Warm ochre earth with faint wheel ruts, small pebbles and a few footprints; the edges break up into a soft fringe of grass tufts. Above and below the road the background is **fully transparent**. The road fills the middle half of the image's height. Same colours as the dirt in image 1, same painted style as the road in image 2. 1536 × 384.

## 3 · Dirt clearings — `dirt_clearings.png`

**Attach:** `refs\ref_forest_goal_clearing.png`, `refs\ref_camera_scale_desert_mission.png`

> Three separate patches of bare packed earth seen from straight above, for a top-down strategy game, on a **fully transparent background** with clear space between them:
> 1. (left, the largest, about half the image) a broad **oval clearing** of trampled ochre earth, like the ground around the glowing rock in image 1, but **without the rock**: the middle is plain earth where a rock will be placed. Soft ragged edges that fade into grass tufts.
> 2. (top right) a smaller round dirt patch.
> 3. (bottom right) a smaller long dirt patch.
>
> No objects, no trees, no stones bigger than a pebble. Warm earth colours from image 1, light from the upper left. Detailed painting, not pixel art. 1536 × 1024.

## 4 · Gravel pads — `gravel_pads.png`

**Attach:** `refs\ref_forest_goal_blue_base.png`, `refs\ref_forest_goal_gravel_se.png`

> Two separate flat areas of grey crushed gravel seen from straight above, for a top-down strategy game, on a **fully transparent background**:
> 1. (left) a roughly rectangular **base pad** with rounded corners, where a headquarters and a landing pad will stand (like the grey area under the base in image 1, but empty).
> 2. (right) an irregular **gravel field** with a few scattered fist-sized stones, like the empty grey field in image 2.
>
> Soft broken edges that fade into grass, a few weeds poking through. No buildings, no vehicles, no markings. Light from the upper left. Detailed painting, not pixel art. 1536 × 1024.

## 5 · Tree clusters — `tree_clusters.png`

**Attach:** `refs\ref_forest_goal_tree_masses.png`, `refs\ref_carbon_tree_scale.png`, `refs\ref_camera_scale_desert_mission.png`

> Three separate **clumps of forest seen from almost straight above**, for a top-down strategy game, on a **fully transparent background** with clear space between them:
> 1. (left, largest) a big clump of about 25 trees, roughly oval, wider than tall.
> 2. (top right) a medium clump of about 12 trees.
> 3. (bottom right) a small clump of about 6 trees.
>
> Mix **dark teal pointed conifers** (star-shaped from above) and **rounder yellow-green and emerald broadleaf crowns**, packed closely so the crowns overlap, like the forest in image 1. Each crown about the size of the tree in image 2. Lit from the upper left: bright crown tops on the upper-left side, deep shade between crowns and on the lower-right side. The clump edges are irregular, made of whole crowns, never cut straight. Only a few trunk bases peek out at the bottom edge. **No ground, no grass, no cast shadow on the ground** (the game draws shadows). Detailed painting, not pixel art. 1536 × 1024.

## 6 · Single trees and forest edge — `trees_single_and_verge.png`

**Attach:** `refs\ref_forest_goal_tree_masses.png`, `refs\ref_carbon_tree_scale.png`

> On a **fully transparent background**, seen from almost straight above for a top-down strategy game, with clear space between them:
> 1. (top left) one **dark teal conifer**, star-shaped crown from above.
> 2. (top middle) one **round broadleaf tree**, yellow-green crown.
> 3. (top right) one **tall emerald broadleaf** with a slightly larger crown.
> 4. (bottom, full width) a long low **forest-edge strip**: a row of bushes, ferns and young saplings, about a quarter the height of the image, irregular on both long sides, meant to sit along the edge of a forest so the trees don't end in a hard line.
>
> Same light (upper left), same scale and colours as image 1. No ground, no cast shadows. Detailed painting, not pixel art. 1536 × 1024.

## 7 · River — `river_strip.png`

**Attach:** `refs\ref_forest_goal_river_nw.png`, `refs\ref_camera_scale_desert_mission.png`

> A **straight horizontal** stretch of a small forest river seen from straight above, for a top-down strategy game. The river runs left to right across the whole image and must **tile seamlessly left-to-right**. Clear blue water with pale ripple highlights and darker depth in the middle; muddy ochre banks with a lip of grass tufts and a few reeds on both sides. The water fills the middle half of the height, the banks the next eighth on each side, and beyond the banks the background is **fully transparent**. Colours like the river in image 1. No bridge, no rocks in the water. Detailed painting, not pixel art. 1536 × 512.

## 8 · River crossings — `river_crossings.png`

**Attach:** `refs\ref_forest_goal_river_nw.png`, your saved `river_strip.png`

> Two separate river-crossing pieces seen from straight above, for a top-down strategy game, each drawn over a **short horizontal stretch of the same river as image 2**, on a **fully transparent background**:
> 1. (left) a **shallow ford**: a broad bar of pale gravel and flat stepping stones running top to bottom across the water, with the water rippling around it, wide enough for a small tank.
> 2. (right) a **wooden plank bridge** running top to bottom across the water, with a simple rail on each side and the plank ends resting on the banks.
>
> Both pieces about as tall as the river is wide plus its banks. Light from the upper left, shadows to the lower right. Detailed painting, not pixel art. 1536 × 1024.

## 9 · Boulders, log and ground details — `rocks_logs_details.png`

**Attach:** `refs\ref_forest_goal_full.png`, `refs\ref_camera_scale_desert_mission.png`

> Separate small pieces seen from almost straight above, for a top-down strategy game, on a **fully transparent background** with clear space between them:
> - top row: a **large mossy boulder**, a **pair of mossy boulders**, a **low mossy rock slab** (grey stone, green moss on the upper-left tops, lit from the upper left);
> - middle row: a **fallen mossy log** lying left to right, and a short **tree stump**;
> - bottom row: three **ground details** that lie flat on grass: a patch of small white and yellow flowers, a scatter of small stones, a patch of ferns.
>
> Each boulder about one cell (a squad of four soldiers) across, the log about three cells long. No ground under them, no cast shadows. Detailed painting, not pixel art. 1536 × 1024.

---

## After you save them

Ask any agent:

```powershell
C:/Python312/python.exe tools/python/make_forest_kit.py
```

It cuts every painting into kit pieces in `assets/textures/rts/forest_kit/` (Detailed `_hd.png` and Pixel `_pixel.png`), keeps whatever you haven't painted yet as a stand-in, and prints which pieces came from your paintings. Then run `tests/test_rts_mission_1_forest.gd` and look at the forest with **F1** to check the blocked ground still matches the trees.

**If a painting comes back at the low isometric angle**, reply in the same chat:

> Much more top-down, please: look almost straight down like the soldiers in the reference. Show the tops of the trees, not their trunks or sides.
