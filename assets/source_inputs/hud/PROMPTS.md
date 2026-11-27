# RTS HUD directions — ChatGPT Images prompts

Five different HUDs to compare as **mockups**: pictures of the whole game screen, not game files yet. Pick the one or two that feel right; an agent then builds them as a real, switchable HUD in Mission 1 so you can play with each one.

Save each result in `D:\Games\Balance5\assets\source_inputs\hud\` with the file name given. Generate each in a **new chat**, so one style does not leak into the next.

**Attach to every prompt:**
1. `refs\gameplay_no_hud_1080.png`: the battlefield with the HUD hidden (keep this picture as the game view)
2. `refs\current_hud_1080.png`: today's placeholder HUD, showing what it must contain

**Paste this first, in every chat** (the shared brief):

> I'm designing the in-game HUD for **Balance**, a real-time strategy game. It's a tribute to Dune II (1992), set across many worlds with a warm, hopeful space-fantasy tone like *Star Wars*. Image 1 is the game view at 1920×1080. Image 2 is our placeholder HUD, which feels dated.
>
> Make a **full-screen landscape mockup** of the game with a new HUD laid over image 1's battlefield. Keep the battlefield art the same and visible. The HUD must contain:
> - **Resources and status:** Orichalcum 340, Forces 5/5, and a Hold timer 0:30 (the objective countdown)
> - a **minimap** of the whole battlefield with a white view rectangle
> - the **selected unit card:** portrait of the Blue Commander (a woman in cobalt armour with an ivory scarf), health bar, Attack 16, Armour 4, Range 5.2, and her ability "Mend +30 HP" marked ready
> - four **command buttons:** Move, Attack, Hold, Mend, each with a clear icon
> - an **objective panel:** "Hold the Orichalcum rock" with a progress bar and the text "Uncontested"
>
> Text must be sharp, large enough to read at 1080p, and spelled exactly as above. Use real UI proportions: crisp edges, consistent margins, nothing painted soft or blurry. The HUD should cover as little of the battlefield as the style allows. No logos, watermarks or extra labels.

**Then paste one of the styles below.**

---

## A · Brass command table — `hud_A_brass.png`

> **Style:** a refined version of image 2. Dark bronze and engraved brass frame with fine bevels, parchment cards with ink text, and a gold accent for Orichalcum. Make it feel crafted and modern, like a premium strategy game, not a 1990s bitmap. Keep the classic layout: a thin top bar, plus a right-hand column with the minimap at top, the unit card, the four command buttons and the objective at the bottom. Thinner borders than image 2, more breathing room, a small engraved emblem of scales in the top-left.

## B · Holo-glass field tablet — `hud_B_holo.png`

> **Style:** a field commander's holographic tablet. Panels are smoked dark glass with soft translucency (the battlefield faintly visible through them), fine cyan light lines, and warm amber for Orichalcum and alerts. The minimap is a glowing hologram with a faint scanline. Buttons are thin outlined glyphs that light up on hover. Rounded-corner panels floating slightly off the screen edges. Layout: minimap bottom-left, unit card bottom-centre, command buttons bottom-right, resources as a slim strip along the top centre, objective as a small pill under the resources. Lots of open battlefield.

## C · Coalition banner console — `hud_C_banner.png`

> **Style:** the Blue Coalition's own console. Royal cobalt enamel panels, ivory trim, thin gold filigree, and the white winged emblem from the headquarters banner in image 1. Panels hang like **banners**: the unit card and command panel drop from the top-right like a heraldic pennant with a pointed lower edge. Text is ivory on cobalt. The same layout must work in crimson and brass for the Red side later, so keep the shapes faction-neutral and the colour easy to swap. Minimap in a round, shield-like frame at top-right.

## D · Minimal floating cards — `hud_D_minimal.png`

> **Style:** a clean modern RTS HUD that leaves the battlefield almost untouched. No frame and no full sidebar. Small dark semi-transparent cards with 8 px rounded corners and a hairline warm-gold border: a compact minimap in the bottom-left corner, the unit card bottom-centre (portrait left, stats right), a 2×2 grid of square command buttons bottom-right, and resources as three small chips in the top-left. The objective is a slim bar at the top centre. A clear modern sans-serif font, white text, colour used only for meaning (cobalt Blue, crimson Red, gold Orichalcum, green health).

## E · Dune II remastered — `hud_E_classic.png`

> **Style:** an HD homage to Dune II's interface. Chunky bevelled stone-and-steel frame, a right-hand sidebar about one sixth of the screen wide, the minimap at the bottom of the sidebar (as in Dune II), the unit portrait in a heavy square frame at the top, and big rectangular command buttons with embossed labels. Hard, crisp bevels with high contrast, like polished pixel art redrawn at 4×, but sharp, never blurry. A sandstone top bar with resources as large engraved numerals.

---

**After you've generated them:** tell an agent which ones you like and what you'd change. The plan is to build the chosen designs as real Godot HUD scenes (`Control` nodes with a theme and sharp fonts, not a drawn picture), with a key in Mission 1 that switches between them while you play.
