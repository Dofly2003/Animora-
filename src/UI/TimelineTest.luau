--!strict
-- Spike B: timeline performance prototype. Draws 30 tracks x 200 keyframes with
-- virtualization (only markers inside the visible time range and rows are drawn,
-- reusing a pool of Frames) and measures frame rate and scrub-to-pose time.
-- Built with plain Instances on purpose: this is the hot path the spike measures.

local RunService = game:GetService("RunService")

local Model = require(script.Parent.Parent.Core.Model)
local Interpolate = require(script.Parent.Parent.Core.Interpolate)
local Localization = require(script.Parent.Parent.Localization)
local Theme = require(script.Parent.Theme)
local StressClip = require(script.Parent.Parent.Dev.StressClip)

local TRACK_COUNT = 30
local KEYS_PER_TRACK = 200
local CLIP_LENGTH = 20 -- seconds

local HEADER_HEIGHT = 36
local RULER_HEIGHT = 24
local ROW_HEIGHT = 20
local NAME_WIDTH = 110
local MARKER_SIZE = 8
local MIN_PPS, MAX_PPS = 10, 2000 -- pixels per second
local AUTO_TEST_SECONDS = 6
local TICK_STEPS = { 0.05, 0.1, 0.25, 0.5, 1, 2, 5 }

local TimelineTest = {}

export type Handle = { destroy: (self: Handle) -> () }

type Stats = {
	frames: number,
	worstFrameMs: number,
	scrubCount: number,
	scrubTotalMs: number,
	scrubMaxMs: number,
	maxMarkers: number,
}

local function newStats(): Stats
	return { frames = 0, worstFrameMs = 0, scrubCount = 0, scrubTotalMs = 0, scrubMaxMs = 0, maxMarkers = 0 }
end

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

local function label(props: { [string]: any }): TextLabel
	local instance = Instance.new("TextLabel")
	instance.BackgroundTransparency = 1
	instance.FontFace = Theme.FONT
	instance.TextSize = Theme.TEXT_SIZE
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
	for key, value in props do
		(instance :: any)[key] = value
	end
	return instance
end

function TimelineTest.mount(parent: Instance): Handle
	local clip, trackNames = StressClip.build(TRACK_COUNT, KEYS_PER_TRACK, CLIP_LENGTH)
	local connections: { RBXScriptConnection } = {}

	-- View state
	local viewStart = 0
	local pps = 60
	local currentTime = 0
	local dirty = true
	local scrubbing = false
	local autoTest: { startedAt: number, stats: Stats }? = nil
	local liveStats = newStats()
	local liveWindowStart = os.clock()
	local lastScrubMs = 0
	local visibleMarkers = 0

	-- Layout ------------------------------------------------------------------
	local root = Instance.new("Frame")
	root.Name = "AnimoraTimelineTest"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.MainBackground)
	root.BorderSizePixel = 0
	root.ClipsDescendants = true

	local statsLabel = label({
		Name = "Stats",
		Position = UDim2.fromOffset(Theme.PADDING, 0),
		Size = UDim2.new(1, -200, 0, HEADER_HEIGHT),
		TextWrapped = true,
		Parent = root,
	})

	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoTest"
	autoButton.AnchorPoint = Vector2.new(1, 0.5)
	autoButton.Position = UDim2.new(1, -Theme.PADDING, 0, HEADER_HEIGHT / 2)
	autoButton.Size = UDim2.fromOffset(180, 26)
	autoButton.FontFace = Theme.FONT
	autoButton.TextSize = Theme.TEXT_SIZE
	autoButton.Text = Localization.t("timelineTest.auto")
	autoButton.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.ButtonText)
	autoButton.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.Button)
	autoButton.Parent = root

	local ruler = Instance.new("Frame")
	ruler.Name = "Ruler"
	ruler.Position = UDim2.fromOffset(NAME_WIDTH, HEADER_HEIGHT)
	ruler.Size = UDim2.new(1, -NAME_WIDTH - 8, 0, RULER_HEIGHT)
	ruler.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.Titlebar)
	ruler.BorderSizePixel = 0
	ruler.ClipsDescendants = true
	ruler.Active = true
	ruler.Parent = root

	label({
		Position = UDim2.fromOffset(Theme.PADDING, HEADER_HEIGHT),
		Size = UDim2.fromOffset(NAME_WIDTH - Theme.PADDING, RULER_HEIGHT),
		TextColor3 = Theme.color(Enum.StudioStyleGuideColor.DimmedText),
		Text = Localization.t("timelineTest.hint"),
		TextScaled = true,
		Parent = root,
	})

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, HEADER_HEIGHT + RULER_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + RULER_HEIGHT))
	body.CanvasSize = UDim2.fromOffset(0, TRACK_COUNT * ROW_HEIGHT)
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ScrollBarThickness = 8
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = root

	local lanes = Instance.new("Frame")
	lanes.Name = "Lanes"
	lanes.Position = UDim2.fromOffset(NAME_WIDTH, 0)
	lanes.Size = UDim2.new(1, -NAME_WIDTH - 8, 0, TRACK_COUNT * ROW_HEIGHT)
	lanes.BackgroundTransparency = 1
	lanes.ClipsDescendants = true
	lanes.Parent = body

	for row, name in trackNames do
		label({
			Position = UDim2.fromOffset(Theme.PADDING, (row - 1) * ROW_HEIGHT),
			Size = UDim2.fromOffset(NAME_WIDTH - Theme.PADDING, ROW_HEIGHT),
			Text = name,
			Parent = body,
		})
		local stripe = Instance.new("Frame")
		stripe.Position = UDim2.fromOffset(0, (row - 1) * ROW_HEIGHT)
		stripe.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.TableItem)
		stripe.BackgroundTransparency = if row % 2 == 0 then 0 else 1
		stripe.Parent = lanes
	end

	local playhead = Instance.new("Frame")
	playhead.Name = "Playhead"
	playhead.Size = UDim2.new(0, 2, 1, -HEADER_HEIGHT)
	playhead.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
	playhead.BorderSizePixel = 0
	playhead.ZIndex = 10
	playhead.Parent = root

	root.Parent = parent

	-- Pools -------------------------------------------------------------------
	local markerPool: { Frame } = {}
	local markersInUse = 0
	local markerColor = Theme.color(Enum.StudioStyleGuideColor.LinkText)

	local function getMarker(index: number): Frame
		local marker = markerPool[index]
		if not marker then
			marker = Instance.new("Frame")
			marker.AnchorPoint = Vector2.new(0.5, 0.5)
			marker.Size = UDim2.fromOffset(MARKER_SIZE, MARKER_SIZE)
			marker.Rotation = 45
			marker.BorderSizePixel = 0
			marker.BackgroundColor3 = markerColor
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
			tickLabel = label({
				AnchorPoint = Vector2.new(0, 0),
				Size = UDim2.fromOffset(60, RULER_HEIGHT),
				TextColor3 = Theme.color(Enum.StudioStyleGuideColor.DimmedText),
				Parent = ruler,
			})
			tickPool[index] = tickLabel
		end
		return tickLabel
	end

	-- Rendering ---------------------------------------------------------------
	local function clampView()
		local laneWidth = math.max(lanes.AbsoluteSize.X, 1)
		local maxStart = math.max(0, CLIP_LENGTH - laneWidth / pps)
		viewStart = math.clamp(viewStart, 0, maxStart)
	end

	local function render()
		clampView()
		local laneWidth = lanes.AbsoluteSize.X
		local viewEnd = viewStart + laneWidth / pps

		-- Keyframe markers, only for visible rows and visible time range.
		local scrollY = body.CanvasPosition.Y
		local firstRow = math.max(1, math.floor(scrollY / ROW_HEIGHT) + 1)
		local lastRow = math.min(TRACK_COUNT, math.ceil((scrollY + body.AbsoluteSize.Y) / ROW_HEIGHT))
		local used = 0
		for row = firstRow, lastRow do
			local keyframes = clip.tracks[trackNames[row]].keyframes
			local index = lowerBound(keyframes, viewStart)
			local y = (row - 1) * ROW_HEIGHT + ROW_HEIGHT / 2
			while index <= #keyframes and keyframes[index].time <= viewEnd do
				used += 1
				local marker = getMarker(used)
				marker.Position = UDim2.fromOffset((keyframes[index].time - viewStart) * pps, y)
				marker.Visible = true
				index += 1
			end
		end
		for index = used + 1, markersInUse do
			markerPool[index].Visible = false
		end
		markersInUse = used
		visibleMarkers = used

		-- Ruler ticks: pick the smallest step that leaves at least 60 px between labels.
		local step = TICK_STEPS[#TICK_STEPS]
		for _, candidate in TICK_STEPS do
			if candidate * pps >= 60 then
				step = candidate
				break
			end
		end
		local tickCount = 0
		local tickTime = math.ceil(viewStart / step) * step
		while tickTime <= viewEnd do
			tickCount += 1
			local tickLabel = getTick(tickCount)
			tickLabel.Position = UDim2.fromOffset((tickTime - viewStart) * pps + 2, 0)
			tickLabel.Text = string.format(if step < 1 then "%.2fs" else "%ds", tickTime)
			tickLabel.Visible = true
			tickTime += step
		end
		for index = tickCount + 1, ticksInUse do
			tickPool[index].Visible = false
		end
		ticksInUse = tickCount

		-- Playhead
		local x = (currentTime - viewStart) * pps
		playhead.Visible = x >= 0 and x <= laneWidth
		playhead.Position = UDim2.fromOffset(NAME_WIDTH + x - 1, HEADER_HEIGHT)
	end

	local function recordScrub(stats: Stats, ms: number)
		stats.scrubCount += 1
		stats.scrubTotalMs += ms
		stats.scrubMaxMs = math.max(stats.scrubMaxMs, ms)
	end

	-- Scrub-to-pose: sample every track at time t (what a real rig preview needs).
	local function setTime(t: number)
		currentTime = math.clamp(t, 0, CLIP_LENGTH)
		local started = os.clock()
		Interpolate.sampleClip(clip, currentTime)
		lastScrubMs = (os.clock() - started) * 1000
		recordScrub(liveStats, lastScrubMs)
		if autoTest then
			recordScrub(autoTest.stats, lastScrubMs)
		end
		dirty = true
	end

	local function timeAtX(x: number): number
		return viewStart + x / pps
	end

	-- Input -------------------------------------------------------------------
	table.insert(
		connections,
		ruler.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				scrubbing = true
				setTime(timeAtX(input.Position.X - ruler.AbsolutePosition.X))
			end
		end)
	)
	table.insert(
		connections,
		ruler.InputChanged:Connect(function(input)
			local x = input.Position.X - ruler.AbsolutePosition.X
			if input.UserInputType == Enum.UserInputType.MouseMovement and scrubbing then
				setTime(timeAtX(x))
			elseif input.UserInputType == Enum.UserInputType.MouseWheel then
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
		end)
	)
	table.insert(
		connections,
		root.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				scrubbing = false
			end
		end)
	)
	table.insert(
		connections,
		ruler.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				scrubbing = false
			end
		end)
	)
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
		autoButton.Activated:Connect(function()
			if not autoTest then
				autoTest = { startedAt = os.clock(), stats = newStats() }
				autoButton.Text = Localization.t("timelineTest.running")
			end
		end)
	)

	-- Frame loop ----------------------------------------------------------------
	local function formatResult(stats: Stats, seconds: number): string
		return Localization.t("timelineTest.result", {
			fps = math.round(stats.frames / seconds),
			worst = string.format("%.1f", stats.worstFrameMs),
			scrubAvg = string.format("%.2f", if stats.scrubCount > 0 then stats.scrubTotalMs / stats.scrubCount else 0),
			scrubMax = string.format("%.2f", stats.scrubMaxMs),
			markers = stats.maxMarkers,
		})
	end

	local lastResult = ""
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(deltaTime)
			if parent:IsA("PluginGui") and not parent.Enabled then
				return
			end
			local frameMs = deltaTime * 1000
			liveStats.frames += 1
			liveStats.worstFrameMs = math.max(liveStats.worstFrameMs, frameMs)

			local running = autoTest
			if running then
				local elapsed = os.clock() - running.startedAt
				local progress = elapsed / AUTO_TEST_SECONDS
				-- Sweep the playhead across the clip while zooming in and out.
				local zoomWave = (math.sin(progress * math.pi * 4) + 1) / 2
				pps = MIN_PPS * 2 + (400 - MIN_PPS * 2) * zoomWave
				setTime(progress * CLIP_LENGTH)
				viewStart = currentTime - lanes.AbsoluteSize.X / pps / 2
				running.stats.frames += 1
				running.stats.worstFrameMs = math.max(running.stats.worstFrameMs, frameMs)
				running.stats.maxMarkers = math.max(running.stats.maxMarkers, visibleMarkers)
				if elapsed >= AUTO_TEST_SECONDS then
					lastResult = formatResult(running.stats, elapsed)
					print("[Animora Spike B] " .. lastResult)
					autoTest = nil
					autoButton.Text = Localization.t("timelineTest.auto")
				end
			end

			if dirty then
				dirty = false
				render()
			end
			liveStats.maxMarkers = math.max(liveStats.maxMarkers, visibleMarkers)

			local windowSeconds = os.clock() - liveWindowStart
			if windowSeconds >= 0.5 then
				statsLabel.Text = Localization.t("timelineTest.live", {
					fps = math.round(liveStats.frames / windowSeconds),
					worst = string.format("%.1f", liveStats.worstFrameMs),
					scrub = string.format("%.2f", lastScrubMs),
					markers = visibleMarkers,
				}) .. (if lastResult ~= "" then "\n" .. lastResult else "")
				liveStats = newStats()
				liveWindowStart = os.clock()
			end
		end)
	)

	local handle = {}
	function handle.destroy(_self: Handle)
		for _, connection in connections do
			connection:Disconnect()
		end
		root:Destroy()
	end
	return handle :: Handle
end

return TimelineTest
