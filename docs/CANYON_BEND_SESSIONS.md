# Playable canyon bend

D4b at `6576387` establishes the left wall. Sessions 1 and 2 shipped in `8e05e40`, followed by the Session 3 hand-laid road in `3093d36`. The briefs below are historical. The current integrated control is [ChatGPT AI Boulders](../scenes/maps/desert_canyon_chatgpt_boulder_test.tscn) at `246e989`. [Review and capture evidence](EXPERIMENT_LOG_AND_LESSONS.md#integrated-canyon-review)

## Session 3 — Make the road read as hand-laid sandstone

```text
In D:\Games\Balance5, use scenes/maps/desert_canyon_bend.tscn as the control. Read AGENTS.md and docs/HD2D_CHECKLIST_AND_RUBRIC.md. Compare assets/textures/maps/desert_approach_rpg_albedo.png with the Session 2 spawn and midway captures at gameplay size. Create a separate road-art scene derived from the bend and give it its own material, editable Krita master and exported maps so both builds can be compared from the Developers Page.

Author a sharp top-down tile of worn sandstone cobbles. Lay short, staggered courses across the direction of travel, with elongated rounded rectangles, occasional wedges and varied joint widths. Give each stone a broad, gently convex crown in the height source, with chipped shoulders and fine grit. Derive a tiling tangent-space normal from that height. Vary the warm stone bodies and recess the joints. Use the existing road-edge mask for sand incursions if needed so verge wear stays at the edges of the road. An image-generated orthographic sheet is an optional starting point; keep the editable layers. Let the scene sun produce the directional highlights. The reference palette describes the final lit image.

Keep the 4 × 4 m repeat, 1024² maps, terrain mipmaps and the existing native DOF. Hold the geometry, sun, exposure, atmosphere and camera fixed across comparisons. Match the scale against the 1 m reference and the commander's boots. Inspect a 3×3 tile repeat and report X and Z wrap-to-neighbor ratios separately, aiming below 2× on both axes.

Capture control and candidate at 1376×768 at spawn, midway and exit. Show the full frames and matching boot-to-curb crops beside the concept. Toggle the candidate normal map in one frozen sunlit crop to demonstrate that the broad crowns catch light. Give separate verdicts for seam/scale and for course shape, relief, warm value contrast and verge wear. If the course direction disappears or the stones still look flat at gameplay size, iterate on the material. Verify the original buttress shadow, landmark reveal, floor contact and exit signal. Add the standalone build to the Developers Page with credit and a dated milestone with time zone, verify launch and Esc return, and record the source, scene, captures and verdicts.
```

### Following passes

1. **Right gateway.** Inherit the integrated boulder scene. Author one asymmetric, reimportable outcrop in Blender and disable only the right gateway card it replaces. Capture the same road-end landmark in control and candidate at the original camera. Pass when the outcrop hides the far road end at spawn, the crater glint is clear by midway, the commander stays grounded at all three stops and the exit fires. Keep the road, roadside boulders, sun and lens fixed.
2. **Atmosphere.** Save a matched control at the new gateway. Test localized, shadowed dust or fog through the opening, then assess warm grading and vignette separately. Keep the native lens active and the legacy screen-row blur disabled. Inspect the hero silhouette in shade and measure the GPU frame-time change on the same walk.
3. **Tactical handoff.** At the crater, transition to tactical framing, select one friendly unit and issue a reachable move order on the shared ground. Verify destination readability, arrival and return through the Developers Page.

## Session 1 — One right-hand buttress

```text
Implement and run the one-buttress test in D:\Games\Balance5. Read AGENTS.md, GEMINI.md and the local HD2D rubric. Use the current checkout and compare it with the D4b baseline at 6576387. Inspect existing changes first. Work in a separate playable test scene with its own asset and capture paths. Keep the launch scene available as the baseline.

Reuse the D4b left wall, commander, collision corridor, 30°/−13° camera, original sun and road. In Blender author one right-hand stepped buttress with an asymmetric silhouette, a ground-level origin, metre scale and matte material. Export it as its own GLB and instance it in a Godot wrapper that owns the material override and a simple blocker. Replace only the right card or cards covering this test section. Place the buttress so the path beyond the turn is partially concealed at spawn and opens up as the commander walks.

In the test scene disable the canvas blur, ray overlay and painted right-side road shadow for the diagnostic images. Keep these settings identical across each A/B pair. Capture a matched baseline before adding the buttress. Choose a fixed, visible feature on the gateway or crater and record its world position before placing the buttress.

Prove three things.
1. Change a visible notch in the Blender source, export the same GLB and let Godot reimport it. Confirm the placed instance updates without rerunning the level assembler. Record the before/after captures and verify its transform, override and blocker survive.
2. From one stationary camera with identical exposure, capture buttress shadow casting on and off. Identify a real shadow crossing at least one full cobblestone. Include the same crop from both captures.
3. Walk the separate test scene at 1376×768. Capture start (Z≈+6), midway (−3.5) and exit (−14). Verify that the buttress hides the preselected landmark at spawn and reveals it by midway or exit, the hero stays grounded at the stops and the exit signal fires. A timeout, missing image or wrong scene is a failed run.

Use the existing walk harness as a starting point. Make it target the test scene and use distinct output names while preserving its normal launch-scene behavior. Inspect the images. Iterate on this one module if a check fails. Record the scene, Blender source, GLB, capture paths, reproducible invocation, measured results and remaining defects in the local experiment log. Report the verdict of each check. The full right wall, road repaint and lens work belong to later passes.
```

## Session 2 — Finish the same playable bend

```text
Complete the one-bend milestone in D:\Games\Balance5. Read AGENTS.md, GEMINI.md, the local HD2D rubric and the latest buttress entry in docs/EXPERIMENT_LOG_AND_LESSONS.md. Locate the actual Session 1 test scene, source GLB and captures. Reuse that scene and its successful settings. If a required buttress check is incomplete, reproduce and address it before judging the road or focus.

Work in two passes and save matched controls for each. Keep the D4b left wall, commander, follow-camera transform/FOV, and the validated buttress placement. Use distinct capture paths. The deliverable is a playable test bend.

Pass A — Ground. Author a sharp, top-down repeatable cobble tile in Krita, keeping editable art and exported maps. Choose and record a real stone length in metres. Preview a 3×3 repeat, then set the scale on the bend using a metre reference and the commander. Verify terrain mipmaps. Measure mean absolute RGB jump across both wrap edges and mean adjacent-pixel jump along each axis on the original and candidate tiles. Aim for wrap jumps within 2× the ordinary neighbor difference on both axes and inspect the raw diffuse and lit road for visible seams. Check curb clearance and show the same view before and after.

Pass B — Focus. On the approved ground compare effects-off, the D4b screen-height filter and CameraAttributesPractical on the test Camera3D, one method per capture. Use the hero's actual camera-space depth. At the resting rig she is roughly 13 m away. Near 10 m and far 17 m are starting thresholds to tune. Keep exposure, sun, framing and the road fixed. Check the boots and nearby paving, a distant ledge at the same screen height, and alpha edges during movement. Record the chosen settings and why. Use the wider sharp range as a tactical readability preview if useful.

Rerun the start/midway/exit walk at 1376×768. Verify ground contact, exit signal, landmark reveal and the buttress shadow. Review captures against the concept and D4b. Record the source files, scene, command, measurements, comparison images and any failed checks in the local log and rubric. Provide the exact scene to play and a verdict on the milestone. A full canyon rebuild, native RTS systems and volumetric-fog production work are outside this slice.
```
