# Reference & HD-2D Style Bible

---

## 1. How Our Target Compares Across Reference Games

| Game / Reference | Core Scene Technique | Movement Axis | Why It Looks Like It Does |
| :--- | :--- | :--- | :--- |
| **Img 1 (`desert_approach_rpg_albedo.png`) — PRIMARY TARGET** | True 3D stepped sedimentary cliff terraces framing a curved cobbled road + 2D sagebushes + telephoto camera tilt-shift + right-to-left afternoon sun shafts | Z-depth trail walk (forward into sunlit canyon gap) | Walls rise high **above** eye level on both sides (`~5–6m+`), built from continuous blocky horizontal steps topped with warm grey-brown stone, finely striated terracotta cliff faces, lush pale-sage bushes in coves, and sharp mid-ground focus |
| **Octopath Traveler** | Elevated view across tread tops and risers, a sharp band around the actors and directional shadows across the route | Reference for Balance's X/Z movement | The autumn stairs show focus on the hero and nearby paving. The forest shows localized shafts. The boats show several actors legible across overlapping depth planes, a useful criterion for tactical zoom. |
| **Ori** | Dark foreground trunks frame a bright opening, with a warm canopy and cool underwater space | Side view | Use one opening for the desert light shaft and a restrained cyan accent for the gauntlet. |
| **Child of Light** | Foreground stone carries fine edges while the distant trees use pale, broad shapes | Side view | Simplify the painted vista in Krita. Reserve fine value changes for the playable shelves. |
| **Hollow Knight** | A light head and strong silhouette remain readable against a quiet middle value | Side view | Test the commander against sunlit cobble and shaded basalt. Repeat at tactical zoom with several units. |

---

## 2. The Four Shared Visual Pillars

Even across Z-depth HD-2D (*Octopath*) and 2D side-scrollers (*Ori*, *Hollow Knight*), the lush diorama feel relies on **4 shared techniques**:

1. **A readable playing distance.** D4b places a screen-height blur around a sharp band (`focal_position_y = 0.60`, `focal_width = 0.28`, `blur_amount = 1.25`). The bend experiment will judge camera-depth blur by whether the commander and nearby paving stay sharp together. Exact FOV, material roughness and fog implementations in the reference games cannot be inferred from these stills.
2. **Dark Out-of-Focus Foreground Framing:** Real high flanking walls or foreground rock silhouettes at edges guide the eye down the sunlit center path (NOT blurry flat 2D `DioramaWings` paintings).
3. **Light and atmospheric separation.** D4b combines exponential fog, material haze, canvas rays and dust. For the new bend, establish a shadow from the right buttress first. The concept's diagonal beam enters through an opening and leaves the shaded bank legible. A localized fog volume can be tested once the geometry produces that separation.
4. **High-Craft Textures Mapped onto Simple Stepped Shapes:** Simple blocky stepped geometry looks handcrafted when covered with finely bedded strata textures (`18–28` horizontal bands/meter), normal maps, and grounded crevice AO.

---

## 3. Sampled Target Palette from Img 1 (`desert_approach_rpg_albedo.png`)

Measured directly from Img 1 (`1376x768`) 10th / 50th / 90th RGB percentiles (`0..255`):

| Region | 10th Pct (Shadows / Crevices) | 50th Pct (Midtone Body) | 90th Pct (Sunlit Highlight) | Visual Note |
| :--- | :--- | :--- | :--- | :--- |
| **`left_wall_upper`** (terracotta strata cliffs) | `[44, 21, 11]` | `[115, 60, 36]` | `[209, 138, 91]` | Warm rust-terracotta with bright sunlit rim beds; never neon orange |
| **`ledge_tops`** (weathered upper shelf caps) | `[32, 18, 8]` | `[114, 75, 48]` | `[180, 118, 81]` | **Warm grey-brown stone**, NOT black charcoal coal! |
| **`path`** (center cobblestone road) | `[88, 63, 35]` | `[149, 106, 67]` | `[233, 192, 143]` | Warm buff/ochre sunlit stones (`192–233` tops) |
| **`sand_verge`** (sandy cove pockets) | `[57, 30, 9]` | `[169, 131, 78]` | `[240, 193, 131]` | Golden warm desert sand |
| **`right_wall`** (shaded eastern cliff face) | `[21, 14, 8]` | `[50, 27, 18]` | `[80, 44, 29]` | Deep warm umber in sun shadow |
