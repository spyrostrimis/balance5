# Source inputs

Original AI-generated images and meshes that the tools in `tools/` turned into committed assets. They were copied from the Antigravity (Gemini) workspace so every tool can be rerun from the repository. `.gdignore` keeps Godot from importing them.

| File | Role | Used by |
| --- | --- | --- |
| `media_1795014976304_da5aec03.jpg` | ChatGPT cobble albedo | `tools/python/build_chatgpt_cobble.py` |
| `media_1795014976270_d8a2de1b.jpg` | ChatGPT cobble height | `tools/python/build_chatgpt_cobble.py` |
| `media_1795022926046_7eba23fa.jpg` | ChatGPT sandstone albedo | `tools/python/build_chatgpt_sandstone.py` |
| `media_1795022967542_3a10c6a3.jpg` | ChatGPT sandstone height | `tools/python/build_chatgpt_sandstone.py` |
| `media_1795020839426_cc5f33df.glb` | HuggingFace TRELLIS.2 boulder | `tools/blender/blender_import_ai_boulders.py` |
| `media_1795020844091_0aaf81c0.glb` | trellis3d.net boulder | `tools/blender/blender_import_ai_boulders.py` |
| `media_1794834895605_af15c30b.jpg` | RTS desert battlefield concept | `tools/python/clean_blue_tank_sprite.py`, `extract_*_sprites.py`, `tools/legacy/*` |
| `combat_commander_hd2d_sprite_1794851030582.jpg` | Commander sprite sheet | `tools/python/process_commander_sprite.py` |
| `desert_canyon_hd2d_1794850108794.jpg` | Early HD-2D canyon render | `tools/python/prepare_rpg_map.py` |
| `test_b_hd2d_ground_raw_1794880450271.jpg` | Test B ground strip | `tools/python/build_test_b_ground.py` |
| `desert_canyon_ledges_diorama_v2_1794882244795.jpg` | Test C2 ledge cutouts | `tools/python/build_test_c2_ledges.py` |
| `desert_stone_sandstone_albedo_sheet_1794942452330.jpg` | Test D stone sheet | `tools/python/build_test_d_textures.py` |
