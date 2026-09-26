--!strict
-- Spike C test clip: raises the right arm and waves it, for R15 and R6 rigs.
-- Temporary developer tool; removed once the real timeline exists.

local Model = require(script.Parent.Parent.Core.Model)
local RigBinder = require(script.Parent.Parent.Studio.RigBinder)

local WaveTest = {}

local RIGHT_ARM_JOINTS = { "RightUpperArm", "Right Arm" } -- R15, R6

-- Angle of the arm away from the body (degrees, sideways) over time.
local WAVE_KEYS: { { time: number, degrees: number } } = {
	{ time = 0, degrees = 0 },
	{ time = 0.4, degrees = 160 },
	{ time = 0.7, degrees = 130 },
	{ time = 1.0, degrees = 165 },
	{ time = 1.3, degrees = 130 },
	{ time = 1.6, degrees = 165 },
	{ time = 2.1, degrees = 0 },
}

-- Walks up from the selected instance to the closest rig model.
function WaveTest.findRig(selected: Instance?): Model?
	local current = selected
	while current and current ~= workspace do
		if current:IsA("Model") and RigBinder.isRig(current) then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Builds the looping wave clip, or returns nil + a reason key when the rig has no right arm.
function WaveTest.buildClip(binder: RigBinder.RigBinder): (Model.Clip?, string?)
	local jointName: string? = nil
	for _, name in RIGHT_ARM_JOINTS do
		if binder.joints[name] then
			jointName = name
			break
		end
	end
	if not jointName then
		return nil, "spike.status.noArm"
	end

	-- A rotation R about the torso's Z axis becomes Transform = C0rot^-1 * R * C0rot,
	-- which works for both R15 and R6 even though their C0 orientations differ.
	local c0Rotation = binder.joints[jointName].C0.Rotation
	local function sideways(degrees: number): CFrame
		return c0Rotation:Inverse() * CFrame.Angles(0, 0, math.rad(degrees)) * c0Rotation
	end

	local clip = Model.newClip("Animora Wave Test")
	clip.length = WAVE_KEYS[#WAVE_KEYS].time
	clip.looped = true
	local track = Model.getOrCreateTrack(clip, jointName)
	for _, key in WAVE_KEYS do
		Model.setKeyframe(track, Model.newKeyframe(key.time, sideways(key.degrees), "Sine", "InOut"))
	end
	return clip, nil
end

return WaveTest
