--!strict
-- Names the kind of rig from its joints, for the status bar: "R15", "R6" or "Custom",
-- plus whether it uses AnimationConstraint joints (Roblox's Avatar Joint Upgrade).

local RigType = {}

export type Kind = "R15" | "R6" | "Custom"

-- `joints` maps each joint's name (its Part1) to its kind ("Motor6D" or "AnimationConstraint").
function RigType.classify(joints: { [string]: string }): (Kind, boolean)
	local constraint = false
	for _, kind in joints do
		constraint = constraint or kind == "AnimationConstraint"
	end
	if joints.LowerTorso and joints.UpperTorso and joints.Head then
		return "R15", constraint
	elseif joints.Torso and joints.Head and joints["Right Arm"] and joints["Left Leg"] then
		return "R6", constraint
	end
	return "Custom", constraint
end

return RigType
