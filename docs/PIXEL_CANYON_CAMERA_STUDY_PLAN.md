# Pixel Canyon camera and depth study

The original brief follows. The [completed comparison](PIXEL_CANYON_CAMERA_STUDY.md) records the implementation, test results and art assessment. The scale and framing are open for review.

**Handoff to Sol · Proposed for the first room.** The owner wants the uphill walk to feel like the commander is entering the painted canyon, with the view accompanying her a little. The art decision is whether a better sense of scale is enough, and whether a small camera move adds anything.

## Starting point

The first room and its viewport are both 960×540. The commander stands at (511, 325), about 125 art pixels tall. Her current size stays constant from foot Y 399 through 274, then changes in steps. At the upper gate near Y 152 she is still about 95 pixels tall. A camera pan can change framing, but it moves her and the stone beneath her by the same distance. Her height against that stone is the first thing to tune.

Use a separate study scene and capture folder. Reuse the room, commander, controls and recorded walk. Keep the existing two-room study available for comparison.

## Three versions of the same walk

1. **A · Current game.** Capture the existing walk at 1080p. Save four standing frames on the near road (Y 425), original spot (325), upper road (217), and just before the gate (about 165). Include the whole commander and the cobbles under her feet.
2. **B · Depth calibration with a fixed camera.** At each mark, sample several ordinary paving stones across the road and compare their typical width with the stones at the original spot. Use those ratios to draft four commander silhouettes on the actual picture. Keep the original spot at 125 pixels. Judge the others against the curb and masonry as well as the paving, since individual stones vary in size. Pick target heights by eye, then interpolate between those marks using boot Y in room coordinates. Use the same local scale for travel speed, rifle muzzle and shadows. Check that the scout and commander look the right size side by side. Review the walk, especially the face, rifle and planted boot. If fine details flicker, compare a few prepared sprite sizes at the same marks. Record the accepted heights.
3. **C · The calibrated walk with a small camera follow.** Start with vertical movement only. Hold the original framing at spawn and through the nearby fight. Once she walks uphill past about Y 300, let the camera travel roughly one pixel uphill per six pixels of boot travel, up to 24 art pixels. As she goes uphill the road drifts gently down the screen. On the return the camera retraces its travel. Follow the ground point, render the final offset on whole art pixels, and check stops and reversals for jitter. These distances are starting values for the comparison.

## What Sol needs to build

- **Art for the edge of the frame.** At the maximum proposed pan, 24 new rows become visible above the painting. Extend the upper cliffs, ruins and sky in a layered 960×564 working copy. Place its top at room Y −24 so every existing pixel lines up at spawn. Use a temporary extension to judge the motion before spending time on the final paint. The playable viewport stays 960×540 with nearest-neighbour doubling at 1080p.
- **One camera inside the study viewport.** Apply the same view to the painting, actors, shrub, shadows and shots. Keep controls and the F2 reference in screen space. Walkable edges, gates, draw order and shot lanes continue to use the original room coordinates. Reset the camera on room entry and when comparing the master. Return from F2 to the current gameplay framing.
- **One matched recording per version.** Reuse the input route and record each version at normal game speed. If calibrated walking speed changes the arrival time, align the comparison clips at the same boot positions. Include the uphill walk, a stop, a reversal, the shrub crossing, one miss and one hit. Test the bend transition both ways and watch for a one-frame jump. Relevant starting files are [the scene](../scenes/pixel_canyon/pixel_canyon.tscn), [commander scale and movement](../scripts/pixel_canyon/pixel_commander.gd), [room changes and firing](../scripts/pixel_canyon/pixel_study.gd), and [the walk test](../tests/test_pixel_canyon_study.gd).

## Decision at review

Compare A with B first. At the upper bend, does she look like a person standing on that stretch of paving? Can you still read her boots and rifle? Then compare B with C. Does the gentle drift help you follow her while the bend stays visible and the road feels steady? Check the original standing composition against the 1080p reference and check for exposed edges at maximum travel.

Deliver a playable comparison, the four matched standing views, and short clips of A, B and C. A and B need no additional canyon painting. C needs the narrow top extension and camera integration. If B reads best, it is a complete outcome. If C wins, tune Arch Overlook against its own road and landmarks in the next pass. A larger push through the canyon would be a separate art study, involving independently painted scenery layers or additional views.
