--!strict
-- Root UI of the Animora dock widget (Fusion 0.3): toolbar on top, timeline below.
-- Owns the editor Session, the rotate gizmo and the Studio selection hookup.
-- The week-1 spike tools are still reachable behind the "Dev" toggle.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Fusion = require(script.Parent.Parent.Packages.Fusion)
local Localization = require(script.Parent.Parent.Localization)
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Parent.Studio.Settings)
local Session = require(script.Parent.Parent.Studio.Session)
local Gizmo = require(script.Parent.Parent.Studio.Gizmo)
local RigBinder = require(script.Parent.Parent.Studio.RigBinder)
local StudioUndo = require(script.Parent.Parent.Studio.StudioUndo)
local Timeline = require(script.Parent.Timeline)
local DevPanel = require(script.Parent.DevPanel)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local ROW_HEIGHT = 34
local TOOLBAR_HEIGHT = ROW_HEIGHT * 2

local App = {}

export type AppHandle = {
	session: Session.Session,
	destroy: (self: AppHandle) -> (),
}

export type AppActions = {
	openTimelineTest: () -> (),
}

function App.mount(parent: Instance, pluginSettings: Settings.Settings, actions: AppActions): AppHandle
	local scope = Fusion.scoped(Fusion)
	local session = Session.new()
	session.onEdit = StudioUndo.record
	local gizmo = Gizmo.new(session)

	local language = scope:Value(Localization.getLanguage())
	local themeTick = scope:Value(0)
	local devMode = scope:Value(false)
	-- Bumped on every session change so toolbar texts recompute.
	local sessionTick = scope:Value(0)
	-- Short message shown in the status bar (e.g. "this model has no Motor6D joints").
	local notice = scope:Value(nil :: { key: string, args: { [string]: any }? }?)

	local cleanups: { () -> () } = {}
	local function track(connection: any)
		table.insert(cleanups, function()
			if typeof(connection) == "function" then
				connection()
			else
				connection:Disconnect()
			end
		end)
	end

	track(Localization.onChanged(function(code)
		language:set(code)
	end))
	track(Theme.onChanged(function()
		themeTick:set(Fusion.peek(themeTick) + 1)
	end))
	track(session.changed:Connect(function()
		sessionTick:set(Fusion.peek(sessionTick) + 1)
	end))

	-- Selecting a rig part in the viewport picks the rig and the joint it belongs to.
	local function onSelectionChanged()
		-- Never touch rigs while the panel is closed or the spike tools are active.
		if Fusion.peek(devMode) or (parent:IsA("PluginGui") and not parent.Enabled) then
			return
		end
		local selected = Selection:Get()[1]
		if not selected then
			return
		end
		local rig = RigBinder.findRig(selected)
		if not rig then
			-- Explain why a selected model is ignored instead of silently doing nothing.
			local model = if selected:IsA("Model") then selected else selected:FindFirstAncestorWhichIsA("Model")
			if model and model ~= workspace then
				notice:set({ key = "editor.status.notRig", args = { name = model.Name } })
			end
			return
		end
		notice:set(nil)
		session:setRig(rig)
		if selected:IsA("BasePart") and session.binder then
			local joint = session.binder.joints[selected.Name]
			if joint and joint.Part1 == selected then
				session:selectJoint(selected.Name)
			end
		end
	end
	track(Selection.SelectionChanged:Connect(onSelectionChanged))

	-- Studio's Ctrl+Z / Ctrl+Y: when the waypoint is an Animora edit, undo/redo it in the
	-- session too. Either way Studio may have rewritten the preview C0s, so re-apply the pose.
	track(ChangeHistoryService.OnUndo:Connect(function(waypoint: string)
		if StudioUndo.isAnimoraWaypoint(waypoint) then
			session:undo()
		end
		session:refreshPose()
	end))
	track(ChangeHistoryService.OnRedo:Connect(function(waypoint: string)
		if StudioUndo.isAnimoraWaypoint(waypoint) then
			session:redo()
		end
		session:refreshPose()
	end))

	-- Closing the panel puts the rig back in its rest pose; reopening picks up the selection.
	if parent:IsA("PluginGui") then
		track(parent:GetPropertyChangedSignal("Enabled"):Connect(function()
			if parent.Enabled then
				onSelectionChanged()
			else
				session:setRig(nil)
			end
		end))
	end

	-- Helpers -------------------------------------------------------------------
	local function text(key: string)
		return scope:Computed(function(use)
			use(language)
			return Localization.t(key)
		end)
	end
	local function color(item: Enum.StudioStyleGuideColor)
		return scope:Computed(function(use)
			use(themeTick)
			return Theme.color(item)
		end)
	end

	local function button(props: {
		text: any,
		width: number,
		onClick: () -> (),
		selected: any?,
		order: number,
	})
		return scope:New("TextButton")({
			LayoutOrder = props.order,
			Size = UDim2.fromOffset(props.width, 26),
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			Text = props.text,
			TextColor3 = color(Enum.StudioStyleGuideColor.ButtonText),
			BackgroundColor3 = scope:Computed(function(use)
				use(themeTick)
				local selected = if props.selected then use(props.selected) else false
				return Theme.color(
					Enum.StudioStyleGuideColor.Button,
					if selected then Enum.StudioStyleGuideModifier.Selected else nil
				)
			end),
			[OnEvent("Activated")] = props.onClick,
		})
	end

	local function languageButton(code: Localization.LanguageCode, order: number)
		return button({
			order = order,
			width = 36,
			text = string.upper(code),
			selected = scope:Computed(function(use)
				return use(language) == code
			end),
			onClick = function()
				pluginSettings:set("language", code)
				Localization.setLanguage(code)
			end,
		})
	end

	local statusText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		local message = use(notice)
		if message then
			return Localization.t(message.key, message.args)
		end
		local rig = session.rig
		if not rig then
			return Localization.t("editor.status.noRig")
		end
		return Localization.t("editor.status.rig", {
			rig = rig.Name,
			joint = session.selectedJoint or Localization.t("editor.status.noJoint"),
		})
	end)

	local timeText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		local clip = session.clip
		if not clip then
			return ""
		end
		return Localization.t("editor.time", {
			time = string.format("%.2f", session.time),
			frame = math.round(session.time * clip.fps),
			frames = math.round(clip.length * clip.fps),
		})
	end)

	local fpsText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		local clip = session.clip
		return Localization.t("editor.fps", { fps = if clip then clip.fps else "-" })
	end)

	local function row(order: number, children: { any })
		local rowChildren: { any } = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.PADDING),
				PaddingRight = UDim.new(0, Theme.PADDING),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.PADDING / 2),
			}),
		}
		for _, child in children do
			table.insert(rowChildren, child)
		end
		return scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			[Children] = rowChildren,
		})
	end

	local function divider(order: number)
		return scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(1, 20),
			BorderSizePixel = 0,
			BackgroundColor3 = color(Enum.StudioStyleGuideColor.Border),
		})
	end

	local playText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		return Localization.t(if session.playing then "editor.pause" else "editor.play")
	end)

	-- Layout --------------------------------------------------------------------
	local timelineHost = scope:New("Frame")({
		Name = "TimelineHost",
		Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT),
		Size = UDim2.new(1, 0, 1, -TOOLBAR_HEIGHT),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return not use(devMode)
		end),
	})

	local devHost = scope:New("ScrollingFrame")({
		Name = "DevHost",
		Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT),
		Size = UDim2.new(1, 0, 1, -TOOLBAR_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 140),
		ScrollBarThickness = 8,
		Visible = devMode,
		[Children] = {
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.PADDING),
				PaddingLeft = UDim.new(0, Theme.PADDING * 2),
				PaddingRight = UDim.new(0, Theme.PADDING * 2),
			}),
			DevPanel.create(scope, { language = language, text = text, color = color }, 1, parent, actions),
		},
	})

	scope:New("Frame")({
		Name = "AnimoraApp",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color(Enum.StudioStyleGuideColor.MainBackground),
		[Children] = {
			scope:New("Frame")({
				Name = "Toolbar",
				Size = UDim2.new(1, 0, 0, TOOLBAR_HEIGHT),
				BackgroundColor3 = color(Enum.StudioStyleGuideColor.Titlebar),
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					row(1, {
						button({
							order = 1,
							width = 70,
							text = playText,
							onClick = function()
								session:togglePlay()
							end,
						}),
						button({
							order = 2,
							width = 60,
							text = text("editor.undo"),
							onClick = function()
								StudioUndo.undo()
							end,
						}),
						button({
							order = 3,
							width = 60,
							text = text("editor.redo"),
							onClick = function()
								StudioUndo.redo()
							end,
						}),
						scope:New("TextLabel")({
							LayoutOrder = 4,
							Size = UDim2.fromOffset(170, 26),
							BackgroundTransparency = 1,
							FontFace = Theme.FONT,
							TextSize = Theme.TEXT_SIZE,
							TextXAlignment = Enum.TextXAlignment.Center,
							Text = timeText,
							TextColor3 = color(Enum.StudioStyleGuideColor.MainText),
						}),
						scope:New("TextLabel")({
							LayoutOrder = 5,
							Size = UDim2.new(1, -620, 0, 26),
							BackgroundTransparency = 1,
							FontFace = Theme.FONT,
							TextSize = Theme.TEXT_SIZE,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							Text = statusText,
							TextColor3 = color(Enum.StudioStyleGuideColor.DimmedText),
						}),
						languageButton("en", 6),
						languageButton("id", 7),
						button({
							order = 8,
							width = 50,
							text = "Dev",
							selected = devMode,
							onClick = function()
								local enable = not Fusion.peek(devMode)
								if enable then
									-- Spike tools pose rigs themselves; release the editor's rig first.
									session:setRig(nil)
								end
								devMode:set(enable)
								if not enable then
									onSelectionChanged()
								end
							end,
						}),
					}),
					row(2, {
						button({
							order = 1,
							width = 34,
							text = "|<",
							onClick = function()
								session:jumpToKey(-1)
							end,
						}),
						button({
							order = 2,
							width = 34,
							text = "<",
							onClick = function()
								session:stepFrame(-1)
							end,
						}),
						button({
							order = 3,
							width = 34,
							text = ">",
							onClick = function()
								session:stepFrame(1)
							end,
						}),
						button({
							order = 4,
							width = 34,
							text = ">|",
							onClick = function()
								session:jumpToKey(1)
							end,
						}),
						divider(5),
						button({
							order = 6,
							width = 60,
							text = text("editor.copy"),
							onClick = function()
								session:copy()
							end,
						}),
						button({
							order = 7,
							width = 60,
							text = text("editor.paste"),
							onClick = function()
								session:paste()
							end,
						}),
						button({
							order = 8,
							width = 60,
							text = text("editor.delete"),
							onClick = function()
								session:deleteSelectedKeys()
							end,
						}),
						button({
							order = 9,
							width = 70,
							text = text("editor.mirror"),
							onClick = function()
								session:mirror()
							end,
						}),
						divider(10),
						button({
							order = 11,
							width = 70,
							text = fpsText,
							onClick = function()
								session:cycleFps()
							end,
						}),
					}),
				},
			}),
			timelineHost,
			devHost,
		},
	})

	local timeline = Timeline.mount(timelineHost, session)
	onSelectionChanged()

	local handle = { session = session }
	function handle.destroy(_self: AppHandle)
		for _, cleanup in cleanups do
			cleanup()
		end
		timeline:destroy()
		gizmo:destroy()
		session:destroy()
		scope:doCleanup()
	end
	return handle :: AppHandle
end

return App
