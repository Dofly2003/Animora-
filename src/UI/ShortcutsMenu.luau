--!strict
-- Shortcut help shown over the timeline: the viewport keys that work right away and how
-- to give the other commands a key in File > Customize Shortcuts. Opens by itself the
-- first time Animora is opened, and from the Shortcuts button afterwards.

local Localization = require(script.Parent.Parent.Localization)
local Theme = require(script.Parent.Theme)
local Shortcuts = require(script.Parent.Parent.Studio.Shortcuts)

local ShortcutsMenu = {}

export type Handle = {
	open: (self: Handle) -> (),
	close: (self: Handle) -> (),
	isOpen: (self: Handle) -> boolean,
	destroy: (self: Handle) -> (),
}

local ROW = 22
local KEY_WIDTH = 90
local NAME_WIDTH = 220

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local instance = Instance.new("TextLabel")
	instance.BackgroundTransparency = 1
	instance.FontFace = Theme.FONT
	instance.TextSize = Theme.TEXT_SIZE
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
	instance.ZIndex = 32
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

function ShortcutsMenu.mount(parent: GuiObject): Handle
	local root = Instance.new("Frame")
	root.Name = "ShortcutsMenu"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.MainBackground)
	root.BorderSizePixel = 0
	root.ZIndex = 30
	root.Active = true
	root.Visible = false
	root.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.PADDING)
	padding.PaddingLeft = UDim.new(0, Theme.PADDING * 2)
	padding.PaddingRight = UDim.new(0, Theme.PADDING * 2)
	padding.Parent = root

	local title = label(root, {
		Size = UDim2.new(1, -90, 0, 26),
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	})
	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 0, 0, 0)
	closeButton.Size = UDim2.fromOffset(80, 26)
	closeButton.FontFace = Theme.FONT
	closeButton.TextSize = Theme.TEXT_SIZE
	closeButton.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.ButtonText)
	closeButton.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.Button)
	closeButton.BorderSizePixel = 0
	closeButton.ZIndex = 32
	closeButton.Parent = root

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 26 + Theme.PADDING)
	list.Size = UDim2.new(1, 0, 1, -(26 + Theme.PADDING * 2))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ZIndex = 31
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- A wrapped paragraph (section intro).
	local function paragraph(text: string, bold: boolean?)
		label(list, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, ROW),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			FontFace = if bold then Font.fromEnum(Enum.Font.BuilderSansBold) else Theme.FONT,
			TextColor3 = Theme.color(
				if bold then Enum.StudioStyleGuideColor.MainText else Enum.StudioStyleGuideColor.DimmedText
			),
			Text = text,
		})
	end

	-- key | what it does | name in Customize Shortcuts
	local function entry(key: string, name: string, studioName: string?)
		local row = Instance.new("Frame")
		row.LayoutOrder = nextOrder()
		row.Size = UDim2.new(1, -12, 0, ROW)
		row.BackgroundTransparency = 1
		row.ZIndex = 31
		row.Parent = list
		label(row, {
			Size = UDim2.fromOffset(KEY_WIDTH, ROW),
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			Text = key,
		})
		label(row, {
			Position = UDim2.fromOffset(KEY_WIDTH, 0),
			Size = UDim2.fromOffset(NAME_WIDTH, ROW),
			Text = name,
		})
		if studioName then
			label(row, {
				Position = UDim2.fromOffset(KEY_WIDTH + NAME_WIDTH, 0),
				Size = UDim2.new(1, -(KEY_WIDTH + NAME_WIDTH), 0, ROW),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = Theme.color(Enum.StudioStyleGuideColor.DimmedText),
				Text = studioName,
			})
		end
	end

	local function spacer()
		local gap = Instance.new("Frame")
		gap.LayoutOrder = nextOrder()
		gap.Size = UDim2.fromOffset(1, Theme.PADDING)
		gap.BackgroundTransparency = 1
		gap.Parent = list
	end

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		order = 0
		title.Text = Localization.t("shortcuts.title")
		closeButton.Text = Localization.t("shortcuts.close")

		paragraph(Localization.t("shortcuts.viewport.title"), true)
		paragraph(Localization.t("shortcuts.viewport.body"))
		for _, spec in Shortcuts.ACTIONS do
			if spec.keyLabel then
				entry(spec.keyLabel, Localization.t("shortcuts.action." .. spec.id))
			end
		end
		entry("Ctrl+Z / Ctrl+Y", Localization.t("shortcuts.undoRedo"))
		spacer()

		paragraph(Localization.t("shortcuts.custom.title"), true)
		paragraph(Localization.t("shortcuts.custom.body"))
		for _, spec in Shortcuts.ACTIONS do
			if spec.suggested then
				entry(spec.suggested, Localization.t("shortcuts.action." .. spec.id), spec.text)
			end
		end
		paragraph(Localization.t("shortcuts.custom.more"))
		spacer()
		paragraph(Localization.t("shortcuts.reopen"))
	end
	render()
	local unsubscribe = Localization.onChanged(render)

	local handle = {}
	local connections = {
		closeButton.Activated:Connect(function()
			handle:close()
		end),
	}

	function handle.open(_self: Handle)
		root.Visible = true
	end
	function handle.close(_self: Handle)
		root.Visible = false
	end
	function handle.isOpen(_self: Handle): boolean
		return root.Visible
	end
	function handle.destroy(_self: Handle)
		unsubscribe()
		for _, connection in connections do
			connection:Disconnect()
		end
		root:Destroy()
	end
	return handle :: Handle
end

return ShortcutsMenu
