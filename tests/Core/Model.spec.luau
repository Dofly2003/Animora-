local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Model = require(game:GetService("ReplicatedStorage").Animora.Core.Model)

describe("Model.setKeyframe", function()
	it("keeps keyframes sorted by time", function()
		local clip = Model.newClip("Test")
		local track = Model.getOrCreateTrack(clip, "Head")
		Model.setKeyframe(track, Model.newKeyframe(1, CFrame.identity))
		Model.setKeyframe(track, Model.newKeyframe(0, CFrame.identity))
		Model.setKeyframe(track, Model.newKeyframe(0.5, CFrame.identity))

		expect(track.keyframes[1].time).toBe(0)
		expect(track.keyframes[2].time).toBe(0.5)
		expect(track.keyframes[3].time).toBe(1)
	end)

	it("replaces a keyframe at the same time", function()
		local clip = Model.newClip("Test")
		local track = Model.getOrCreateTrack(clip, "Head")
		Model.setKeyframe(track, Model.newKeyframe(1, CFrame.identity))
		Model.setKeyframe(track, Model.newKeyframe(1, CFrame.new(0, 1, 0)))

		expect(#track.keyframes).toBe(1)
		expect(track.keyframes[1].value.Y).toBe(1)
	end)
end)

describe("Model.snapToFrame", function()
	it("rounds to the nearest frame", function()
		local clip = Model.newClip("Test", 30)
		expect(Model.snapToFrame(clip, 0.51)).toBeCloseTo(0.5, 5)
	end)
end)
