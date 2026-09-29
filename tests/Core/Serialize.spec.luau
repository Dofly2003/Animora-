local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local HttpService = game:GetService("HttpService")
local Animora = game:GetService("ReplicatedStorage").Animora
local Model = require(Animora.Core.Model)
local Serialize = require(Animora.Core.Serialize)

describe("Serialize", function()
	it("round-trips a clip through JSON", function()
		local clip = Model.newClip("Wave", 24)
		clip.length = 3
		clip.looped = true
		clip.priority = Enum.AnimationPriority.Movement
		local track = Model.getOrCreateTrack(clip, "RightUpperArm")
		local value = CFrame.new(0, 0.5, 0) * CFrame.Angles(0.1, 0.2, 0.3)
		Model.setKeyframe(track, Model.newKeyframe(0.5, value, "Sine", "InOut"))

		local json = HttpService:JSONEncode(Serialize.encodeClip(clip))
		local decoded = Serialize.decodeClip(HttpService:JSONDecode(json))
		expect(decoded).never.toBeNil()
		local result = decoded :: Model.Clip
		expect(result.name).toBe("Wave")
		expect(result.fps).toBe(24)
		expect(result.length).toBe(3)
		expect(result.looped).toBe(true)
		expect(result.priority).toBe(Enum.AnimationPriority.Movement)
		local keyframe = result.tracks.RightUpperArm.keyframes[1]
		expect(keyframe.time).toBe(0.5)
		expect(keyframe.easingStyle).toBe("Sine")
		expect(keyframe.easingDirection).toBe("InOut")
		expect(keyframe.value:FuzzyEq(value, 1e-5)).toBe(true)
	end)

	it("rejects data from an unknown version", function()
		expect(Serialize.decodeClip({ version = 999, tracks = {} })).toBeNil()
		expect(Serialize.decodeClip("not a clip")).toBeNil()
	end)
end)
