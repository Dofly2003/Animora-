# Spike results (week 1)

Fill in each spike after trying it. These decide the approach for Phase 1.

## A. Export and publish KeyframeSequence

- Goal: create a 2-second KeyframeSequence for an R15 rig from code, publish it, play it in game.
- Pass if: it publishes, gets an asset ID, and plays exactly like the preview.
- Result: _not started_
- Notes:

## B. Timeline performance

- Goal: timeline widget with 30 tracks x 200 keyframes; scroll, zoom, scrub.
- Pass if: stays above 30 fps while scrubbing; scrub-to-pose under 16 ms.
- Result: _not started_
- Notes:

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
