--!strict
-- Animations panel docked at the bottom of the timeline: the rig's animation list
-- (click one to edit it) with New, Duplicate, Rename and Delete. All list changes are
-- undoable with Ctrl+Z and saved in the place.

local Localization = require(script.Parent.Parent.Localization)
local Session = require(script.Parent.Parent.Studio.Session)
local Theme = require(script.Parent.Theme)

local AnimationsMenu = {}

export type Handle = {
	open: (self: Handle) -> (),
	close: (self: Handle) -> (),
	isOpen: (self: Handle) -> boolean,
	destroy: (self: Handle) -> (),
}

local ROW = 26
local HEIGHT = 190
local LIST_WIDTH = 260

function AnimationsMenu.mount(
	parent: GuiObject,
	session: Session.Session,
	notify: (key: string, args: { [string]: any }?) -> ()
): Handle
	local connections: { any } = {}

	local root = Instance.new("Frame")
	root.Name = "AnimationsMenu"
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
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = root

	local function newLabel(props: { [string]: any }): TextLabel
		local instance = Instance.new("TextLabel")
		instance.BackgroundTransparency = 1
		instance.FontFace = Theme.FONT
		instance.TextSize = Theme.TEXT_SIZE
		instance.TextXAlignment = Enum.TextXAlignment.Left
		instance.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
		instance.ZIndex = 21
		for key, value in props do
			(instance :: any)[key] = value
		end
		instance.Parent = root
		return instance
	end

	local function newButton(parentFrame: Instance, props: { [string]: any }): TextButton
		local instance = Instance.new("TextButton")
		instance.FontFace = Theme.FONT
		instance.TextSize = Theme.TEXT_SIZE
		instance.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.ButtonText)
		instance.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.Button)
		instance.BorderSizePixel = 0
		instance.ZIndex = 22
		for key, value in props do
			(instance :: any)[key] = value
		end
		instance.Parent = parentFrame
		return instance
	end

	local title = newLabel({ Size = UDim2.new(1, -90, 0, ROW) })
	local closeButton = newButton(root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(80, ROW - 2),
	})

	-- Left: the list of animations.
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, ROW + 4)
	list.Size = UDim2.new(0, LIST_WIDTH, 1, -(ROW + 4))
	list.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.MainBackground)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = root
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = list

	-- Right: actions.
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.Position = UDim2.fromOffset(LIST_WIDTH + Theme.PADDING, ROW + 4)
	actions.Size = UDim2.new(1, -(LIST_WIDTH + Theme.PADDING), 1, -(ROW + 4))
	actions.ZIndex = 21
	actions.Parent = root

	local newButtonInstance =
		newButton(actions, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(110, ROW - 2) })
	local duplicateButton =
		newButton(actions, { Position = UDim2.fromOffset(116, 0), Size = UDim2.fromOffset(110, ROW - 2) })
	local deleteButton =
		newButton(actions, { Position = UDim2.fromOffset(232, 0), Size = UDim2.fromOffset(110, ROW - 2) })

	local nameBox = Instance.new("TextBox")
	nameBox.Position = UDim2.fromOffset(0, ROW + 6)
	nameBox.Size = UDim2.fromOffset(226, ROW - 2)
	nameBox.FontFace = Theme.FONT
	nameBox.TextSize = Theme.TEXT_SIZE
	nameBox.ClearTextOnFocus = false
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.MainText)
	nameBox.BackgroundColor3 = Theme.color(Enum.StudioStyleGuideColor.InputFieldBackground)
	nameBox.BorderColor3 = Theme.color(Enum.StudioStyleGuideColor.InputFieldBorder)
	nameBox.ZIndex = 22
	nameBox.Parent = actions
	local renameButton =
		newButton(actions, { Position = UDim2.fromOffset(232, ROW + 6), Size = UDim2.fromOffset(110, ROW - 2) })

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(0, (ROW + 6) * 2)
	hint.Size = UDim2.new(1, 0, 0, ROW * 2)
	hint.FontFace = Theme.FONT
	hint.TextSize = Theme.TEXT_SIZE - 1
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.TextColor3 = Theme.color(Enum.StudioStyleGuideColor.DimmedText)
	hint.ZIndex = 21
	hint.Parent = actions

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local rig = session.rig
		title.Text = if rig
			then Localization.t("animations.title", { rig = rig.Name, count = #session.clips })
			else Localization.t("editor.status.noRig")
		for index, clip in session.clips do
			local active = clip == session.clip
			local row = newButton(list, {
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, ROW - 2),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = (if active then "  > " else "    ") .. clip.name,
				BackgroundColor3 = Theme.color(
					Enum.StudioStyleGuideColor.Button,
					if active then Enum.StudioStyleGuideModifier.Selected else nil
				),
			})
			row.Activated:Connect(function()
				session:selectAnimation(clip)
			end)
		end
		if not nameBox:IsFocused() then
			nameBox.Text = if session.clip then session.clip.name else ""
		end
	end

	local function applyTexts()
		closeButton.Text = Localization.t("import.close")
		newButtonInstance.Text = Localization.t("animations.new")
		duplicateButton.Text = Localization.t("animations.duplicate")
		deleteButton.Text = Localization.t("animations.delete")
		renameButton.Text = Localization.t("animations.rename")
		nameBox.PlaceholderText = Localization.t("animations.namePlaceholder")
		hint.Text = Localization.t("animations.hint")
		refresh()
	end
	applyTexts()
	table.insert(connections, Localization.onChanged(applyTexts))

	local function rename()
		if not session.clip then
			return
		end
		local name = session:renameAnimation(nameBox.Text)
		if name then
			notify("animations.renamed", { name = name })
		end
	end

	local handle = {}
	table.insert(
		connections,
		closeButton.Activated:Connect(function()
			handle:close()
		end)
	)
	table.insert(
		connections,
		newButtonInstance.Activated:Connect(function()
			local clip = session:newAnimation()
			if clip then
				notify("animations.created", { name = clip.name })
				nameBox:CaptureFocus()
			end
		end)
	)
	table.insert(
		connections,
		duplicateButton.Activated:Connect(function()
			local clip = session:duplicateAnimation()
			if clip then
				notify("animations.created", { name = clip.name })
			end
		end)
	)
	table.insert(
		connections,
		deleteButton.Activated:Connect(function()
			local name = session:deleteAnimation()
			if name then
				notify("animations.deleted", { name = name })
			end
		end)
	)
	table.insert(connections, renameButton.Activated:Connect(rename))
	table.insert(
		connections,
		nameBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				rename()
			end
		end)
	)
	table.insert(
		connections,
		session.changed:Connect(function(change)
			if root.Visible and (change == "animation" or change == "clip" or change == "rig") then
				refresh()
			end
		end)
	)

	function handle.open(_self: Handle)
		refresh()
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

return AnimationsMenu
