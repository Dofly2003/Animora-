--!strict
-- Shows poses on a rig in edit mode (no Play Solo) and plays clips by sampling them
-- every frame. Write modes (Spike C, 2026-09-26):
--   "C0":        edit-mode preview. Motor6D joints: C0 = rest C0 * transform (restored
--                on stop). AnimationConstraint joints (Avatar Joint Upgrade) are not
--                solved in edit mode, so their parts are placed directly with forward
--                kinematics, parents first; stop places them back at the rest pose.
--   "Transform": writes the joints' Transform. Only visible while the game runs.

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Interpolate = require(script.Parent.Parent.Core.Interpolate)
local RigBinder = require(script.Parent.RigBinder)

export type Mode = "Transform" | "C0"

-- The rig's rest C0 is also stored as an attribute on each Motor6D while a pose is
-- shown, so a rig saved mid-preview (or after a crash) can still be restored.
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
		_originalC0: { [Motor6D]: CFrame },
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
		_originalC0 = {},
		_order = binder:jointOrder(),
		_constraintPose = {},
		_constraintPosed = false,
	}, Preview)
end

function Preview.isPlaying(self: Preview): boolean
	return self._connection ~= nil
end

-- Places every AnimationConstraint-driven part from the root outwards:
-- Part1 = Part0 * Attachment0 * Transform * Attachment1:Inverse().
function Preview._placeConstraintParts(self: Preview)
	for _, entry in self._order do
		local joint = self.binder.joints[entry.name]
		if joint and joint.kind == "AnimationConstraint" then
			local transform = self._constraintPose[entry.name] or CFrame.identity
			joint.Part1.CFrame = joint.Part0.CFrame
				* RigBinder.frame0(joint)
				* transform
				* RigBinder.frame1(joint):Inverse()
		end
	end
end

function Preview._apply(self: Preview, pose: { [string]: CFrame })
	if self.mode == "Transform" then
		self.binder:applyPose(pose)
		return
	end
	local touchedConstraints = false
	for jointName, transform in pose do
		local joint = self.binder.joints[jointName]
		if joint then
			if joint.kind == "Motor6D" then
				local motor = joint.instance :: Motor6D
				motor.C0 = self:_restC0(motor) * transform
			else
				self._constraintPose[jointName] = transform
				touchedConstraints = true
			end
		end
	end
	if touchedConstraints then
		self._constraintPosed = true
		self:_placeConstraintParts()
	end
end

function Preview._restC0(self: Preview, joint: Motor6D): CFrame
	local known = self._originalC0[joint]
	if known then
		return known
	end
	local stored = joint:GetAttribute(REST_ATTRIBUTE)
	local rest = if typeof(stored) == "CFrame" then stored else joint.C0
	if stored == nil then
		joint:SetAttribute(REST_ATTRIBUTE, rest)
	end
	self._originalC0[joint] = rest
	return rest
end

-- The joint's rest frame on Part0: its C0 before Animora posed it, or Attachment0's
-- CFrame (Animora never changes attachments).
function Preview.restC0(self: Preview, joint: RigBinder.Joint): CFrame
	if joint.kind == "Motor6D" then
		return self:_restC0(joint.instance :: Motor6D)
	end
	return RigBinder.frame0(joint)
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
	for joint, originalC0 in self._originalC0 do
		if joint.Parent then
			joint.C0 = originalC0
			joint:SetAttribute(REST_ATTRIBUTE, nil)
		end
	end
	table.clear(self._originalC0)
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
