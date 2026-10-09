--!strict
-- Root UI of the Animora dock widget (Fusion 0.3): toolbar on top, timeline below.
-- Owns the editor Session, the gizmos and the Studio selection hookup.
--
-- Toolbar rows, grouped by purpose:
--   1. Clip      animation, length, loop, FPS, priority | export, import, language
--   2. Playback  keyframe/frame stepping, play, time | undo, redo | rotate / move mode
--   3. Edit      copy, paste, delete, mirror, easing, then the status message

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(script.Parent.Parent.Packages.Fusion)
local Localization = require(script.Parent.Parent.Localization)
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Parent.Studio.Settings)
local Session = require(script.Parent.Parent.Studio.Session)
local Gizmo = require(script.Parent.Parent.Studio.Gizmo)
local CameraPathView = require(script.Parent.Parent.Studio.CameraPathView)
local RigBinder = require(script.Parent.Parent.Studio.RigBinder)
local StudioUndo = require(script.Parent.Parent.Studio.StudioUndo)
local ViewportPicker = require(script.Parent.Parent.Studio.ViewportPicker)
local Storage = require(script.Parent.Parent.Studio.Storage)
local RunGuard = require(script.Parent.Parent.Studio.RunGuard)
local RigType = require(script.Parent.Parent.Core.RigType)
local CameraBake = require(script.Parent.Parent.Core.CameraBake)
local Model = require(script.Parent.Parent.Core.Model)
local Timeline = require(script.Parent.Timeline)
local ImportMenu = require(script.Parent.ImportMenu)
local EasingMenu = require(script.Parent.EasingMenu)
local AnimationsMenu = require(script.Parent.AnimationsMenu)
local ShortcutsMenu = require(script.Parent.ShortcutsMenu)
local Shortcuts = require(script.Parent.Parent.Studio.Shortcuts)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local MODIFIER_KEYS = {
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.LeftAlt,
	Enum.KeyCode.RightAlt,
}

local ROW_HEIGHT = 34
local TOOLBAR_HEIGHT = ROW_HEIGHT * 3

local App = {}

export type AppHandle = {
	session: Session.Session,
	-- Shows a short message in the status bar (cleared by the next rig selection).
	notify: (key: string, args: { [string]: any }?) -> (),
	destroy: (self: AppHandle) -> (),
}

export type AppActions = {
	plugin: Plugin,
}

function App.mount(parent: Instance, pluginSettings: Settings.Settings, actions: AppActions): AppHandle
	local scope = Fusion.scoped(Fusion)
	local session = Session.new()
	-- Every edit becomes a Studio undo waypoint that also saves the clip into the place.
	session.onEdit = function(name: string)
		StudioUndo.record(name, function()
			local rig = session.rig
			if rig then
				Storage.saveClips(rig, session.clips)
			end
		end)
	end
	session.loadClips = Storage.loadClips
	local gizmo = Gizmo.new(session)
	local cameraPath = CameraPathView.new(session)

	local language = scope:Value(Localization.getLanguage())
	local themeTick = scope:Value(0)
	-- Bumped on every session change so toolbar texts recompute.
	local sessionTick = scope:Value(0)
	-- Short message shown in the status bar (e.g. "this model has no joints").
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

	-- Clicking in the viewport picks a single body part (Studio's tools are switched off
	-- while the panel is open, so the whole model is not selected or rotated).
	local picker = ViewportPicker.new(actions.plugin, session, function()
		return not RunGuard.isRunning()
	end, function()
		return gizmo:isDragging()
	end)
	local function updatePicker()
		local open = not parent:IsA("PluginGui") or parent.Enabled
		picker:setActive(open)
	end

	-- Viewport keys (Space, Z C [ ] M, and R / T like Studio's rotate and move tools). Keys
	-- only reach the plugin while it is activated (panel open, picking on). Ctrl / Alt
	-- combos are left to Studio, so Ctrl+Z / Ctrl+C undo and copy instead of stepping frames.
	track(actions.plugin:GetMouse().KeyDown:Connect(function(key: string)
		if not picker:isActive() or not session.rig or RunGuard.isRunning() then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		for _, modifier in MODIFIER_KEYS do
			if UserInputService:IsKeyDown(modifier) then
				return
			end
		end
		Shortcuts.handleKey(key, session)
	end))
	-- Re-activate after the user picked another Studio tool and came back to Animora.
	track(session.changed:Connect(function(change)
		if (change == "rig" or change == "selection") and session.rig then
			updatePicker()
		end
	end))

	-- Selecting a rig part in the viewport picks the rig and the joint it belongs to.
	local function onSelectionChanged()
		-- Never touch rigs while the panel is closed or a Run (F8) test is going on.
		if RunGuard.isRunning() or (parent:IsA("PluginGui") and not parent.Enabled) then
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
		local picked = false
		if selected:IsA("BasePart") and session.binder then
			local joint = session.binder.joints[selected.Name]
			if joint and joint.Part1 == selected then
				session:selectJoint(selected.Name)
				picked = true
			end
		end
		-- Studio's Select tool picked the whole model (Animora's picking was not active
		-- yet, e.g. on the first click after opening the place): use the body part under
		-- the mouse, so the first click already selects an arm or the torso.
		if not picked then
			picker:pickUnderMouse()
		end
		updatePicker()
	end
	track(Selection.SelectionChanged:Connect(onSelectionChanged))

	-- Run (F8): release the rig so the game starts from the rest pose, not the preview pose
	-- (otherwise animations would play on top of it).
	track(RunGuard.watch(function()
		session:setRig(nil)
	end))

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
			updatePicker()
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

	-- "R15", "R6" or "Custom rig", plus "Constraint" for Avatar Joint Upgrade rigs.
	local function rigTypeText(): string
		local binder = session.binder
		if not binder then
			return ""
		end
		local kinds: { [string]: string } = {}
		for name, joint in binder.joints do
			kinds[name] = joint.kind
		end
		local kind, constraint = RigType.classify(kinds)
		local label = if kind == "Custom" then Localization.t("editor.rigType.custom") else kind
		return if constraint then label .. " · Constraint" else label
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
			type = rigTypeText(),
			joint = if session.selectedJoint == Model.CAMERA_TRACK
				then Localization.t("camera.track")
				else session.selectedJoint or Localization.t("editor.status.noJoint"),
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

	local loopSelected = scope:Computed(function(use)
		use(sessionTick)
		return session.clip ~= nil and session.clip.looped
	end)

	local priorityText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		local clip = session.clip
		return Localization.t("editor.priority", { priority = if clip then clip.priority.Name else "-" })
	end)

	-- FOV shown in the toolbar: the keyed FOV at the playhead, else the Studio camera's.
	local fovText = scope:Computed(function(use)
		use(sessionTick)
		local fov = session:cameraFov()
		if not fov then
			local camera = workspace.CurrentCamera
			fov = if camera then camera.FieldOfView else Model.DEFAULT_FOV
		end
		return string.format("%d", math.round(fov :: number))
	end)

	local lengthText = scope:Computed(function(use)
		use(sessionTick)
		local clip = session.clip
		return if clip then string.format("%.2f", clip.length) else ""
	end)

	-- Exports the body as a KeyframeSequence and, when the clip has camera keys, the camera
	-- as a ModuleScript shot plus the AnimoraCamera player in ReplicatedStorage.
	local function exportClip()
		local rig = session.rig
		local clip = session.clip
		local sequence = session:buildExport()
		local camera = session:buildCameraExport()
		if not (rig and clip and (sequence or camera)) then
			notice:set({ key = "editor.export.empty" })
			return
		end
		local path, shotPath = "", ""
		local cameraModule: ModuleScript? = nil
		local cameraError: string? = nil
		-- Its own waypoint name: undoing an export must not undo a clip edit.
		StudioUndo.recordOther("Animora export", function()
			if sequence then
				path = Storage.placeExport(rig, sequence)
			end
			if camera then
				-- Writing a script's Source needs the plugin's Script Injection permission.
				local ok, result = pcall(function()
					cameraModule, shotPath =
						Storage.placeCameraExport(clip.name, CameraBake.toSource(camera, clip.name))
				end)
				if not ok then
					cameraError = tostring(result)
					warn("[Animora] Camera export failed:", result)
				end
			end
		end)
		if cameraError then
			notice:set({ key = "editor.export.cameraBlocked", args = { path = path } })
			if sequence then
				Selection:Set({ sequence })
			end
			return
		end
		Selection:Set({ if sequence then sequence else cameraModule :: Instance })
		if sequence and camera then
			notice:set({ key = "editor.export.withCamera", args = { path = path, camera = shotPath } })
		elseif camera then
			notice:set({ key = "editor.export.cameraOnly", args = { camera = shotPath } })
		else
			notice:set({ key = "editor.export.done", args = { path = path } })
		end
	end

	local function importSequence(sequence: KeyframeSequence, sourceName: string)
		local count = session:importSequence(sequence)
		notice:set({
			key = if count > 0 then "editor.import.done" else "editor.import.none",
			args = { count = count, name = sourceName },
		})
	end

	-- Import: a KeyframeSequence selected in the Explorer is imported directly; otherwise
	-- a menu lists the animations saved in the place and offers import by asset ID.
	local importMenu: ImportMenu.Handle? = nil
	local easingMenu: EasingMenu.Handle? = nil
	local animationsMenu: AnimationsMenu.Handle? = nil
	local shortcutsMenu: ShortcutsMenu.Handle? = nil

	-- The shortcut help opens by itself the first time the panel is open, so new users
	-- see the keys without looking for them.
	local function showShortcutsOnce()
		if not shortcutsMenu or (parent:IsA("PluginGui") and not parent.Enabled) then
			return
		end
		if pluginSettings:get("shortcutsShown") then
			return
		end
		pluginSettings:set("shortcutsShown", true)
		shortcutsMenu:open()
	end

	local animationText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		local clip = session.clip
		return Localization.t("animations.button", { name = if clip then clip.name else "-" })
	end)

	-- Only one bottom panel (easing / animations) at a time.
	local function togglePanel(panel: any, other: any)
		if not panel then
			return
		end
		if panel:isOpen() then
			panel:close()
		else
			if other then
				other:close()
			end
			panel:open()
		end
	end

	local easingText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		local style, direction = session:selectedEasing()
		if style then
			return Localization.t("easing.button", { style = style, direction = direction or "" })
		end
		return Localization.t("easing.buttonEmpty")
	end)
	local function importClip()
		if not session.rig then
			notice:set({ key = "editor.status.noRig" })
			return
		end
		for _, selected in Selection:Get() do
			if selected:IsA("KeyframeSequence") then
				importSequence(selected, selected.Name)
				return
			end
		end
		if importMenu then
			importMenu:open()
		end
	end

	-- A horizontal run of controls. Rows hold a left group and an optional right group.
	local function group(children: { any }, alignRight: boolean?)
		local groupChildren: { any } = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.PADDING / 2),
			}),
		}
		for _, child in children do
			table.insert(groupChildren, child)
		end
		return scope:New("Frame")({
			AnchorPoint = Vector2.new(if alignRight then 1 else 0, 0),
			Position = UDim2.fromScale(if alignRight then 1 else 0, 0),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			[Children] = groupChildren,
		})
	end

	local function row(order: number, left: { any }, right: { any }?, extra: any?)
		local rowChildren: { any } = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.PADDING),
				PaddingRight = UDim.new(0, Theme.PADDING),
			}),
			group(left),
		}
		if right then
			table.insert(rowChildren, group(right, true))
		end
		if extra then
			table.insert(rowChildren, extra)
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

	local function label(order: number, width: number, value: any, dimmed: boolean?)
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(width, 26),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			Text = value,
			TextColor3 = color(
				if dimmed then Enum.StudioStyleGuideColor.DimmedText else Enum.StudioStyleGuideColor.MainText
			),
		})
	end

	local playText = scope:Computed(function(use)
		use(language)
		use(sessionTick)
		return Localization.t(if session.playing then "editor.pause" else "editor.play")
	end)

	local lengthBox = scope:New("TextBox")({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(56, 24),
		FontFace = Theme.FONT,
		TextSize = Theme.TEXT_SIZE,
		ClearTextOnFocus = false,
		Text = lengthText,
		TextColor3 = color(Enum.StudioStyleGuideColor.MainText),
		BackgroundColor3 = color(Enum.StudioStyleGuideColor.InputFieldBackground),
		BorderColor3 = color(Enum.StudioStyleGuideColor.InputFieldBorder),
	}) :: TextBox
	track(lengthBox.FocusLost:Connect(function()
		local seconds = tonumber(lengthBox.Text)
		if seconds then
			session:setLength(seconds)
		end
		local clip = session.clip
		lengthBox.Text = if clip then string.format("%.2f", clip.length) else ""
	end))

	local fovBox = scope:New("TextBox")({
		LayoutOrder = 8,
		Size = UDim2.fromOffset(44, 24),
		FontFace = Theme.FONT,
		TextSize = Theme.TEXT_SIZE,
		ClearTextOnFocus = false,
		Text = fovText,
		TextColor3 = color(Enum.StudioStyleGuideColor.MainText),
		BackgroundColor3 = color(Enum.StudioStyleGuideColor.InputFieldBackground),
		BorderColor3 = color(Enum.StudioStyleGuideColor.InputFieldBorder),
	}) :: TextBox
	track(fovBox.FocusLost:Connect(function(enterPressed: boolean)
		local fov = tonumber(fovBox.Text)
		if fov and enterPressed then
			local applied = session:setCameraFov(fov)
			if applied then
				notice:set({
					key = "camera.fovSet",
					args = {
						fov = string.format("%d", math.round(applied)),
						time = string.format("%.2f", session.time),
					},
				})
			end
		end
		fovBox.Text = Fusion.peek(fovText)
	end))

	-- Layout --------------------------------------------------------------------
	local timelineHost = scope:New("Frame")({
		Name = "TimelineHost",
		Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT),
		Size = UDim2.new(1, 0, 1, -TOOLBAR_HEIGHT),
		BackgroundTransparency = 1,
	})

	local function modeSelected(mode: Session.GizmoMode)
		return scope:Computed(function(use)
			use(sessionTick)
			return session.gizmoMode == mode
		end)
	end

	-- Width of the edit row's buttons; the status message fills the rest of that row.
	local EDIT_GROUP_WIDTH = 560

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
					-- 1. Clip settings | file and language
					row(1, {
						button({
							order = 1,
							width = 170,
							text = animationText,
							onClick = function()
								togglePanel(animationsMenu, easingMenu)
							end,
						}),
						divider(2),
						label(3, 52, text("editor.length")),
						(function()
							lengthBox.LayoutOrder = 4
							return lengthBox
						end)(),
						label(5, 12, "s", true),
						button({
							order = 6,
							width = 60,
							text = text("editor.loop"),
							selected = loopSelected,
							onClick = function()
								session:toggleLooped()
							end,
						}),
						button({
							order = 7,
							width = 70,
							text = fpsText,
							onClick = function()
								session:cycleFps()
							end,
						}),
						button({
							order = 8,
							width = 150,
							text = priorityText,
							onClick = function()
								session:cyclePriority()
							end,
						}),
					}, {
						button({
							order = 1,
							width = 70,
							text = text("editor.export"),
							onClick = exportClip,
						}),
						button({
							order = 2,
							width = 70,
							text = text("editor.import"),
							onClick = importClip,
						}),
						divider(3),
						button({
							order = 4,
							width = 80,
							text = text("shortcuts.button"),
							onClick = function()
								if shortcutsMenu then
									if shortcutsMenu:isOpen() then
										shortcutsMenu:close()
									else
										shortcutsMenu:open()
									end
								end
							end,
						}),
						languageButton("en", 5),
						languageButton("id", 6),
					}),
					-- 2. Playback and time | undo | gizmo mode
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
							width = 70,
							text = playText,
							onClick = function()
								session:togglePlay()
							end,
						}),
						button({
							order = 4,
							width = 34,
							text = ">",
							onClick = function()
								session:stepFrame(1)
							end,
						}),
						button({
							order = 5,
							width = 34,
							text = ">|",
							onClick = function()
								session:jumpToKey(1)
							end,
						}),
						label(6, 140, timeText),
						divider(7),
						button({
							order = 8,
							width = 60,
							text = text("editor.undo"),
							onClick = function()
								StudioUndo.undo()
							end,
						}),
						button({
							order = 9,
							width = 60,
							text = text("editor.redo"),
							onClick = function()
								StudioUndo.redo()
							end,
						}),
						divider(10),
						button({
							order = 11,
							width = 80,
							text = text("editor.rotateMode"),
							selected = modeSelected("rotate"),
							onClick = function()
								session:setGizmoMode("rotate")
							end,
						}),
						button({
							order = 12,
							width = 80,
							text = text("editor.moveMode"),
							selected = modeSelected("move"),
							onClick = function()
								session:setGizmoMode("move")
							end,
						}),
						divider(13),
						button({
							order = 14,
							width = 100,
							text = text("camera.key"),
							onClick = function()
								if session:keyCameraFromView() then
									notice:set({
										key = "camera.keyed",
										args = { time = string.format("%.2f", session.time) },
									})
								end
							end,
						}),
						button({
							order = 15,
							width = 100,
							text = text("camera.view"),
							selected = scope:Computed(function(use)
								use(sessionTick)
								return session.cameraPreview
							end),
							onClick = function()
								session:setCameraPreview(not session.cameraPreview)
							end,
						}),
					}),
					-- 3. Keyframe editing, then the status message
					row(
						3,
						{
							button({
								order = 1,
								width = 60,
								text = text("editor.copy"),
								onClick = function()
									session:copy()
								end,
							}),
							button({
								order = 2,
								width = 60,
								text = text("editor.paste"),
								onClick = function()
									session:paste()
								end,
							}),
							button({
								order = 3,
								width = 60,
								text = text("editor.delete"),
								onClick = function()
									session:deleteSelectedKeys()
								end,
							}),
							button({
								order = 4,
								width = 70,
								text = text("editor.mirror"),
								onClick = function()
									session:mirror()
								end,
							}),
							divider(5),
							button({
								order = 6,
								width = 170,
								text = easingText,
								onClick = function()
									togglePanel(easingMenu, animationsMenu)
								end,
							}),
							divider(7),
							label(8, 30, text("camera.fovLabel")),
							(function()
								fovBox.LayoutOrder = 9
								return fovBox
							end)(),
						},
						nil,
						scope:New("TextLabel")({
							Position = UDim2.fromOffset(EDIT_GROUP_WIDTH, 0),
							Size = UDim2.new(1, -EDIT_GROUP_WIDTH, 1, 0),
							BackgroundTransparency = 1,
							FontFace = Theme.FONT,
							TextSize = Theme.TEXT_SIZE,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							Text = statusText,
							TextColor3 = color(Enum.StudioStyleGuideColor.DimmedText),
						})
					),
				},
			}),
			timelineHost,
		},
	})

	local timeline = Timeline.mount(timelineHost, session)
	easingMenu = EasingMenu.mount(timelineHost, session, function(key, args)
		notice:set({ key = key, args = args })
	end)
	animationsMenu = AnimationsMenu.mount(timelineHost, session, function(key, args)
		notice:set({ key = key, args = args })
	end)
	importMenu = ImportMenu.mount(timelineHost, {
		importSequence = importSequence,
		notify = function(key, args)
			notice:set({ key = key, args = args })
		end,
	})
	shortcutsMenu = ShortcutsMenu.mount(timelineHost)
	if parent:IsA("PluginGui") then
		track(parent:GetPropertyChangedSignal("Enabled"):Connect(showShortcutsOnce))
	end
	onSelectionChanged()
	updatePicker()
	showShortcutsOnce()

	local handle = {
		session = session,
		notify = function(key: string, args: { [string]: any }?)
			notice:set({ key = key, args = args })
		end,
	}
	function handle.destroy(_self: AppHandle)
		for _, cleanup in cleanups do
			cleanup()
		end
		timeline:destroy()
		if importMenu then
			importMenu:destroy()
		end
		if easingMenu then
			easingMenu:destroy()
		end
		if animationsMenu then
			animationsMenu:destroy()
		end
		if shortcutsMenu then
			shortcutsMenu:destroy()
		end
		picker:destroy()
		gizmo:destroy()
		cameraPath:destroy()
		session:destroy()
		scope:doCleanup()
	end
	return handle :: AppHandle
end

return App
