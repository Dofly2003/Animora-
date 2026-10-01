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
		expect(table.concat(ids, ",")).toBe(
			"Idle,Walk,Run,Jump,Wave,ScaredIdle,ScaredWalk,ScaredRun,FlashlightExplore,"
				.. "KuntiFloat,KuntiChase,KuntiLunge,PocongHop,PocongLeap,TuyulRun,TuyulPeek,"
				.. "NiskalaIdle,NiskalaWalk,NiskalaRun,NiskalaJump"
		)
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

	it("builds Scared Walk as a slow crouched loop that scans both sides", function()
		local clip = build("ScaredWalk", R15)
		expect(clip.looped).toBe(true)
		expect(clip.length).toBeCloseTo(2.4, 4)
		local hip = clip.tracks.RightUpperLeg.keyframes
		expect(hip[1].value:FuzzyEq(hip[#hip].value, 1e-4)).toBe(true)

		local sawRight, sawLeft = false, false
		for _, keyframe in clip.tracks.Head.keyframes do
			local facing = keyframe.value:VectorToWorldSpace(Vector3.new(0, 0, -1))
			sawRight = sawRight or facing.X > 0.5
			sawLeft = sawLeft or facing.X < -0.5
		end
		expect(sawRight and sawLeft).toBe(true)
	end)

	it("builds Flashlight with the right arm raised and a sweep to both sides", function()
		local clip = build("FlashlightExplore", R15)
		expect(clip.looped).toBe(true)
		expect(clip.length).toBeCloseTo(2.8, 4)
		local hip = clip.tracks.RightUpperLeg.keyframes
		expect(hip[1].value:FuzzyEq(hip[#hip].value, 1e-4)).toBe(true)

		local sawRight, sawLeft = false, false
		for _, keyframe in clip.tracks.UpperTorso.keyframes do
			local facing = keyframe.value:VectorToWorldSpace(Vector3.new(0, 0, -1))
			sawRight = sawRight or facing.X > 0.3
			sawLeft = sawLeft or facing.X < -0.3
		end
		expect(sawRight and sawLeft).toBe(true)
		expect(#clip.tracks.RightUpperArm.keyframes).toBe(6)
	end)

	it("builds the ghost set with seamless loops", function()
		for _, id in { "KuntiFloat", "KuntiChase", "PocongHop", "TuyulRun", "TuyulPeek" } do
			local clip = build(id, R15)
			expect(clip.looped).toBe(true)
			for _, track in clip.tracks do
				local keys = track.keyframes
				expect(keys[1].value:FuzzyEq(keys[#keys].value, 1e-4)).toBe(true)
			end
		end
		for _, id in { "KuntiLunge", "PocongLeap" } do
			expect(build(id, R15).looped).toBe(false)
		end
	end)

	it("builds the NISKALA set with seamless loops and a glance back", function()
		for _, id in { "NiskalaIdle", "NiskalaWalk", "NiskalaRun" } do
			local clip = build(id, R15)
			expect(clip.looped).toBe(true)
			for _, track in clip.tracks do
				local keys = track.keyframes
				expect(keys[1].value:FuzzyEq(keys[#keys].value, 1e-4)).toBe(true)
			end
			local glanced = false
			for _, keyframe in clip.tracks.Head.keyframes do
				local facing = keyframe.value:VectorToWorldSpace(Vector3.new(0, 0, -1))
				glanced = glanced or facing.X < -0.4
			end
			expect(glanced).toBe(true)
		end
		local jump = build("NiskalaJump", R15)
		expect(jump.looped).toBe(false)
		expect(jump.length).toBeCloseTo(1.3, 4)
	end)

	it("keeps the pocong's legs bound together", function()
		local clip = build("PocongHop", R15)
		local right, left = clip.tracks.RightLowerLeg.keyframes, clip.tracks.LeftLowerLeg.keyframes
		for index, keyframe in right do
			local rightX = keyframe.value:ToEulerAnglesXYZ()
			local leftX = left[index].value:ToEulerAnglesXYZ()
			expect(math.abs(rightX - leftX) < 1e-3).toBe(true)
		end
	end)

	it("builds for R6 without knees and elbows", function()
		local clip = build("Run", R6)
		expect(clip.tracks["Right Leg"]).never.toBeNil()
		expect(clip.tracks.Torso).never.toBeNil() -- waist lean moved onto the root
		expect(clip.tracks.RightLowerLeg).toBeNil()
	end)
end)
