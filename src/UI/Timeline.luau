--!strict
-- The editor timeline: one row per rig joint (tree order), keyframe markers, a ruler
-- to scrub, and the playhead. Keyframes can be clicked (Shift/Ctrl adds), box-selected
-- by dragging empty space, and dragged sideways to move them. Uses the Spike B design: plain Instances, pooled
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
local HIT_RADIUS = 7 -- px around a marker that counts as clicking it
local DRAG_THRESHOLD = 4 -- px of movement before a click becomes a drag
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
	-- Dragging selected keyframes sideways: `delta` is the preview offset in seconds.
	local keyDrag: { startX: number, delta: number, moved: boolean, clickedTime: number }? = nil
	-- Rubber-band selection in lane coordinates.
	local boxSelect: { x0: number, y0: number, x1: number, y1: number, additive: boolean, moved: boolean }? = nil

	local colors = {
		background = Theme.color(Enum.StudioStyleGuideColor.MainBackground),
		ruler = Theme.color(Enum.StudioStyleGuideColor.Titlebar),
		stripe = Theme.color(Enum.StudioStyleGuideColor.TableItem),
		selectedRow = Theme.color(Enum.StudioStyleGuideColor.Item, Enum.StudioStyleGuideModifier.Selected),
		marker = Theme.color(Enum.StudioStyleGuideColor.LinkText),
		selectedMarker = Color3.fromRGB(255, 170, 40),
		selectedKey = Color3.fromRGB(255, 255, 255),
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

	local selectionBox = Instance.new("Frame")
	selectionBox.Name = "SelectionBox"
	selectionBox.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
	selectionBox.BackgroundTransparency = 0.75
	selectionBox.BorderSizePixel = 0
	selectionBox.ZIndex = 6
	selectionBox.Visible = false
	selectionBox.Parent = lanes

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
				local rowColor = if name == session.selectedJoint then colors.selectedMarker else colors.marker
				local keyframes = track.keyframes
				local dragDelta = if keyDrag then keyDrag.delta else 0
				-- Widen the window by the drag offset so dragged keys stay visible.
				local index = lowerBound(keyframes, viewStart - 1 / clip.fps - math.abs(dragDelta))
				local y = (row - 1) * ROW_HEIGHT + ROW_HEIGHT / 2
				while index <= #keyframes and keyframes[index].time <= viewEnd + math.abs(dragDelta) do
					local time = keyframes[index].time
					local selected = session:isKeySelected(name, time)
					if selected then
						time += dragDelta
					end
					used += 1
					local marker = getMarker(used)
					marker.Position = UDim2.fromOffset((time - viewStart) * pps, y)
					marker.BackgroundColor3 = if selected then colors.selectedKey else rowColor
					marker.Size = if selected
						then UDim2.fromOffset(MARKER_SIZE + 3, MARKER_SIZE + 3)
						else UDim2.fromOffset(MARKER_SIZE, MARKER_SIZE)
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

		-- Rubber band
		local box = boxSelect
		selectionBox.Visible = box ~= nil and box.moved
		if box then
			selectionBox.Position = UDim2.fromOffset(math.min(box.x0, box.x1), math.min(box.y0, box.y1))
			selectionBox.Size = UDim2.fromOffset(math.abs(box.x1 - box.x0), math.abs(box.y1 - box.y0))
		end

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
	local function lanePoint(input: InputObject): (number, number)
		return input.Position.X - lanes.AbsolutePosition.X, input.Position.Y - lanes.AbsolutePosition.Y
	end

	-- The keyframe under a lane point, if any (within HIT_RADIUS pixels).
	local function hitKey(x: number, y: number): Session.KeyRef?
		local clip = session.clip
		local entry = session.jointOrder[math.floor(y / ROW_HEIGHT) + 1]
		local track = clip and entry and clip.tracks[entry.name]
		if not (entry and track) then
			return nil
		end
		local time = timeAtX(x)
		local keyframes = track.keyframes
		local index = lowerBound(keyframes, time)
		local best: number? = nil
		for _, candidate in { index - 1, index } do
			local keyframe = keyframes[candidate]
			if keyframe and math.abs(keyframe.time - time) * pps <= HIT_RADIUS then
				if best == nil or math.abs(keyframe.time - time) < math.abs(best - time) then
					best = keyframe.time
				end
			end
		end
		return if best then { joint = entry.name, time = best } else nil
	end

	local function isAdditive(input: InputObject): boolean
		return input:IsModifierKeyDown(Enum.ModifierKey.Shift) or input:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
	end

	table.insert(
		connections,
		lanes.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not session.clip then
				return
			end
			session:pause()
			local x, y = lanePoint(input)
			local entry = session.jointOrder[math.floor(y / ROW_HEIGHT) + 1]
			if entry then
				session:selectJoint(entry.name)
			end

			local key = hitKey(x, y)
			if key then
				if isAdditive(input) then
					session:addKeySelection({ key }, true)
				elseif not session:isKeySelected(key.joint, key.time) then
					session:setKeySelection({ key })
				end
				if session:isKeySelected(key.joint, key.time) then
					keyDrag = { startX = x, delta = 0, moved = false, clickedTime = key.time }
				end
			else
				boxSelect = { x0 = x, y0 = y, x1 = x, y1 = y, additive = isAdditive(input), moved = false }
			end
			dirty = true
		end)
	)

	table.insert(
		connections,
		root.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local x, y = lanePoint(input)
			local clip = session.clip
			if keyDrag and clip then
				if math.abs(x - keyDrag.startX) >= DRAG_THRESHOLD then
					keyDrag.moved = true
				end
				if keyDrag.moved then
					keyDrag.delta = math.round((x - keyDrag.startX) / pps * clip.fps) / clip.fps
					dirty = true
				end
			elseif boxSelect then
				boxSelect.x1, boxSelect.y1 = x, y
				if math.abs(x - boxSelect.x0) + math.abs(y - boxSelect.y0) >= DRAG_THRESHOLD then
					boxSelect.moved = true
				end
				dirty = true
			end
		end)
	)

	local function finishPointer(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		scrubbing = false

		local drag = keyDrag
		keyDrag = nil
		if drag then
			if drag.moved and drag.delta ~= 0 then
				session:moveSelectedKeys(drag.delta)
			elseif not drag.moved then
				session:setTime(drag.clickedTime)
			end
			dirty = true
		end

		local box = boxSelect
		boxSelect = nil
		if box then
			if box.moved then
				-- Select every keyframe inside the rectangle.
				local clip = session.clip
				local refs: { Session.KeyRef } = {}
				local t0, t1 = timeAtX(math.min(box.x0, box.x1)), timeAtX(math.max(box.x0, box.x1))
				local firstRow = math.max(1, math.floor(math.min(box.y0, box.y1) / ROW_HEIGHT) + 1)
				local lastRow = math.min(#session.jointOrder, math.floor(math.max(box.y0, box.y1) / ROW_HEIGHT) + 1)
				for row = firstRow, lastRow do
					local name = session.jointOrder[row].name
					local track = clip and clip.tracks[name]
					if track then
						for _, keyframe in track.keyframes do
							if keyframe.time >= t0 and keyframe.time <= t1 then
								table.insert(refs, { joint = name, time = keyframe.time })
							end
						end
					end
				end
				if box.additive then
					session:addKeySelection(refs)
				else
					session:setKeySelection(refs)
				end
			else
				-- Plain click on empty space: clear the key selection and move the playhead.
				if not box.additive then
					session:setKeySelection({})
				end
				session:setTime(timeAtX(box.x0))
			end
			dirty = true
		end
	end

	for _, frame in { root, ruler, lanes } do
		table.insert(connections, frame.InputEnded:Connect(finishPointer))
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
