--!strict
-- Animora plugin entry point: creates the toolbar button and the main dock widget.

local RunGuard = require(script.Studio.RunGuard)

-- Inside a running play test (Play F5 copies the edit place) Animora stays out of the
-- way: undo any preview offsets that were copied in, and do not start the editor.
if RunGuard.isRunning() then
	RunGuard.restoreAll()
	return
end

local Localization = require(script.Localization)
local Version = require(script.Version)
local Settings = require(script.Studio.Settings)
local App = require(script.UI.App)
local Shortcuts = require(script.Studio.Shortcuts)

local pluginSettings = Settings.new(plugin)
Localization.setLanguage(pluginSettings:get("language"))

-- Toolbar icon: assets/icon/icon-64.png uploaded to Roblox (an Image asset ID, not a
-- Decal ID). Regenerate the PNGs with `python scripts/make_icon.py`.
local ICON = "rbxassetid://108366725262430"

local toolbar = plugin:CreateToolbar("Animora")
local toggleButton =
	toolbar:CreateButton("Animora", Localization.t("toolbar.open.tooltip", { version = Version }), ICON)
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

local app = App.mount(widget, pluginSettings, { plugin = plugin })

Shortcuts.register(plugin, widget, function()
	return app.session
end, function(text, ran)
	app.notify(if ran then "shortcut.ran" else "shortcut.needsRig", { name = text })
end)

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
end)

plugin.Unloading:Connect(function()
	app:destroy()
end)
