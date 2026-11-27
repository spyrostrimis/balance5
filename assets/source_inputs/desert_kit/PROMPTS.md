# Desert kit — ChatGPT Images prompts

Paintings for the shared desert kit (`assets/textures/rts/desert_kit/`). Save each result **as the exact file name given**, in this folder:

`D:\Games\Balance5\assets\source_inputs\desert_kit\`

Download the full-size PNG from ChatGPT (not a screenshot). Reference images to attach are in `refs\`.

---

## 1 · Blue Field HQ at Carbon's camera — `blue_field_hq_steep.png`

**Why:** the current HQ was painted at your reference image's lower camera, so it shows a tall front wall and reads as a building from a different game next to Carbon's flat-topped outpost. Reusable 4's prompt asked for a steeper view, but ChatGPT kept the original angle. This prompt gives it a concrete target instead: the outpost painting it has to match.

**Attach (in this order):**
1. `refs\ref_carbon_outpost_angle.png`: the camera angle to copy (Carbon's outpost: almost straight down, with only a thin front edge visible)
2. `refs\ref_current_hq_too_low.png`: the building design to keep (this angle is too low)
3. `refs\ref_owner_hq_sheet.webp`: your original reference (bottom-right building)
4. `refs\ref_mission_hq_in_game.png`: how it sits in the game today, next to the outpost, soldiers and tank

**Paste:**

> Repaint the building from image 2 (the Blue field headquarters: sandstone base, blue-grey metal roof, round roof drum, small hatch, blue pennant on a mast, arched doorway with steps, broad cobalt banner with an ivory winged emblem) so it is seen from **exactly the same camera as the grey outpost in image 1**.
>
> Camera: a steep top-down RTS view, about 65° down from the horizon. Like image 1, the **roof fills about three quarters of the building's height** in the picture. The south (front) wall is a **thin band, about one fifth of the height**, showing only the top of the arched doorway, the banner and the steps. No side walls visible except a sliver on the right. No perspective or vanishing point: parallel edges stay parallel. Image 4 shows why: the current version looks taller and closer than everything around it.
>
> Keep the footprint roughly square, slightly wider than deep, like image 1. Hang the banner from the front edge of the roof so it reads from above. Light from the **upper left**: brighter roof planes facing up-left, shaded right edges, a short soft shadow only at the right and bottom foot. Same warm desert palette, painted detail and miniature scale as image 1. Keep the two door lamps small and dim so the gold crystals elsewhere on the map stay brighter.
>
> One isolated building on a **fully transparent background**, centred, with some empty margin. No ground pad, no sand patch, no cast shadow on the ground, no text, no border. Detailed digital painting, not pixel art, no black outlines.

**If it still comes back at the low angle**, reply in the same chat:

> Closer to image 1's camera, please: more roof, much less front wall. The front wall should be no taller than the banner.

**After you save it**, ask any agent to run:

```powershell
C:/Python312/python.exe tools/python/make_desert_kit_hq.py
```

It cuts the building out, writes `blue_field_hq_hd.png`, `blue_field_hq_pixel.png` and the HQ portrait into the kit, and sets the piece's size to the new proportions. Every map using `scenes/rts/desert_kit/pieces/blue_field_hq.tscn` updates at once. Then check the HQ's blocked ground with **F1** in Mission 1 and adjust its **Blocked Poly** if the footprint changed.
