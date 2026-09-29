--!strict
-- Finds a rig's joints. Two joint kinds are supported, behind one Joint shape:
--   Motor6D             classic R6/R15 and most custom rigs
--   AnimationConstraint avatars using Roblox's "Avatar Joint Upgrade" (joint plus a
--                       BallSocketConstraint, attachments instead of C0/C1)
-- Both follow Part1 * frame1 = Part0 * frame0 * Transform, where frame0/frame1 are
-- C0/C1 for a Motor6D and Attachment0/Attachment1.CFrame for an AnimationConstraint,
-- so poses, export and mirroring treat them the same way.

local RigBinder = {}
RigBinder.__index = RigBinder

export type JointKind = "Motor6D" | "AnimationConstraint"

export type Joint = {
	name: string, -- name of Part1; the joint's key everywhere in Animora
	kind: JointKind,
	instance: Instance, -- the Motor6D or AnimationConstraint
	Part0: BasePart,
	Part1: BasePart,
}

export type RigBinder = typeof(setmetatable({} :: { rig: Model, joints: { [string]: Joint } }, RigBinder))

export type JointEntry = { name: string, depth: number }

-- Reads a joint instance into a Joint, or nil when it is not a usable joint.
local function readJoint(instance: Instance): Joint?
	if instance:IsA("Motor6D") then
		local part0, part1 = instance.Part0, instance.Part1
		if part0 and part1 then
			return { name = part1.Name, kind = "Motor6D", instance = instance, Part0 = part0, Part1 = part1 }
		end
	elseif instance:IsA("AnimationConstraint") then
		local attachment0, attachment1 = instance.Attachment0, instance.Attachment1
		local part0 = attachment0 and attachment0.Parent
		local part1 = attachment1 and attachment1.Parent
		if part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") then
			return {
				name = part1.Name,
				kind = "AnimationConstraint",
				instance = instance,
				Part0 = part0,
				Part1 = part1,
			}
		end
	end
	return nil
end

-- Collects every joint in the rig, keyed by the name of its Part1. A Motor6D wins
-- over an AnimationConstraint on the same part.
function RigBinder.new(rig: Model): RigBinder
	local joints: { [string]: Joint } = {}
	for _, descendant in rig:GetDescendants() do
		local joint = readJoint(descendant)
		if joint then
			local existing = joints[joint.name]
			if not existing or (existing.kind ~= "Motor6D" and joint.kind == "Motor6D") then
				joints[joint.name] = joint
			end
		end
	end
	return setmetatable({ rig = rig, joints = joints }, RigBinder)
end

-- Rest-relative frame on Part0 (C0 or Attachment0.CFrame), as currently stored.
function RigBinder.frame0(joint: Joint): CFrame
	if joint.kind == "Motor6D" then
		return (joint.instance :: Motor6D).C0
	end
	return ((joint.instance :: AnimationConstraint).Attachment0 :: Attachment).CFrame
end

-- Frame on Part1 (C1 or Attachment1.CFrame).
function RigBinder.frame1(joint: Joint): CFrame
	if joint.kind == "Motor6D" then
		return (joint.instance :: Motor6D).C1
	end
	return ((joint.instance :: AnimationConstraint).Attachment1 :: Attachment).CFrame
end

-- A rig is a model whose own parts are connected by joints. A folder-like model that
-- only *contains* rigs (its joints belong to child models) is not a rig.
function RigBinder.isRig(instance: Instance): boolean
	if not instance:IsA("Model") then
		return false
	end
	for _, descendant in instance:GetDescendants() do
		local joint = readJoint(descendant)
		if joint and joint.Part1.Parent == instance then
			return true
		end
	end
	return false
end

-- Rigs directly inside a container (used when Studio selects a whole group model).
local function childRigs(container: Instance): { Model }
	local rigs = {}
	for _, child in container:GetChildren() do
		if RigBinder.isRig(child) then
			table.insert(rigs, child :: Model)
		end
	end
	return rigs
end

-- Finds the rig for a selected instance: the closest rig model above it, or, when a
-- group model holding exactly one rig is selected, that rig.
function RigBinder.findRig(instance: Instance?): Model?
	local current = instance
	while current and current ~= workspace and current ~= game do
		if RigBinder.isRig(current) then
			return current :: Model
		end
		current = current.Parent
	end
	if instance and instance:IsA("Model") then
		local rigs = childRigs(instance)
		if #rigs == 1 then
			return rigs[1]
		end
	end
	return nil
end

-- The root of the joint tree: a part that drives joints but is not driven by any
-- (HumanoidRootPart on R6/R15, whatever the root is on custom rigs).
function RigBinder.findRootPart(joints: { [string]: Joint }): BasePart?
	local driven: { [BasePart]: boolean } = {}
	for _, joint in joints do
		driven[joint.Part1] = true
	end
	for _, joint in joints do
		if not driven[joint.Part0] then
			return joint.Part0
		end
	end
	return nil
end

-- Joints in tree order (parent before children, children sorted by name) with their
-- depth, for showing the rig hierarchy in the timeline and posing parents first.
function RigBinder.jointOrder(self: RigBinder): { JointEntry }
	local order: { JointEntry } = {}
	local childrenOf: { [BasePart]: { Joint } } = {}
	for _, joint in self.joints do
		childrenOf[joint.Part0] = childrenOf[joint.Part0] or {}
		table.insert(childrenOf[joint.Part0], joint)
	end

	local visited: { [BasePart]: boolean } = {}
	local function visit(part: BasePart, depth: number)
		if visited[part] then
			return
		end
		visited[part] = true
		local children = childrenOf[part] or {}
		table.sort(children, function(a, b)
			return a.name < b.name
		end)
		for _, joint in children do
			table.insert(order, { name = joint.name, depth = depth })
			visit(joint.Part1, depth + 1)
		end
	end

	local root = RigBinder.findRootPart(self.joints)
	if root then
		visit(root, 0)
	end
	return order
end

-- Writes Transform on every joint (only visible while the game runs).
function RigBinder.applyPose(self: RigBinder, pose: { [string]: CFrame })
	for jointName, transform in pose do
		local joint = self.joints[jointName]
		if joint then
			(joint.instance :: any).Transform = transform
		end
	end
end

function RigBinder.resetPose(self: RigBinder)
	for _, joint in self.joints do
		(joint.instance :: any).Transform = CFrame.identity
	end
end

return RigBinder
