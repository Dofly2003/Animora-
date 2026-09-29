local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Animora = game:GetService("ReplicatedStorage").Animora
local Session = require(Animora.Studio.Session)
local RigBinder = require(Animora.Studio.RigBinder)

local REST_C0 = CFrame.new(1, 0.5, 0)

-- Root -> Torso -> Arm, plus Root -> Head, built from plain Parts and Motor6Ds.
local function makeRig(): (Model, Motor6D)
	local model = Instance.new("Model")
	model.Name = "TestRig"
	local function part(name: string): Part
		local instance = Instance.new("Part")
		instance.Name = name
		instance.Parent = model
		return instance
	end
	local root, torso, arm, head = part("Root"), part("Torso"), part("Arm"), part("Head")
	root.Anchored = true
	local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame): Motor6D
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = c0
		motor.Parent = part0
		return motor
	end
	joint("RootJoint", root, torso, CFrame.identity)
	joint("Neck", root, head, CFrame.new(0, 1.5, 0))
	local shoulder = joint("Shoulder", torso, arm, REST_C0)
	model.Parent = workspace
	return model, shoulder
end

local rigs: { Model } = {}
afterEach(function()
	for _, rig in rigs do
		rig:Destroy()
	end
	table.clear(rigs)
end)

describe("RigBinder.jointOrder", function()
	it("lists joints parent-first with depth", function()
		local rig = makeRig()
		table.insert(rigs, rig)
		local order = RigBinder.new(rig):jointOrder()
		expect(#order).toBe(3)
		expect(order[1].name).toBe("Head")
		expect(order[1].depth).toBe(0)
		expect(order[2].name).toBe("Torso")
		expect(order[3].name).toBe("Arm")
		expect(order[3].depth).toBe(1)
	end)
end)

describe("Session", function()
	it("auto-keys a joint and poses the rig through C0", function()
		local rig, shoulder = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		session:setTime(0.5)

		local raised = CFrame.Angles(0, 0, math.rad(90))
		session:commitJoint("Arm", raised)

		local track = (session.clip :: any).tracks.Arm
		expect(#track.keyframes).toBe(1)
		expect(track.keyframes[1].time).toBeCloseTo(0.5, 5)
		expect(shoulder.C0:FuzzyEq(REST_C0 * raised, 1e-4)).toBe(true)
		session:destroy()
	end)

	it("undo removes the keyframe and redo brings it back", function()
		local rig, shoulder = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		session:commitJoint("Arm", CFrame.Angles(0, 0, 1))

		expect(session:undo()).toBe(true)
		expect((session.clip :: any).tracks.Arm).toBeNil()
		expect(shoulder.C0:FuzzyEq(REST_C0, 1e-4)).toBe(true)

		expect(session:redo()).toBe(true)
		expect(#(session.clip :: any).tracks.Arm.keyframes).toBe(1)
		session:destroy()
	end)

	it("restores the rest pose and clears the attribute when the rig is released", function()
		local rig, shoulder = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		session:commitJoint("Arm", CFrame.Angles(1, 0, 0))
		expect(shoulder:GetAttribute("AnimoraRestC0")).never.toBeNil()

		session:setRig(nil)
		expect(shoulder.C0:FuzzyEq(REST_C0, 1e-4)).toBe(true)
		expect(shoulder:GetAttribute("AnimoraRestC0")).toBeNil()
		session:destroy()
	end)

	it("keeps each rig's clip when switching rigs", function()
		local rigA = makeRig()
		local rigB = makeRig()
		table.insert(rigs, rigA)
		table.insert(rigs, rigB)
		local session = Session.new()
		session:setRig(rigA)
		session:commitJoint("Arm", CFrame.Angles(1, 0, 0))
		session:setRig(rigB)
		expect((session.clip :: any).tracks.Arm).toBeNil()
		session:setRig(rigA)
		expect(#(session.clip :: any).tracks.Arm.keyframes).toBe(1)
		session:destroy()
	end)
end)
