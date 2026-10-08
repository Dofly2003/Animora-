local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Translate = require(game:GetService("ReplicatedStorage").Animora.Core.Translate)

local function part1(part0: CFrame, rest0: CFrame, transform: CFrame, frame1: CFrame): CFrame
	return part0 * rest0 * transform * frame1:Inverse()
end

describe("Translate", function()
	it("moves Part1 by exactly the world delta, keeping its rotation", function()
		local part0 = CFrame.new(3, 2, -5) * CFrame.Angles(0, math.rad(40), 0)
		local rest0 = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(10), 0, math.rad(-20))
		local frame1 = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.rad(15), 0)
		local transform = CFrame.new(0.1, 0, 0.3) * CFrame.Angles(math.rad(25), math.rad(-10), 0)
		local delta = Vector3.new(1.5, -0.75, 2)

		local before = part1(part0, rest0, transform, frame1)
		local after = part1(part0, rest0, Translate.apply(transform, delta, part0, rest0), frame1)

		local moved = after.Position - before.Position
		expect((moved - delta).Magnitude < 1e-4).toBe(true)
		expect(after.Rotation:FuzzyEq(before.Rotation, 1e-4)).toBe(true)
	end)

	it("keeps the transform's rotation and only changes its position", function()
		local transform = CFrame.Angles(0, math.rad(30), 0)
		local moved = Translate.apply(transform, Vector3.new(0, 1, 0), CFrame.identity, CFrame.identity)
		expect(moved.Rotation:FuzzyEq(transform.Rotation, 1e-6)).toBe(true)
		expect((moved.Position - Vector3.new(0, 1, 0)).Magnitude < 1e-6).toBe(true)
	end)

	it("snaps drag distances to a step", function()
		expect(Translate.snap(0.26, 0.1)).toBeCloseTo(0.3, 6)
		expect(Translate.snap(-0.04, 0.1)).toBeCloseTo(0, 6)
		expect(Translate.snap(0.123, 0)).toBe(0.123)
	end)
end)
