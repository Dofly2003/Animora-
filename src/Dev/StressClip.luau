--!strict
-- Spike B test data: a clip with many tracks and keyframes to stress the timeline.

local Model = require(script.Parent.Parent.Core.Model)

local StressClip = {}

local EASINGS: { Model.EasingStyle } = { "Linear", "Sine", "Cubic", "Back", "Bounce", "Constant" }

-- Returns the clip plus its track names in display order.
function StressClip.build(trackCount: number, keysPerTrack: number, length: number): (Model.Clip, { string })
	local clip = Model.newClip("Animora Stress Test")
	clip.length = length
	local names = {}
	local random = Random.new(2026)
	for trackIndex = 1, trackCount do
		local name = string.format("Track%02d", trackIndex)
		table.insert(names, name)
		local track = Model.getOrCreateTrack(clip, name)
		for keyIndex = 0, keysPerTrack - 1 do
			local time = keyIndex * length / (keysPerTrack - 1)
			local value = CFrame.Angles(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1))
			local easing = EASINGS[random:NextInteger(1, #EASINGS)]
			-- Append directly: times are generated in order, so the list stays sorted.
			table.insert(track.keyframes, Model.newKeyframe(time, value, easing, "InOut"))
		end
	end
	return clip, names
end

return StressClip
