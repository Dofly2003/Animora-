--!strict
-- Starter animations (Idle, Walk, Run, Jump, Wave, Scared Idle, Scared Walk, Scared Run,
-- Flashlight, the Kuntilanak / Pocong / Tuyul ghost set and the NISKALA everyday set)
-- authored for Animora.
-- They are simple,
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

-- Flashlight: a curious but wary explorer. Slow careful steps in place, the right arm
-- held out in front aiming a flashlight, the left hand raised near the chest, and the
-- upper body, head and light sweeping right and left together (two stride cycles,
-- 2.8 s). Made for a horror loading screen or a "holding flashlight" walk.
local FLASHLIGHT_STEP = 0.7 -- seconds per step

-- Legs only; the upper body is keyed by the sweep below so the two never fight.
local function flashlightStep(step: number): { [string]: JointPose }
	local side = if (step // 2) % 2 == 0 then 1 else -1
	if step % 2 == 0 then
		-- Contact: `side` 1 = right foot forward.
		return {
			root = { y = -0.14, ry = 2 * side },
			hipR = { rx = 8 + 18 * side },
			hipL = { rx = 8 - 18 * side },
			kneeR = { rx = if side > 0 then -15 else -30 },
			kneeL = { rx = if side > 0 then -30 else -15 },
			elbowR = { rx = 14 },
		}
	end
	-- Passing: `side` carries the weight while the other leg lifts past it.
	return {
		root = { y = -0.06 },
		hipR = { rx = if side > 0 then 4 else 28 },
		hipL = { rx = if side > 0 then 28 else 4 },
		kneeR = { rx = if side > 0 then -20 else -50 },
		kneeL = { rx = if side > 0 then -50 else -20 },
		elbowR = { rx = 18 },
	}
end

local function flashlightExplore(): Template
	local keys: { TemplateKey } = {}
	for step = 0, 8 do
		table.insert(keys, {
			time = step * FLASHLIGHT_STEP / 2,
			easing = "Sine",
			direction = "InOut",
			pose = flashlightStep(step),
		})
	end

	-- Sweep: front, right, hold, left, hold, front. The waist turns the chest (and the
	-- raised arm with it), the neck adds a bit more, and the shoulder aims the light a
	-- little further out (+rz swings the raised right arm to the right).
	-- Negative ry turns the face to the character's right.
	local sweeps = {
		{ time = 0.0, turn = 0, aim = 0 },
		{ time = 0.6, turn = -1, aim = 1 },
		{ time = 1.1, turn = -0.8, aim = 0.8 },
		{ time = 1.8, turn = 1, aim = -1 },
		{ time = 2.3, turn = 0.8, aim = -0.8 },
		{ time = 2.8, turn = 0, aim = 0 },
	}
	for _, sweep in sweeps do
		table.insert(keys, {
			time = sweep.time,
			easing = "Sine",
			direction = "InOut",
			pose = {
				waist = { rx = -8, ry = 25 * sweep.turn },
				neck = { rx = -4, ry = 30 * sweep.turn },
				shoulderR = { rx = 80, rz = 12 * sweep.aim },
				shoulderL = { rx = 40, rz = -12 },
				elbowL = { rx = 70 },
			},
		})
	end

	return {
		id = "FlashlightExplore",
		name = "Flashlight",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		keys = keys,
	}
end

-- Ghost set for horror games: Kuntilanak, Pocong and Tuyul. A ghost AI script moves the
-- character around; these clips only give each ghost its body language.

-- Kuntilanak: hovering with the head drooped to one side, limbs hanging limp and the
-- toes pointing down.
local function kuntiFloatPose(lift: number, sway: number): { [string]: JointPose }
	return {
		root = { y = lift, rx = 4, rz = sway },
		waist = { rx = 3 },
		neck = { rx = -18, rz = 14 + sway },
		shoulderR = { rx = 12 + sway, rz = 10 },
		shoulderL = { rx = 12 - sway, rz = 10 },
		elbowR = { rx = 14 },
		elbowL = { rx = 14 },
		hipR = { rx = 8 },
		hipL = { rx = 6 },
		kneeR = { rx = -18 },
		kneeL = { rx = -24 },
		ankleR = { rx = -35 },
		ankleL = { rx = -35 },
	}
end

-- Flying chase: body pitched forward, arms reaching ahead, legs trailing behind.
local function kuntiChasePose(lift: number, reach: number, sway: number): { [string]: JointPose }
	return {
		root = { y = lift, rx = -55, rz = sway },
		waist = { rx = -10 },
		neck = { rx = 50, ry = sway * 1.5 },
		shoulderR = { rx = 140 + reach, rz = 8 },
		shoulderL = { rx = 140 - reach, rz = 8 },
		elbowR = { rx = 10 },
		elbowL = { rx = 10 },
		hipR = { rx = -25 },
		hipL = { rx = -20 },
		kneeR = { rx = -40 },
		kneeL = { rx = -30 },
		ankleR = { rx = -40 },
		ankleL = { rx = -40 },
	}
end

-- Jumpscare: the head snaps up and the arms fling wide as she lunges at the camera.
local function kuntiLungePose(tremble: number): { [string]: JointPose }
	return {
		root = { y = 0.6, z = -1.2 - math.abs(tremble) * 0.02, rx = -15 },
		waist = { rx = -15 },
		neck = { rx = 25 - math.abs(tremble) * 0.5, ry = tremble },
		shoulderR = { rx = 60 + tremble, rz = 110 + tremble },
		shoulderL = { rx = 60 - tremble, rz = 110 - tremble },
		elbowR = { rx = 20 },
		elbowL = { rx = 20 },
		hipR = { rx = 10 },
		hipL = { rx = 10 },
		kneeR = { rx = -20 },
		kneeL = { rx = -20 },
		ankleR = { rx = -35 },
		ankleL = { rx = -35 },
	}
end

-- Pocong: wrapped body, arms bound to the sides and legs tied together, so only the
-- whole body bends and springs.
local function pocongPose(y: number, bend: number, point: number, lean: number, nod: number): { [string]: JointPose }
	return {
		root = { y = y, rx = lean },
		waist = { rx = 0 },
		neck = { rx = nod, rz = 10 },
		shoulderR = { rx = 0, rz = -3 },
		shoulderL = { rx = 0, rz = -3 },
		elbowR = { rx = 0 },
		elbowL = { rx = 0 },
		hipR = { rx = bend * 0.6 },
		hipL = { rx = bend * 0.6 },
		kneeR = { rx = -bend },
		kneeL = { rx = -bend },
		ankleR = { rx = point },
		ankleL = { rx = point },
	}
end

-- Tuyul: a small child ghost. Runs bent forward with the arms swept back, squats and
-- giggles behind its hands.
local function tuyulRunPose(step: number): { [string]: JointPose }
	local side = if (step // 2) % 2 == 0 then 1 else -1
	local pose = if step % 2 == 0 then stride(side, 40, 70, 0, 0, -0.35) else passing(side, 80, 8, -0.1, -12)
	local root = pose.root or {}
	root.rx = -18
	pose.root = root
	pose.waist = { rx = -12, ry = if step % 2 == 0 then -6 * side else 0 }
	pose.neck = { rx = 22 }
	pose.shoulderR = { rx = -75 + 8 * side, rz = 18 }
	pose.shoulderL = { rx = -75 - 8 * side, rz = 18 }
	pose.elbowR = { rx = 8 }
	pose.elbowL = { rx = 8 }
	return pose
end

local function tuyulSquatPose(bounce: number, lookY: number, lookX: number): { [string]: JointPose }
	return {
		root = { y = -1.4 + bounce, rx = -10 },
		waist = { rx = -18 },
		neck = { rx = 18 + lookX, ry = lookY },
		hipR = { rx = 85 },
		hipL = { rx = 85 },
		kneeR = { rx = -120 },
		kneeL = { rx = -120 },
		ankleR = { rx = 35 },
		ankleL = { rx = 35 },
		shoulderR = { rx = 55, rz = -12 },
		shoulderL = { rx = 55, rz = -12 },
		elbowR = { rx = 125 },
		elbowL = { rx = 125 },
	}
end

local function ghostKey(
	time: number,
	pose: { [string]: JointPose },
	easing: Model.EasingStyle?,
	direction: Model.EasingDirection?
): TemplateKey
	return { time = time, easing = easing or "Sine", direction = direction or "InOut", pose = pose }
end

local function ghostTemplates(): { Template }
	local tuyulRun: { TemplateKey } = {}
	for step = 0, 4 do
		table.insert(tuyulRun, ghostKey(step * 0.1, tuyulRunPose(step)))
	end

	return {
		{
			id = "KuntiFloat",
			name = "Kunti Float",
			looped = true,
			priority = Enum.AnimationPriority.Idle,
			keys = {
				ghostKey(0, kuntiFloatPose(0.2, 0)),
				ghostKey(1.5, kuntiFloatPose(0.7, 3)),
				ghostKey(3, kuntiFloatPose(0.2, 0)),
			},
		},
		{
			id = "KuntiChase",
			name = "Kunti Chase",
			looped = true,
			priority = Enum.AnimationPriority.Movement,
			keys = {
				ghostKey(0, kuntiChasePose(0.5, 6, -4)),
				ghostKey(0.6, kuntiChasePose(0.9, -6, 4)),
				ghostKey(1.2, kuntiChasePose(0.5, 6, -4)),
			},
		},
		{
			id = "KuntiLunge",
			name = "Kunti Lunge",
			looped = false,
			priority = Enum.AnimationPriority.Action,
			keys = {
				ghostKey(0, kuntiFloatPose(0.2, 0), "Quad", "Out"),
				ghostKey(0.12, kuntiLungePose(0), "Linear"),
				ghostKey(0.35, kuntiLungePose(5), "Linear"),
				ghostKey(0.55, kuntiLungePose(-5), "Linear"),
				ghostKey(1, kuntiLungePose(0)),
			},
		},
		{
			id = "PocongHop",
			name = "Pocong Hop",
			looped = true,
			priority = Enum.AnimationPriority.Movement,
			keys = {
				ghostKey(0, pocongPose(-0.5, 25, 12, -6, -8)),
				ghostKey(0.15, pocongPose(0.3, 5, -15, 0, -4), "Quad", "Out"),
				ghostKey(0.4, pocongPose(2.6, 10, -25, 4, 5), "Quad", "In"),
				ghostKey(0.65, pocongPose(0.6, 5, -10, 0, -2)),
				ghostKey(0.8, pocongPose(-0.5, 25, 12, -6, -8)),
			},
		},
		{
			id = "PocongLeap",
			name = "Pocong Leap",
			looped = false,
			priority = Enum.AnimationPriority.Action,
			keys = {
				ghostKey(0, pocongPose(0, 5, 0, 0, -5)),
				ghostKey(0.35, pocongPose(-1.2, 55, 25, -12, -12), "Quad", "In"),
				ghostKey(0.45, pocongPose(1, 0, -30, 6, 0), "Quad", "Out"),
				ghostKey(0.8, pocongPose(5, 12, -30, 10, 15), "Quad", "In"),
				ghostKey(1.15, pocongPose(-0.8, 40, 20, -8, -10), "Quad", "Out"),
				ghostKey(1.4, pocongPose(0, 10, 5, 0, -6)),
			},
		},
		{
			id = "TuyulRun",
			name = "Tuyul Run",
			looped = true,
			priority = Enum.AnimationPriority.Movement,
			keys = tuyulRun,
		},
		{
			id = "TuyulPeek",
			name = "Tuyul Peek",
			looped = true,
			priority = Enum.AnimationPriority.Idle,
			keys = {
				ghostKey(0, tuyulSquatPose(0, 0, 0)),
				ghostKey(0.5, tuyulSquatPose(0, -50, 0), "Quad", "Out"),
				ghostKey(1, tuyulSquatPose(0, -45, 0)),
				ghostKey(1.2, tuyulSquatPose(0, 0, -5)),
				ghostKey(1.3, tuyulSquatPose(0.25, 0, -8)),
				ghostKey(1.4, tuyulSquatPose(0, 0, -5)),
				ghostKey(1.5, tuyulSquatPose(0.25, 0, -8)),
				ghostKey(1.6, tuyulSquatPose(0, 0, -5)),
				ghostKey(2.1, tuyulSquatPose(0, 50, 0), "Quad", "Out"),
				ghostKey(2.6, tuyulSquatPose(0, 45, 0)),
				ghostKey(3, tuyulSquatPose(0, 0, 0)),
			},
		},
	}
end

-- NISKALA set: everyday Idle, Walk, Run and Jump with a quiet unease. The body is a
-- little guarded (shoulders drawn in, arms close, head slightly low) and every loop
-- has one short glance over the shoulder, as if something might be behind you.

-- Idle: slow breathing, arms held close against the cold, one look back per loop.
local function niskalaIdleBody(breath: number): { [string]: JointPose }
	return {
		root = { y = -0.05 - 0.03 * breath },
		waist = { rx = -5 + 2 * breath },
		kneeR = { rx = -6 },
		kneeL = { rx = -3 },
		shoulderR = { rx = 8 + 2 * breath, rz = 2 },
		shoulderL = { rx = 8 + 2 * breath, rz = 2 },
		elbowR = { rx = 20 + 4 * breath },
		elbowL = { rx = 20 + 4 * breath },
	}
end

-- Walk contact pose: `side` 1 = right foot forward. Smaller arm swing, slight lean.
local function niskalaWalkStride(side: number): { [string]: JointPose }
	local pose = stride(side, 26, 28, 14, 20, -0.04)
	pose.waist = { rx = -6, ry = -5 * side }
	pose.shoulderR = { rx = -14 * side, rz = 3 }
	pose.shoulderL = { rx = 14 * side, rz = 3 }
	return pose
end

local function niskalaWalkPassing(side: number): { [string]: JointPose }
	local pose = passing(side, 42, 24, 0.07, -6)
	pose.shoulderR = { rx = 0, rz = 3 }
	pose.shoulderL = { rx = 0, rz = 3 }
	return pose
end

-- Run contact pose: forward lean, arms pumping close to the body.
local function niskalaRunStride(side: number): { [string]: JointPose }
	local pose = stride(side, 48, 70, 48, 85, -0.1)
	pose.waist = { rx = -14, ry = -8 * side }
	pose.shoulderR = { rx = -48 * side, rz = 6 }
	pose.shoulderL = { rx = 48 * side, rz = 6 }
	return pose
end

local function niskalaRunPassing(side: number): { [string]: JointPose }
	local pose = passing(side, 95, 85, 0.25, -14)
	pose.shoulderR = { rx = 0, rz = 8 }
	pose.shoulderL = { rx = 0, rz = 8 }
	return pose
end

-- Jump pose: `y` moves the body up or down; the left leg bends a little less.
local function niskalaJumpPose(
	y: number,
	lean: number,
	hip: number,
	knee: number,
	ankle: number,
	arm: number,
	armOut: number,
	elbow: number,
	headX: number,
	headY: number
): { [string]: JointPose }
	return {
		root = { y = y },
		waist = { rx = lean },
		neck = { rx = headX, ry = headY },
		hipR = { rx = hip },
		hipL = { rx = hip * 0.85 },
		kneeR = { rx = knee },
		kneeL = { rx = knee * 0.85 },
		ankleR = { rx = ankle },
		ankleL = { rx = ankle },
		shoulderR = { rx = arm, rz = armOut },
		shoulderL = { rx = arm, rz = armOut },
		elbowR = { rx = elbow },
		elbowL = { rx = elbow },
	}
end

-- Adds head keys (time, rx, ry) to a key list.
local function addLooks(keys: { TemplateKey }, looks: { { number } })
	for _, look in looks do
		table.insert(keys, ghostKey(look[1], { neck = { rx = look[2], ry = look[3] } }))
	end
end

-- Builds a two-cycle stride loop: contact and passing poses every half step.
local function strideLoop(
	step: number,
	contact: (number) -> { [string]: JointPose },
	pass: (number) -> { [string]: JointPose }
): { TemplateKey }
	local keys: { TemplateKey } = {}
	for index = 0, 8 do
		local side = if (index // 2) % 2 == 0 then 1 else -1
		local pose = if index % 2 == 0 then contact(side) else pass(side)
		table.insert(keys, ghostKey(index * step / 2, pose))
	end
	return keys
end

local function niskalaTemplates(): { Template }
	local idle: { TemplateKey } = {
		ghostKey(0, niskalaIdleBody(0)),
		ghostKey(1.6, niskalaIdleBody(1)),
		ghostKey(3.2, niskalaIdleBody(0)),
		ghostKey(4.0, niskalaIdleBody(0.6)),
		ghostKey(4.8, niskalaIdleBody(0)),
	}
	-- Positive ry turns the face to the character's left.
	addLooks(idle, {
		{ 0, -6, 0 },
		{ 1.8, -6, 0 },
		{ 2.2, -2, 55 }, -- look back over the left shoulder
		{ 2.9, -3, 48 },
		{ 3.3, -5, -15 }, -- quick check to the right
		{ 3.8, -6, 0 },
		{ 4.8, -6, 0 },
	})

	local walk = strideLoop(0.6, niskalaWalkStride, niskalaWalkPassing)
	addLooks(walk, {
		{ 0, -4, 0 },
		{ 1.1, -4, 0 },
		{ 1.4, -2, 30 }, -- short glance to the left
		{ 1.8, -3, 25 },
		{ 2.1, -4, 0 },
		{ 2.4, -4, 0 },
	})

	local run = strideLoop(0.4, niskalaRunStride, niskalaRunPassing)
	addLooks(run, {
		{ 0, 6, 0 },
		{ 0.8, 6, 0 },
		{ 0.95, 8, 40 }, -- quick look back
		{ 1.15, 6, 0 },
		{ 1.6, 6, 0 },
	})

	return {
		{
			id = "NiskalaIdle",
			name = "Niskala Idle",
			looped = true,
			priority = Enum.AnimationPriority.Idle,
			keys = idle,
		},
		{
			id = "NiskalaWalk",
			name = "Niskala Walk",
			looped = true,
			priority = Enum.AnimationPriority.Movement,
			keys = walk,
		},
		{
			id = "NiskalaRun",
			name = "Niskala Run",
			looped = true,
			priority = Enum.AnimationPriority.Movement,
			keys = run,
		},
		{
			id = "NiskalaJump",
			name = "Niskala Jump",
			looped = false,
			priority = Enum.AnimationPriority.Action,
			keys = {
				ghostKey(0, niskalaJumpPose(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
				-- Crouch, arms swung back.
				ghostKey(0.2, niskalaJumpPose(-0.6, -20, 40, -75, 15, -30, 8, 20, 6, 0), "Quad", "Out"),
				-- Push off: body stretched, toes pointing down, arms forward for balance.
				ghostKey(0.4, niskalaJumpPose(1.2, -4, -6, -10, -25, 70, 15, 30, 0, 0), "Quad", "Out"),
				-- Knees tucked at the top.
				ghostKey(0.65, niskalaJumpPose(1, -8, 45, -70, -10, 50, 30, 40, -4, 0), "Quad", "In"),
				-- Heavy landing, eyes on the ground.
				ghostKey(0.85, niskalaJumpPose(-0.55, -16, 38, -70, 15, 25, 25, 35, -10, 0), "Quad", "Out"),
				-- Straighten up with a glance to the left.
				ghostKey(1.05, niskalaJumpPose(-0.15, -6, 12, -22, 5, 8, 8, 18, -4, 30)),
				ghostKey(1.3, niskalaJumpPose(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
			},
		},
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
	flashlightExplore(),
}
for _, template in ghostTemplates() do
	table.insert(LIST, template)
end
for _, template in niskalaTemplates() do
	table.insert(LIST, template)
end

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
