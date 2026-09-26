--!strict
-- Bakes a clip into one Linear keyframe per frame. Roblox Pose objects only support a
-- few easing styles (and flip In/Out), so exporting baked keys keeps the published
-- animation identical to Animora's preview for every easing style.

local Model = require(script.Parent.Model)
local Interpolate = require(script.Parent.Interpolate)

local Bake = {}

function Bake.bakeClip(clip: Model.Clip, fps: number?): Model.Clip
	local rate = fps or clip.fps
	local baked = Model.newClip(clip.name, rate)
	baked.length = clip.length
	baked.looped = clip.looped
	baked.priority = clip.priority

	local frameCount = math.max(1, math.round(clip.length * rate))
	for jointName, track in clip.tracks do
		if #track.keyframes > 0 then
			local bakedTrack = Model.getOrCreateTrack(baked, jointName)
			for frame = 0, frameCount do
				local time = math.min(frame / rate, clip.length)
				Model.setKeyframe(bakedTrack, Model.newKeyframe(time, Interpolate.sampleTrack(track, time), "Linear"))
			end
		end
	end
	return baked
end

return Bake
