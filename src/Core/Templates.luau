--!strict
-- Starter animations (Idle, Walk, Run, Jump, Wave) authored for Animora. They are simple,
-- clean starting points meant to be edited, not final animations.
--
-- Poses are written per *logical* joint (hipR, kneeL, ...) in the parent part's space,
-- in degrees, using the character's axes (X right, Y up, Z back; the character faces
-- -Z). For a limb hanging down, +rx swings it forward; for the torso or head, -rx leans
-- forward. Left-side values are written like the right side ("+rz = away from the
-- body") and mirrored automatically. Each logical joint maps to R15 or R6 joint names;
-- joints a rig does not have (R6 has no knees or elbows) are skipped.

local Model = require(script.Parent.Model)
local Mirror = require(script.Parent.Mirror)

local Templates = {}

export type JointPose = { rx: number?, ry: number?, rz: number?, y: number?, z: number? }
export type TemplateKey = {
	time: number,
	easing: Model.EasingStyle?,
	direction: Model.EasingDirection?,
	pose: { [string]: JointPose },
}
export type Template = {
	id: string,
	name: string,
	looped: boolean,
	priority: Enum.AnimationPriority,
	keys: { TemplateKey },
}

-- Logical joint -> candidate joint names (R15 first, then R6).
local JOINT_NAMES: { [string]: { string } } = {
	root = { "LowerTorso", "Torso" },
	waist = { "UpperTorso" },
	neck = { "Head" },
	shoulderR = { "RightUpperArm", "Right Arm" },
	shoulderL = { "LeftUpperArm", "Left Arm" },
	elbowR = { "RightLowerArm" },
	elbowL = { "LeftLowerArm" },
	hipR = { "RightUpperLeg", "Right Leg" },
	hipL = { "LeftUpperLeg", "Left Leg" },
	kneeR = { "RightLowerLeg" },
	kneeL = { "LeftLowerLeg" },
	ankleR = { "RightFoot" },
	ankleL = { "LeftFoot" },
}

local LEFT_SIDE: { [string]: boolean } = {
	shoulderL = true,
	elbowL = true,
	hipL = true,
	kneeL = true,
	ankleL = true,
}

-- Walk pose: `side` 1 = right leg forward, -1 = left leg forward.
local function stride(side: number, hip: number, knee: number, arm: number, elbow: number, bob: number)
	return {
		root = { y = bob, ry = 4 * side },
		waist = { ry = -6 * side },
		hipR = { rx = hip * side },
		hipL = { rx = -hip * side },
		kneeR = { rx = if side > 0 then -8 else -knee },
		kneeL = { rx = if side > 0 then -knee else -8 },
		shoulderR = { rx = -arm * side },
		shoulderL = { rx = arm * side },
		elbowR = { rx = elbow },
		elbowL = { rx = elbow },
	}
end

-- Passing pose between two strides: `side` is the leg carrying the weight.
local function passing(side: number, knee: number, elbow: number, bob: number, lean: number)
	return {
		root = { y = bob },
		waist = { rx = lean },
		hipR = { rx = if side > 0 then -5 else 25 },
		hipL = { rx = if side > 0 then 25 else -5 },
		kneeR = { rx = if side > 0 then -5 else -knee },
		kneeL = { rx = if side > 0 then -knee else -5 },
		elbowR = { rx = elbow },
		elbowL = { rx = elbow },
	}
end

local function copyPose(pose: { [string]: JointPose }): { [string]: JointPose }
	local copy = {}
	for joint, value in pose do
		copy[joint] = table.clone(value)
	end
	return copy
end

local LIST: { Template } = {
	{
		id = "Idle",
		name = "Idle",
		looped = true,
		priority = Enum.AnimationPriority.Idle,
		keys = {
			{
				time = 0,
				easing = "Sine",
				direction = "InOut",
				pose = {
					root = { y = 0 },
					waist = { rx = 0 },
					neck = { rx = 0 },
					shoulderR = { rz = 4 },
					shoulderL = { rz = 4 },
					elbowR = { rx = 6 },
					elbowL = { rx = 6 },
				},
			},
			{
				time = 1.2,
				easing = "Sine",
				direction = "InOut",
				pose = {
					root = { y = -0.04 },
					waist = { rx = 2.5 },
					neck = { rx = -2 },
					shoulderR = { rz = 7, rx = 2 },
					shoulderL = { rz = 7, rx = 2 },
					elbowR = { rx = 10 },
					elbowL = { rx = 10 },
				},
			},
			{
				time = 2.4,
				easing = "Sine",
				direction = "InOut",
				pose = {
					root = { y = 0 },
					waist = { rx = 0 },
					neck = { rx = 0 },
					shoulderR = { rz = 4 },
					shoulderL = { rz = 4 },
					elbowR = { rx = 6 },
					elbowL = { rx = 6 },
				},
			},
		},
	},
	{
		id = "Walk",
		name = "Walk",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		keys = {
			{ time = 0, easing = "Sine", direction = "InOut", pose = stride(1, 28, 30, 22, 12, 0) },
			{ time = 0.25, easing = "Sine", direction = "InOut", pose = passing(1, 40, 18, 0.12, 0) },
			{ time = 0.5, easing = "Sine", direction = "InOut", pose = stride(-1, 28, 30, 22, 12, 0) },
			{ time = 0.75, easing = "Sine", direction = "InOut", pose = passing(-1, 40, 18, 0.12, 0) },
			{ time = 1.0, easing = "Sine", direction = "InOut", pose = stride(1, 28, 30, 22, 12, 0) },
		},
	},
	{
		id = "Run",
		name = "Run",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		keys = {
			{
				time = 0,
				easing = "Sine",
				direction = "InOut",
				pose = (function()
					local pose = stride(1, 50, 75, 55, 80, -0.1)
					pose.waist = { rx = -12, ry = -10 }
					pose.neck = { rx = 8 }
					return pose
				end)(),
			},
			{
				time = 0.18,
				easing = "Sine",
				direction = "InOut",
				pose = (function()
					local pose = passing(1, 95, 80, 0.3, -12)
					pose.neck = { rx = 8 }
					return pose
				end)(),
			},
			{
				time = 0.36,
				easing = "Sine",
				direction = "InOut",
				pose = (function()
					local pose = stride(-1, 50, 75, 55, 80, -0.1)
					pose.waist = { rx = -12, ry = 10 }
					pose.neck = { rx = 8 }
					return pose
				end)(),
			},
			{
				time = 0.54,
				easing = "Sine",
				direction = "InOut",
				pose = (function()
					local pose = passing(-1, 95, 80, 0.3, -12)
					pose.neck = { rx = 8 }
					return pose
				end)(),
			},
			{
				time = 0.72,
				easing = "Sine",
				direction = "InOut",
				pose = (function()
					local pose = stride(1, 50, 75, 55, 80, -0.1)
					pose.waist = { rx = -12, ry = -10 }
					pose.neck = { rx = 8 }
					return pose
				end)(),
			},
		},
	},
	{
		id = "Jump",
		name = "Jump",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		keys = {
			{
				time = 0,
				easing = "Sine",
				direction = "InOut",
				pose = {
					root = { y = 0 },
					waist = { rx = 0 },
					hipR = { rx = 0 },
					hipL = { rx = 0 },
					kneeR = { rx = 0 },
					kneeL = { rx = 0 },
					shoulderR = { rx = 0 },
					shoulderL = { rx = 0 },
				},
			},
			{
				time = 0.25,
				easing = "Quad",
				direction = "Out",
				pose = {
					root = { y = -0.7 },
					waist = { rx = -18 },
					hipR = { rx = 45 },
					hipL = { rx = 45 },
					kneeR = { rx = -80 },
					kneeL = { rx = -80 },
					shoulderR = { rx = -35 },
					shoulderL = { rx = -35 },
				},
			},
			{
				time = 0.45,
				easing = "Quad",
				direction = "Out",
				pose = {
					root = { y = 1.4 },
					waist = { rx = 4 },
					hipR = { rx = -8 },
					hipL = { rx = -8 },
					kneeR = { rx = -5 },
					kneeL = { rx = -5 },
					shoulderR = { rx = 165 },
					shoulderL = { rx = 165 },
				},
			},
			{
				time = 0.7,
				easing = "Quad",
				direction = "In",
				pose = {
					root = { y = 1.0 },
					waist = { rx = -6 },
					hipR = { rx = 35 },
					hipL = { rx = 30 },
					kneeR = { rx = -60 },
					kneeL = { rx = -50 },
					shoulderR = { rx = 100, rz = 20 },
					shoulderL = { rx = 100, rz = 20 },
				},
			},
			{
				time = 0.9,
				easing = "Quad",
				direction = "Out",
				pose = {
					root = { y = -0.4 },
					waist = { rx = -12 },
					hipR = { rx = 30 },
					hipL = { rx = 30 },
					kneeR = { rx = -55 },
					kneeL = { rx = -55 },
					shoulderR = { rx = 20, rz = 15 },
					shoulderL = { rx = 20, rz = 15 },
				},
			},
			{
				time = 1.2,
				easing = "Sine",
				direction = "InOut",
				pose = {
					root = { y = 0 },
					waist = { rx = 0 },
					hipR = { rx = 0 },
					hipL = { rx = 0 },
					kneeR = { rx = 0 },
					kneeL = { rx = 0 },
					shoulderR = { rx = 0, rz = 0 },
					shoulderL = { rx = 0, rz = 0 },
				},
			},
		},
	},
	{
		id = "Wave",
		name = "Wave",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		keys = {
			{
				time = 0,
				easing = "Sine",
				direction = "InOut",
				pose = {
					shoulderR = { rz = 0 },
					elbowR = { rz = 0, rx = 0 },
					neck = { ry = 0 },
				},
			},
			{
				time = 0.35,
				easing = "Back",
				direction = "Out",
				pose = {
					shoulderR = { rz = 150 },
					elbowR = { rz = -20, rx = 10 },
					neck = { ry = -8 },
				},
			},
			{
				time = 0.6,
				easing = "Sine",
				direction = "InOut",
				pose = {
					shoulderR = { rz = 135 },
					elbowR = { rz = 25, rx = 10 },
					neck = { ry = -8 },
				},
			},
			{
				time = 0.85,
				easing = "Sine",
				direction = "InOut",
				pose = {
					shoulderR = { rz = 160 },
					elbowR = { rz = -25, rx = 10 },
					neck = { ry = -8 },
				},
			},
			{
				time = 1.1,
				easing = "Sine",
				direction = "InOut",
				pose = {
					shoulderR = { rz = 135 },
					elbowR = { rz = 25, rx = 10 },
					neck = { ry = -8 },
				},
			},
			{
				time = 1.35,
				easing = "Sine",
				direction = "InOut",
				pose = {
					shoulderR = { rz = 155 },
					elbowR = { rz = -15, rx = 10 },
					neck = { ry = -8 },
				},
			},
			{
				time = 1.8,
				easing = "Sine",
				direction = "InOut",
				pose = {
					shoulderR = { rz = 0 },
					elbowR = { rz = 0, rx = 0 },
					neck = { ry = 0 },
				},
			},
		},
	},
}

-- R6 has no separate waist: lean its upper body a little through the root instead.
local function withR6Waist(pose: { [string]: JointPose }, hasWaist: boolean): { [string]: JointPose }
	if hasWaist or not pose.waist then
		return pose
	end
	local result = copyPose(pose)
	local root = result.root or {}
	root.rx = (root.rx or 0) + (pose.waist.rx or 0) * 0.5
	root.ry = (root.ry or 0) + (pose.waist.ry or 0) * 0.5
	result.root = root
	result.waist = nil
	return result
end

function Templates.list(): { Template }
	return LIST
end

function Templates.get(id: string): Template?
	for _, template in LIST do
		if template.id == id then
			return template
		end
	end
	return nil
end

-- Parent-space CFrame of a pose value (left side mirrored across the character's X).
local function parentSpace(value: JointPose, isLeft: boolean): CFrame
	local cframe = CFrame.new(0, value.y or 0, value.z or 0)
		* CFrame.Angles(math.rad(value.rx or 0), math.rad(value.ry or 0), math.rad(value.rz or 0))
	return if isLeft then Mirror.mirrorTransform(cframe) else cframe
end

-- Builds a clip from a template for a rig. `hasJoint(name)` says whether the rig has a
-- joint; `restFrame(name)` returns that joint's rest C0 / Attachment0 CFrame, used to
-- turn parent-space poses into joint Transforms: T = C0rot^-1 * P * C0rot.
function Templates.build(
	template: Template,
	hasJoint: (name: string) -> boolean,
	restFrame: (name: string) -> CFrame,
	fps: number
): Model.Clip
	local clip = Model.newClip(template.name, fps)
	clip.looped = template.looped
	clip.priority = template.priority

	local resolved: { [string]: string } = {}
	for logical, names in JOINT_NAMES do
		for _, name in names do
			if hasJoint(name) then
				resolved[logical] = name
				break
			end
		end
	end

	local length = 0
	for _, key in template.keys do
		length = math.max(length, key.time)
		local pose = withR6Waist(key.pose, resolved.waist ~= nil)
		for logical, value in pose do
			local jointName = resolved[logical]
			if jointName then
				local rest = restFrame(jointName).Rotation
				local transform = rest:Inverse() * parentSpace(value, LEFT_SIDE[logical] == true) * rest
				Model.setKeyframe(
					Model.getOrCreateTrack(clip, jointName),
					Model.newKeyframe(key.time, transform, key.easing or "Sine", key.direction or "InOut")
				)
			end
		end
	end
	clip.length = math.max(length, 0.1)
	return clip
end

return Templates
