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
- How to run: open the Animora panel, select an R15 or R6 rig, press **Wave (Transform)**, then **Stop**, then **Wave (C0)**. Note the updates/sec shown, whether the arm moves, and whether the pose is restored after Stop. The fallback mode (C0) is tested in the same run.
- Result: _not started_
- Notes:
