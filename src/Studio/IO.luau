--!strict
-- Converts between Animora clips and Roblox KeyframeSequence instances.
-- Phase 2 tasks: import (KeyframeSequence -> Clip) and full easing mapping.
-- Spike A (week 1) validates export + publish; see docs/spike-results.md.

local Model = require(script.Parent.Parent.Core.Model)

local IO = {}

local POSE_EASING_STYLE: { [Model.EasingStyle]: Enum.PoseEasingStyle } = {
	Linear = Enum.PoseEasingStyle.Linear,
	Constant = Enum.PoseEasingStyle.Constant,
	Cubic = Enum.PoseEasingStyle.Cubic,
	Elastic = Enum.PoseEasingStyle.Elastic,
	Bounce = Enum.PoseEasingStyle.Bounce,
}

-- Builds the Pose hierarchy for one keyframe by walking the rig's joint tree
-- (Pose objects must be nested parent -> child like the rig's parts). Like the
-- built-in Animation Editor, only keyed joints and the chain of parents leading
-- to them are written; untouched branches are left out to keep the asset small.
local function buildPoseTree(
	rootPart: BasePart,
	joints: { [string]: Motor6D },
	valuesByJoint: { [string]: Model.Keyframe }
): Pose
	local function build(part: BasePart): Pose?
		local children: { Pose } = {}
		for _, joint in joints do
			if joint.Part0 == part and joint.Part1 then
				local child = build(joint.Part1)
				if child then
					table.insert(children, child)
				end
			end
		end

		local keyframe = valuesByJoint[part.Name]
		if not keyframe and #children == 0 then
			return nil
		end

		local pose = Instance.new("Pose")
		pose.Name = part.Name
		if keyframe then
			pose.CFrame = keyframe.value
			pose.EasingStyle = POSE_EASING_STYLE[keyframe.easingStyle] or Enum.PoseEasingStyle.Linear
			pose.EasingDirection = (Enum.PoseEasingDirection :: any)[keyframe.easingDirection]
		else
			pose.Weight = 0
		end
		for _, child in children do
			child.Parent = pose
		end
		return pose
	end

	local rootPose = build(rootPart)
	if rootPose then
		return rootPose
	end
	local emptyRoot = Instance.new("Pose")
	emptyRoot.Name = rootPart.Name
	emptyRoot.Weight = 0
	return emptyRoot
end

-- The root of the joint tree: a part that drives joints but is not driven by any
-- (HumanoidRootPart on R6/R15, whatever the root is on custom rigs).
local function findRootPart(joints: { [string]: Motor6D }): BasePart?
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

-- Exports a clip as a KeyframeSequence (not parented anywhere). Pass a baked clip
-- (Core/Bake) so every easing style survives export; see Bake.luau for why.
function IO.exportKeyframeSequence(clip: Model.Clip, joints: { [string]: Motor6D }): KeyframeSequence
	local rootPart = findRootPart(joints)
	assert(rootPart, "Rig has no Motor6D joint tree")

	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = clip.name
	sequence.Loop = clip.looped
	sequence.Priority = clip.priority

	-- Group keyframes by time across all tracks.
	local byTime: { [number]: { [string]: Model.Keyframe } } = {}
	for jointName, track in clip.tracks do
		for _, keyframe in track.keyframes do
			byTime[keyframe.time] = byTime[keyframe.time] or {}
			byTime[keyframe.time][jointName] = keyframe
		end
	end

	for time, valuesByJoint in byTime do
		local keyframeInstance = Instance.new("Keyframe")
		keyframeInstance.Time = time
		buildPoseTree(rootPart, joints, valuesByJoint).Parent = keyframeInstance
		keyframeInstance.Parent = sequence
	end

	return sequence
end

return IO
