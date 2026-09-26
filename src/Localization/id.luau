--!strict
-- Bahasa Indonesia. Keys must match en.luau; missing keys fall back to English.
return {
	["toolbar.open.tooltip"] = "Buka editor animasi Animora",

	["app.welcome.title"] = "Selamat datang di Animora",
	["app.welcome.body"] = "Pilih rig di viewport untuk mulai menganimasikan.",

	["settings.language"] = "Bahasa",
	["settings.language.en"] = "English",
	["settings.language.id"] = "Bahasa Indonesia",

	["timeline.play"] = "Putar",
	["timeline.pause"] = "Jeda",
	["timeline.loop"] = "Ulang",
	["timeline.frame"] = "Frame {frame}",

	["spike.title"] = "Tes developer - Spike C: preview di mode edit, Spike A: ekspor",
	["spike.wave"] = "Lambai",
	["spike.stop"] = "Stop",
	["spike.export"] = "Ekspor lambaian",
	["spike.export.done"] = "{name} ({keyframes} keyframe) diekspor ke ServerStorage > AnimoraSaves > Exports dan sudah dipilih. Klik kanan > Save to Roblox untuk mem-publish.",
	["spike.export.error"] = "Ekspor gagal: {reason}",
	["spike.status.idle"] = "Pilih rig (atau salah satu part-nya) di viewport, lalu tekan tombol Lambai.",
	["spike.status.noRig"] = "Belum ada rig yang dipilih. Pilih model yang punya joint Motor6D.",
	["spike.status.noArm"] = "Rig ini tidak punya joint RightUpperArm (R15) atau Right Arm (R6).",
	["spike.status.playing"] = "Memutar di {rig}: {fps} update/detik. Tekan Stop sebelum menyimpan place.",
	["spike.status.stopped"] = "Berhenti. Pose rig sudah dikembalikan.",
	["spike.status.noUpdates"] = "Tidak ada update frame di mode edit (Heartbeat tidak berjalan). Tolong laporkan hasil ini.",

	["export.success"] = '"{name}" berhasil diekspor ke {location}',
	["export.error"] = "Ekspor gagal: {reason}",
}
