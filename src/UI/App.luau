--!strict
-- Root UI of the Animora dock widget (Fusion 0.3).
-- Phase 0/1 placeholder: welcome message + language switch. Timeline, Inspector
-- and Toolbar components are added in Phase 2 (see docs/ROADMAP.md).

local Fusion = require(script.Parent.Parent.Packages.Fusion)
local Localization = require(script.Parent.Parent.Localization)
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Parent.Studio.Settings)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local App = {}

export type AppHandle = { destroy: (self: AppHandle) -> () }

function App.mount(parent: Instance, pluginSettings: Settings.Settings): AppHandle
	local scope = Fusion.scoped(Fusion)

	local language = scope:Value(Localization.getLanguage())
	local themeTick = scope:Value(0)

	local unsubscribeLanguage = Localization.onChanged(function(code)
		language:set(code)
	end)
	local themeConnection = Theme.onChanged(function()
		themeTick:set(Fusion.peek(themeTick) + 1)
	end)

	-- Re-evaluates when language or Studio theme changes.
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

	local function languageButton(code: Localization.LanguageCode)
		return scope:New("TextButton")({
			Size = UDim2.fromOffset(140, 28),
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			Text = text("settings.language." .. code),
			TextColor3 = color(Enum.StudioStyleGuideColor.ButtonText),
			BackgroundColor3 = scope:Computed(function(use)
				use(themeTick)
				local selected = use(language) == code
				return Theme.color(
					Enum.StudioStyleGuideColor.Button,
					if selected then Enum.StudioStyleGuideModifier.Selected else nil
				)
			end),
			[OnEvent("Activated")] = function()
				pluginSettings:set("language", code)
				Localization.setLanguage(code)
			end,
		})
	end

	scope:New("Frame")({
		Name = "AnimoraApp",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color(Enum.StudioStyleGuideColor.MainBackground),

		[Children] = {
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.PADDING * 2),
				PaddingLeft = UDim.new(0, Theme.PADDING * 2),
				PaddingRight = UDim.new(0, Theme.PADDING * 2),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.PADDING),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = text("app.welcome.title"),
				TextColor3 = color(Enum.StudioStyleGuideColor.MainText),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = Theme.TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = text("app.welcome.body"),
				TextColor3 = color(Enum.StudioStyleGuideColor.DimmedText),
			}),
			scope:New("Frame")({
				Name = "LanguageRow",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, Theme.PADDING),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromOffset(70, 28),
						BackgroundTransparency = 1,
						FontFace = Theme.FONT,
						TextSize = Theme.TEXT_SIZE,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = text("settings.language"),
						TextColor3 = color(Enum.StudioStyleGuideColor.MainText),
					}),
					languageButton("en"),
					languageButton("id"),
				},
			}),
		},
	})

	local handle = {}
	function handle.destroy(_self: AppHandle)
		unsubscribeLanguage()
		themeConnection:Disconnect()
		scope:doCleanup()
	end
	return handle :: AppHandle
end

return App
