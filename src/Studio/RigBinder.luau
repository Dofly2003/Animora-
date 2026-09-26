--!strict
-- Finds a rig's Motor6D joints. applyPose writes Motor6D.Transform, which only shows
-- while the game runs; edit-mode preview goes through Studio/Preview in "C0" mode
-- (see docs/spike-results.md, Spike C).

local RigBinder = {}
RigBinder.__index = RigBinder

export type RigBinder = typeof(setmetatable({} :: { rig: Model, joints: { [string]: Motor6D } }, RigBinder))

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

function RigBinder.isRig(instance: Instance): boolean
	return instance:IsA("Model") and instance:FindFirstChildWhichIsA("Motor6D", true) ~= nil
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
