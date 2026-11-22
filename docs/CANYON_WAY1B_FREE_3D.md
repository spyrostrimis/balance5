# 3D Canyon · Way 1B Free 3D Modules

Play [3D Canyon · Way 1B Free 3D Modules](../scenes/maps/canyon_way1b_free_3d.tscn) in Godot or choose **Developers Page → Canyon builds → 3D Canyon · Way 1B Free 3D Modules** in [Balance.exe](../builds/Balance.exe). Walk with WASD or arrow keys. Esc returns to the Developers Page.

- **Walk & Palette Comparison Sheet (Start · Midway · Exit):** [way1b_comparison_sheet.jpg](../render_captures/way1b_free_3d/way1b_comparison_sheet.jpg)
- **Final 1376×768 Forward+ Captures:** [Start (`Z = +6.0`)](../render_captures/way1b_free_3d/W1B_Final_pos1_start.png) · [Midway (`Z = -3.5`)](../render_captures/way1b_free_3d/W1B_Final_pos2_midway.png) · [Exit (`Z = -14.0`)](../render_captures/way1b_free_3d/W1B_Final_pos3_exit.png)
- **Raw Native Scan Colors (`Key G`):** [Start](../render_captures/way1b_free_3d/W1B_RawColors_pos1_start.png) · [Midway](../render_captures/way1b_free_3d/W1B_RawColors_pos2_midway.png) · [Exit](../render_captures/way1b_free_3d/W1B_RawColors_pos3_exit.png)
- **Complete 61-Asset Audit & Catalog:** [CANYON_ASSET_CATALOG.md](CANYON_ASSET_CATALOG.md)

---

## Kept Anchors & Free 3D Module Roster

The study preserves the three anchor rocks and the commander untouched on the `canyon_v2` S-curve route (`Z ∈ [-14.5, 7.5]`, `-21°` camera pitch, `30°` FOV, native camera depth of field, backlit `42°` sun):
- **Commander:** [blue_commander_3d.tscn](../scenes/actors/blue_commander_3d.tscn)
- **Two ChatGPT AI Boulders (Trellis):** [chatgpt_boulder_hf_trellis2.tscn](../scenes/maps/chatgpt_boulder_hf_trellis2.tscn) (`z = 4.85, lateral = -1.82`) and [chatgpt_boulder_trellis3dnet.tscn](../scenes/maps/chatgpt_boulder_trellis3dnet.tscn) (`z = 4.65, lateral = +1.50`)
- **Pale Photo-Textured Grand Canyon Rock:** `grand_canyon_rock.glb` (`z = 2.40, lateral = +1.35`)

Every surrounding environmental role is built from real 3D photogrammetry scans and kit modules exported via [build_way1b_free_3d.py](../tools/blender/build_way1b_free_3d.py) and [build_way1b_textures.py](../tools/python/build_way1b_textures.py):

| Canyon Role | Free 3D Assets Used | Implementation & Visual Iteration Notes |
| :--- | :--- | :--- |
| **1. 3D Cobblestone Path** | **Namaqualand Stones 01** (`stone_a..e`, 5 distinct stone shapes) + **Moon Rock 04** (`moon_rock_04`, broad worn crown) | Packed in staggered courses along the S-curve via `MultiMeshInstance3D` (`1.5–2.2 cm` walkable crown height, `21–38 cm` stone footprint, `3–5 cm` dark mortar joints, tapering smoothly into desert dunes from `Z = -12.4` to `-15.2`). Balanced at `0.54` palette harmonization to preserve natural stone-to-stone mineral hue variety while unifying into warm desert sandstone. |
| **2. Stone Curb Blocks** | **Rock 07** (long straight sides, chipped corner) + **Namaqualand Boulder 03** (flat-topped broken end block) + **Namaqualand Boulder 05** | Placed along both road edges (`±1.24 m` from route center, `0.66–0.72 m` spacing), automatically cleared around the two Trellis boulders and the pale Grand Canyon rock, with `Boulder 03` anchoring gaps and boulder transitions. |
| **3. Cliffs Left & Right** | **Namaqualand Cliff 02** (`20.2 × 7.2 m` projecting bend nose) + **Rock Face 01** (`7.1 × 5.1 m` horizontal shelves) + **Namaqualand Cliff 01** (`8.3 × 5.0 m`) + **Rock Face 02** (`4.9 × 4.8 m`) + **Namaqualand Boulder 02 & 03** lower ledges | **Two-tier canyon wall architecture:** two overlapping lower courses of watertight `Namaqualand Boulder 02 / 03` ledges (`lateral = 2.72–3.85 m`, graded to darker weathered slate-sandstone) topped by towering `5–8.5 m` warm terracotta cliff scans (`Namaqualand Cliff 02/01` and `Rock Face 01/02`). The right inner-bend buttress at `Z = -8.9` occludes the Orichalcum crater at spawn (`25.94 m`) and reveals it cleanly by midway (`Z = -3.52`). |
| **4. Plants & Sandy Verge** | **Cheiridopsis Succulent** (6 distinct 3D desert succulent clusters `a, c, d, f, h, i`) + **Sand Rocks Small 01** + **Namaqualand Rocks 01** (`a..d`) | Curated botanical clusters in the `1.2 m` sandy verge between curbs and cliffs (plus accent plants on lower cliff shelves), paired with analytic radial soft contact-shadow discs, `Namaqualand Rocks 01` root stones, and `Sand Rocks Small 01` settled sand-and-pebble banks where the curb breaks. |
| **5. Exit View** | **Canyon River Terrain 2K** (distant river gorge) + **Mountain Desert 009** (natural sandstone arch) + **Plateau Desert 002** | Placed beyond the `Z = -22.2` Orichalcum crater: `Mountain Desert 009` (`z = -34.0, y = -4.1`, rotated `-72°` so its upper arch window aligns with the `-21°` camera frustum) frames a patch of bright sky on the left while `Canyon River Terrain` (`z = -66.0`) carries the eye into the distant gorge. |

---

## Interactive Hotkeys

- **`G`** — Toggle **Harmonized Warm Desert Canyon Palette** (default) ↔ **Raw Native Photogrammetry Scan Colors**
- **`R`** — Toggle **3D Scanned Cobblestone Path** (`Namaqualand Stones 01` + `Moon Rock 04`) on/off
- **`K`** — Toggle **3D Scanned Curb Blocks** (`Rock 07` + `Namaqualand Boulder 03 / 05`) on/off
- **`B`** — Toggle **3D Succulent Plants & Verge Rocks** (`Cheiridopsis Succulent` + `Sand Rocks Small 01` + `Namaqualand Rocks 01`) on/off
- **`W`** — Toggle **Way 1B Scanned Cliffs** on/off
- **`V`** — Toggle **Exit Vista** (`Mountain Desert 009` Arch + `Canyon River Terrain`) on/off

---

## Verification Metrics (`1376×768` Forward+ & Headless Corridor Check)

| Stop | Commander Position | Camera Origin | Floor Contact | Exit Signal | Crater Landmark `(0.25, 0.03, -22.2)` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Start (`Z = +6.0`)** | `(1.937, 0.0001, 6.000)` | `(1.162, 5.500, 17.900)` | `true` | `false` | **Occluded** (`InnerBendButtress` at `25.94 m`) |
| **Midway (`Z = -3.5`)** | `(-0.264, 0.0009, -3.524)` | `(-0.374, 5.500, 8.703)` | `true` | `false` | **Visible (`clear`)** at pixel `(735.6, 106.5)` |
| **Exit (`Z = -14.0`)** | `(-0.848, 0.0008, -13.973)` | `(-0.378, 5.500, -1.626)` | `true` | `true` | **Visible (`clear`)** at pixel `(662.0, 230.5)` |
| **Post-Strafe Check** | `(-1.313, 0.0009, -13.848)` | — | `true` | `true` | `flip_h = true` |

- **Headless logic & physics corridor test (`tests/test_canyon_way1b_free_3d.gd`):** `PASS` — verified all 5 Way 1B groups (`62` cliff modules, `61` curb blocks, `6` cobble MultiMeshes, `163` verge plant/rock/shadow nodes, `3` vista formations), kept anchors, interactive key toggles, left/right physics corridor containment (`±1.15 m`), spawn/exit end caps, exit signal, and obstacle-aware `NavigationServer3D` pathing around the boulders.
