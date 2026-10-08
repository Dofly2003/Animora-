# Roadmap

About 30 weeks at 10–15 hours per week. Each phase ends with a gate that must pass before moving on.

| Phase | Weeks | Output | Gate |
| --- | --- | --- | --- |
| 0. Spikes | 1 | Export/publish prototype, timeline performance prototype, edit-mode preview | All three spikes pass (see `spike-results.md`) |
| 1. Foundation | 2–3 | Data model, interpolation, undo/redo, rig binding | An R15 rig can be posed and previewed from code |
| 2. MVP core | 4–8 | Timeline UI, gizmos, easing, copy/paste, mirror, export/import, autosave | A walk animation is made end-to-end and plays in game |
| 3. MVP beta | 9–10 | Testing with 5–10 animators, bug fixes, short guide | No critical bugs; free release on Creator Store |
| 4. v1 | 11–22 | IK, curve editor, camera, objects, multi-rig, onion skin, pose library, Moon save import | A 2-character cutscene with camera is made without other plugins |
| 5. v2 | 23–30 | Markers + Luau code generator, animation debugger, extra easing | Beta users rate it equal to or better than paid alternatives |

## Wishlist

Requested features that are not scheduled yet. Newest first.

| Requested | Feature | Notes |
| --- | --- | --- |
| 2026-09-29 | Camera animation (cutscenes) | Planned for v1; asked for by the project owner, parked until the beta ships |

## Status (2026-10-08)

Phase 2 (MVP core) gate passed: many clips have been made end to end and play in a real game. Now in phase 3 (MVP beta).

Done: phase 0 spikes; timeline, rotate gizmo with auto-key, keyframe editing (select, move, delete, copy/paste, mirror), frame stepping and FPS, per-keyframe easing, Studio Ctrl+Z/Ctrl+Y, bindable shortcuts, R6 / R15 / AnimationConstraint avatars, autosave, several animations per rig, export/import (place and asset ID), 20 starter templates (basic, Scared, Flashlight, ghost and NISKALA sets) in a scrollable list.

Also done since: move gizmo for the root joint with rotate (R) / move (T) modes, picking body parts through accessories, a toolbar grouped into clip / playback / edit rows, spike tools removed, rig-type label (R15 / R6 / custom, plus Constraint), plugin icon.

Before beta: run the test place, user guide, v0.1.0 release.
