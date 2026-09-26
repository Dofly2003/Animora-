--!strict
-- Plays a clip on a rig in edit mode (no Play Solo) by sampling it every frame.
-- Two write modes are compared in Spike C:
--   "Transform": writes Motor6D.Transform (not saved, not in undo history)
--   "C0":        writes Motor6D.C0 = original C0 * transform, restored on stop

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Interpolate = require(script.Parent.Parent.Core.Interpolate)
local RigBinder = require(script.Parent.RigBinder)

export type Mode = "Transform" | "C0"

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
			if not self._originalC0[joint] then
				self._originalC0[joint] = joint.C0
			end
			joint.C0 = self._originalC0[joint] * transform
		end
	end
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
			end
		end
		table.clear(self._originalC0)
	end
end

return Preview
