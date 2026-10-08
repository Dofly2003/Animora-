--!strict
-- Editor state for one Studio session: the active rig, its animations (clips) and the
-- one being edited, the current time,
-- the selected joint and keyframes, playback, clipboard and undo history. UI and
-- gizmos read from here and call its methods; `changed` fires with what changed
-- ("rig", "animation", "clip", "time", "selection", "keys", "playing").

local HttpService = game:GetService("HttpService")

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Interpolate = require(script.Parent.Parent.Core.Interpolate)
local Commands = require(script.Parent.Parent.Core.Commands)
local Signal = require(script.Parent.Parent.Core.Signal)
local Mirror = require(script.Parent.Parent.Core.Mirror)
local Templates = require(script.Parent.Parent.Core.Templates)
local Bake = require(script.Parent.Parent.Core.Bake)
local RigBinder = require(script.Parent.RigBinder)
local Preview = require(script.Parent.Preview)
local IO = require(script.Parent.IO)

local DEFAULT_FPS = 30
local DEFAULT_LENGTH = 2 -- seconds

export type Change = "rig" | "animation" | "clip" | "time" | "selection" | "keys" | "playing"

-- A keyframe is identified by its joint and time.
export type KeyRef = { joint: string, time: number }

-- A rig's animations and the one being edited.
type RigState = { clips: { Model.Clip }, active: Model.Clip }

-- Deep copy of every track, the clip settings and the key selection, used for undo.
type ClipSettings = {
	name: string,
	length: number,
	fps: number,
	looped: boolean,
	priority: Enum.AnimationPriority,
}
type Snapshot = { tracks: { [string]: { Model.Keyframe } }, settings: ClipSettings, selection: { KeyRef } }

-- Copied keyframes, shared across rigs so poses can be pasted onto another rig.
type ClipboardItem = { joint: string, offset: number, keyframe: Model.Keyframe }
local clipboard: { ClipboardItem } = {}

local SUPPORTED_FPS = { 24, 30, 60 }
local PRIORITIES = {
	Enum.AnimationPriority.Core,
	Enum.AnimationPriority.Idle,
	Enum.AnimationPriority.Movement,
	Enum.AnimationPriority.Action,
	Enum.AnimationPriority.Action2,
	Enum.AnimationPriority.Action3,
	Enum.AnimationPriority.Action4,
}
local MIN_LENGTH, MAX_LENGTH = 0.1, 600 -- seconds
local TIME_EPSILON = 1e-4

local Session = {}
Session.__index = Session

export type GizmoMode = "rotate" | "move"

export type Session = typeof(setmetatable(
	{} :: {
		rig: Model?,
		binder: RigBinder.RigBinder?,
		jointOrder: { RigBinder.JointEntry },
		-- The rig's animations, in list order; `clip` is the one being edited.
		clips: { Model.Clip },
		clip: Model.Clip?,
		history: Commands.History,
		-- Called after every recorded edit with its name (used to add a Studio undo waypoint
		-- and to save the rig's animations into the place).
		onEdit: ((name: string) -> ())?,
		-- Loads a rig's saved animations the first time the rig is opened in this session.
		loadClips: ((rig: Model) -> { Model.Clip }?)?,
		time: number,
		selectedJoint: string?,
		-- Which viewport handles to show: rotate rings, or move arrows (root joint only).
		gizmoMode: GizmoMode,
		-- When true, the Studio camera follows the camera track while scrubbing / playing.
		cameraPreview: boolean,
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
		clips = {},
		clip = nil,
		-- One history for all rigs: undoing an edit switches back to the rig it was made on.
		history = Commands.History.new(),
		onEdit = nil,
		loadClips = nil,
		time = 0,
		selectedJoint = nil,
		gizmoMode = "rotate",
		cameraPreview = false,
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

local function newId(): string
	return HttpService:GenerateGUID(false)
end

local function newClip(name: string): Model.Clip
	local clip = Model.newClip(name, DEFAULT_FPS)
	clip.length = DEFAULT_LENGTH
	clip.id = newId()
	return clip
end

-- Switches the edited rig. The previous rig goes back to its rest pose; each rig keeps
-- its animations for the rest of the Studio session.
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
			local clips = (self.loadClips and self.loadClips(rig)) or {}
			if #clips == 0 then
				table.insert(clips, newClip("Animation"))
			end
			for _, clip in clips do
				clip.id = clip.id or newId()
			end
			state = { clips = clips, active = clips[1] }
			self._rigStates[rig] = state
		end
		self.binder = binder
		-- The camera track is listed first, above the rig's joints.
		self.jointOrder = { { name = Model.CAMERA_TRACK, depth = 0 } }
		for _, entry in binder:jointOrder() do
			table.insert(self.jointOrder, entry)
		end
		self.clips = state.clips
		self.clip = state.active
		self._preview = Preview.new(binder, "C0")
		self.time = math.clamp(self.time, 0, state.active.length)
		self:refreshPose()
	else
		self.binder = nil
		self.jointOrder = {}
		self.clips = {}
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

-- The joint's rest frame on Part0 (C0 / Attachment0 before Animora posed it).
function Session.restFrame0(self: Session, jointName: string): CFrame?
	local joint = self.binder and self.binder.joints[jointName]
	local preview = self._preview
	if joint and preview then
		return preview:restC0(joint)
	end
	return nil
end

-- True for the joint that connects the rig to its root part (LowerTorso on R15,
-- Torso on R6): the one whose position, not just rotation, is animated.
function Session.isRootJoint(self: Session, jointName: string): boolean
	local binder = self.binder
	local joint = binder and binder.joints[jointName]
	return joint ~= nil and joint.Part0 == RigBinder.findRootPart(binder.joints)
end

-- Name of the root joint (see isRootJoint), or nil when the rig has none.
function Session.rootJointName(self: Session): string?
	local binder = self.binder
	if not binder then
		return nil
	end
	local rootPart = RigBinder.findRootPart(binder.joints)
	for name, joint in binder.joints do
		if joint.Part0 == rootPart then
			return name
		end
	end
	return nil
end

-- Switches between rotate rings and move arrows. Only the root joint can be moved, so
-- move mode selects it when another joint is selected.
function Session.setGizmoMode(self: Session, mode: GizmoMode)
	if mode == "move" then
		local root = self:rootJointName()
		if root and self.selectedJoint ~= root then
			self:selectJoint(root)
		end
	end
	if mode ~= self.gizmoMode then
		self.gizmoMode = mode
		self.changed:Fire("gizmoMode")
	end
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
	self:_applyCameraPreview()
end

-- Camera ---------------------------------------------------------------------------------

-- The camera track's CFrame at the current time, or nil when it has no keyframes.
function Session.cameraTransform(self: Session): CFrame?
	local override = self._override
	if override and override.name == Model.CAMERA_TRACK then
		return override.value
	end
	local track = self.clip and self.clip.tracks[Model.CAMERA_TRACK]
	if not track or #track.keyframes == 0 then
		return nil
	end
	return Interpolate.sampleTrack(track, self.time)
end

function Session._applyCameraPreview(self: Session)
	if not self.cameraPreview then
		return
	end
	local value = self:cameraTransform()
	local camera = workspace.CurrentCamera
	if value and camera then
		camera.CFrame = value
	end
end

-- Stores the Studio viewport's camera as a camera keyframe at the playhead. Undoable.
function Session.keyCameraFromView(self: Session): boolean
	local camera = workspace.CurrentCamera
	if not (self.clip and camera) then
		return false
	end
	self:commitJoint(Model.CAMERA_TRACK, camera.CFrame)
	self:selectJoint(Model.CAMERA_TRACK)
	return true
end

-- Turns "look through the camera" on or off.
function Session.setCameraPreview(self: Session, on: boolean)
	if on == self.cameraPreview then
		return
	end
	self.cameraPreview = on
	self:_applyCameraPreview()
	self.changed:Fire("cameraPreview")
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
	local isCamera = jointName == Model.CAMERA_TRACK and self.binder ~= nil
	if jointName and not isCamera and not (self.binder and self.binder.joints[jointName]) then
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

	self:_execute("Set keyframe", clip, {
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
-- rig (and to `clip`, the animation it changed), so undo works even after the user moved
-- on to another rig or animation.
function Session._execute(self: Session, name: string, clip: Model.Clip?, step: { apply: () -> (), revert: () -> () })
	local rig = self.rig
	local function onRig(action: () -> ())
		return function()
			if rig and self.rig ~= rig and rig.Parent then
				self:setRig(rig)
			end
			if self.rig ~= rig then
				return
			end
			if clip and self.clip ~= clip and table.find(self.clips, clip) then
				self:_activate(clip)
			end
			action()
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

-- Where playback loops: the last keyframe on any track, or the clip length when the
-- clip has no keyframe after time 0.
function Session.playbackEnd(self: Session): number
	local clip = self.clip
	if not clip then
		return 0
	end
	local last = 0
	for _, track in clip.tracks do
		local keyframes = track.keyframes
		if #keyframes > 0 then
			last = math.max(last, keyframes[#keyframes].time)
		end
	end
	return if last > 0 then last else clip.length
end

-- Plays from the playhead up to the last keyframe, then loops back to the start.
function Session.play(self: Session)
	local clip = self.clip
	if self.playing or not clip then
		return
	end
	local loopEnd = self:playbackEnd()
	if loopEnd <= 0 then
		return
	end
	self.playing = true
	self._override = nil
	if self.time >= loopEnd then
		self.time = 0
	end
	self._playConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self.time = (self.time + deltaTime) % loopEnd
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
	local clip = self.clip :: Model.Clip
	local settings = {
		name = clip.name,
		length = clip.length,
		fps = clip.fps,
		looped = clip.looped,
		priority = clip.priority,
	}
	return { tracks = tracks, settings = settings, selection = selection }
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
	clip.name = snapshot.settings.name
	clip.length = snapshot.settings.length
	clip.fps = snapshot.settings.fps
	clip.looped = snapshot.settings.looped
	clip.priority = snapshot.settings.priority
	self.time = math.min(self.time, clip.length)
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
	self:_execute(name, clip, {
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
			if name ~= Model.CAMERA_TRACK then
				local keyframe = Model.newKeyframe(self.time, self:getJointTransform(name))
				table.insert(items, { joint = name, offset = 0, keyframe = keyframe })
			end
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
			local known = binder.joints[item.joint] ~= nil or item.joint == Model.CAMERA_TRACK
			if known and time <= clip.length + TIME_EPSILON then
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

-- Easing ----------------------------------------------------------------------------

-- Easing of the first selected keyframe, for showing the current choice in the UI.
function Session.selectedEasing(self: Session): (Model.EasingStyle?, Model.EasingDirection?)
	local clip = self.clip
	local ref = self.selectedKeys[1]
	local keyframe = clip and ref and findKeyframe(clip.tracks[ref.joint], ref.time)
	if keyframe then
		return keyframe.easingStyle, keyframe.easingDirection
	end
	return nil, nil
end

-- Sets the easing (style and/or direction) of every selected keyframe. A keyframe's
-- easing shapes the motion from it to the next keyframe. Returns how many changed.
function Session.setEasing(self: Session, style: Model.EasingStyle?, direction: Model.EasingDirection?): number
	local refs = self.selectedKeys
	if #refs == 0 or not (style or direction) then
		return 0
	end
	local changed = 0
	self:_edit("Change easing", function(clip)
		for _, ref in refs do
			local keyframe = findKeyframe(clip.tracks[ref.joint], ref.time)
			if keyframe then
				keyframe.easingStyle = style or keyframe.easingStyle
				keyframe.easingDirection = direction or keyframe.easingDirection
				changed += 1
			end
		end
	end)
	return changed
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

-- Clip settings (undoable, saved like any other edit) --------------------------------

-- Cycles 24 -> 30 -> 60 FPS. Keyframes keep their time in seconds.
function Session.cycleFps(self: Session): number?
	local clip = self.clip
	if not clip then
		return nil
	end
	local index = table.find(SUPPORTED_FPS, clip.fps) or 0
	local fps = SUPPORTED_FPS[index % #SUPPORTED_FPS + 1]
	self:_edit("Change FPS", function(editClip)
		editClip.fps = fps
	end)
	self:setTime(self.time)
	return fps
end

-- Sets the clip length in seconds. Keyframes after the new end are kept (shown shaded).
function Session.setLength(self: Session, seconds: number)
	local clip = self.clip
	if not clip or seconds ~= seconds then
		return
	end
	local length = math.clamp(seconds, MIN_LENGTH, MAX_LENGTH)
	if math.abs(length - clip.length) < TIME_EPSILON then
		return
	end
	self:_edit("Change length", function(editClip)
		editClip.length = length
	end)
end

function Session.toggleLooped(self: Session)
	local clip = self.clip
	if not clip then
		return
	end
	local looped = not clip.looped
	self:_edit("Toggle loop", function(editClip)
		editClip.looped = looped
	end)
end

-- Cycles Core -> Idle -> Movement -> Action -> Action2..4.
function Session.cyclePriority(self: Session)
	local clip = self.clip
	if not clip then
		return
	end
	local index = table.find(PRIORITIES, clip.priority) or 0
	local priority = PRIORITIES[index % #PRIORITIES + 1]
	self:_edit("Change priority", function(editClip)
		editClip.priority = priority
	end)
end

-- Import / export ------------------------------------------------------------------------

-- Replaces the clip's keyframes with those of a KeyframeSequence (undoable). Returns the
-- number of keyframes imported.
function Session.importSequence(self: Session, sequence: KeyframeSequence): number
	local binder = self.binder
	if not binder or not self.clip then
		return 0
	end
	local result = IO.importKeyframeSequence(sequence, function(name)
		return binder.joints[name] ~= nil
	end)
	if result.keyframeCount == 0 then
		return 0
	end
	self:_edit("Import animation", function(clip)
		local camera = clip.tracks[Model.CAMERA_TRACK]
		table.clear(clip.tracks)
		clip.tracks[Model.CAMERA_TRACK] = camera
		for name, keyframes in result.tracks do
			clip.tracks[name] = { jointName = name, keyframes = keyframes }
		end
		clip.length = math.max(result.length, MIN_LENGTH)
		clip.looped = sequence.Loop
		clip.priority = sequence.Priority
		self.selectedKeys = {}
	end)
	self:setTime(0)
	return result.keyframeCount
end

-- Builds a KeyframeSequence of the clip up to the last keyframe, baked per frame so
-- every easing style plays back exactly like the preview. Not parented anywhere.
function Session.buildExport(self: Session): KeyframeSequence?
	local clip = self.clip
	local binder = self.binder
	if not (clip and binder) then
		return nil
	end
	local exportClip = table.clone(clip)
	-- The camera is not part of a KeyframeSequence; it is exported separately.
	exportClip.tracks = table.clone(clip.tracks)
	exportClip.tracks[Model.CAMERA_TRACK] = nil
	if next(exportClip.tracks) == nil then
		return nil
	end
	exportClip.length = self:playbackEnd()
	return IO.exportKeyframeSequence(Bake.bakeClip(exportClip), binder.joints)
end

-- Animation list (per rig) --------------------------------------------------------------

-- Makes `clip` the animation being edited (not an undo step).
function Session._activate(self: Session, clip: Model.Clip)
	if self.clip == clip then
		return
	end
	self:pause()
	self._override = nil
	self.clip = clip
	local state = self.rig and self._rigStates[self.rig]
	if state then
		state.active = clip
	end
	self.selectedKeys = {}
	self.time = math.clamp(self.time, 0, clip.length)
	self:refreshPose()
	self.changed:Fire("animation")
end

function Session.selectAnimation(self: Session, clip: Model.Clip)
	if table.find(self.clips, clip) then
		self:_activate(clip)
	end
end

-- `base`, or `base 2`, `base 3`... so names in one rig's list stay unique.
function Session.uniqueName(self: Session, base: string, except: Model.Clip?): string
	local function taken(name: string): boolean
		for _, clip in self.clips do
			if clip ~= except and clip.name == name then
				return true
			end
		end
		return false
	end
	local trimmed = string.gsub(base, "^%s*(.-)%s*$", "%1")
	local name = if trimmed == "" then "Animation" else trimmed
	if not taken(name) then
		return name
	end
	local index = 2
	while taken(name .. " " .. index) do
		index += 1
	end
	return name .. " " .. index
end

-- Adds `clip` to the list at `index` (undoable) and makes it the active animation.
function Session._insertAnimation(self: Session, stepName: string, clip: Model.Clip, index: number)
	local clips = self.clips
	local previous = self.clip
	self:_execute(stepName, nil, {
		apply = function()
			table.insert(clips, math.min(index, #clips + 1), clip)
			self:_activate(clip)
			self.changed:Fire("clip")
		end,
		revert = function()
			local position = table.find(clips, clip)
			if position then
				table.remove(clips, position)
			end
			if previous and table.find(clips, previous) then
				self:_activate(previous)
			elseif clips[1] then
				self:_activate(clips[1])
			end
			self.changed:Fire("clip")
		end,
	})
end

-- Creates an empty animation (undoable) and switches to it.
function Session.newAnimation(self: Session, name: string?): Model.Clip?
	if not self.rig then
		return nil
	end
	local clip = newClip(self:uniqueName(name or "Animation"))
	self:_insertAnimation("New animation", clip, #self.clips + 1)
	return clip
end

-- Copies a clip deeply (tracks, keyframes and settings) under a new id.
local function copyClip(source: Model.Clip, name: string): Model.Clip
	local clip = table.clone(source)
	clip.id = newId()
	clip.name = name
	clip.tracks = {}
	for trackName, track in source.tracks do
		local keyframes = {}
		for index, keyframe in track.keyframes do
			keyframes[index] = table.clone(keyframe)
		end
		clip.tracks[trackName] = { jointName = trackName, keyframes = keyframes }
	end
	return clip
end

-- Copies the active animation (undoable) and switches to the copy.
function Session.duplicateAnimation(self: Session): Model.Clip?
	local source = self.clip
	if not (self.rig and source) then
		return nil
	end
	local clip = copyClip(source, self:uniqueName(source.name .. " copy"))
	local index = (table.find(self.clips, source) or #self.clips) + 1
	self:_insertAnimation("Duplicate animation", clip, index)
	return clip
end

-- Renames the active animation (undoable). Returns the name actually used.
function Session.renameAnimation(self: Session, name: string): string?
	local clip = self.clip
	if not clip then
		return nil
	end
	local newName = self:uniqueName(name, clip)
	local oldName = clip.name
	if newName == oldName then
		return newName
	end
	self:_execute("Rename animation", clip, {
		apply = function()
			clip.name = newName
			self.changed:Fire("clip")
		end,
		revert = function()
			clip.name = oldName
			self.changed:Fire("clip")
		end,
	})
	return newName
end

-- Deletes the active animation (undoable). A rig always keeps at least one animation,
-- so deleting the last one leaves a fresh empty animation in its place.
function Session.deleteAnimation(self: Session): string?
	local clip = self.clip
	local clips = self.clips
	if not (self.rig and clip) then
		return nil
	end
	local index = table.find(clips, clip) or 1
	local replacement: Model.Clip? = nil
	if #clips == 1 then
		replacement = newClip("Animation")
	end
	self:_execute("Delete animation", nil, {
		apply = function()
			local position = table.find(clips, clip)
			if position then
				table.remove(clips, position)
			end
			if replacement then
				table.insert(clips, replacement)
			end
			self:_activate(clips[math.clamp(index, 1, #clips)])
			self.changed:Fire("clip")
		end,
		revert = function()
			if replacement then
				local position = table.find(clips, replacement)
				if position then
					table.remove(clips, position)
				end
			end
			table.insert(clips, math.min(index, #clips + 1), clip)
			self:_activate(clip)
			self.changed:Fire("clip")
		end,
	})
	return clip.name
end

-- Creates a new animation from a starter template (Idle, Walk, Run, Jump, Wave) fitted
-- to this rig's joints (undoable) and switches to it. Nil when the rig has none of the
-- template's joints.
function Session.newAnimationFromTemplate(self: Session, templateId: string): Model.Clip?
	local binder = self.binder
	local preview = self._preview
	local template = Templates.get(templateId)
	if not (binder and preview and template) then
		return nil
	end
	local clip = Templates.build(template, function(name)
		return binder.joints[name] ~= nil
	end, function(name)
		return preview:restC0(binder.joints[name])
	end, DEFAULT_FPS)
	if next(clip.tracks) == nil then
		return nil
	end
	clip.id = newId()
	clip.name = self:uniqueName(template.name)
	self:_insertAnimation("New animation from template", clip, #self.clips + 1)
	self:setTime(0)
	return clip
end

function Session.destroy(self: Session)
	self:setRig(nil)
	self.changed:DisconnectAll()
end

return Session
