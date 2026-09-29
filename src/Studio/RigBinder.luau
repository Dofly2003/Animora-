--!strict
-- Finds a rig's Motor6D joints. applyPose writes Motor6D.Transform, which only shows
-- while the game runs; edit-mode preview goes through Studio/Preview in "C0" mode
-- (see docs/spike-results.md, Spike C).

local RigBinder = {}
RigBinder.__index = RigBinder

export type RigBinder = typeof(setmetatable({} :: { rig: Model, joints: { [string]: Motor6D } }, RigBinder))

export type JointEntry = { name: string, depth: number }

-- Collects every Motor6D in the rig, keyed by the name of its Part1.
function RigBinder.new(rig: Model): RigBinder
	local joints: { [string]: Motor6D } = {}
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 then
			joints[descendant.Part1.Name] = descendant
		end
	end
	return setmetatable({ rig = rig, joints = joints }, RigBinder)
end

-- A rig is a model whose own parts are connected by Motor6Ds. A folder-like model
-- that only *contains* rigs (its Motor6Ds belong to child models) is not a rig.
function RigBinder.isRig(instance: Instance): boolean
	if not instance:IsA("Model") then
		return false
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 and descendant.Part1.Parent == instance then
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
function RigBinder.findRootPart(joints: { [string]: Motor6D }): BasePart?
	local driven: { [BasePart]: boolean } = {}
	for _, joint in joints do
		if joint.Part1 then
			driven[joint.Part1] = true
		end
	end
	for _, joint in joints do
		local part0 = joint.Part0
		if part0 and not driven[part0] then
			return part0
		end
	end
	return nil
end

-- Joints in tree order (parent before children, children sorted by name) with their
-- depth, for showing the rig hierarchy in the timeline.
function RigBinder.jointOrder(self: RigBinder): { JointEntry }
	local order: { JointEntry } = {}
	local childrenOf: { [BasePart]: { Motor6D } } = {}
	for _, joint in self.joints do
		local part0 = joint.Part0
		if part0 then
			childrenOf[part0] = childrenOf[part0] or {}
			table.insert(childrenOf[part0], joint)
		end
	end

	local visited: { [BasePart]: boolean } = {}
	local function visit(part: BasePart, depth: number)
		if visited[part] then
			return
		end
		visited[part] = true
		local children = childrenOf[part] or {}
		table.sort(children, function(a, b)
			return (a.Part1 :: BasePart).Name < (b.Part1 :: BasePart).Name
		end)
		for _, joint in children do
			local part1 = joint.Part1 :: BasePart
			table.insert(order, { name = part1.Name, depth = depth })
			visit(part1, depth + 1)
		end
	end

	local root = RigBinder.findRootPart(self.joints)
	if root then
		visit(root, 0)
	end
	return order
end

function RigBinder.applyPose(self: RigBinder, pose: { [string]: CFrame })
	for jointName, transform in pose do
		local joint = self.joints[jointName]
		if joint then
			joint.Transform = transform
		end
	end
end

function RigBinder.resetPose(self: RigBinder)
	for _, joint in self.joints do
		joint.Transform = CFrame.identity
	end
end

return RigBinder
