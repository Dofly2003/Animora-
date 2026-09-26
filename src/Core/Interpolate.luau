--!strict
-- Computes a track's pose at any time t using per-keyframe easing.

local TweenService = game:GetService("TweenService")

local Model = require(script.Parent.Model)

local Interpolate = {}

-- Maps an eased alpha for 0..1 progress. "Constant" holds the previous keyframe.
function Interpolate.ease(alpha: number, style: Model.EasingStyle, direction: Model.EasingDirection): number
	if style == "Constant" then
		return 0
	end
	return TweenService:GetValue(alpha, (Enum.EasingStyle :: any)[style], (Enum.EasingDirection :: any)[direction])
end

-- Returns the joint transform of `track` at `time` (identity when the track is empty).
function Interpolate.sampleTrack(track: Model.Track, time: number): CFrame
	local keyframes = track.keyframes
	local count = #keyframes
	if count == 0 then
		return CFrame.identity
	end
	if time <= keyframes[1].time then
		return keyframes[1].value
	end
	if time >= keyframes[count].time then
		return keyframes[count].value
	end

	for index = 1, count - 1 do
		local from = keyframes[index]
		local to = keyframes[index + 1]
		if time >= from.time and time < to.time then
			local alpha = (time - from.time) / (to.time - from.time)
			local eased = Interpolate.ease(alpha, from.easingStyle, from.easingDirection)
			return from.value:Lerp(to.value, eased)
		end
	end

	return keyframes[count].value
end

-- Samples every track of the clip; returns { [jointName]: CFrame }.
function Interpolate.sampleClip(clip: Model.Clip, time: number): { [string]: CFrame }
	local pose = {}
	for jointName, track in clip.tracks do
		pose[jointName] = Interpolate.sampleTrack(track, time)
	end
	return pose
end

return Interpolate
