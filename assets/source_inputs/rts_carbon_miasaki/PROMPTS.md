# Miasaki ImageGen sources

Created with the built-in ImageGen tool on 25 November 2026. Forest Fight 4, supplied by the owner, was the paint, colour and light reference. The Carbon pieces and assembled sheets were the references for exact angle, position, proportions and silhouette. The accepted cliff repaint was an additional limestone and sage reference for the other rocks and scrub. [In-game comparison](../../../docs/RTS_REUSABLE_2_CARBON_MIASAKI.md)

## Northeast prompts

| Saved source | Final prompt brief |
| --- | --- |
| `cliff.png` | Repaint the whole transparent Carbon cliff sprite in opaque fantasy gouache. Keep the canvas, shape, tiers, front faces and lower-left spring. Paint the exposed limestone in peach cream and pink-gold with cool lavender-grey faces, deep plum under ledges, restrained sage and turquoise bounce at the shore. Keep the upper-left sunlight, clear exterior, and original high oblique view. |
| `outpost.png` | Repaint the original square flagstone base, corner beacons, ramp and slanted roof precisely in place. Use pale worn flags, blue-grey paint, crimson piping, softened brass and a deep cool face under the roof. Keep the sprite isolated and the sun upper left. |
| `sand.png` | Full-bleed seamless flat ground from directly above. Take the peach-gold forest path into a quiet desert tile around `#dfa56c` with faint wind strokes and fine gouache texture. Level light and low contrast for troops. Leave the surface clear of stones, vegetation, cracks and dune crests. |
| `red_soldier.png` | Repaint the eight columns and four rows of Carbon Legionaries with garnet armour, coral shoulders, brass trim, nickel rifles and dark plum boots. Keep their exact poses, angle and contact on transparent. Make the upper-left light and colours legible at troop size. |
| `blue_tank_hull.png` | Repaint the eight columns and two rows of hulls only. Keep the track spacing, mount centres, all headings and the same viewpoint. Use cobalt plates, warm dust along fenders and deep blue-violet track joints in upper-left light. Keep clear transparent gutters. |
| `blue_tank_turret.png` | Repaint the eight Blue turret-only sprites with royal blue and sky-blue planes, warm daubs and plum metal shadows. Preserve the centre and ring, barrel length, direction and placement in all eight cells on transparency. |

## Map and units prompts

| Saved source | Final prompt brief |
| --- | --- |
| `rocks.png` | Repaint a 2 × 2 sheet with the mesa and elbow ridge above the three boulders and small outcrop. Keep each silhouette, exposed south face and projection. Match the accepted pale limestone cliff with broad gouache strokes, peach-gold planes, cool shadows and deep cracks. Keep clear gutters and no orange halo. |
| `mirrored_rocks.png` | Paint the three already mirrored pieces in place. Keep the bend on the left-facing ridge, the boulder arrangement and the low outcrop shape. Move the highlights to the upper left and use deep lavender-grey under the ledges. Keep the same isolated cutouts and projection. |
| `paving.png` | Keep a tileable straight strip across the top half and an isolated oval plaza below. Paint flat pale-buff flags with faint lavender joins, soft peach sand shoulders and pale edge marker stones. Keep the original projection, silhouettes and gutters. Lower contrast so units stay clear. |
| `dunes.png` | Paint three separate oval ripple fields in one horizontal row. Keep the original three footprints, diagonal rising crest angles and spacing. Use softly broken honey highlights above muted mauve-buff troughs, with soft peach sand between bands and transparent gutters. |
| `scrub.png` | Repaint the two low bush sizes from the same high angle. Use clustered sage leaves with ochre-lit tips, small blue-green shadows and tight rocky footings. Keep the two shapes isolated on transparency. |
| `orichalcum.png` | Preserve the original oval outcrop, terraces, height and crystal positions. Paint sharply faceted amber and honey-white crystals as the strongest colour on the map. Keep the centre rock cool and dark with a pale limestone rim, deep cracks and restrained amber bounce. Leave the cutout isolated. |
| `blue_soldier.png` | Repaint the original eight directions by four step frames with royal and sky-blue armour, pale brass trim, cool dark boots and upper-left sunlight. Keep the existing order of facings, rifle poses, silhouette and gaps on transparency. |
| `blue_commander.png` | Repaint the eight columns and four rows using Forest Fight 4 for the Commander herself. Use cobalt armour, chestnut hair, muted leather and the pale scarf as the clearest accent at tactical size. Keep Carbon's foot placement, angle, pose and spacing. |
| `red_commander.png` | Repaint the original eight by four Commander sheet with garnet armour, a darker gold-edged mantle and plum shade. Use warm upper-left gouache light. Keep the hood, angles, pose, feet and gaps on transparency. |
| `red_tank_hull.png` | Preserve the two rows of eight hulls, mounting point, dual tracks and onboard angle. Repaint with garnet armour, vermilion highlights, grey steel and warm brass. Leave the turret and gun off the sheet. |
| `red_tank_turret.png` | Keep the single row of eight turrets at the original scale and with the original mount and barrel axis. Use garnet, vermilion edge highlights and dark blue-grey gunmetal in upper-left light. Keep the backdrop transparent. |
| `portrait_blue.png` | Keep the single Carbon portrait's whole figure, camera and quiet backdrop. Paint the Commander with the forest's chestnut hair, ivory scarf, cobalt armour, warm leather and cool shadows. Keep the large colour groups legible in the small unit card. |
| `portraits.png` | Keep the 3 × 2 sheet and the framing of each square. First row Blue tank, Red tank, four Blue soldiers. Second row four Red soldiers, Red Commander and amber Orichalcum. Use warm buff backdrops, vivid faction colours, gouache marks and violet shadow shapes. |

Build the game-sized PNGs with `tools/python/make_rts_carbon_miasaki.py`. It keeps Carbon's precise transparency, animation boxes and contact points, and prepares the dune paint for the same live track effect.
