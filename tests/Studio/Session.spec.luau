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

-- Same shape as an "Avatar Joint Upgrade" rig: AnimationConstraints between
-- attachments instead of Motor6Ds. Returns the rig and its Arm part.
local function makeConstraintRig(kinematic: boolean?): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "ConstraintRig"
	local function part(name: string, cframe: CFrame): Part
		local instance = Instance.new("Part")
		instance.Name = name
		instance.Size = Vector3.new(1, 1, 1)
		instance.CFrame = cframe
		instance.Parent = model
		return instance
	end
	local root = part("Root", CFrame.new(0, 10, 0))
	root.Anchored = true
	local arm = part("Arm", CFrame.new(1, 10, 0))
	local hand = part("Hand", CFrame.new(1, 9, 0))
	local function link(name: string, part0: BasePart, offset0: CFrame, part1: BasePart, offset1: CFrame)
		local attachment0 = Instance.new("Attachment")
		attachment0.CFrame = offset0
		attachment0.Parent = part0
		local attachment1 = Instance.new("Attachment")
		attachment1.CFrame = offset1
		attachment1.Parent = part1
		local constraint = Instance.new("AnimationConstraint")
		constraint.Name = name
		constraint.Attachment0 = attachment0
		constraint.Attachment1 = attachment1
		if kinematic then
			-- Kinematic constraints make the body one rigid assembly, like Motor6Ds.
			(constraint :: any).IsKinematic = true
		end
		constraint.Parent = part1
	end
	-- Shoulder pivot at (1, 10.5, 0); wrist pivot at (1, 9.5, 0).
	link("Shoulder", root, CFrame.new(1, 0.5, 0), arm, CFrame.new(0, 0.5, 0))
	link("Wrist", arm, CFrame.new(0, -0.5, 0), hand, CFrame.new(0, 0.5, 0))
	model.Parent = workspace
	return model, arm
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

describe("RigBinder.findRig", function()
	it("finds the rig from one of its parts", function()
		local rig = makeRig()
		table.insert(rigs, rig)
		expect(RigBinder.findRig(rig:FindFirstChild("Arm"))).toBe(rig)
	end)

	it("does not treat a group model holding rigs as a rig", function()
		local group = Instance.new("Model")
		group.Name = "Rigs"
		local rigA = makeRig()
		local rigB = makeRig()
		rigA.Parent = group
		rigB.Parent = group
		group.Parent = workspace
		table.insert(rigs, group :: any)

		expect(RigBinder.isRig(group)).toBe(false)
		expect(RigBinder.findRig(group)).toBeNil()
		expect(RigBinder.findRig(rigB:FindFirstChild("Head"))).toBe(rigB)
	end)

	it("picks the single rig inside a selected group model", function()
		local group = Instance.new("Model")
		local rig = makeRig()
		rig.Parent = group
		group.Parent = workspace
		table.insert(rigs, group :: any)
		expect(RigBinder.findRig(group)).toBe(rig)
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

	it("deletes selected keyframes and undo restores them", function()
		local rig = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		session:setTime(0)
		session:commitJoint("Arm", CFrame.Angles(0, 0, 0.5))
		session:setTime(1)
		session:commitJoint("Arm", CFrame.Angles(0, 0, 1))

		session:setKeySelection({ { joint = "Arm", time = 1 } })
		expect(session:deleteSelectedKeys()).toBe(1)
		expect(#(session.clip :: any).tracks.Arm.keyframes).toBe(1)
		expect(#session.selectedKeys).toBe(0)

		session:undo()
		expect(#(session.clip :: any).tracks.Arm.keyframes).toBe(2)
		session:destroy()
	end)

	it("moves selected keyframes by whole frames", function()
		local rig = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		session:setTime(0.5)
		session:commitJoint("Arm", CFrame.Angles(0, 0, 1))
		session:setKeySelection({ { joint = "Arm", time = 0.5 } })

		session:moveSelectedKeys(0.26) -- 7.8 frames at 30 FPS -> 8 frames
		local keyframes = (session.clip :: any).tracks.Arm.keyframes
		expect(#keyframes).toBe(1)
		expect(keyframes[1].time).toBeCloseTo(0.5 + 8 / 30, 4)
		expect(session.selectedKeys[1].time).toBeCloseTo(keyframes[1].time, 4)
		session:destroy()
	end)

	it("copies a pose and pastes it at another time", function()
		local rig = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		local pose = CFrame.Angles(0.3, 0, 0)
		session:commitJoint("Arm", pose)
		expect(session:copy()).toBe(1)

		session:setTime(1.5)
		expect(session:paste()).toBe(1)
		local keyframes = (session.clip :: any).tracks.Arm.keyframes
		expect(#keyframes).toBe(2)
		expect(keyframes[2].time).toBeCloseTo(1.5, 4)
		expect(keyframes[2].value:FuzzyEq(pose, 1e-4)).toBe(true)
		session:destroy()
	end)

	it("jumps between keyframes and steps frames", function()
		local rig = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		session:setTime(0.5)
		session:commitJoint("Arm", CFrame.Angles(0, 0, 1))
		session:setTime(0)

		session:jumpToKey(1)
		expect(session.time).toBeCloseTo(0.5, 4)
		session:stepFrame(3)
		expect(session.time).toBeCloseTo(0.6, 4)
		session:jumpToKey(-1)
		expect(session.time).toBeCloseTo(0.5, 4)
		session:destroy()
	end)

	it("cycles the frame rate 30 -> 60 -> 24", function()
		local rig = makeRig()
		table.insert(rigs, rig)
		local session = Session.new()
		session:setRig(rig)
		expect(session:cycleFps()).toBe(60)
		expect(session:cycleFps()).toBe(24)
		session:destroy()
	end)

	it("poses AnimationConstraint rigs by placing parts, children following", function()
		local rig, arm = makeConstraintRig()
		table.insert(rigs, rig)
		local hand = rig:FindFirstChild("Hand") :: BasePart
		local armRest, handRest = arm.CFrame, hand.CFrame

		expect(RigBinder.isRig(rig)).toBe(true)
		local session = Session.new()
		session:setRig(rig)
		expect(#session.jointOrder).toBe(2)

		-- Swing the arm 90 degrees about Z around the shoulder pivot.
		session:commitJoint("Arm", CFrame.Angles(0, 0, math.rad(90)))
		expect(arm.CFrame.Position:FuzzyEq(Vector3.new(1.5, 10.5, 0), 1e-3)).toBe(true)
		-- The hand is re-placed from the moved arm, not left behind.
		expect(hand.CFrame.Position:FuzzyEq(Vector3.new(2.5, 10.5, 0), 1e-3)).toBe(true)

		session:setRig(nil)
		expect(arm.CFrame:FuzzyEq(armRest, 1e-3)).toBe(true)
		expect(hand.CFrame:FuzzyEq(handRest, 1e-3)).toBe(true)
		session:destroy()
	end)

	it("poses rigid (kinematic) AnimationConstraint rigs through Attachment0", function()
		local rig, arm = makeConstraintRig(true)
		table.insert(rigs, rig)
		local hand = rig:FindFirstChild("Hand") :: BasePart
		local shoulderAttachment = (arm:FindFirstChild("Shoulder") :: any).Attachment0 :: Attachment
		local attachmentRest = shoulderAttachment.CFrame

		local session = Session.new()
		session:setRig(rig)
		session:commitJoint("Arm", CFrame.Angles(0, 0, math.rad(90)))
		expect(arm.CFrame.Position:FuzzyEq(Vector3.new(1.5, 10.5, 0), 1e-3)).toBe(true)
		expect(hand.CFrame.Position:FuzzyEq(Vector3.new(2.5, 10.5, 0), 1e-3)).toBe(true)

		session:setRig(nil)
		expect(shoulderAttachment.CFrame:FuzzyEq(attachmentRest, 1e-4)).toBe(true)
		expect(shoulderAttachment:GetAttribute("AnimoraRestC0")).toBeNil()
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
