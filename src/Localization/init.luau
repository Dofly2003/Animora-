--!strict
-- Simple string table localization. English is the default and the fallback;
-- a missing key in another language falls back to English, then to the key itself.

export type LanguageCode = "en" | "id"

local Localization = {}

local languages: { [LanguageCode]: { [string]: string } } = {
	en = require(script.en),
	id = require(script.id),
}

Localization.DEFAULT = "en" :: LanguageCode
Localization.SUPPORTED = { "en", "id" } :: { LanguageCode }

local current: LanguageCode = Localization.DEFAULT
local listeners: { (LanguageCode) -> () } = {}

function Localization.getLanguage(): LanguageCode
	return current
end

function Localization.setLanguage(code: string?)
	local nextCode: LanguageCode = if code == "id" then "id" else "en"
	if nextCode == current then
		return
	end
	current = nextCode
	for _, listener in listeners do
		task.spawn(listener, current)
	end
end

-- Returns a function that unsubscribes the listener.
function Localization.onChanged(listener: (LanguageCode) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Looks up a string and fills {name} placeholders from `args`.
function Localization.t(key: string, args: { [string]: any }?): string
	local text = languages[current][key] or languages.en[key] or key
	if args then
		text = string.gsub(text, "{(%w+)}", function(name)
			local value = args[name]
			return if value ~= nil then tostring(value) else "{" .. name .. "}"
		end)
	end
	return text
end

return Localization
