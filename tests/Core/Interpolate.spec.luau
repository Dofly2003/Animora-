local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Animora = game:GetService("ReplicatedStorage").Animora
local Model = require(Animora.Core.Model)
local Interpolate = require(Animora.Core.Interpolate)

describe("Interpolate.sampleTrack", function()
	local track = { jointName = "Head", keyframes = {} }
	Model.setKeyframe(track, Model.newKeyframe(0, CFrame.new(0, 0, 0)))
	Model.setKeyframe(track, Model.newKeyframe(1, CFrame.new(0, 10, 0)))

	it("interpolates linearly between keyframes", function()
		expect(Interpolate.sampleTrack(track, 0.5).Y).toBeCloseTo(5, 5)
	end)

	it("clamps before the first and after the last keyframe", function()
		expect(Interpolate.sampleTrack(track, -1).Y).toBe(0)
		expect(Interpolate.sampleTrack(track, 2).Y).toBe(10)
	end)

	it("holds the previous value with Constant easing", function()
		local constant = { jointName = "Head", keyframes = {} }
		Model.setKeyframe(constant, Model.newKeyframe(0, CFrame.new(0, 0, 0), "Constant"))
		Model.setKeyframe(constant, Model.newKeyframe(1, CFrame.new(0, 10, 0)))
		expect(Interpolate.sampleTrack(constant, 0.9).Y).toBe(0)
	end)
end)
