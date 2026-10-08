--!strict
-- Picks rigs and joints by clicking in the 3D viewport. While the Animora panel is open
-- the plugin is activated (plugin:Activate), which switches off Studio's Select / Move /
-- Rotate tools: a click then picks one body part instead of selecting the whole model,
-- and Studio's own handles cannot rotate the whole rig by accident.
--
-- Clicks look through clothing, hair and other accessories: once the rig under the mouse
-- is known, a second cast only hits its body parts, and a thin sphere cast forgives clicks
-- that land just beside a limb (useful when the camera is far away).

local RigBinder = require(script.Parent.RigBinder)
local Session = require(script.Parent.Session)

local CAST_DISTANCE = 2000
local FORGIVING_RADIUS = 0.35 -- studs; a click this close to a limb still picks it

local ViewportPicker = {}
ViewportPicker.__index = ViewportPicker

export type ViewportPicker = typeof(setmetatable(
	{} :: {
		_plugin: Plugin,
		_mouse: PluginMouse,
		_session: Session.Session,
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

-- The rig's animatable body parts (each joint's Part1).
local function bodyParts(binder: RigBinder.RigBinder): { Instance }
	local parts = {}
	for _, joint in binder.joints do
		table.insert(parts, joint.Part1)
	end
	return parts
end

-- Casts the mouse ray against the rig's body parts only: first exactly, then with a
-- small sphere so near misses still count.
local function castBody(ray: Ray, binder: RigBinder.RigBinder): BasePart?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = bodyParts(binder)
	local direction = ray.Direction.Unit * CAST_DISTANCE
	local hit = workspace:Raycast(ray.Origin, direction, params)
		or workspace:Spherecast(ray.Origin, FORGIVING_RADIUS, direction, params)
	return if hit then hit.Instance :: BasePart else nil
end

function ViewportPicker.new(
	pluginRef: Plugin,
	session: Session.Session,
	canPick: () -> boolean,
	isDraggingGizmo: () -> boolean
): ViewportPicker
	local self = setmetatable({
		_plugin = pluginRef,
		_mouse = pluginRef:GetMouse(),
		_session = session,
		_active = false,
		_connections = {},
	}, ViewportPicker)
	local mouse = self._mouse

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
			local ray = mouse.UnitRay
			-- Let a gizmo handle click register first; ignore clicks that started a drag.
			task.defer(function()
				if not isDraggingGizmo() then
					self:pick(target, ray)
				end
			end)
		end)
	)
	return self
end

-- Picks the rig and body part for a click. `target` is what the mouse hit (it may be an
-- accessory); `ray` is the mouse ray. Returns true when a joint was selected.
function ViewportPicker.pick(self: ViewportPicker, target: BasePart?, ray: Ray): boolean
	local session = self._session
	local rig = if target then RigBinder.findRig(target) else nil
	-- A click just beside the current rig's thin limbs hits the world behind it; still
	-- try the current rig.
	rig = rig or session.rig
	if not rig then
		return false
	end

	local binder = if session.binder and session.rig == rig then session.binder else RigBinder.new(rig)
	local part = castBody(ray, binder)
	if not part and target and target:IsDescendantOf(rig) then
		part = bodyPartFor(target, binder)
	end
	if not part then
		return false
	end
	session:setRig(rig)
	session:selectJoint(part.Name)
	return true
end

-- Picks whatever is under the mouse right now (used when Studio selected the whole rig
-- before Animora's picking was active).
function ViewportPicker.pickUnderMouse(self: ViewportPicker): boolean
	local mouse = self._mouse
	return self:pick(mouse.Target, mouse.UnitRay)
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
