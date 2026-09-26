--!strict
-- Persistent per-user plugin settings (stored by Studio via plugin:SetSetting).

local DEFAULTS: { [string]: any } = {
	language = "en",
	timelineFps = 60,
}

local Settings = {}
Settings.__index = Settings

export type Settings = typeof(setmetatable({} :: { _plugin: Plugin }, Settings))

function Settings.new(pluginRef: Plugin): Settings
	return setmetatable({ _plugin = pluginRef }, Settings)
end

function Settings.get(self: Settings, key: string): any
	local ok, value = pcall(function()
		return self._plugin:GetSetting("Animora." .. key)
	end)
	if ok and value ~= nil then
		return value
	end
	return DEFAULTS[key]
end

function Settings.set(self: Settings, key: string, value: any)
	pcall(function()
		self._plugin:SetSetting("Animora." .. key, value)
	end)
end

return Settings
