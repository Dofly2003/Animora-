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
-- (Pose objects must be nested parent -> child like the rig's parts).
local function buildPoseTree(rootPart: BasePart, joints: { [string]: Motor6D }, valuesByJoint: { [string]: Model.Keyframe }): Pose
	local function build(part: BasePart): Pose
		local pose = Instance.new("Pose")
		pose.Name = part.Name
		local keyframe = valuesByJoint[part.Name]
		if keyframe then
			pose.CFrame = keyframe.value
			pose.EasingStyle = POSE_EASING_STYLE[keyframe.easingStyle] or Enum.PoseEasingStyle.Linear
			pose.EasingDirection = (Enum.PoseEasingDirection :: any)[keyframe.easingDirection]
		else
			pose.Weight = 0
		end
		for _, joint in joints do
			if joint.Part0 == part and joint.Part1 then
				build(joint.Part1).Parent = pose
			end
		end
		return pose
	end
	return build(rootPart)
end

-- Exports a clip for `rig` as a KeyframeSequence (not parented anywhere).
-- NOTE: styles Roblox Pose does not support (Sine, Quad, Back, ...) must be baked
-- into extra keyframes before export; that is a Phase 2 task.
function IO.exportKeyframeSequence(clip: Model.Clip, rig: Model, joints: { [string]: Motor6D }): KeyframeSequence
	local rootPart = rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(rootPart, "Rig needs a PrimaryPart or HumanoidRootPart")

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
