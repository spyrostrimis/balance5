# Balance — Game Design

The design source of truth for every contributor and coding agent (Claude Code, Codex, Antigravity/Gemini). The design was written by the project owner. When a technical note elsewhere disagrees with this file, this file wins. Mark anything not yet decided as **open** rather than inventing it.

## 1. What Balance is

**Balance is a real-time strategy game, a tribute to Dune II (1992).** Its gameplay, graphics and HUD layout follow Dune II. Its feel and warmth are fantasy, closer to *The Lord of the Rings* and *Star Wars* than to modern military.

**Priority: the RTS comes first.** The RPG walking sequences, the 3D canyon and the HD-2D look are extras. If they fail, the project keeps the RTS and is still a success. When time is short, spend it on the RTS.

## 2. The world

### Political backstory

A just and widely respected king, the **Peacebringer**, united most of his home planet through diplomacy and brought the neighbouring planets of the system into an alliance. Peace and prosperity followed.

Believing large ground forces were no longer needed, he abruptly discharged most of the military. He kept only the Royal Guard and the police, and relied heavily on automated orbital defences. Many discharged military families, and the workers who depended on them, lost income and social standing. Others saw the policy as a strategic danger.

A young **lieutenant** used the backlash to organise a military coup during a palace ceremony. He slaughtered the king and seized power. The king's only son, the **prince**, aged 17, arrived late to the ceremony and escaped with loyalists, helped by a brave woman of the **Royal Guard**. Over the following years the prince and the guard had an on-and-off romance, but they have not been together for some time.

**The game begins ten years later.**

### Main characters

None has a name yet (**open**).

| Character | Role now | Age now |
| --- | --- | --- |
| The prince | **Blue Leader** | about 27 |
| The former lieutenant who led the coup | **Red Leader** | about 40 |
| The Royal Guard veteran who escaped with the prince | **Blue Commander** (Blue's field commander) | about 37 |

The Blue Commander is more than a romantic supporting character. She needs her own goals and her own judgment. In the concept art she wears blue armour and a pale scarf, carries a rifle, and wears a gauntlet marked with a cyan cross, matching Blue's healing role.

Mission 1 also has a **Red Commander**, Red's field commander (**open**: who this is).

### Orichalcum

Orichalcum is the game's **only resource**. It is scarce and mined from small rock formations. It is the crystal that funds armies: whoever holds a field can pay for ships, arms and soldiers. In the concept art it shows as dark rock veined with glowing teal crystal. In the RTS goal art it is a rock outcrop of gold crystals.

## 3. Factions

| Faction (provisional names) | Who they are | How they fight |
| --- | --- | --- |
| **Blue** | Freedom: a democratic coalition | Healing and repair, coordination |
| **Red** | Order: centralised command | Offence, swift strikes |
| **Green** | Opportunists: merchants and local lords | Ambush, stealth |
| **Palatinate / Clergy** | An ancient covert religious order | Unpredictable |

**Blue — freedom, justice, self-determination.** A democratic coalition against arbitrary power, and generally the sympathetic side.
- Flaws: bureaucracy, slow decisions, arrogance, losing touch with ordinary citizens.
- Themes: protection, restoration, shared morale.
- Suggested strengths (not balanced or final): keeping scarce units alive and coordinating them, healing and repair.

**Red — order, power, centralised command.** Authoritarian, ruthless and decisive. Red promises peace through unified strength and believes the ends can justify the means. Not cartoon villains: its leadership and logistical effectiveness have real appeal.
- Suggested strengths: offensive power, coordinated strikes, swift action. Costs and weaknesses: **open**.

**Green — opportunism: merchants and local lords.** A loose collection of self-interested actors with no interest in ruling the galaxy. They ally with either side when it pays. Their story role matters; do not dismiss it.
- Suggested style: ambush, stealth, lethal equipment, but weak cohesion as a large army.

**Palatinate / Clergy — an ancient covert religious order.** Antagonistic or unpredictable. Sometimes they oppose every faction, sometimes they quietly back one.
- History: they once spread religions among intelligent civilisations to impose social order. The plan was discredited when it set off sectarian conflicts nobody intended.
- Now: a new guard has replaced the old one. It prefers hidden guidance and manipulation, in the manner of a covert intellectual order.
- Powers and technology: **open**. (The concept art's pale temple with violet banners may suit them; not decided.)

**Units are not only humans, infantry, vehicles and tanks.** The lore is closer to *The Lord of the Rings* and *Star Wars*. Expect creatures, mechs and fantastical units alongside soldiers and vehicles.

## 4. Structure

- **Campaigns.** Blue and Red each get a full classic single-player campaign. Green and the Palatinate get mini-campaigns or single missions later.
- **Shared opening.** Both campaigns start with the same mission, *The First Claim*, seen from either side. Blue's version is on a tropical forest planet, Red's on a desert planet. Planet names are **open**.
- **One faction per map.** The player controls one faction. The AI plays the others.
- **Alliances are set per map.** An AI faction (Green, the Palatinate, or Blue/Red) may fight alongside either side, or against everyone. Example: in the **Ashfall** skirmish, Green's merchants side with the player's opponent.
- **Mission types.** Standard base-destruction missions sit alongside other objectives, including resource control and survival.

## 5. Mission 1 — "The First Claim"

| | |
| --- | --- |
| Setting | Tropical forest when playing Blue, desert when playing Red |
| Forces | Four troops per side, plus each side's field commander (Blue Commander, Red Commander) |
| Objective | Both sides contest one Orichalcum rock in the centre of the map. It is the only field on that world. |
| Winning | Hold uncontested control of the area near the rock for a short time, or eliminate all resistance |
| Teaches | Selecting units, moving, attacking, using the commander's ability, and how control points work |
| Leaves out | Base building |

## 6. Gameplay pillars

- **Scope.** Small armies and few buildings and units at first. Losing a unit hurts. Repairing and retreating matter more than replacing.
- **Economy.** One scarce material, Orichalcum, mined at first from small rock formations. Larger deposits (mountains, mines) are future possibilities. Deposits are rare and/or finite; rate, renewal and tuning are **open**. Harvesters are high-value targets.
- **Harvesting.** A harvester travels as a truck. At a deposit it transforms into a humanoid robot, extracts Orichalcum, transforms back, then returns to a refinery.
- **Tactical leaders.** Selected commander/hero characters have active and possibly passive abilities.
- **Hazards.** Some planets have powerful wandering creatures that may attack harvesters, armies, civilians and even structures. Not part of prototype 001.
- **After the prototype.** Base building, refinery, production and repair costs follow once the tactical foundation is stable.

## 7. Look and feel

**RTS direction.** The original **RTS Reusable 2 Carbon** is the owner's model for future RTS work. Build the battlefield from reusable modular Painted HD 2D art. Use Carbon in play and the painted reference to guide the camera, terrain composition and material treatment. [Playable model and assessment](RTS_REUSABLE_2_CARBON.md)

| Reference | File | What it sets |
| --- | --- | --- |
| Img 1 — overall feeling | [`references/concept_world_blue_vs_red.webp`](references/concept_world_blue_vs_red.webp) | Warm fantasy desert, Blue and Red squads, Orichalcum vein, ancient temple, Blue Commander portrait |
| Img 2 — RTS goal | [`references/rts_mission1_hud_goal.webp`](references/rts_mission1_hud_goal.webp) | Top-down pixel art map with the Dune II-style HUD (below) |
| RTS Mission 1 maps | [`references/rts_mission1_forest_blue.webp`](references/rts_mission1_forest_blue.webp), [`references/rts_mission1_desert_red.webp`](references/rts_mission1_desert_red.webp) | Blue's forest and Red's desert versions of the same layout |
| Img 3 — RPG goal | [`references/rpg_canyon_goal.jpg`](references/rpg_canyon_goal.jpg) (also `assets/textures/maps/desert_approach_rpg_albedo.png`) | HD-2D canyon: tilt-shift focus, stepped strata, light shafts |
| Blue Commander sprite | [`references/blue_commander_pixel.webp`](references/blue_commander_pixel.webp) | Pixel-art character style |

**RTS HUD (from Img 2).** A top bar shows the game logo (a scales emblem), mission name, Orichalcum count, squad count and objective timer (for example "Hold 0:17"), plus Menu (F10). The minimap is top-right. Below it are tabs, a selected-unit card (portrait, name, faction and type, health, attack, armour, range, squad members) and the command buttons **Move, Attack, Hold, Mend**. At the bottom is the objective panel with a progress bar ("Hold the Orichalcum rock").

**RPG combat.** RPG fights use the *Streets of Rage 4* approach: characters move freely in depth (Z), but face and shoot only left and right, never diagonally, up or down.

**Storyboards.** Illustrated briefing panels move the story along and explain things, in the manner of Dune II's mentat briefings: a character portrait beside a framed illustration with text above.

**Inspiration (not reusable IP).** Dune II, Command & Conquer, Red Alert, Warcraft III, DotA, Transformers, Star Wars, The Lord of the Rings, Greek mythology, Octopath Traveler, Ori and the Blind Forest / Will of the Wisps, Child of Light and Streets of Rage 4. **Everything shipped must be original or properly licensed.** Do not copy names, characters, art, music, levels or UI from these works. Third-party screenshots used as mood references stay out of the repository.

## 8. Production

- **Engine:** Godot 4.7.2 (Forward+), with Git and GitHub (`spyrostrimis/balance5`).
- **Available tools:** Visual Studio Code, Krita, Tiled, Aseprite, Blender, Audacity, Python with Pillow, and more. The owner can also buy or download software, sprites, sound effects, music, AI-generated images, text-to-3D and image-to-3D generators, and curated 3D asset packs. Ask when something would help.
- **Licensing:** record the source and licence of every bought or downloaded asset next to it.

## 9. Open questions

- Names: characters, planets, factions (all provisional), units.
- The Red Commander's identity.
- The Palatinate's powers, technology and look.
- Faction costs, weaknesses and balance numbers.
- Orichalcum extraction rate, renewal and deposit sizes.
- How the RPG sequences and storyboards connect to campaign missions.
