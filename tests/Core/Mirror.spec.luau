local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Mirror = require(game:GetService("ReplicatedStorage").Animora.Core.Mirror)

describe("Mirror.oppositeJoint", function()
	it("swaps R15 and R6 left/right names", function()
		expect(Mirror.oppositeJoint("LeftUpperArm")).toBe("RightUpperArm")
		expect(Mirror.oppositeJoint("Right Leg")).toBe("Left Leg")
	end)

	it("keeps center joints", function()
		expect(Mirror.oppositeJoint("Head")).toBe("Head")
	end)
end)

describe("Mirror.mirrorTransform", function()
	it("is its own inverse", function()
		local transform = CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 0.6, 0.9)
		local twice = Mirror.mirrorTransform(Mirror.mirrorTransform(transform))
		expect(twice.Position:FuzzyEq(transform.Position, 1e-5)).toBe(true)
		expect(twice.LookVector:FuzzyEq(transform.LookVector, 1e-5)).toBe(true)
	end)

	it("mirrors between joints with different rest orientations (R6 shoulders)", function()
		local rightRest = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
		local leftRest = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		-- Raise the right arm sideways: rotation about the torso's Z axis.
		local raiseInParent = CFrame.Angles(0, 0, math.rad(90))
		local rightTransform = rightRest.Rotation:Inverse() * raiseInParent * rightRest.Rotation

		local leftTransform = Mirror.mirrorJointTransform(rightTransform, rightRest, leftRest)
		local leftInParent = leftRest.Rotation * leftTransform * leftRest.Rotation:Inverse()
		-- The mirrored left arm raises sideways the other way: rotation of -90 degrees about Z.
		expect(leftInParent:FuzzyEq(CFrame.Angles(0, 0, math.rad(-90)), 1e-4)).toBe(true)
	end)

	it("negates X position", function()
		expect(Mirror.mirrorTransform(CFrame.new(2, 0, 0)).X).toBe(-2)
	end)
end)
