--!strict
-- Converts between Animora clips and Roblox KeyframeSequence instances.
-- Export writes baked Linear keys (see Core/Bake); import reads Pose trees back into
-- tracks. Spike A (week 1) validated export + publish; see docs/spike-results.md.

local Model = require(script.Parent.Parent.Core.Model)
local RigBinder = require(script.Parent.RigBinder)

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
	joints: { [string]: RigBinder.Joint },
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

-- Exports a clip as a KeyframeSequence (not parented anywhere). Pass a baked clip
-- (Core/Bake) so every easing style survives export; see Bake.luau for why.
function IO.exportKeyframeSequence(clip: Model.Clip, joints: { [string]: RigBinder.Joint }): KeyframeSequence
	local rootPart = RigBinder.findRootPart(joints)
	assert(rootPart, "Rig has no joint tree")

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

-- Pose easing styles Roblox supports, mapped back to Animora styles on import.
local FROM_POSE_EASING_STYLE: { [string]: Model.EasingStyle } = {
	Linear = "Linear",
	Constant = "Constant",
	Cubic = "Cubic",
	CubicV2 = "Cubic",
	Elastic = "Elastic",
	Bounce = "Bounce",
}

export type ImportResult = {
	tracks: { [string]: { Model.Keyframe } },
	length: number,
	keyframeCount: number,
}

-- Reads every weighted Pose of a KeyframeSequence into per-joint keyframes. Poses with
-- Weight 0 only hold the hierarchy together and are skipped. Only joints the rig has
-- (per `hasJoint`) are imported.
function IO.importKeyframeSequence(sequence: KeyframeSequence, hasJoint: (name: string) -> boolean): ImportResult
	local tracks: { [string]: { Model.Keyframe } } = {}
	local length = 0
	local count = 0

	local function readPose(pose: Instance, time: number)
		if pose:IsA("Pose") then
			if pose.Weight > 0 and hasJoint(pose.Name) then
				local keyframes = tracks[pose.Name] or {}
				tracks[pose.Name] = keyframes
				table.insert(
					keyframes,
					Model.newKeyframe(
						time,
						pose.CFrame,
						FROM_POSE_EASING_STYLE[pose.EasingStyle.Name] or "Linear",
						pose.EasingDirection.Name :: any
					)
				)
				count += 1
			end
			for _, child in pose:GetChildren() do
				readPose(child, time)
			end
		end
	end

	for _, keyframe in sequence:GetKeyframes() do
		local keyframeInstance = keyframe :: Keyframe
		length = math.max(length, keyframeInstance.Time)
		for _, child in keyframeInstance:GetChildren() do
			readPose(child, keyframeInstance.Time)
		end
	end
	for _, keyframes in tracks do
		table.sort(keyframes, function(a, b)
			return a.time < b.time
		end)
	end
	return { tracks = tracks, length = length, keyframeCount = count }
end

return IO
