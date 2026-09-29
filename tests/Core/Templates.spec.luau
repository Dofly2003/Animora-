local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Templates = require(game:GetService("ReplicatedStorage").Animora.Core.Templates)

local R15 = {
	LowerTorso = true,
	UpperTorso = true,
	Head = true,
	RightUpperArm = true,
	LeftUpperArm = true,
	RightLowerArm = true,
	LeftLowerArm = true,
	RightUpperLeg = true,
	LeftUpperLeg = true,
	RightLowerLeg = true,
	LeftLowerLeg = true,
}
local R6 =
	{ Torso = true, Head = true, ["Right Arm"] = true, ["Left Arm"] = true, ["Right Leg"] = true, ["Left Leg"] = true }

local function build(id: string, joints: { [string]: boolean })
	return Templates.build(Templates.get(id) :: any, function(name)
		return joints[name] == true
	end, function()
		return CFrame.identity
	end, 30)
end

describe("Templates", function()
	it("offers the starter animations", function()
		local ids = {}
		for _, template in Templates.list() do
			table.insert(ids, template.id)
		end
		expect(table.concat(ids, ",")).toBe("Idle,Walk,Run,Jump,Wave,ScaredIdle,ScaredRun")
	end)

	it("builds Walk for R15 with legs swinging in opposite directions", function()
		local clip = build("Walk", R15)
		expect(clip.looped).toBe(true)
		expect(clip.length).toBe(1)
		local right = clip.tracks.RightUpperLeg.keyframes[1].value
		local left = clip.tracks.LeftUpperLeg.keyframes[1].value
		expect(right:FuzzyEq(CFrame.Angles(math.rad(28), 0, 0), 1e-4)).toBe(true)
		expect(left:FuzzyEq(CFrame.Angles(math.rad(-28), 0, 0), 1e-4)).toBe(true)
		expect(clip.tracks.RightLowerLeg).never.toBeNil()
	end)

	it("mirrors left-side sideways rotation so both arms move away from the body", function()
		local clip = build("Idle", R15)
		local right = clip.tracks.RightUpperArm.keyframes[1].value
		local left = clip.tracks.LeftUpperArm.keyframes[1].value
		-- An arm hanging down (-Y) tilted outwards: right goes to +X, left to -X.
		expect(right:VectorToWorldSpace(Vector3.new(0, -1, 0)).X > 0).toBe(true)
		expect(left:VectorToWorldSpace(Vector3.new(0, -1, 0)).X < 0).toBe(true)
	end)

	it("builds Scared Idle as a seamless trembling loop with head glances", function()
		local clip = build("ScaredIdle", R15)
		expect(clip.looped).toBe(true)
		expect(clip.length).toBe(4)
		expect(clip.priority).toBe(Enum.AnimationPriority.Idle)

		-- Many tremble keys on the shoulders, and the loop starts and ends on the same pose.
		local shoulder = clip.tracks.RightUpperArm.keyframes
		expect(#shoulder > 40).toBe(true)
		expect(shoulder[1].value:FuzzyEq(shoulder[#shoulder].value, 1e-4)).toBe(true)

		-- The head looks right (face towards +X) and later left (-X).
		local head = clip.tracks.Head.keyframes
		local sawRight, sawLeft = false, false
		for _, keyframe in head do
			local facing = keyframe.value:VectorToWorldSpace(Vector3.new(0, 0, -1))
			sawRight = sawRight or facing.X > 0.5
			sawLeft = sawLeft or facing.X < -0.5
		end
		expect(sawRight).toBe(true)
		expect(sawLeft).toBe(true)
	end)

	it("builds Scared Run with alternating strides and a look back", function()
		local clip = build("ScaredRun", R15)
		expect(clip.looped).toBe(true)
		expect(clip.length).toBeCloseTo(1.2, 4)

		local hip = clip.tracks.RightUpperLeg.keyframes
		local first, last = hip[1].value, hip[#hip].value
		expect(first:FuzzyEq(last, 1e-4)).toBe(true) -- seamless loop

		local lookedBack = false
		for _, keyframe in clip.tracks.Head.keyframes do
			local facing = keyframe.value:VectorToWorldSpace(Vector3.new(0, 0, -1))
			lookedBack = lookedBack or facing.X < -0.9
		end
		expect(lookedBack).toBe(true)
	end)

	it("builds for R6 without knees and elbows", function()
		local clip = build("Run", R6)
		expect(clip.tracks["Right Leg"]).never.toBeNil()
		expect(clip.tracks.Torso).never.toBeNil() -- waist lean moved onto the root
		expect(clip.tracks.RightLowerLeg).toBeNil()
	end)
end)
