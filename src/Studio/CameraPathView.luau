--!strict
-- Draws the camera track in the viewport: the path the camera travels (sampled the same
-- way it plays back), a small camera at every keyframe pointing where it looks, and a
-- dot where the camera is at the playhead. Hidden while looking through the camera.
-- Uses handle adornments in CoreGui, so nothing is added to the place.

local CoreGui = game:GetService("CoreGui")

local Model = require(script.Parent.Parent.Core.Model)
local Session = require(script.Parent.Session)

local MAX_SAMPLES = 240 -- path segments drawn at most
local PATH_COLOR = Color3.fromRGB(155, 123, 255)
local KEY_COLOR = Color3.fromRGB(255, 170, 40)
local SELECTED_COLOR = Color3.fromRGB(255, 255, 255)
local HEAD_COLOR = Color3.fromRGB(255, 69, 58)

local CameraPathView = {}
CameraPathView.__index = CameraPathView

export type CameraPathView = typeof(setmetatable(
	{} :: {
		session: Session.Session,
		folder: Folder,
		_segments: { CylinderHandleAdornment },
		_keys: { { body: BoxHandleAdornment, lens: CylinderHandleAdornment } },
		_head: SphereHandleAdornment,
		_connection: any,
	},
	CameraPathView
))

local function adornee(): BasePart?
	-- Adornments need a part; the Terrain sits at the origin, so CFrames stay in world space.
	return workspace.Terrain :: any
end

local function place(item: HandleAdornment, cframe: CFrame)
	item.Adornee = adornee()
	item.CFrame = cframe
	item.Visible = true
end

-- A cylinder from `a` to `b` (its axis is the CFrame's Z axis, centred on the CFrame).
local function placeSegment(item: CylinderHandleAdornment, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	if length < 1e-4 then
		item.Visible = false
		return
	end
	item.Height = length
	place(item, CFrame.lookAt((a + b) / 2, b))
end

function CameraPathView.new(session: Session.Session): CameraPathView
	local folder = Instance.new("Folder")
	folder.Name = "AnimoraCameraPath"
	folder.Archivable = false
	folder.Parent = CoreGui

	local head = Instance.new("SphereHandleAdornment")
	head.Radius = 0.35
	head.Color3 = HEAD_COLOR
	head.AlwaysOnTop = true
	head.ZIndex = 3
	head.Visible = false
	head.Parent = folder

	local self = setmetatable({
		session = session,
		folder = folder,
		_segments = {},
		_keys = {},
		_head = head,
		_connection = nil,
	}, CameraPathView)

	self._connection = session.changed:Connect(function(change)
		if change == "time" then
			self:_updateHead()
		else
			self:refresh()
		end
	end)
	self:refresh()
	return self
end

function CameraPathView._segment(self: CameraPathView, index: number): CylinderHandleAdornment
	local item = self._segments[index]
	if not item then
		item = Instance.new("CylinderHandleAdornment")
		item.Radius = 0.06
		item.Color3 = PATH_COLOR
		item.Transparency = 0.15
		item.AlwaysOnTop = true
		item.ZIndex = 1
		item.Parent = self.folder
		self._segments[index] = item
	end
	return item
end

function CameraPathView._key(self: CameraPathView, index: number)
	local item = self._keys[index]
	if not item then
		local body = Instance.new("BoxHandleAdornment")
		body.Size = Vector3.new(0.9, 0.6, 1.1)
		body.AlwaysOnTop = true
		body.ZIndex = 2
		body.Parent = self.folder
		local lens = Instance.new("CylinderHandleAdornment")
		lens.Radius = 0.22
		lens.Height = 0.5
		lens.AlwaysOnTop = true
		lens.ZIndex = 2
		lens.Parent = self.folder
		item = { body = body, lens = lens }
		self._keys[index] = item
	end
	return item
end

function CameraPathView._shown(self: CameraPathView): Model.Track?
	local session = self.session
	local clip = session.clip
	local track = clip and clip.tracks[Model.CAMERA_TRACK]
	if session.cameraPreview or not session.binder or not track or #track.keyframes == 0 then
		return nil
	end
	return track
end

function CameraPathView._updateHead(self: CameraPathView)
	local value = if self:_shown() then self.session:cameraTransform() else nil
	if value then
		place(self._head, CFrame.new(value.Position))
	else
		self._head.Visible = false
	end
end

-- Redraws the path and the keyframe cameras.
function CameraPathView.refresh(self: CameraPathView)
	local track = self:_shown()
	local usedSegments, usedKeys = 0, 0
	if track then
		local session = self.session
		local keyframes = track.keyframes
		local first, last = keyframes[1].time, keyframes[#keyframes].time
		if last > first then
			local fps = if session.clip then session.clip.fps else 30
			local steps = math.clamp(math.ceil((last - first) * fps), 1, MAX_SAMPLES)
			local previous = (session:cameraTransform(first) :: CFrame).Position
			for step = 1, steps do
				local point = (session:cameraTransform(first + (last - first) * step / steps) :: CFrame).Position
				usedSegments += 1
				placeSegment(self:_segment(usedSegments), previous, point)
				previous = point
			end
		end
		for _, keyframe in keyframes do
			usedKeys += 1
			local item = self:_key(usedKeys)
			local selected = session:isKeySelected(Model.CAMERA_TRACK, keyframe.time)
			local color = if selected then SELECTED_COLOR else KEY_COLOR
			local view = keyframe.value
			item.body.Color3 = color
			item.lens.Color3 = color
			place(item.body, view)
			place(item.lens, view * CFrame.new(0, 0, -0.75)) -- the lens points where it looks
		end
	end
	for index = usedSegments + 1, #self._segments do
		self._segments[index].Visible = false
	end
	for index = usedKeys + 1, #self._keys do
		self._keys[index].body.Visible = false
		self._keys[index].lens.Visible = false
	end
	self:_updateHead()
end

function CameraPathView.destroy(self: CameraPathView)
	if self._connection then
		self._connection:Disconnect()
	end
	self.folder:Destroy()
end

return CameraPathView
