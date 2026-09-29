--!strict
-- English strings (default + fallback). Keep keys sorted by area.
return {
	["toolbar.open.tooltip"] = "Open the Animora animation editor",

	["app.welcome.title"] = "Welcome to Animora",
	["app.welcome.body"] = "Select a rig in the viewport to start animating.",

	["settings.language"] = "Language",
	["settings.language.en"] = "English",
	["settings.language.id"] = "Bahasa Indonesia",

	["timeline.play"] = "Play",
	["timeline.pause"] = "Pause",
	["timeline.loop"] = "Loop",
	["timeline.frame"] = "Frame {frame}",

	["editor.noRig"] = "Select a rig (click any part of it) in the viewport to start animating.",
	["editor.rulerHint"] = "drag = scrub, wheel = zoom, Shift+wheel = pan",
	["editor.status.noRig"] = "No rig selected",
	["editor.status.rig"] = "{rig} - {joint}. Click a body part, then drag the rotate rings to set a keyframe.",
	["editor.status.notRig"] = "{name} has no Motor6D joints between its own parts, so it cannot be animated yet (skinned/bone rigs are not supported).",
	["editor.status.noJoint"] = "no joint selected",
	["editor.time"] = "{time} s - frame {frame}/{frames}",
	["editor.play"] = "Play",
	["editor.pause"] = "Pause",
	["editor.undo"] = "Undo",
	["editor.fps"] = "{fps} FPS",
	["editor.copy"] = "Copy",
	["editor.paste"] = "Paste",
	["editor.delete"] = "Delete",
	["editor.mirror"] = "Mirror",
	["editor.redo"] = "Redo",

	["shortcut.ran"] = "Shortcut: {name}",
	["shortcut.needsRig"] = "Shortcut {name} received, but open the Animora panel and select a rig first.",

	["spike.title"] = "Dev tests - Spike C: edit-mode preview, Spike A: export, Spike B: timeline",
	["spike.wave"] = "Wave",
	["spike.stop"] = "Stop",
	["spike.export"] = "Export wave",
	["spike.export.done"] = "Exported {name} ({keyframes} keyframes) to ServerStorage > AnimoraSaves > Exports and selected it. Right-click it > Save to Roblox to publish.",
	["spike.export.error"] = "Export failed: {reason}",
	["spike.status.idle"] = "Select a rig (or any part of it) in the viewport, then press a Wave button.",
	["spike.status.noRig"] = "No rig selected. Select a model that has Motor6D joints.",
	["spike.status.noArm"] = "This rig has no RightUpperArm (R15) or Right Arm (R6) joint.",
	["spike.status.playing"] = "Playing on {rig}: {fps} updates/sec. Press Stop before saving the place.",
	["spike.status.stopped"] = "Stopped. Rig pose restored.",
	["spike.status.noUpdates"] = "No frame updates in edit mode (Heartbeat is not firing). Please report this result.",

	["spike.timeline"] = "Timeline test",
	["timelineTest.auto"] = "Run auto test (6 s)",
	["timelineTest.running"] = "Running...",
	["timelineTest.hint"] = "Ruler: drag = scrub, wheel = zoom, Shift+wheel = pan",
	["timelineTest.live"] = "Live: {fps} fps, worst frame {worst} ms, last scrub {scrub} ms, {markers} markers drawn",
	["timelineTest.result"] = "Auto test: {fps} fps avg, worst frame {worst} ms, scrub avg {scrubAvg} ms / max {scrubMax} ms, up to {markers} markers",

	["export.success"] = 'Exported "{name}" to {location}',
	["export.error"] = "Export failed: {reason}",
}
