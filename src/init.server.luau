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
local Settings = require(script.Studio.Settings)
local App = require(script.UI.App)
local TimelineTest = require(script.UI.TimelineTest)
local Shortcuts = require(script.Studio.Shortcuts)

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

-- Spike B: separate floating widget for the timeline performance test, created on first use.
local timelineTestWidget: DockWidgetPluginGui? = nil
local timelineTest: TimelineTest.Handle? = nil
local function openTimelineTest()
	if not timelineTestWidget then
		local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, true, 1000, 420, 600, 250)
		local testWidget = plugin:CreateDockWidgetPluginGuiAsync("AnimoraTimelineTest", info)
		testWidget.Title = "Animora - Timeline test (Spike B)"
		timelineTestWidget = testWidget
		timelineTest = TimelineTest.mount(testWidget)
	end
	(timelineTestWidget :: DockWidgetPluginGui).Enabled = true
end

local app = App.mount(widget, pluginSettings, { openTimelineTest = openTimelineTest, plugin = plugin })

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
	if timelineTest then
		timelineTest:destroy()
	end
end)
