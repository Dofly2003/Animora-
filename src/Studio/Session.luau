--!strict
-- Editor state for one Studio session: the active rig, its clip, the current time,
-- the selected joint, playback and undo history. UI and gizmos read from here and
-- call its methods; `changed` fires with what changed ("rig", "clip", "time",
-- "selection", "playing").

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Interpolate = require(script.Parent.Parent.Core.Interpolate)
local Commands = require(script.Parent.Parent.Core.Commands)
local Signal = require(script.Parent.Parent.Core.Signal)
local RigBinder = require(script.Parent.RigBinder)
local Preview = require(script.Parent.Preview)

local DEFAULT_FPS = 30
local DEFAULT_LENGTH = 2 -- seconds

export type Change = "rig" | "clip" | "time" | "selection" | "playing"

type RigState = { clip: Model.Clip, history: Commands.History }

local Session = {}
Session.__index = Session

export type Session = typeof(setmetatable(
	{} :: {
		rig: Model?,
		binder: RigBinder.RigBinder?,
		jointOrder: { RigBinder.JointEntry },
		clip: Model.Clip?,
		history: Commands.History?,
		time: number,
		selectedJoint: string?,
		playing: boolean,
		changed: Signal.Signal,
		_preview: Preview.Preview?,
		_override: { name: string, value: CFrame }?,
		_rigStates: { [Model]: RigState },
		_playConnection: RBXScriptConnection?,
	},
	Session
))

function Session.new(): Session
	return setmetatable({
		rig = nil,
		binder = nil,
		jointOrder = {},
		clip = nil,
		history = nil,
		time = 0,
		selectedJoint = nil,
		playing = false,
		changed = Signal.new(),
		_preview = nil,
		_override = nil,
		-- Weak keys: a deleted rig does not keep its clip alive.
		_rigStates = setmetatable({}, { __mode = "k" }) :: any,
		_playConnection = nil,
	}, Session)
end

-- Switches the edited rig. The previous rig goes back to its rest pose; each rig
-- keeps its own clip and undo history for the rest of the Studio session.
function Session.setRig(self: Session, rig: Model?)
	if rig == self.rig then
		return
	end
	self:pause()
	if self._preview then
		self._preview:restore()
	end
	self._preview = nil
	self._override = nil
	self.selectedJoint = nil
	self.rig = rig

	if rig then
		local binder = RigBinder.new(rig)
		local state = self._rigStates[rig]
		if not state then
			local clip = Model.newClip(rig.Name, DEFAULT_FPS)
			clip.length = DEFAULT_LENGTH
			state = { clip = clip, history = Commands.History.new() }
			self._rigStates[rig] = state
		end
		self.binder = binder
		self.jointOrder = binder:jointOrder()
		self.clip = state.clip
		self.history = state.history
		self._preview = Preview.new(binder, "C0")
		self.time = math.clamp(self.time, 0, state.clip.length)
		self:refreshPose()
	else
		self.binder = nil
		self.jointOrder = {}
		self.clip = nil
		self.history = nil
	end
	self.changed:Fire("rig")
end

-- Current transform of a joint: the drag in progress, else the clip sampled at `time`.
function Session.getJointTransform(self: Session, jointName: string): CFrame
	local override = self._override
	if override and override.name == jointName then
		return override.value
	end
	local track = self.clip and self.clip.tracks[jointName]
	return if track then Interpolate.sampleTrack(track, self.time) else CFrame.identity
end

-- Re-applies the pose at the current time to the rig (also after Studio undo/redo,
-- which can change the C0 values underneath us).
function Session.refreshPose(self: Session)
	local preview = self._preview
	if not preview then
		return
	end
	local pose: { [string]: CFrame } = {}
	for _, entry in self.jointOrder do
		pose[entry.name] = self:getJointTransform(entry.name)
	end
	preview:showPose(pose)
end

function Session.setTime(self: Session, time: number)
	local clip = self.clip
	if not clip then
		return
	end
	self.time = Model.snapToFrame(clip, math.clamp(time, 0, clip.length))
	self:refreshPose()
	self.changed:Fire("time")
end

function Session.selectJoint(self: Session, jointName: string?)
	if jointName and not (self.binder and self.binder.joints[jointName]) then
		jointName = nil
	end
	if jointName ~= self.selectedJoint then
		self.selectedJoint = jointName
		self.changed:Fire("selection")
	end
end

-- Live preview while dragging a gizmo; nothing is stored until commitJoint.
function Session.previewJoint(self: Session, jointName: string, value: CFrame)
	self._override = { name = jointName, value = value }
	self:refreshPose()
end

function Session.cancelPreview(self: Session)
	self._override = nil
	self:refreshPose()
end

-- Stores `value` as a keyframe for the joint at the current time (auto-key). Undoable.
function Session.commitJoint(self: Session, jointName: string, value: CFrame)
	self._override = nil
	local clip = self.clip
	local history = self.history
	if not (clip and history) then
		return
	end

	local time = self.time
	local existing = clip.tracks[jointName]
	local previous: Model.Keyframe? = nil
	if existing then
		for _, keyframe in existing.keyframes do
			if math.abs(keyframe.time - time) < 1e-6 then
				previous = table.clone(keyframe)
				break
			end
		end
	end

	history:execute({
		name = "Set keyframe",
		apply = function()
			local track = Model.getOrCreateTrack(clip, jointName)
			local easingStyle = if previous then previous.easingStyle else "Linear"
			local easingDirection = if previous then previous.easingDirection else "In"
			Model.setKeyframe(track, Model.newKeyframe(time, value, easingStyle, easingDirection))
			self:_afterEdit()
		end,
		revert = function()
			local track = clip.tracks[jointName]
			if track then
				if previous then
					Model.setKeyframe(track, previous)
				else
					Model.removeKeyframe(track, time)
					if #track.keyframes == 0 then
						clip.tracks[jointName] = nil
					end
				end
			end
			self:_afterEdit()
		end,
	})
end

function Session._afterEdit(self: Session)
	self:refreshPose()
	self.changed:Fire("clip")
end

function Session.undo(self: Session): boolean
	return self.history ~= nil and self.history:undo() ~= nil
end

function Session.redo(self: Session): boolean
	return self.history ~= nil and self.history:redo() ~= nil
end

function Session.play(self: Session)
	local clip = self.clip
	if self.playing or not clip then
		return
	end
	self.playing = true
	self._override = nil
	self._playConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self.time = (self.time + deltaTime) % clip.length
		self:refreshPose()
		self.changed:Fire("time")
	end)
	self.changed:Fire("playing")
end

-- Stops playback and snaps the playhead to the nearest frame.
function Session.pause(self: Session)
	if not self.playing then
		return
	end
	self.playing = false
	if self._playConnection then
		self._playConnection:Disconnect()
		self._playConnection = nil
	end
	self.changed:Fire("playing")
	self:setTime(self.time)
end

function Session.togglePlay(self: Session)
	if self.playing then
		self:pause()
	else
		self:play()
	end
end

function Session.destroy(self: Session)
	self:setRig(nil)
	self.changed:DisconnectAll()
end

return Session
