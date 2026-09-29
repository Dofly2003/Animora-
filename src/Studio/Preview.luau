--!strict
-- Shows poses on a rig in edit mode (no Play Solo) and plays clips by sampling them
-- every frame. Write modes (Spike C, 2026-09-26):
--   "C0":        edit-mode preview. The joint's Part0 frame is offset by the transform
--                and restored on stop: C0 for a Motor6D, Attachment0.CFrame for a rigid
--                (kinematic) AnimationConstraint, since both keep the body one rigid
--                assembly. A non-rigid AnimationConstraint is not solved in edit mode, so
--                its part is placed directly with forward kinematics, parents first.
--   "Transform": writes the joints' Transform. Only visible while the game runs.

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Interpolate = require(script.Parent.Parent.Core.Interpolate)
local RigBinder = require(script.Parent.RigBinder)

export type Mode = "Transform" | "C0"

-- The rest C0 / attachment CFrame is also stored as an attribute on the instance while a
-- pose is shown, so a rig saved mid-preview (or after a crash) can still be restored.
local REST_ATTRIBUTE = "AnimoraRestC0"

local Preview = {}
Preview.__index = Preview

export type Preview = typeof(setmetatable(
	{} :: {
		binder: RigBinder.RigBinder,
		mode: Mode,
		frameCount: number,
		startedAt: number,
		_connection: RBXScriptConnection?,
		-- Rest frame of each offset instance (Motor6D C0 or Attachment CFrame).
		_original: { [Instance]: CFrame },
		-- Per joint: true when Part0 and Part1 are one rigid assembly.
		_rigid: { [string]: boolean },
		_order: { RigBinder.JointEntry },
		_constraintPose: { [string]: CFrame },
		_constraintPosed: boolean,
	},
	Preview
))

function Preview.new(binder: RigBinder.RigBinder, mode: Mode): Preview
	return setmetatable({
		binder = binder,
		mode = mode,
		frameCount = 0,
		startedAt = 0,
		_connection = nil,
		_original = {},
		_rigid = {},
		_order = binder:jointOrder(),
		_constraintPose = {},
		_constraintPosed = false,
	}, Preview)
end

function Preview.isPlaying(self: Preview): boolean
	return self._connection ~= nil
end

-- Motor6D C0 or Attachment0.CFrame: the frame on Part0 that Animora offsets.
local function offsetTarget(joint: RigBinder.Joint): Instance
	if joint.kind == "Motor6D" then
		return joint.instance
	end
	return (joint.instance :: AnimationConstraint).Attachment0 :: Attachment
end

local function readFrame(target: Instance): CFrame
	return if target:IsA("Motor6D") then target.C0 else (target :: Attachment).CFrame
end

local function writeFrame(target: Instance, value: CFrame)
	if target:IsA("Motor6D") then
		target.C0 = value
	else
		(target :: Attachment).CFrame = value
	end
end

-- Rest frame of a C0 / attachment, remembered (and saved as an attribute) on first use.
function Preview._restFrame(self: Preview, target: Instance): CFrame
	local known = self._original[target]
	if known then
		return known
	end
	local stored = target:GetAttribute(REST_ATTRIBUTE)
	local rest = if typeof(stored) == "CFrame" then stored else readFrame(target)
	if stored == nil then
		target:SetAttribute(REST_ATTRIBUTE, rest)
	end
	self._original[target] = rest
	return rest
end

-- Motor6Ds are always rigid. An AnimationConstraint is rigid when it joins Part0 and
-- Part1 into one assembly (kinematic): moving one part would drag the whole body.
function Preview._isOffsetJoint(self: Preview, joint: RigBinder.Joint): boolean
	if joint.kind == "Motor6D" then
		return true
	end
	local known = self._rigid[joint.name]
	if known == nil then
		known = joint.Part0.AssemblyRootPart ~= nil and joint.Part0.AssemblyRootPart == joint.Part1.AssemblyRootPart
		self._rigid[joint.name] = known
	end
	return known
end

-- Places non-rigid AnimationConstraint parts from the root outwards:
-- Part1 = Part0 * Attachment0 * Transform * Attachment1:Inverse().
function Preview._placeConstraintParts(self: Preview)
	for _, entry in self._order do
		local joint = self.binder.joints[entry.name]
		if joint and not self:_isOffsetJoint(joint) then
			local transform = self._constraintPose[entry.name] or CFrame.identity
			joint.Part1.CFrame = joint.Part0.CFrame * self:restC0(joint) * transform * RigBinder.frame1(joint):Inverse()
		end
	end
end

function Preview._apply(self: Preview, pose: { [string]: CFrame })
	if self.mode == "Transform" then
		self.binder:applyPose(pose)
		return
	end
	local placeParts = false
	for jointName, transform in pose do
		local joint = self.binder.joints[jointName]
		if joint then
			if self:_isOffsetJoint(joint) then
				local target = offsetTarget(joint)
				writeFrame(target, self:_restFrame(target) * transform)
			else
				self._constraintPose[jointName] = transform
				placeParts = true
			end
		end
	end
	if placeParts then
		self._constraintPosed = true
		self:_placeConstraintParts()
	end
end

-- The joint's rest frame on Part0: its C0 / Attachment0 CFrame before Animora posed it.
function Preview.restC0(self: Preview, joint: RigBinder.Joint): CFrame
	local target = offsetTarget(joint)
	local known = self._original[target]
	if known then
		return known
	end
	local stored = target:GetAttribute(REST_ATTRIBUTE)
	return if typeof(stored) == "CFrame" then stored else readFrame(target)
end

-- Shows a single static pose (used while editing). Call restore() to undo it.
function Preview.showPose(self: Preview, pose: { [string]: CFrame })
	self:_apply(pose)
end

-- Starts playback; `onTick(elapsedSeconds)` runs after each applied frame.
function Preview.play(self: Preview, clip: Model.Clip, onTick: ((number) -> ())?)
	self:stop()
	self.frameCount = 0
	self.startedAt = os.clock()

	self._connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - self.startedAt
		local t = elapsed
		if clip.looped then
			t = elapsed % clip.length
		elseif elapsed > clip.length then
			self:stop()
			return
		end
		self:_apply(Interpolate.sampleClip(clip, t))
		self.frameCount += 1
		if onTick then
			onTick(elapsed)
		end
	end)
end

-- Stops playback and puts every touched joint back to its rest pose.
function Preview.stop(self: Preview)
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self.mode == "Transform" then
		self.binder:resetPose()
		return
	end
	for target, rest in self._original do
		if target.Parent then
			writeFrame(target, rest)
			target:SetAttribute(REST_ATTRIBUTE, nil)
		end
	end
	table.clear(self._original)
	if self._constraintPosed then
		table.clear(self._constraintPose)
		self:_placeConstraintParts()
		self._constraintPosed = false
	end
end

-- Same as stop(): stops playback (if any) and puts the rig back in its rest pose.
function Preview.restore(self: Preview)
	self:stop()
end

return Preview
