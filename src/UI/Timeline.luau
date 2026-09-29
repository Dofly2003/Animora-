--!strict
-- The editor timeline: one row per rig joint (tree order), keyframe markers, a ruler
-- to scrub, and the playhead. Uses the Spike B design: plain Instances, pooled
-- markers, only visible rows and time range drawn, render at most once per frame.

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Localization = require(script.Parent.Parent.Localization)
local Session = require(script.Parent.Parent.Studio.Session)
local Theme = require(script.Parent.Theme)

local RULER_HEIGHT = 24
local ROW_HEIGHT = 22
local NAME_WIDTH = 170
local MARKER_SIZE = 9
local SCROLLBAR = 8
local MIN_PPS, MAX_PPS = 20, 3000
local TICK_STEPS = { 1 / 30, 0.1, 0.25, 0.5, 1, 2, 5, 10 }

local Timeline = {}

export type Handle = { destroy: (self: Handle) -> () }

-- Index of the first keyframe with time >= t (binary search).
local function lowerBound(keyframes: { Model.Keyframe }, t: number): number
	local low, high = 1, #keyframes + 1
	while low < high do
		local mid = (low + high) // 2
		if keyframes[mid].time < t then
			low = mid + 1
		else
			high = mid
		end
	end
	return low
end

local function newLabel(parent: Instance, props: { [string]: any }): TextLabel
	local instance = Instance.new("TextLabel")
	instance.BackgroundTransparency = 1
	instance.FontFace = Theme.FONT
	instance.TextSize = Theme.TEXT_SIZE
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

function Timeline.mount(parent: GuiObject, session: Session.Session): Handle
	local connections: { any } = {}
	local viewStart = 0
	local pps = 200 -- pixels per second
	local dirty = true
	local rowsDirty = true
	local scrubbing = false

	local colors = {
		background = Theme.color(Enum.StudioStyleGuideColor.MainBackground),
		ruler = Theme.color(Enum.StudioStyleGuideColor.Titlebar),
		stripe = Theme.color(Enum.StudioStyleGuideColor.TableItem),
		selectedRow = Theme.color(Enum.StudioStyleGuideColor.Item, Enum.StudioStyleGuideModifier.Selected),
		marker = Theme.color(Enum.StudioStyleGuideColor.LinkText),
		selectedMarker = Color3.fromRGB(255, 170, 40),
		outOfRange = Color3.new(0, 0, 0),
		dim = Theme.color(Enum.StudioStyleGuideColor.DimmedText),
	}

	-- Layout ------------------------------------------------------------------
	local root = Instance.new("Frame")
	root.Name = "Timeline"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = colors.background
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = parent

	local emptyLabel = newLabel(root, {
		Name = "Empty",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = colors.dim,
		Text = Localization.t("editor.noRig"),
	})

	local hint = newLabel(root, {
		Name = "Hint",
		Position = UDim2.fromOffset(Theme.PADDING, 0),
		Size = UDim2.fromOffset(NAME_WIDTH - Theme.PADDING, RULER_HEIGHT),
		TextColor3 = colors.dim,
		TextScaled = true,
		Text = Localization.t("editor.rulerHint"),
	})

	local ruler = Instance.new("Frame")
	ruler.Name = "Ruler"
	ruler.Position = UDim2.fromOffset(NAME_WIDTH, 0)
	ruler.Size = UDim2.new(1, -NAME_WIDTH - SCROLLBAR, 0, RULER_HEIGHT)
	ruler.BackgroundColor3 = colors.ruler
	ruler.BorderSizePixel = 0
	ruler.ClipsDescendants = true
	ruler.Active = true
	ruler.Parent = root

	local rulerEnd = Instance.new("Frame")
	rulerEnd.Name = "OutOfRange"
	rulerEnd.BackgroundColor3 = colors.outOfRange
	rulerEnd.BackgroundTransparency = 0.6
	rulerEnd.BorderSizePixel = 0
	rulerEnd.Size = UDim2.fromScale(1, 1)
	rulerEnd.Parent = ruler

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, RULER_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -RULER_HEIGHT)
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ScrollBarThickness = SCROLLBAR
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = root

	local names = Instance.new("Frame")
	names.Name = "Names"
	names.Size = UDim2.new(0, NAME_WIDTH, 1, 0)
	names.BackgroundTransparency = 1
	names.Parent = body

	local lanes = Instance.new("Frame")
	lanes.Name = "Lanes"
	lanes.Position = UDim2.fromOffset(NAME_WIDTH, 0)
	lanes.Size = UDim2.new(1, -NAME_WIDTH - SCROLLBAR, 1, 0)
	lanes.BackgroundTransparency = 1
	lanes.ClipsDescendants = true
	lanes.Active = true
	lanes.Parent = body

	local lanesEnd = rulerEnd:Clone()
	lanesEnd.ZIndex = 3
	lanesEnd.Parent = lanes

	local playhead = Instance.new("Frame")
	playhead.Name = "Playhead"
	playhead.Size = UDim2.new(0, 2, 1, 0)
	playhead.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
	playhead.BorderSizePixel = 0
	playhead.ZIndex = 10
	playhead.Parent = root

	-- Rows (rebuilt when the rig changes) ---------------------------------------
	local rowItems: { Instance } = {}
	local rowIndexByName: { [string]: number } = {}
	local rowButtons: { [string]: TextButton } = {}

	local function rebuildRows()
		for _, item in rowItems do
			item:Destroy()
		end
		table.clear(rowItems)
		table.clear(rowIndexByName)
		table.clear(rowButtons)

		for index, entry in session.jointOrder do
			rowIndexByName[entry.name] = index
			local y = (index - 1) * ROW_HEIGHT

			local button = Instance.new("TextButton")
			button.Name = entry.name
			button.Position = UDim2.fromOffset(0, y)
			button.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			button.AutoButtonColor = false
			button.BorderSizePixel = 0
			button.BackgroundColor3 = colors.stripe
			button.BackgroundTransparency = if index % 2 == 0 then 0 else 1
			button.FontFace = Theme.FONT
			button.TextSize = Theme.TEXT_SIZE
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
			button.Text = string.rep(" ", 2) .. string.rep("  ", entry.depth) .. entry.name
			button.Parent = names
			table.insert(
				connections,
				button.Activated:Connect(function()
					session:selectJoint(entry.name)
				end)
			)
			rowButtons[entry.name] = button
			table.insert(rowItems, button)

			local stripe = Instance.new("Frame")
			stripe.Position = UDim2.fromOffset(0, y)
			stripe.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			stripe.BorderSizePixel = 0
			stripe.BackgroundColor3 = colors.stripe
			stripe.BackgroundTransparency = if index % 2 == 0 then 0 else 1
			stripe.Parent = lanes
			table.insert(rowItems, stripe)
		end

		local height = #session.jointOrder * ROW_HEIGHT
		body.CanvasSize = UDim2.fromOffset(0, height)
		names.Size = UDim2.new(0, NAME_WIDTH, 0, height)
		lanes.Size = UDim2.new(1, -NAME_WIDTH - SCROLLBAR, 0, height)
	end

	-- Pools -------------------------------------------------------------------
	local markerPool: { Frame } = {}
	local markersInUse = 0
	local function getMarker(index: number): Frame
		local marker = markerPool[index]
		if not marker then
			marker = Instance.new("Frame")
			marker.AnchorPoint = Vector2.new(0.5, 0.5)
			marker.Size = UDim2.fromOffset(MARKER_SIZE, MARKER_SIZE)
			marker.Rotation = 45
			marker.BorderSizePixel = 0
			marker.ZIndex = 2
			marker.Parent = lanes
			markerPool[index] = marker
		end
		return marker
	end

	local tickPool: { TextLabel } = {}
	local ticksInUse = 0
	local function getTick(index: number): TextLabel
		local tickLabel = tickPool[index]
		if not tickLabel then
			tickLabel = newLabel(ruler, { Size = UDim2.fromOffset(70, RULER_HEIGHT), TextColor3 = colors.dim })
			tickPool[index] = tickLabel
		end
		return tickLabel
	end

	-- Rendering ---------------------------------------------------------------
	local function fitView()
		local clip = session.clip
		local laneWidth = lanes.AbsoluteSize.X
		if clip and laneWidth > 0 then
			pps = math.clamp(laneWidth / (clip.length * 1.1), MIN_PPS, MAX_PPS)
			viewStart = 0
		end
	end

	local function render()
		local clip = session.clip
		local hasRig = clip ~= nil and #session.jointOrder > 0
		emptyLabel.Visible = not hasRig
		ruler.Visible = hasRig
		body.Visible = hasRig
		hint.Visible = hasRig
		if not (hasRig and clip) then
			playhead.Visible = false
			return
		end

		local laneWidth = lanes.AbsoluteSize.X
		viewStart = math.clamp(viewStart, 0, math.max(0, clip.length + 1 - laneWidth / pps))
		local viewEnd = viewStart + laneWidth / pps

		-- Shade the area after the end of the clip.
		local endX = (clip.length - viewStart) * pps
		for _, shade in { rulerEnd, lanesEnd } do
			shade.Position = UDim2.fromOffset(math.max(endX, 0), 0)
			shade.Visible = endX < laneWidth
		end

		-- Row highlight
		for name, button in rowButtons do
			local selected = name == session.selectedJoint
			local index = rowIndexByName[name]
			button.BackgroundColor3 = if selected then colors.selectedRow else colors.stripe
			button.BackgroundTransparency = if selected then 0 elseif index % 2 == 0 then 0 else 1
		end

		-- Keyframe markers for visible rows and time range only.
		local scrollY = body.CanvasPosition.Y
		local firstRow = math.max(1, math.floor(scrollY / ROW_HEIGHT) + 1)
		local lastRow = math.min(#session.jointOrder, math.ceil((scrollY + body.AbsoluteSize.Y) / ROW_HEIGHT))
		local used = 0
		for row = firstRow, lastRow do
			local name = session.jointOrder[row].name
			local track = clip.tracks[name]
			if track then
				local color = if name == session.selectedJoint then colors.selectedMarker else colors.marker
				local keyframes = track.keyframes
				local index = lowerBound(keyframes, viewStart - 1 / clip.fps)
				local y = (row - 1) * ROW_HEIGHT + ROW_HEIGHT / 2
				while index <= #keyframes and keyframes[index].time <= viewEnd do
					used += 1
					local marker = getMarker(used)
					marker.Position = UDim2.fromOffset((keyframes[index].time - viewStart) * pps, y)
					marker.BackgroundColor3 = color
					marker.Visible = true
					index += 1
				end
			end
		end
		for index = used + 1, markersInUse do
			markerPool[index].Visible = false
		end
		markersInUse = used

		-- Ruler ticks: smallest step leaving at least 50 px between labels.
		local step = TICK_STEPS[#TICK_STEPS]
		for _, candidate in TICK_STEPS do
			if candidate * pps >= 50 then
				step = candidate
				break
			end
		end
		local tickCount = 0
		local tickIndex = math.ceil(viewStart / step - 1e-6)
		while tickIndex * step <= viewEnd do
			local tickTime = tickIndex * step
			tickCount += 1
			local tickLabel = getTick(tickCount)
			tickLabel.Position = UDim2.fromOffset((tickTime - viewStart) * pps + 3, 0)
			tickLabel.Text = if step < 1 then string.format("%.2f", tickTime) else string.format("%ds", tickTime)
			tickLabel.Visible = true
			tickIndex += 1
		end
		for index = tickCount + 1, ticksInUse do
			tickPool[index].Visible = false
		end
		ticksInUse = tickCount

		-- Playhead
		local x = (session.time - viewStart) * pps
		playhead.Visible = x >= 0 and x <= laneWidth
		playhead.Position = UDim2.fromOffset(NAME_WIDTH + x - 1, 0)
	end

	-- Input -------------------------------------------------------------------
	local function timeAtX(x: number): number
		return viewStart + x / pps
	end

	local function onWheel(input: InputObject, x: number)
		local direction = input.Position.Z
		if input:IsModifierKeyDown(Enum.ModifierKey.Shift) then
			viewStart -= direction * 80 / pps
		else
			local anchorTime = timeAtX(x)
			pps = math.clamp(pps * 1.2 ^ direction, MIN_PPS, MAX_PPS)
			viewStart = anchorTime - x / pps
		end
		dirty = true
	end

	table.insert(
		connections,
		ruler.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				scrubbing = true
				session:pause()
				session:setTime(timeAtX(input.Position.X - ruler.AbsolutePosition.X))
			end
		end)
	)
	table.insert(
		connections,
		ruler.InputChanged:Connect(function(input)
			local x = input.Position.X - ruler.AbsolutePosition.X
			if input.UserInputType == Enum.UserInputType.MouseMovement and scrubbing then
				session:setTime(timeAtX(x))
			elseif input.UserInputType == Enum.UserInputType.MouseWheel then
				onWheel(input, x)
			end
		end)
	)
	-- Clicking in a lane selects that joint and moves the playhead there.
	table.insert(
		connections,
		lanes.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local row = math.floor((input.Position.Y - lanes.AbsolutePosition.Y) / ROW_HEIGHT) + 1
			local entry = session.jointOrder[row]
			if entry then
				session:selectJoint(entry.name)
			end
			session:pause()
			session:setTime(timeAtX(input.Position.X - lanes.AbsolutePosition.X))
		end)
	)
	for _, frame in { root, ruler } do
		table.insert(
			connections,
			frame.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					scrubbing = false
				end
			end)
		)
	end
	table.insert(
		connections,
		body:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			dirty = true
		end)
	)
	table.insert(
		connections,
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			dirty = true
		end)
	)
	table.insert(
		connections,
		Localization.onChanged(function()
			emptyLabel.Text = Localization.t("editor.noRig")
			hint.Text = Localization.t("editor.rulerHint")
		end)
	)

	table.insert(
		connections,
		session.changed:Connect(function(change: Session.Change)
			if change == "rig" then
				rowsDirty = true
			end
			dirty = true
		end)
	)

	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			if rowsDirty then
				rowsDirty = false
				rebuildRows()
				body.CanvasPosition = Vector2.zero
				fitView()
			end
			if dirty then
				dirty = false
				render()
			end
		end)
	)

	local handle = {}
	function handle.destroy(_self: Handle)
		for _, connection in connections do
			if typeof(connection) == "function" then
				connection()
			else
				connection:Disconnect()
			end
		end
		root:Destroy()
	end
	return handle :: Handle
end

return Timeline
