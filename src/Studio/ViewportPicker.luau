--!strict
-- Picks rigs and joints by clicking in the 3D viewport. While the Animora panel is open
-- the plugin is activated (plugin:Activate), which switches off Studio's Select / Move /
-- Rotate tools: a click then picks one body part instead of selecting the whole model,
-- and Studio's own handles cannot rotate the whole rig by accident.

local RigBinder = require(script.Parent.RigBinder)
local Session = require(script.Parent.Session)

local ViewportPicker = {}
ViewportPicker.__index = ViewportPicker

export type ViewportPicker = typeof(setmetatable(
	{} :: {
		_plugin: Plugin,
		_active: boolean,
		_connections: { RBXScriptConnection },
	},
	ViewportPicker
))

-- Accessories and tools are welded to a body part; clicking them picks that part.
local function bodyPartFor(target: BasePart, binder: RigBinder.RigBinder): BasePart?
	if binder.joints[target.Name] and binder.joints[target.Name].Part1 == target then
		return target
	end
	for _, child in target:GetChildren() do
		if child:IsA("Weld") or child:IsA("WeldConstraint") then
			local weld = child :: any
			for _, other in { weld.Part0, weld.Part1 } do
				if
					other
					and other ~= target
					and binder.joints[other.Name]
					and binder.joints[other.Name].Part1 == other
				then
					return other
				end
			end
		end
	end
	return nil
end

function ViewportPicker.new(
	pluginRef: Plugin,
	session: Session.Session,
	canPick: () -> boolean,
	isDraggingGizmo: () -> boolean
): ViewportPicker
	local self = setmetatable({ _plugin = pluginRef, _active = false, _connections = {} }, ViewportPicker)
	local mouse = pluginRef:GetMouse()

	-- The user chose another Studio tool (e.g. Move); stop picking until re-activated.
	table.insert(
		self._connections,
		pluginRef.Deactivation:Connect(function()
			self._active = false
		end)
	)

	table.insert(
		self._connections,
		mouse.Button1Down:Connect(function()
			if not (self._active and canPick()) then
				return
			end
			local target = mouse.Target
			-- Let a gizmo handle click register first; ignore clicks that started a drag.
			task.defer(function()
				if isDraggingGizmo() or not target then
					return
				end
				local rig = RigBinder.findRig(target)
				if not rig then
					return
				end
				session:setRig(rig)
				local binder = session.binder
				local part = binder and bodyPartFor(target, binder)
				session:selectJoint(if part then part.Name else nil)
			end)
		end)
	)
	return self
end

-- Turns picking on (activating the plugin) or off (giving the mouse back to Studio).
function ViewportPicker.setActive(self: ViewportPicker, active: boolean)
	if active and not self._active then
		self._plugin:Activate(true)
		self._active = true
	elseif not active and self._active then
		self._active = false
		self._plugin:Deactivate()
	end
end

function ViewportPicker.isActive(self: ViewportPicker): boolean
	return self._active
end

function ViewportPicker.destroy(self: ViewportPicker)
	self:setActive(false)
	for _, connection in self._connections do
		connection:Disconnect()
	end
end

return ViewportPicker
