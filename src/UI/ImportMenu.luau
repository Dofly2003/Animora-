--!strict
-- Import dialog shown over the timeline: lists every KeyframeSequence saved in the place
-- (ServerStorage.RBX_ANIMSAVES, where Animora and the Animation Editor export to) and
-- can load a published animation by asset ID.

local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ServerStorage = game:GetService("ServerStorage")

local Localization = require(script.Parent.Parent.Localization)
local Theme = require(script.Parent.Theme)

local ImportMenu = {}

export type Handle = {
	open: (self: Handle) -> (),
	close: (self: Handle) -> (),
	destroy: (self: Handle) -> (),
}

export type Callbacks = {
	-- Imports the sequence and returns how many keyframes were imported.
	importSequence: (sequence: KeyframeSequence, sourceName: string) -> (),
	notify: (key: string, args: { [string]: any }?) -> (),
}

local ROW = 26

local function label(parent: Instance, props: { [string]: any }): TextLabel
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

local function button(parent: Instance, text: string, props: { [string]: any }): TextButton
	local instance = Instance.new("TextButton")
	instance.FontFace = Theme.FONT
	instance.TextSize = Theme.TEXT_SIZE
	instance.Text = text
	instance.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.ButtonText)
	instance.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.Button)
	instance.BorderSizePixel = 0
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- "RBX_ANIMSAVES > Rig > Walk" style path for display.
local function displayPath(sequence: Instance): string
	local parts = {}
	local current: Instance? = sequence
	while current and current ~= ServerStorage and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, " > ")
end

function ImportMenu.mount(parent: GuiObject, callbacks: Callbacks): Handle
	local root = Instance.new("Frame")
	root.Name = "ImportMenu"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.MainBackground)
	root.BorderSizePixel = 0
	root.ZIndex = 20
	root.Active = true
	root.Visible = false
	root.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.PADDING)
	padding.PaddingLeft = UDim.new(0, Theme.PADDING * 2)
	padding.PaddingRight = UDim.new(0, Theme.PADDING * 2)
	padding.Parent = root

	local title = label(root, {
		Size = UDim2.new(1, -90, 0, ROW),
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 21,
	})
	local closeButton = button(root, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(80, ROW),
		ZIndex = 21,
	})

	-- From asset ID
	local idLabel = label(root, {
		Position = UDim2.fromOffset(0, ROW + Theme.PADDING),
		Size = UDim2.fromOffset(160, ROW),
		ZIndex = 21,
	})
	local idBox = Instance.new("TextBox")
	idBox.Position = UDim2.fromOffset(160, ROW + Theme.PADDING)
	idBox.Size = UDim2.fromOffset(200, ROW)
	idBox.FontFace = Theme.FONT
	idBox.TextSize = Theme.TEXT_SIZE
	idBox.ClearTextOnFocus = false
	idBox.Text = ""
	idBox.PlaceholderText = "1234567890"
	idBox.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
	idBox.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.InputFieldBackground)
	idBox.BorderColor3 = Theme.color(Enum.StudioStyleGuideColor.InputFieldBorder)
	idBox.ZIndex = 21
	idBox.Parent = root
	local idButton = button(root, "", {
		Position = UDim2.fromOffset(368, ROW + Theme.PADDING),
		Size = UDim2.fromOffset(90, ROW),
		ZIndex = 21,
	})

	-- From the place
	local listLabel = label(root, {
		Position = UDim2.fromOffset(0, (ROW + Theme.PADDING) * 2),
		Size = UDim2.new(1, 0, 0, ROW),
		ZIndex = 21,
	})
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, (ROW + Theme.PADDING) * 3)
	list.Size = UDim2.new(1, 0, 1, -(ROW + Theme.PADDING) * 3 - Theme.PADDING)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ZIndex = 21
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function applyTexts()
		title.Text = Localization.t("import.title")
		closeButton.Text = Localization.t("import.close")
		idLabel.Text = Localization.t("import.fromId")
		idButton.Text = Localization.t("import.load")
		listLabel.Text = Localization.t("import.fromPlace")
	end
	applyTexts()
	local unsubscribe = Localization.onChanged(applyTexts)

	local handle = {}

	local function refreshList()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local sequences: { KeyframeSequence } = {}
		local folder = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
		if folder then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("KeyframeSequence") then
					table.insert(sequences, descendant)
				end
			end
		end
		table.sort(sequences, function(a, b)
			return displayPath(a) < displayPath(b)
		end)
		if #sequences == 0 then
			label(list, {
				Size = UDim2.new(1, -10, 0, ROW * 2),
				TextWrapped = true,
				TextColor3 = Theme.color(Enum.StudioStyleGuideColor.DimmedText),
				Text = Localization.t("import.empty"),
				ZIndex = 22,
			})
			return
		end
		for index, sequence in sequences do
			local path = displayPath(sequence)
			local row = button(list, "  " .. path, {
				LayoutOrder = index,
				Size = UDim2.new(1, -10, 0, ROW),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 22,
			})
			row.Activated:Connect(function()
				handle:close()
				callbacks.importSequence(sequence, path)
			end)
		end
	end

	local connections = {
		closeButton.Activated:Connect(function()
			handle:close()
		end),
		idButton.Activated:Connect(function()
			local id = string.match(idBox.Text, "%d+")
			if not id then
				callbacks.notify("import.badId")
				return
			end
			callbacks.notify("import.loading", { id = id })
			task.spawn(function()
				local ok, result = pcall(function()
					return AnimationClipProvider:GetAnimationClipAsync("rbxassetid://" .. id)
				end)
				if not ok then
					callbacks.notify("import.loadFailed", { id = id, reason = tostring(result) })
				elseif not result:IsA("KeyframeSequence") then
					callbacks.notify("import.curveUnsupported", { id = id })
				else
					handle:close()
					callbacks.importSequence(result :: KeyframeSequence, "ID " .. id)
				end
			end)
		end),
	}

	function handle.open(_self: Handle)
		refreshList()
		root.Visible = true
	end
	function handle.close(_self: Handle)
		root.Visible = false
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

return ImportMenu
