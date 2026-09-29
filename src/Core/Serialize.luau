--!strict
-- Converts a clip to and from plain tables (JSON-safe: numbers, strings, booleans,
-- arrays) so it can be stored in the place. CFrames are stored as their 12 components.

local Model = require(script.Parent.Model)

local Serialize = {}

Serialize.VERSION = 1

export type SavedKeyframe = { t: number, cf: { number }, e: string, d: string }
export type SavedClip = {
	version: number,
	id: string?,
	name: string,
	length: number,
	fps: number,
	looped: boolean,
	priority: string,
	tracks: { [string]: { SavedKeyframe } },
}

function Serialize.encodeClip(clip: Model.Clip): SavedClip
	local tracks = {}
	for name, track in clip.tracks do
		local keyframes = {}
		for index, keyframe in track.keyframes do
			keyframes[index] = {
				t = keyframe.time,
				cf = { keyframe.value:GetComponents() },
				e = keyframe.easingStyle,
				d = keyframe.easingDirection,
			}
		end
		tracks[name] = keyframes
	end
	return {
		version = Serialize.VERSION,
		id = clip.id,
		name = clip.name,
		length = clip.length,
		fps = clip.fps,
		looped = clip.looped,
		priority = clip.priority.Name,
		tracks = tracks,
	}
end

-- Returns nil when the data is not a clip this version understands.
function Serialize.decodeClip(data: any): Model.Clip?
	if type(data) ~= "table" or data.version ~= Serialize.VERSION or type(data.tracks) ~= "table" then
		return nil
	end
	local clip = Model.newClip(tostring(data.name or "Animation"), tonumber(data.fps) or 30)
	clip.id = if type(data.id) == "string" then data.id else nil
	clip.length = tonumber(data.length) or 2
	clip.looped = data.looped == true
	local ok, priority = pcall(function()
		return (Enum.AnimationPriority :: any)[data.priority]
	end)
	if ok and priority then
		clip.priority = priority
	end
	for name, keyframes in data.tracks do
		if type(name) == "string" and type(keyframes) == "table" then
			local track = Model.getOrCreateTrack(clip, name)
			for _, saved in keyframes do
				if type(saved) == "table" and type(saved.cf) == "table" and #saved.cf == 12 then
					Model.setKeyframe(
						track,
						Model.newKeyframe(
							tonumber(saved.t) or 0,
							CFrame.new(table.unpack(saved.cf)),
							saved.e :: any,
							saved.d :: any
						)
					)
				end
			end
			if #track.keyframes == 0 then
				clip.tracks[name] = nil
			end
		end
	end
	return clip
end

return Serialize
