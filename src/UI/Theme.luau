--!strict
-- Reads colors from the current Studio theme so Animora matches light and dark mode.

local Theme = {}

local function studioTheme(): StudioTheme
	return (settings() :: any).Studio.Theme
end

function Theme.color(
	item: Enum.StudioStyleGuideColor,
	modifier: Enum.StudioStyleGuideModifier?
): Color3
	return studioTheme():GetColor(item, modifier or Enum.StudioStyleGuideModifier.Default)
end

-- Fires when the user switches Studio between light and dark theme.
function Theme.onChanged(callback: () -> ()): RBXScriptConnection
	return (settings() :: any).Studio.ThemeChanged:Connect(callback)
end

Theme.FONT = Font.fromEnum(Enum.Font.BuilderSans)
Theme.TEXT_SIZE = 14
Theme.PADDING = 8

return Theme
