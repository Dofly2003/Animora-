--!strict
-- Bakes the camera track into per-frame data a game can play back (see CameraPlayer),
-- and writes it as the source of a ModuleScript. Baking keeps playback exactly like the
-- editor (orbit blend, easing, FOV) without shipping that logic to the game.
--
-- Data format (version 1):
--   { version = 1, fps, length, looped, root = { 12 numbers },
--     frames = { { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, fov }, ... } }
-- `root` is the rig root's CFrame at export, so a game can replay the shot around the
-- rig wherever it stands (CameraPlayer's `origin` option).

local CameraBake = {}

CameraBake.VERSION = 1

export type Data = {
	version: number,
	fps: number,
	length: number,
	looped: boolean,
	root: { number },
	frames: { { number } },
}

local function round(value: number): number
	return math.round(value * 10000) / 10000
end

local function components(value: CFrame): { number }
	local list = { value:GetComponents() }
	for index, number in list do
		list[index] = round(number)
	end
	return list
end

-- `sampleCamera(t)` and `sampleFov(t)` give the camera at time t (seconds).
function CameraBake.bake(
	sampleCamera: (number) -> CFrame,
	sampleFov: (number) -> number,
	length: number,
	fps: number,
	looped: boolean,
	root: CFrame
): Data
	local frames = {}
	local count = math.max(1, math.round(length * fps))
	for index = 0, count do
		local time = math.min(index / fps, length)
		local frame = components(sampleCamera(time))
		table.insert(frame, round(sampleFov(time)))
		table.insert(frames, frame)
	end
	return {
		version = CameraBake.VERSION,
		fps = fps,
		length = length,
		looped = looped,
		root = components(root),
		frames = frames,
	}
end

local function numberList(list: { number }): string
	local parts = table.create(#list)
	for index, number in list do
		parts[index] = string.format("%.4f", number):gsub("%.?0+$", "")
		if parts[index] == "-0" or parts[index] == "" then
			parts[index] = "0"
		end
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- Luau source for a ModuleScript returning `data`.
function CameraBake.toSource(data: Data, name: string): string
	local lines = {
		'-- Camera shot "' .. name .. '" exported by Animora. Play it from a LocalScript:',
		"--   local AnimoraCamera = require(game.ReplicatedStorage.AnimoraCamera)",
		"--   AnimoraCamera.play(require(path.to.this.module))",
		"return {",
		string.format("\tversion = %d,", data.version),
		string.format("\tfps = %d,", data.fps),
		string.format("\tlength = %s,", tostring(round(data.length))),
		string.format("\tlooped = %s,", tostring(data.looped)),
		"\troot = " .. numberList(data.root) .. ",",
		"\tframes = {",
	}
	for _, frame in data.frames do
		table.insert(lines, "\t\t" .. numberList(frame) .. ",")
	end
	table.insert(lines, "\t},")
	table.insert(lines, "}")
	return table.concat(lines, "\n") .. "\n"
end

return CameraBake
