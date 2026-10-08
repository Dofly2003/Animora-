# Changelog

All notable changes to Animora are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-08

First public beta.

### Added
- Timeline with one row per joint in rig order, keyframe markers, scrubbing, zoom and pan, frame stepping and jump to previous / next keyframe.
- Rotate gizmo with auto-key, and a move gizmo for the root joint; switch with R / T or the toolbar.
- Viewport picking of single body parts, through hair, clothing and accessories, with a forgiving radius for thin limbs.
- Keyframe editing: select (click, Shift/Ctrl, box), move, delete, copy/paste, left/right mirror.
- Per-keyframe easing: 12 styles (Linear, Constant, Sine, Quad, Cubic, Quart, Quint, Exponential, Circular, Back, Elastic, Bounce) with In / Out / InOut.
- Clip settings: length, loop, 24 / 30 / 60 FPS, priority.
- Several animations per rig, created empty or from 20 starter templates (basic moves, a Scared set, Flashlight, a Kuntilanak / Pocong / Tuyul ghost set and a NISKALA set).
- R6, R15, custom Motor6D rigs and AnimationConstraint avatars (Avatar Joint Upgrade); the status bar names the rig type.
- Autosave into the place (ServerStorage > AnimoraSaves), Studio Ctrl+Z / Ctrl+Y for every edit.
- Export to KeyframeSequence (ServerStorage > RBX_ANIMSAVES) for publishing; import from the place, the Explorer selection or an asset ID.
- Rebindable Studio shortcuts for playback, stepping, copy/paste, delete, mirror and gizmo mode.
- English and Indonesian UI, user guide in both languages.
- Plugin icon.

[Unreleased]: https://github.com/Dofly2003/Animora-/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Dofly2003/Animora-/releases/tag/v0.1.0
