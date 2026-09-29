--!strict
-- Rotate handles (ArcHandles in CoreGui) on the selected joint's part. Dragging
-- previews the rotation live; releasing stores a keyframe at the current time.
--
-- Math: Part1 = Part0 * C0 * T * C1:Inverse(). Rotating Part1 about one of its own
-- axes `a` around the joint pivot means T' = T * R, where R rotates about
-- C1.Rotation:Inverse() * a (the same axis expressed in the joint frame).

local CoreGui = game:GetService("CoreGui")

local Session = require(script.Parent.Session)

local Gizmo = {}
Gizmo.__index = Gizmo

export type Gizmo = typeof(setmetatable(
	{} :: {
		session: Session.Session,
		handles: ArcHandles,
		_connections: { any },
		_drag: { jointName: string, start: CFrame, last: CFrame? }?,
	},
	Gizmo
))

function Gizmo.new(session: Session.Session): Gizmo
	local handles = Instance.new("ArcHandles")
	handles.Name = "AnimoraRotateHandles"
	handles.Visible = false
	handles.Archivable = false
	handles.Parent = CoreGui

	local self = setmetatable({
		session = session,
		handles = handles,
		_connections = {},
		_drag = nil,
	}, Gizmo)

	table.insert(
		self._connections,
		session.changed:Connect(function()
			self:refresh()
		end)
	)

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
			if not (drag and joint) then
				return
			end
			local jointAxis = joint.C1.Rotation:Inverse() * Vector3.FromAxis(axis)
			local value = drag.start * CFrame.fromAxisAngle(jointAxis, relativeAngle)
			drag.last = value
			session:previewJoint(drag.jointName, value)
		end)
	)

	table.insert(
		self._connections,
		handles.MouseButton1Up:Connect(function()
			local drag = self._drag
			self._drag = nil
			if drag and drag.last then
				session:commitJoint(drag.jointName, drag.last)
			elseif drag then
				session:cancelPreview()
			end
		end)
	)

	self:refresh()
	return self
end

function Gizmo.refresh(self: Gizmo)
	local session = self.session
	local jointName = session.selectedJoint
	local joint = jointName and session.binder and session.binder.joints[jointName]
	self.handles.Adornee = if joint then joint.Part1 else nil
	self.handles.Visible = joint ~= nil and not session.playing
end

function Gizmo.destroy(self: Gizmo)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.handles:Destroy()
end

return Gizmo
