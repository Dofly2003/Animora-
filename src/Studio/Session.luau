--!strict
-- Editor state for one Studio session: the active rig, its clip, the current time,
-- the selected joint and keyframes, playback, clipboard and undo history. UI and
-- gizmos read from here and call its methods; `changed` fires with what changed
-- ("rig", "clip", "time", "selection", "keys", "playing").

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Interpolate = require(script.Parent.Parent.Core.Interpolate)
local Commands = require(script.Parent.Parent.Core.Commands)
local Signal = require(script.Parent.Parent.Core.Signal)
local Mirror = require(script.Parent.Parent.Core.Mirror)
local RigBinder = require(script.Parent.RigBinder)
local Preview = require(script.Parent.Preview)

local DEFAULT_FPS = 30
local DEFAULT_LENGTH = 2 -- seconds

export type Change = "rig" | "clip" | "time" | "selection" | "keys" | "playing"

-- A keyframe is identified by its joint and time.
export type KeyRef = { joint: string, time: number }

type RigState = { clip: Model.Clip }

-- Deep copy of every track plus the key selection, used for undo of multi-key edits.
type Snapshot = { tracks: { [string]: { Model.Keyframe } }, selection: { KeyRef } }

-- Copied keyframes, shared across rigs so poses can be pasted onto another rig.
type ClipboardItem = { joint: string, offset: number, keyframe: Model.Keyframe }
local clipboard: { ClipboardItem } = {}

local SUPPORTED_FPS = { 24, 30, 60 }
local TIME_EPSILON = 1e-4

local Session = {}
Session.__index = Session

export type Session = typeof(setmetatable(
	{} :: {
		rig: Model?,
		binder: RigBinder.RigBinder?,
		jointOrder: { RigBinder.JointEntry },
		clip: Model.Clip?,
		history: Commands.History,
		-- Called after every recorded edit with its name (used to add a Studio undo waypoint).
		onEdit: ((name: string) -> ())?,
		time: number,
		selectedJoint: string?,
		selectedKeys: { KeyRef },
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
		-- One history for all rigs: undoing an edit switches back to the rig it was made on.
		history = Commands.History.new(),
		onEdit = nil,
		time = 0,
		selectedJoint = nil,
		selectedKeys = {},
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
-- keeps its own clip for the rest of the Studio session.
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
	self.selectedKeys = {}
	self.rig = rig

	if rig then
		local binder = RigBinder.new(rig)
		local state = self._rigStates[rig]
		if not state then
			local clip = Model.newClip(rig.Name, DEFAULT_FPS)
			clip.length = DEFAULT_LENGTH
			state = { clip = clip }
			self._rigStates[rig] = state
		end
		self.binder = binder
		self.jointOrder = binder:jointOrder()
		self.clip = state.clip
		self._preview = Preview.new(binder, "C0")
		self.time = math.clamp(self.time, 0, state.clip.length)
		self:refreshPose()
	else
		self.binder = nil
		self.jointOrder = {}
		self.clip = nil
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
	if not clip then
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

	self:_execute("Set keyframe", {
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

-- Records an edit made on the current rig. Its apply/revert first switch back to that
-- rig, so undo works even after the user moved on to another rig.
function Session._execute(self: Session, name: string, step: { apply: () -> (), revert: () -> () })
	local rig = self.rig
	local function onRig(action: () -> ())
		return function()
			if rig and self.rig ~= rig and rig.Parent then
				self:setRig(rig)
			end
			if self.rig == rig then
				action()
			end
		end
	end
	self.history:execute({ name = name, apply = onRig(step.apply), revert = onRig(step.revert) })
	if self.onEdit then
		self.onEdit(name)
	end
end

function Session.undo(self: Session): boolean
	return self.history:undo() ~= nil
end

function Session.redo(self: Session): boolean
	return self.history:redo() ~= nil
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

-- Key selection -------------------------------------------------------------------

function Session.isKeySelected(self: Session, joint: string, time: number): boolean
	for _, ref in self.selectedKeys do
		if ref.joint == joint and math.abs(ref.time - time) < TIME_EPSILON then
			return true
		end
	end
	return false
end

function Session.setKeySelection(self: Session, refs: { KeyRef })
	self.selectedKeys = refs
	self.changed:Fire("keys")
end

-- Adds refs to the selection; with `toggle`, refs already selected are removed instead.
function Session.addKeySelection(self: Session, refs: { KeyRef }, toggle: boolean?)
	local selection = table.clone(self.selectedKeys)
	for _, ref in refs do
		local found = nil
		for index, existing in selection do
			if existing.joint == ref.joint and math.abs(existing.time - ref.time) < TIME_EPSILON then
				found = index
				break
			end
		end
		if found and toggle then
			table.remove(selection, found)
		elseif not found then
			table.insert(selection, ref)
		end
	end
	self:setKeySelection(selection)
end

-- Multi-key edits (undo via snapshots) ---------------------------------------------

function Session._snapshot(self: Session): Snapshot
	local tracks = {}
	for name, track in (self.clip :: Model.Clip).tracks do
		local keyframes = {}
		for index, keyframe in track.keyframes do
			keyframes[index] = table.clone(keyframe)
		end
		tracks[name] = keyframes
	end
	local selection = {}
	for index, ref in self.selectedKeys do
		selection[index] = table.clone(ref)
	end
	return { tracks = tracks, selection = selection }
end

function Session._restore(self: Session, snapshot: Snapshot)
	local clip = self.clip :: Model.Clip
	table.clear(clip.tracks)
	for name, keyframes in snapshot.tracks do
		local copy = {}
		for index, keyframe in keyframes do
			copy[index] = table.clone(keyframe)
		end
		clip.tracks[name] = { jointName = name, keyframes = copy }
	end
	local selection = {}
	for index, ref in snapshot.selection do
		selection[index] = table.clone(ref)
	end
	self.selectedKeys = selection
	self:refreshPose()
	self.changed:Fire("clip")
	self.changed:Fire("keys")
end

-- Runs `mutate` on the clip and records it as one undoable step.
function Session._edit(self: Session, name: string, mutate: (clip: Model.Clip) -> ())
	local clip = self.clip
	if not clip then
		return
	end
	self:pause()
	local before = self:_snapshot()
	mutate(clip)
	for trackName, track in clip.tracks do
		if #track.keyframes == 0 then
			clip.tracks[trackName] = nil
		end
	end
	local after = self:_snapshot()
	self:_execute(name, {
		apply = function()
			self:_restore(after)
		end,
		revert = function()
			self:_restore(before)
		end,
	})
end

local function findKeyframe(track: Model.Track?, time: number): Model.Keyframe?
	if not track then
		return nil
	end
	for _, keyframe in track.keyframes do
		if math.abs(keyframe.time - time) < TIME_EPSILON then
			return keyframe
		end
	end
	return nil
end

function Session.deleteSelectedKeys(self: Session): number
	local refs = self.selectedKeys
	if #refs == 0 then
		return 0
	end
	self:_edit("Delete keyframes", function(clip)
		for _, ref in refs do
			local track = clip.tracks[ref.joint]
			local keyframe = findKeyframe(track, ref.time)
			if track and keyframe then
				Model.removeKeyframe(track, keyframe.time)
			end
		end
		self.selectedKeys = {}
	end)
	return #refs
end

-- Moves the selected keyframes by `delta` seconds (snapped to whole frames). Keys that
-- land on an existing keyframe replace it.
function Session.moveSelectedKeys(self: Session, delta: number)
	local clip = self.clip
	if not clip or #self.selectedKeys == 0 then
		return
	end
	local frames = math.round(delta * clip.fps)
	if frames == 0 then
		return
	end
	local shift = frames / clip.fps
	local refs = self.selectedKeys
	self:_edit("Move keyframes", function(editClip)
		local moving: { { joint: string, keyframe: Model.Keyframe } } = {}
		for _, ref in refs do
			local track = editClip.tracks[ref.joint]
			local keyframe = findKeyframe(track, ref.time)
			if track and keyframe then
				Model.removeKeyframe(track, keyframe.time)
				table.insert(moving, { joint = ref.joint, keyframe = keyframe })
			end
		end
		local selection = {}
		for _, item in moving do
			local time = Model.snapToFrame(editClip, math.clamp(item.keyframe.time + shift, 0, editClip.length))
			local moved = table.clone(item.keyframe)
			moved.time = time
			Model.setKeyframe(Model.getOrCreateTrack(editClip, item.joint), moved)
			table.insert(selection, { joint = item.joint, time = time })
		end
		self.selectedKeys = selection
	end)
end

-- Copies the selected keyframes; with none selected, copies the current pose of every
-- animated joint at the playhead.
function Session.copy(self: Session): number
	local clip = self.clip
	if not clip then
		return 0
	end
	local items: { ClipboardItem } = {}
	if #self.selectedKeys > 0 then
		local earliest = math.huge
		for _, ref in self.selectedKeys do
			earliest = math.min(earliest, ref.time)
		end
		for _, ref in self.selectedKeys do
			local keyframe = findKeyframe(clip.tracks[ref.joint], ref.time)
			if keyframe then
				table.insert(
					items,
					{ joint = ref.joint, offset = ref.time - earliest, keyframe = table.clone(keyframe) }
				)
			end
		end
	else
		for name in clip.tracks do
			local keyframe = Model.newKeyframe(self.time, self:getJointTransform(name))
			table.insert(items, { joint = name, offset = 0, keyframe = keyframe })
		end
	end
	clipboard = items
	return #items
end

-- Pastes copied keyframes at the playhead (skipping joints this rig does not have).
function Session.paste(self: Session): number
	local binder = self.binder
	if not binder or #clipboard == 0 then
		return 0
	end
	local startTime = self.time
	local pasted = 0
	self:_edit("Paste keyframes", function(clip)
		local selection = {}
		for _, item in clipboard do
			local time = Model.snapToFrame(clip, startTime + item.offset)
			if binder.joints[item.joint] and time <= clip.length + TIME_EPSILON then
				local keyframe = table.clone(item.keyframe)
				keyframe.time = time
				Model.setKeyframe(Model.getOrCreateTrack(clip, item.joint), keyframe)
				table.insert(selection, { joint = item.joint, time = time })
				pasted += 1
			end
		end
		self.selectedKeys = selection
	end)
	return pasted
end

-- Mirrors the pose at the playhead: the selected joint onto its opposite side, or,
-- with no joint selected, the whole pose left <-> right.
function Session.mirror(self: Session): number
	local binder = self.binder
	local preview = self._preview
	local clip = self.clip
	if not (binder and preview and clip) then
		return 0
	end

	local sources: { string } = {}
	if self.selectedJoint then
		table.insert(sources, self.selectedJoint)
	else
		for name in clip.tracks do
			table.insert(sources, name)
		end
	end

	-- Compute every mirrored value from the pose before writing any of them.
	local writes: { { joint: string, value: CFrame } } = {}
	for _, source in sources do
		local target = Mirror.oppositeJoint(source)
		local fromJoint = binder.joints[source]
		local toJoint = binder.joints[target]
		local isCenterJoint = target == source
		if fromJoint and toJoint and not (isCenterJoint and self.selectedJoint ~= nil) then
			local value = Mirror.mirrorJointTransform(
				self:getJointTransform(source),
				preview:restC0(fromJoint),
				preview:restC0(toJoint)
			)
			table.insert(writes, { joint = target, value = value })
		end
	end
	if #writes == 0 then
		return 0
	end

	local time = self.time
	self:_edit("Mirror pose", function(editClip)
		for _, write in writes do
			local track = Model.getOrCreateTrack(editClip, write.joint)
			local existing = findKeyframe(track, time)
			local keyframe = Model.newKeyframe(
				time,
				write.value,
				if existing then existing.easingStyle else "Linear",
				if existing then existing.easingDirection else "In"
			)
			Model.setKeyframe(track, keyframe)
		end
	end)
	return #writes
end

-- Navigation ------------------------------------------------------------------------

function Session.stepFrame(self: Session, frames: number)
	local clip = self.clip
	if not clip then
		return
	end
	self:pause()
	self:setTime(self.time + frames / clip.fps)
end

-- Jumps to the next (direction 1) or previous (-1) keyframe time on any track.
function Session.jumpToKey(self: Session, direction: number)
	local clip = self.clip
	if not clip then
		return
	end
	self:pause()
	local bestTime: number? = nil
	local bestDistance = math.huge
	for _, track in clip.tracks do
		for _, keyframe in track.keyframes do
			local distance = (keyframe.time - self.time) * direction
			if distance > TIME_EPSILON and distance < bestDistance then
				bestDistance = distance
				bestTime = keyframe.time
			end
		end
	end
	if bestTime then
		self:setTime(bestTime)
	end
end

-- Cycles 24 -> 30 -> 60 FPS. Keyframes keep their time in seconds.
function Session.cycleFps(self: Session): number?
	local clip = self.clip
	if not clip then
		return nil
	end
	local index = table.find(SUPPORTED_FPS, clip.fps) or 0
	clip.fps = SUPPORTED_FPS[index % #SUPPORTED_FPS + 1]
	self:setTime(self.time)
	self.changed:Fire("clip")
	return clip.fps
end

function Session.destroy(self: Session)
	self:setRig(nil)
	self.changed:DisconnectAll()
end

return Session
