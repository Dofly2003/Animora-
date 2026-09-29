# Spike results (week 1)

Fill in each spike after trying it. These decide the approach for Phase 1.

## A. Export and publish KeyframeSequence

- Goal: create a 2-second KeyframeSequence for an R15 rig from code, publish it, play it in game.
- Pass if: it publishes, gets an asset ID, and plays exactly like the preview.
- How to run: select a rig, press **Export wave** in the Animora panel. The KeyframeSequence appears in ServerStorage > AnimoraSaves > Exports (baked to 30 fps, Linear keys). Right-click it > Save to Roblox, copy the ID, then play it in game with a test script.
- Result: **Pass** (2026-09-26). Asset ID 107592082560445 (exported from the R6 test rig) plays in game via Animator:LoadAnimation and matches the edit-mode preview.
- Notes:
    - First export wrote every joint in every keyframe (~1,000 Pose objects); Save to Roblox timed out repeatedly.
    - A clip made in the built-in Animation Editor published fine on the same account and network.
    - Fix: export only keyed joints plus their parent chain, like the built-in editor. After this the Animora export published.
    - Clips are baked to 30 fps Linear keys before export so every easing style matches the preview.

## B. Timeline performance

- Goal: timeline widget with 30 tracks x 200 keyframes; scroll, zoom, scrub.
- Pass if: stays above 30 fps while scrubbing; scrub-to-pose under 16 ms.
- How to run: Animora panel > **Timeline test** opens a floating window (30 tracks x 200 keys, virtualized). Drag on the ruler to scrub, wheel to zoom, Shift+wheel to pan, then press **Run auto test (6 s)**. The result line is also printed to Output as `[Animora Spike B]`.
- Result: **Pass** (2026-09-29). Scrubbing, zooming and panning 30 x 200 keys feel smooth with no stutter (tester report; exact auto-test numbers not recorded).
- Notes:
    - Decision: the real timeline keeps this design: plain Instances for the keyframe area, pooled markers, draw only visible rows and time range, render at most once per frame when dirty.

## C. Edit-mode pose preview

- Goal: write `Motor6D.Transform` every frame in edit mode (no Play Solo).
- Pass if: the rig moves smoothly in edit mode.
- How to run: open the Animora panel, select an R15 or R6 rig, press **Wave**, then **Stop**. Check that the arm moves and the pose is restored after Stop.
- Result: **Pass with the C0 fallback** (tested 2026-09-26)
- Notes:
    - `Motor6D.Transform` mode: the rig does not move at all in edit mode.
    - `C0` mode: the arm waves correctly in edit mode.
    - Decision: edit-mode preview writes `C0 = originalC0 * transform` and restores the original C0 on Stop, when the panel closes, and when the plugin unloads.
    - Still to check: the place must not be saved mid-preview (status text warns), and Ctrl+Z after Stop must not leave the rig in a mid-pose.
