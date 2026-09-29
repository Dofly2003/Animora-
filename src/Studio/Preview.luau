--!strict
-- Plays a clip on a rig in edit mode (no Play Solo) by sampling it every frame.
-- Write modes (Spike C, 2026-09-26):
--   "C0":        writes Motor6D.C0 = original C0 * transform, restored on stop. Default: works in edit mode.
--   "Transform": writes Motor6D.Transform. Not rendered in edit mode; only useful while the game runs.

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
	}, Preview)
end

function Preview.isPlaying(self: Preview): boolean
	return self._connection ~= nil
end

function Preview._apply(self: Preview, pose: { [string]: CFrame })
	if self.mode == "Transform" then
		self.binder:applyPose(pose)
		return
	end
	for jointName, transform in pose do
		local joint = self.binder.joints[jointName]
		if joint then
			joint.C0 = self:_restC0(joint) * transform
		end
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

-- The joint's rest C0 (its C0 before Animora posed it).
function Preview.restC0(self: Preview, joint: Motor6D): CFrame
	return self:_restC0(joint)
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
	else
		for joint, originalC0 in self._originalC0 do
			if joint.Parent then
				joint.C0 = originalC0
				joint:SetAttribute(REST_ATTRIBUTE, nil)
			end
		end
		table.clear(self._originalC0)
	end
end

-- Same as stop(): stops playback (if any) and puts the rig back in its rest pose.
function Preview.restore(self: Preview)
	self:stop()
end

return Preview
