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

	["spike.title"] = "Dev test - Spike C: edit-mode preview",
	["spike.waveTransform"] = "Wave (Transform)",
	["spike.waveC0"] = "Wave (C0)",
	["spike.stop"] = "Stop",
	["spike.status.idle"] = "Select a rig (or any part of it) in the viewport, then press a Wave button.",
	["spike.status.noRig"] = "No rig selected. Select a model that has Motor6D joints.",
	["spike.status.noArm"] = "This rig has no RightUpperArm (R15) or Right Arm (R6) joint.",
	["spike.status.playing"] = "Playing ({mode}) on {rig}: {fps} updates/sec",
	["spike.status.stopped"] = "Stopped. Rig pose restored.",
	["spike.status.noUpdates"] = "No frame updates in edit mode (Heartbeat is not firing). Please report this result.",

	["export.success"] = 'Exported "{name}" to {location}',
	["export.error"] = "Export failed: {reason}",
}
