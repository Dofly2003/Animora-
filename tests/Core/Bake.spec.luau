local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Animora = game:GetService("ReplicatedStorage").Animora
local Model = require(Animora.Core.Model)
local Interpolate = require(Animora.Core.Interpolate)
local Bake = require(Animora.Core.Bake)

describe("Bake.bakeClip", function()
	local clip = Model.newClip("Test")
	clip.length = 1
	local track = Model.getOrCreateTrack(clip, "Head")
	Model.setKeyframe(track, Model.newKeyframe(0, CFrame.new(0, 0, 0), "Sine", "InOut"))
	Model.setKeyframe(track, Model.newKeyframe(1, CFrame.new(0, 10, 0)))

	it("creates one linear key per frame including both ends", function()
		local baked = Bake.bakeClip(clip, 10)
		expect(#baked.tracks.Head.keyframes).toBe(11)
		expect(baked.tracks.Head.keyframes[4].easingStyle).toBe("Linear")
	end)

	it("matches the original curve at every frame", function()
		local baked = Bake.bakeClip(clip, 10)
		for _, keyframe in baked.tracks.Head.keyframes do
			expect(keyframe.value.Y).toBeCloseTo(Interpolate.sampleTrack(track, keyframe.time).Y, 4)
		end
	end)
end)
