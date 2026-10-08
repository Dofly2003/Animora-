--!strict
-- Rotate handles (ArcHandles in CoreGui) on the selected joint's part, or, in move mode,
-- move arrows (Handles) on the root joint so the whole body can be raised, lowered or
-- shifted. Joints other than the root always show the rotate rings.
-- Dragging previews the change live; releasing stores a keyframe at the current time.
--
-- Rotate math: Part1 = Part0 * C0 * T * C1:Inverse() (C0/C1 are the attachment frames for
-- AnimationConstraints). Rotating Part1 about one of its own axes `a` around the joint
-- pivot means T' = T * R, where R rotates about C1.Rotation:Inverse() * a (the same
-- axis expressed in the joint frame). Move math: see Core/Translate.

local CoreGui = game:GetService("CoreGui")

local Session = require(script.Parent.Session)
local RigBinder = require(script.Parent.RigBinder)
local Translate = require(script.Parent.Parent.Core.Translate)

local MOVE_STEP = 0.05 -- studs; drags snap to this so values stay tidy

local Gizmo = {}
Gizmo.__index = Gizmo

type Drag = {
	jointName: string,
	start: CFrame,
	last: CFrame?,
	-- Move drags only: the frames at the moment the drag started.
	part0: CFrame?,
	part1: CFrame?,
	rest0: CFrame?,
}

export type Gizmo = typeof(setmetatable(
	{} :: {
		session: Session.Session,
		handles: ArcHandles,
		moveHandles: Handles,
		highlight: SelectionBox,
		_connections: { any },
		_drag: Drag?,
	},
	Gizmo
))

function Gizmo.new(session: Session.Session): Gizmo
	local handles = Instance.new("ArcHandles")
	handles.Name = "AnimoraRotateHandles"
	handles.Visible = false
	handles.Archivable = false
	handles.Parent = CoreGui

	local moveHandles = Instance.new("Handles")
	moveHandles.Name = "AnimoraMoveHandles"
	moveHandles.Style = Enum.HandlesStyle.Movement
	moveHandles.Visible = false
	moveHandles.Archivable = false
	moveHandles.Parent = CoreGui

	-- Outline of the selected body part, so it is clear which joint the rings rotate.
	local highlight = Instance.new("SelectionBox")
	highlight.Name = "AnimoraSelectedPart"
	highlight.Color3 = Color3.fromRGB(255, 170, 40)
	highlight.LineThickness = 0.03
	highlight.Visible = false
	highlight.Archivable = false
	highlight.Parent = CoreGui

	local self = setmetatable({
		session = session,
		handles = handles,
		moveHandles = moveHandles,
		highlight = highlight,
		_connections = {},
		_drag = nil,
	}, Gizmo)

	local function finishDrag()
		local drag = self._drag
		self._drag = nil
		if drag and drag.last then
			session:commitJoint(drag.jointName, drag.last)
		elseif drag then
			session:cancelPreview()
		end
	end

	table.insert(
		self._connections,
		session.changed:Connect(function()
			self:refresh()
		end)
	)

	-- Rotate rings.
	table.insert(
		self._connections,
		handles.MouseButton1Down:Connect(function()
			local jointName = session.selectedJoint
			if jointName and not session.playing then
				self._drag = { jointName = jointName, start = session:getJointTransform(jointName), last = nil }
			end
		end)
	)

	table.insert(
		self._connections,
		handles.MouseDrag:Connect(function(axis: Enum.Axis, relativeAngle: number)
			local drag = self._drag
			local joint = drag and session.binder and session.binder.joints[drag.jointName]
			if not (drag and joint) or drag.part1 then
				return
			end
			local jointAxis = RigBinder.frame1(joint).Rotation:Inverse() * Vector3.FromAxis(axis)
			local value = drag.start * CFrame.fromAxisAngle(jointAxis, relativeAngle)
			drag.last = value
			session:previewJoint(drag.jointName, value)
		end)
	)

	table.insert(self._connections, handles.MouseButton1Up:Connect(finishDrag))

	-- Move arrows (root joint only).
	table.insert(
		self._connections,
		moveHandles.MouseButton1Down:Connect(function()
			local jointName = session.selectedJoint
			local joint = jointName and session.binder and session.binder.joints[jointName]
			local rest0 = jointName and session:restFrame0(jointName)
			if jointName and joint and rest0 and not session.playing then
				self._drag = {
					jointName = jointName,
					start = session:getJointTransform(jointName),
					last = nil,
					part0 = joint.Part0.CFrame,
					part1 = joint.Part1.CFrame,
					rest0 = rest0,
				}
			end
		end)
	)

	table.insert(
		self._connections,
		moveHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
			local drag = self._drag
			if not (drag and drag.part0 and drag.part1 and drag.rest0) then
				return
			end
			-- The arrows follow the part's own axes as they were when the drag began.
			local direction = drag.part1:VectorToWorldSpace(Vector3.FromNormalId(face))
			local worldDelta = direction * Translate.snap(distance, MOVE_STEP)
			local value = Translate.apply(drag.start, worldDelta, drag.part0, drag.rest0)
			drag.last = value
			session:previewJoint(drag.jointName, value)
		end)
	)

	table.insert(self._connections, moveHandles.MouseButton1Up:Connect(finishDrag))

	self:refresh()
	return self
end

function Gizmo.refresh(self: Gizmo)
	local session = self.session
	local jointName = session.selectedJoint
	local joint = jointName and session.binder and session.binder.joints[jointName]
	local editable = joint ~= nil and not session.playing
	local movable = editable and session.gizmoMode == "move" and jointName ~= nil and session:isRootJoint(jointName)
	self.handles.Adornee = if joint then joint.Part1 else nil
	self.handles.Visible = editable and not movable
	self.moveHandles.Adornee = if movable and joint then joint.Part1 else nil
	self.moveHandles.Visible = movable
	self.highlight.Adornee = if joint then joint.Part1 else nil
	self.highlight.Visible = joint ~= nil
end

function Gizmo.isDragging(self: Gizmo): boolean
	return self._drag ~= nil
end

function Gizmo.destroy(self: Gizmo)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.handles:Destroy()
	self.moveHandles:Destroy()
	self.highlight:Destroy()
end

return Gizmo
