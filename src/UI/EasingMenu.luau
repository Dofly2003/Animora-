--!strict
-- Easing panel docked at the bottom of the timeline: pick a style and a direction for the
-- selected keyframes. Each keyframe's easing shapes the motion to the next keyframe.

local Localization = require(script.Parent.Parent.Localization)
local Session = require(script.Parent.Parent.Studio.Session)
local Theme = require(script.Parent.Theme)
local Model = require(script.Parent.Parent.Core.Model)

local EasingMenu = {}

export type Handle = {
	open: (self: Handle) -> (),
	close: (self: Handle) -> (),
	isOpen: (self: Handle) -> boolean,
	destroy: (self: Handle) -> (),
}

local STYLES: { Model.EasingStyle } = {
	"Linear",
	"Constant",
	"Sine",
	"Quad",
	"Cubic",
	"Quart",
	"Quint",
	"Exponential",
	"Circular",
	"Back",
	"Elastic",
	"Bounce",
}
local DIRECTIONS: { Model.EasingDirection } = { "In", "Out", "InOut" }

local ROW = 26
local HEIGHT = ROW * 5 + 24

function EasingMenu.mount(parent: GuiObject, session: Session.Session, notify: (key: string, args: any?) -> ()): Handle
	local root = Instance.new("Frame")
	root.Name = "EasingMenu"
	-- Docked at the bottom so the keyframes stay visible and clickable above it.
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.fromScale(0, 1)
	root.Size = UDim2.new(1, 0, 0, HEIGHT)
	root.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.Titlebar)
	root.BorderSizePixel = 0
	root.ZIndex = 20
	root.Active = true
	root.Visible = false
	root.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, Theme.PADDING)
	padding.PaddingRight = UDim.new(0, Theme.PADDING)
	padding.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -90, 0, ROW)
	title.FontFace = Theme.FONT
	title.TextSize = Theme.TEXT_SIZE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
	title.ZIndex = 21
	title.Parent = root

	local function makeButton(text: string, parentFrame: Instance): TextButton
		local instance = Instance.new("TextButton")
		instance.FontFace = Theme.FONT
		instance.TextSize = Theme.TEXT_SIZE
		instance.Text = text
		instance.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.ButtonText)
		instance.BorderSizePixel = 0
		instance.ZIndex = 22
		instance.Parent = parentFrame
		return instance
	end

	local closeButton = makeButton("", root)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 0, 0, 0)
	closeButton.Size = UDim2.fromOffset(80, ROW - 2)

	local styleGrid = Instance.new("Frame")
	styleGrid.BackgroundTransparency = 1
	styleGrid.Position = UDim2.fromOffset(0, ROW + 4)
	styleGrid.Size = UDim2.new(1, 0, 0, ROW * 2 + 4)
	styleGrid.ZIndex = 21
	styleGrid.Parent = root
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(96, ROW - 2)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = styleGrid

	local directionRow = Instance.new("Frame")
	directionRow.BackgroundTransparency = 1
	directionRow.Position = UDim2.fromOffset(0, ROW * 3 + 12)
	directionRow.Size = UDim2.new(1, 0, 0, ROW)
	directionRow.ZIndex = 21
	directionRow.Parent = root
	local directionLayout = Instance.new("UIListLayout")
	directionLayout.FillDirection = Enum.FillDirection.Horizontal
	directionLayout.Padding = UDim.new(0, 4)
	directionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	directionLayout.Parent = directionRow

	local directionLabel = Instance.new("TextLabel")
	directionLabel.BackgroundTransparency = 1
	directionLabel.Size = UDim2.fromOffset(70, ROW - 2)
	directionLabel.FontFace = Theme.FONT
	directionLabel.TextSize = Theme.TEXT_SIZE
	directionLabel.TextXAlignment = Enum.TextXAlignment.Left
	directionLabel.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
	directionLabel.ZIndex = 22
	directionLabel.LayoutOrder = 0
	directionLabel.Parent = directionRow

	local styleButtons: { [string]: TextButton } = {}
	local directionButtons: { [string]: TextButton } = {}
	local connections: { any } = {}

	local function highlight()
		local style, direction = session:selectedEasing()
		for name, styleButton in styleButtons do
			styleButton.BackgroundColor3 = Theme.color(
				Enum.StudioStyleGuideColor.Button,
				if name == style then Enum.StudioStyleGuideModifier.Selected else nil
			)
		end
		for name, directionButton in directionButtons do
			directionButton.BackgroundColor3 = Theme.color(
				Enum.StudioStyleGuideColor.Button,
				if name == direction then Enum.StudioStyleGuideModifier.Selected else nil
			)
		end
		local count = #session.selectedKeys
		title.Text = if count > 0
			then Localization.t("easing.title", { count = count })
			else Localization.t("easing.noSelection")
	end

	local function apply(style: Model.EasingStyle?, direction: Model.EasingDirection?)
		local changed = session:setEasing(style, direction)
		if changed == 0 then
			notify("easing.noSelection")
		else
			notify("easing.applied", {
				count = changed,
				style = style or "",
				direction = direction or "",
			})
		end
		highlight()
	end

	for index, style in STYLES do
		local styleButton = makeButton(style, styleGrid)
		styleButton.LayoutOrder = index
		styleButtons[style] = styleButton
		table.insert(
			connections,
			styleButton.Activated:Connect(function()
				apply(style, nil)
			end)
		)
	end
	for index, direction in DIRECTIONS do
		local directionButton = makeButton(direction, directionRow)
		directionButton.LayoutOrder = index
		directionButton.Size = UDim2.fromOffset(80, ROW - 2)
		directionButtons[direction] = directionButton
		table.insert(
			connections,
			directionButton.Activated:Connect(function()
				apply(nil, direction)
			end)
		)
	end

	local handle = {}
	local function applyTexts()
		closeButton.Text = Localization.t("import.close")
		directionLabel.Text = Localization.t("easing.direction")
		highlight()
	end
	applyTexts()
	table.insert(connections, Localization.onChanged(applyTexts))
	table.insert(
		connections,
		closeButton.Activated:Connect(function()
			handle:close()
		end)
	)
	-- Keep the highlight and title in sync while the panel is open.
	table.insert(
		connections,
		session.changed:Connect(function(change)
			if root.Visible and (change == "keys" or change == "clip" or change == "rig") then
				highlight()
			end
		end)
	)

	function handle.open(_self: Handle)
		highlight()
		root.Visible = true
	end
	function handle.close(_self: Handle)
		root.Visible = false
	end
	function handle.isOpen(_self: Handle): boolean
		return root.Visible
	end
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

return EasingMenu
