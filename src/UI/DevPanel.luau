--!strict
-- Temporary developer panel for the week-1 spikes. Spike C: play a wave on the
-- selected rig in edit mode and report how many frame updates per second arrive.

local Selection = game:GetService("Selection")

local Fusion = require(script.Parent.Parent.Packages.Fusion)
local Localization = require(script.Parent.Parent.Localization)
local Theme = require(script.Parent.Theme)
local RigBinder = require(script.Parent.Parent.Studio.RigBinder)
local Preview = require(script.Parent.Parent.Studio.Preview)
local WaveTest = require(script.Parent.Parent.Dev.WaveTest)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type Status = { key: string, args: { [string]: any }? }

export type Helpers = {
	language: Fusion.Value<Localization.LanguageCode>,
	text: (key: string) -> Fusion.Computed<string>,
	color: (item: Enum.StudioStyleGuideColor) -> Fusion.Computed<Color3>,
}

local DevPanel = {}

function DevPanel.create(scope: Fusion.Scope<typeof(Fusion)>, helpers: Helpers, layoutOrder: number): Frame
	local status = scope:Value({ key = "spike.status.idle" } :: Status)
	local preview: Preview.Preview? = nil

	local function setStatus(key: string, args: { [string]: any }?)
		status:set({ key = key, args = args })
	end

	local function stop()
		if preview then
			preview:stop()
			preview = nil
			setStatus("spike.status.stopped")
		end
	end

	local function startWave(mode: Preview.Mode)
		stop()
		local rig = WaveTest.findRig(Selection:Get()[1])
		if not rig then
			setStatus("spike.status.noRig")
			return
		end
		local binder = RigBinder.new(rig)
		local clip, reason = WaveTest.buildClip(binder)
		if not clip then
			setStatus(reason or "spike.status.noArm")
			return
		end

		local current = Preview.new(binder, mode)
		preview = current
		setStatus("spike.status.playing", { mode = mode, rig = rig.Name, fps = "..." })

		local lastReport = 0
		current:play(clip, function(elapsed)
			if elapsed - lastReport >= 0.5 then
				lastReport = elapsed
				local fps = math.round(current.frameCount / elapsed)
				setStatus("spike.status.playing", { mode = mode, rig = rig.Name, fps = fps })
			end
		end)

		-- If no frame arrived at all, Heartbeat does not run in edit mode: record that as the spike result.
		task.delay(1.5, function()
			if preview == current and current.frameCount == 0 then
				setStatus("spike.status.noUpdates")
			end
		end)
	end

	-- Always put the rig back when the plugin unloads or the UI is destroyed.
	table.insert(scope, function()
		if preview then
			preview:stop()
			preview = nil
		end
	end)

	local function button(key: string, width: number, onClick: () -> ())
		return scope:New("TextButton")({
			Size = UDim2.fromOffset(width, 28),
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			Text = helpers.text(key),
			TextColor3 = helpers.color(Enum.StudioStyleGuideColor.ButtonText),
			BackgroundColor3 = helpers.color(Enum.StudioStyleGuideColor.Button),
			[OnEvent("Activated")] = onClick,
		})
	end

	return scope:New("Frame")({
		Name = "DevPanel",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.PADDING / 2),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				TextSize = Theme.TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = helpers.text("spike.title"),
				TextColor3 = helpers.color(Enum.StudioStyleGuideColor.MainText),
			}),
			scope:New("Frame")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, Theme.PADDING),
					}),
					button("spike.waveTransform", 180, function()
						startWave("Transform")
					end),
					button("spike.waveC0", 150, function()
						startWave("C0")
					end),
					button("spike.stop", 90, stop),
				},
			}),
			scope:New("TextLabel")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = Theme.TEXT_SIZE,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = scope:Computed(function(use)
					use(helpers.language)
					local current = use(status)
					return Localization.t(current.key, current.args)
				end),
				TextColor3 = helpers.color(Enum.StudioStyleGuideColor.DimmedText),
			}),
		},
	})
end

return DevPanel
