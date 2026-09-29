--!strict
-- Starter animations (Idle, Walk, Run, Jump, Wave, Scared Idle, Scared Walk, Scared Run)
-- authored for Animora. They are simple,
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

-- Scared Idle: a frightened, stiff stance (half crouch, hunched, hands pulled to the
-- chest) that keeps trembling while the head snaps left and right, scanning for
-- something that could appear at any moment.
local SCARED_LENGTH = 4.0
local TREMBLE_STEP = 0.08 -- seconds between tremble keys (about 12 shakes per second)

-- Base posture; tremble keys add small offsets on top of it.
local SCARED_BASE: { [string]: JointPose } = {
	root = { y = -0.25 },
	waist = { rx = -12 },
	hipR = { rx = 18 },
	hipL = { rx = 18 },
	kneeR = { rx = -30 },
	kneeL = { rx = -30 },
	ankleR = { rx = 12 },
	ankleL = { rx = 12 },
	shoulderR = { rx = 28, rz = -10 },
	shoulderL = { rx = 28, rz = -10 },
	elbowR = { rx = 75 },
	elbowL = { rx = 75 },
}

-- Head: quick glances right and left, holding each look with small scanning motions.
-- Negative ry turns the face to the character's right; negative rx keeps the head low.
local SCARED_LOOKS: { { time: number, ry: number, rx: number, easing: Model.EasingStyle } } = {
	{ time = 0.0, ry = 0, rx = -6, easing = "Sine" },
	{ time = 0.5, ry = 0, rx = -6, easing = "Quad" },
	{ time = 0.75, ry = -55, rx = -2, easing = "Sine" }, -- snap right
	{ time = 1.3, ry = -45, rx = -4, easing = "Sine" },
	{ time = 1.7, ry = -52, rx = -2, easing = "Quad" },
	{ time = 2.0, ry = 55, rx = -2, easing = "Sine" }, -- snap left
	{ time = 2.6, ry = 45, rx = -5, easing = "Sine" },
	{ time = 3.0, ry = 52, rx = -3, easing = "Quad" },
	{ time = 3.35, ry = 0, rx = -8, easing = "Sine" }, -- back to the front, head low
	{ time = 4.0, ry = 0, rx = -6, easing = "Sine" },
}

-- Tremble amplitudes (degrees / studs) per joint and axis.
local TREMBLE: { [string]: { [string]: number } } = {
	waist = { rx = 1.2, rz = 0.8 },
	shoulderR = { rx = 1.5, rz = 2.5 },
	shoulderL = { rx = 1.5, rz = 2.5 },
	elbowR = { rx = 3 },
	elbowL = { rx = 3 },
	root = { y = 0.012 },
}

local function scaredIdle(): Template
	local keys: { TemplateKey } = {}

	-- Tremble: alternating small offsets on top of the base posture. Deterministic
	-- pseudo-random amplitudes keep it organic; the first and last keys are the plain
	-- base pose so the loop is seamless.
	local random = Random.new(1337)
	local steps = math.round(SCARED_LENGTH / TREMBLE_STEP)
	for step = 0, steps do
		local time = math.min(step * TREMBLE_STEP, SCARED_LENGTH)
		local edge = step == 0 or step == steps
		local sign = if step % 2 == 0 then 1 else -1
		local pose: { [string]: JointPose } = {}
		for joint, base in SCARED_BASE do
			local value = table.clone(base)
			local amplitudes = TREMBLE[joint]
			if amplitudes and not edge then
				for axis, amplitude in amplitudes do
					local jitter = sign * amplitude * random:NextNumber(0.5, 1);
					(value :: any)[axis] = ((value :: any)[axis] or 0) + jitter
				end
			end
			pose[joint] = value
		end
		table.insert(keys, { time = time, easing = "Linear", direction = "InOut", pose = pose })
	end

	for _, look in SCARED_LOOKS do
		table.insert(keys, {
			time = look.time,
			easing = look.easing,
			direction = "Out",
			pose = { neck = { rx = look.rx, ry = look.ry } },
		})
	end

	return {
		id = "ScaredIdle",
		name = "Scared Idle",
		looped = true,
		priority = Enum.AnimationPriority.Idle,
		keys = keys,
	}
end

-- Scared Run: panicked fleeing that pairs with Scared Idle. Strong forward lean, head
-- low, fast strides with high knees, arms pumping wide with the elbows out, and one
-- glance back over the shoulder per loop (two stride cycles, 1.2 s).
local SCARED_RUN_STRIDE = 0.3 -- seconds per step

local function scaredRunStride(side: number): { [string]: JointPose }
	local pose = stride(side, 50, 80, 60, 95, -0.08)
	pose.root = { y = -0.08, rx = -6, ry = 5 * side }
	pose.waist = { rx = -20, ry = -8 * side }
	pose.shoulderR = { rx = -60 * side, rz = 18 }
	pose.shoulderL = { rx = 60 * side, rz = 18 }
	return pose
end

local function scaredRunPassing(side: number): { [string]: JointPose }
	local pose = passing(side, 100, 95, 0.22, -20)
	pose.root = { y = 0.22, rx = -6 }
	pose.shoulderR = { rx = 0, rz = 22 }
	pose.shoulderL = { rx = 0, rz = 22 }
	return pose
end

local function scaredRun(): Template
	local keys: { TemplateKey } = {}
	for step = 0, 8 do
		local time = step * SCARED_RUN_STRIDE / 2
		-- Even steps are contact poses (right, left, right...), odd steps passing poses.
		local side = if (step // 2) % 2 == 0 then 1 else -1
		local pose = if step % 2 == 0 then scaredRunStride(side) else scaredRunPassing(side)
		table.insert(keys, { time = time, easing = "Sine", direction = "InOut", pose = pose })
	end

	-- Head: low and forward, then a quick look back over the left shoulder and a snap
	-- back to the front. Positive ry turns the face to the character's left.
	local looks = {
		{ time = 0.0, rx = -10, ry = 0, easing = "Sine" :: Model.EasingStyle },
		{ time = 0.5, rx = -10, ry = 0, easing = "Quad" :: Model.EasingStyle },
		{ time = 0.68, rx = 4, ry = 80, easing = "Sine" :: Model.EasingStyle },
		{ time = 0.85, rx = 4, ry = 75, easing = "Quad" :: Model.EasingStyle },
		{ time = 1.0, rx = -10, ry = 0, easing = "Sine" :: Model.EasingStyle },
		{ time = 1.2, rx = -10, ry = 0, easing = "Sine" :: Model.EasingStyle },
	}
	for _, look in looks do
		table.insert(keys, {
			time = look.time,
			easing = look.easing,
			direction = "Out",
			pose = { neck = { rx = look.rx, ry = look.ry } },
		})
	end

	return {
		id = "ScaredRun",
		name = "Scared Run",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		keys = keys,
	}
end

-- Scared Walk: a slow, cautious creep between Scared Idle and Scared Run. Half crouch,
-- hunched back, hands held at the chest with only a small swing, careful steps and a
-- slow head scan right and left (two stride cycles, 2.4 s).
local SCARED_WALK_STEP = 0.6 -- seconds per step

-- Contact pose: `side` 1 = right foot forward.
local function scaredWalkStride(side: number): { [string]: JointPose }
	return {
		root = { y = -0.22, ry = 3 * side },
		waist = { rx = -14, ry = -4 * side },
		hipR = { rx = 10 + 22 * side },
		hipL = { rx = 10 - 22 * side },
		kneeR = { rx = if side > 0 then -20 else -35 },
		kneeL = { rx = if side > 0 then -35 else -20 },
		shoulderR = { rx = 28 - 6 * side, rz = -10 },
		shoulderL = { rx = 28 + 6 * side, rz = -10 },
		elbowR = { rx = 75 },
		elbowL = { rx = 75 },
	}
end

-- Passing pose: `side` is the leg carrying the weight; the other leg lifts past it.
local function scaredWalkPassing(side: number): { [string]: JointPose }
	return {
		root = { y = -0.12 },
		waist = { rx = -14 },
		hipR = { rx = if side > 0 then 5 else 32 },
		hipL = { rx = if side > 0 then 32 else 5 },
		kneeR = { rx = if side > 0 then -25 else -60 },
		kneeL = { rx = if side > 0 then -60 else -25 },
		shoulderR = { rx = 28, rz = -10 },
		shoulderL = { rx = 28, rz = -10 },
		elbowR = { rx = 78 },
		elbowL = { rx = 78 },
	}
end

local function scaredWalk(): Template
	local keys: { TemplateKey } = {}
	for step = 0, 8 do
		local time = step * SCARED_WALK_STEP / 2
		local side = if (step // 2) % 2 == 0 then 1 else -1
		local pose = if step % 2 == 0 then scaredWalkStride(side) else scaredWalkPassing(side)
		table.insert(keys, { time = time, easing = "Sine", direction = "InOut", pose = pose })
	end

	-- Slow, nervous scan: right, hold, left, hold, front. Head kept low.
	local looks = {
		{ time = 0.0, rx = -8, ry = 0 },
		{ time = 0.5, rx = -6, ry = -40 },
		{ time = 1.0, rx = -6, ry = -35 },
		{ time = 1.5, rx = -6, ry = 40 },
		{ time = 2.0, rx = -6, ry = 35 },
		{ time = 2.4, rx = -8, ry = 0 },
	}
	for _, look in looks do
		table.insert(keys, {
			time = look.time,
			easing = "Sine",
			direction = "InOut",
			pose = { neck = { rx = look.rx, ry = look.ry } },
		})
	end

	return {
		id = "ScaredWalk",
		name = "Scared Walk",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		keys = keys,
	}
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
	scaredIdle(),
	scaredWalk(),
	scaredRun(),
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
