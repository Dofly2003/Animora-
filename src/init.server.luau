--!strict
-- Animora plugin entry point: creates the toolbar button and the main dock widget.

local Localization = require(script.Localization)
local Settings = require(script.Studio.Settings)
local App = require(script.UI.App)

local pluginSettings = Settings.new(plugin)
Localization.setLanguage(pluginSettings:get("language"))

local toolbar = plugin:CreateToolbar("Animora")
local toggleButton = toolbar:CreateButton(
	"Animora",
	Localization.t("toolbar.open.tooltip"),
	"" -- TODO: upload the Animora icon and put its rbxassetid:// here
)
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Bottom,
	false, -- initially enabled
	false, -- override previous enabled state
	900, -- default width
	320, -- default height
	600, -- min width
	200 -- min height
)
local widget = plugin:CreateDockWidgetPluginGuiAsync("AnimoraMain", widgetInfo)
widget.Title = "Animora"
widget.Name = "Animora"

local app = App.mount(widget, pluginSettings)

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
end)

plugin.Unloading:Connect(function()
	app:destroy()
end)
