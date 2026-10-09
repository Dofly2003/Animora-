local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Templates = require(game:GetService("ReplicatedStorage").Animora.Core.Templates)
local Model = require(game:GetService("ReplicatedStorage").Animora.Core.Model)

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
		expect(table.concat(ids, ",")).toBe("Idle,Walk,Run,Jump,Wave")
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

	it("builds for R6 without knees and elbows", function()
		local clip = build("Run", R6)
		expect(clip.tracks["Right Leg"]).never.toBeNil()
		expect(clip.tracks.Torso).never.toBeNil() -- waist lean moved onto the root
		expect(clip.tracks.RightLowerLeg).toBeNil()
	end)
	it("places the camera keys of a cutscene template around the rig", function()
		local template = {
			id = "TestShot",
			name = "Test Shot",
			looped = false,
			priority = Enum.AnimationPriority.Action,
			keys = { { time = 0, pose = { root = { z = 0 } } }, { time = 1, pose = { root = { z = -2 } } } },
			camera = {
				{ time = 0, position = Vector3.new(0, 2, -10), lookAt = Vector3.new(0, 1, 0), fov = 60 },
				{ time = 2, position = Vector3.new(4, 2, -8), lookAt = Vector3.new(0, 1, 0), fov = 40 },
			},
		}
		local rootFrame = CFrame.new(10, 3, -20) * CFrame.Angles(0, math.rad(90), 0)
		local clip = Templates.build(template :: any, function(name)
			return R15[name] == true
		end, function()
			return CFrame.identity
		end, 30, rootFrame)
		expect(clip.length).toBeCloseTo(2, 4) -- the camera can run longer than the body
		local first = clip.tracks[Model.CAMERA_TRACK].keyframes[1].value
		local expected = rootFrame:PointToWorldSpace(Vector3.new(0, 2, -10))
		expect((first.Position - expected).Magnitude < 1e-3).toBe(true)
		expect(Model.fovFrom(clip.tracks[Model.CAMERA_FOV_TRACK].keyframes[2].value)).toBeCloseTo(40, 3)
		-- Without the rig's root frame the camera is left out.
		local bodyOnly = Templates.build(template :: any, function(name)
			return R15[name] == true
		end, function()
			return CFrame.identity
		end, 30)
		expect(bodyOnly.tracks[Model.CAMERA_TRACK]).toBeNil()
	end)
end)
