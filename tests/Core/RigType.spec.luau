local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RigType = require(game:GetService("ReplicatedStorage").Animora.Core.RigType)

describe("RigType", function()
	it("recognises R15 rigs", function()
		local kind, constraint = RigType.classify({
			LowerTorso = "Motor6D",
			UpperTorso = "Motor6D",
			Head = "Motor6D",
			RightHand = "Motor6D",
		})
		expect(kind).toBe("R15")
		expect(constraint).toBe(false)
	end)

	it("recognises R6 rigs", function()
		local kind = RigType.classify({
			Torso = "Motor6D",
			Head = "Motor6D",
			["Right Arm"] = "Motor6D",
			["Left Arm"] = "Motor6D",
			["Right Leg"] = "Motor6D",
			["Left Leg"] = "Motor6D",
		})
		expect(kind).toBe("R6")
	end)

	it("flags AnimationConstraint avatars", function()
		local kind, constraint = RigType.classify({
			LowerTorso = "AnimationConstraint",
			UpperTorso = "AnimationConstraint",
			Head = "AnimationConstraint",
		})
		expect(kind).toBe("R15")
		expect(constraint).toBe(true)
	end)

	it("calls anything else a custom rig", function()
		local kind = RigType.classify({ Body = "Motor6D", Tail = "Motor6D" })
		expect(kind).toBe("Custom")
	end)
end)
