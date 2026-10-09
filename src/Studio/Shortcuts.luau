--!strict
-- Keyboard shortcuts. Plugin panels do not receive key presses directly, so there are two
-- ways in:
--   * Viewport keys (`key`): work right away while the viewport has focus and the panel
--     is open (Space, Z C [ ] M R T). Read by App from the plugin mouse.
--   * Studio Plugin Actions: every command is registered with Studio; users assign their
--     own keys under File > Customize Shortcuts (search "Animora"). Copy / paste / delete
--     have no viewport key because Ctrl+C / Ctrl+V / Delete act on Studio's selection.
-- Undo/redo need neither: Animora edits are part of Studio's Ctrl+Z / Ctrl+Y history.

local Session = require(script.Parent.Session)

local Shortcuts = {}

export type ActionSpec = {
	id: string,
	-- Name in File > Customize Shortcuts (Studio shows it as is, so it stays English).
	text: string,
	tip: string,
	-- Character from PluginMouse.KeyDown that runs the action in the viewport.
	key: string?,
	-- How the viewport key or a suggested Customize Shortcuts binding is written.
	keyLabel: string?,
	suggested: string?,
	run: (session: Session.Session) -> (),
}

Shortcuts.ACTIONS = {
	{
		id = "AnimoraPlayPause",
		text = "Animora: Play / Pause",
		tip = "Play or pause the animation",
		key = " ",
		keyLabel = "Space",
		run = function(session)
			session:togglePlay()
		end,
	},
	{
		id = "AnimoraPreviousFrame",
		text = "Animora: Previous frame",
		tip = "Move the playhead one frame back",
		key = "z",
		keyLabel = "Z",
		run = function(session)
			session:stepFrame(-1)
		end,
	},
	{
		id = "AnimoraNextFrame",
		text = "Animora: Next frame",
		tip = "Move the playhead one frame forward",
		key = "c",
		keyLabel = "C",
		run = function(session)
			session:stepFrame(1)
		end,
	},
	{
		id = "AnimoraPreviousKeyframe",
		text = "Animora: Previous keyframe",
		tip = "Jump to the previous keyframe",
		key = "[",
		keyLabel = "[",
		run = function(session)
			session:jumpToKey(-1)
		end,
	},
	{
		id = "AnimoraNextKeyframe",
		text = "Animora: Next keyframe",
		tip = "Jump to the next keyframe",
		key = "]",
		keyLabel = "]",
		run = function(session)
			session:jumpToKey(1)
		end,
	},
	{
		id = "AnimoraRotateMode",
		text = "Animora: Rotate mode",
		tip = "Show the rotate rings (R in the viewport)",
		key = "r",
		keyLabel = "R",
		run = function(session)
			session:setGizmoMode("rotate")
		end,
	},
	{
		id = "AnimoraMoveMode",
		text = "Animora: Move mode",
		tip = "Show the move arrows on the root joint (T in the viewport)",
		key = "t",
		keyLabel = "T",
		run = function(session)
			session:setGizmoMode("move")
		end,
	},
	{
		id = "AnimoraMirror",
		text = "Animora: Mirror pose",
		tip = "Mirror the selected joint (or the whole pose) left/right",
		key = "m",
		keyLabel = "M",
		run = function(session)
			session:mirror()
		end,
	},
	{
		id = "AnimoraCopy",
		text = "Animora: Copy keyframes",
		tip = "Copy the selected keyframes (or the current pose)",
		suggested = "Alt+C",
		run = function(session)
			session:copy()
		end,
	},
	{
		id = "AnimoraPaste",
		text = "Animora: Paste keyframes",
		tip = "Paste copied keyframes at the playhead",
		suggested = "Alt+V",
		run = function(session)
			session:paste()
		end,
	},
	{
		id = "AnimoraDeleteKeyframes",
		text = "Animora: Delete keyframes",
		tip = "Delete the selected keyframes",
		suggested = "Alt+D",
		run = function(session)
			session:deleteSelectedKeys()
		end,
	},
} :: { ActionSpec }

-- A key bound in Customize Shortcuts that is also a viewport key fires both paths for one
-- press; running it twice would undo toggles (play, mirror), so repeats this close together
-- are dropped.
local REPEAT_WINDOW = 0.15
local lastRun: { [string]: number } = {}

local function runOnce(spec: ActionSpec, session: Session.Session)
	local now = os.clock()
	local last = lastRun[spec.id]
	if last and now - last < REPEAT_WINDOW then
		return
	end
	lastRun[spec.id] = now
	spec.run(session)
end

-- Runs the action bound to a viewport key; returns false when no action uses that key.
function Shortcuts.handleKey(key: string, session: Session.Session): boolean
	for _, spec in Shortcuts.ACTIONS do
		if spec.key == key then
			runOnce(spec, session)
			return true
		end
	end
	return false
end

-- Registers every action; they only act while the Animora panel is open. `report` is
-- told which shortcut fired and whether it ran, so the status bar can confirm it.
function Shortcuts.register(
	pluginRef: Plugin,
	widget: PluginGui,
	getSession: () -> Session.Session?,
	report: (text: string, ran: boolean) -> ()
)
	for _, spec in Shortcuts.ACTIONS do
		local action = pluginRef:CreatePluginAction(spec.id, spec.text, spec.tip, "", true)
		action.Triggered:Connect(function()
			local session = getSession()
			local canRun = widget.Enabled and session ~= nil and session.rig ~= nil
			if canRun and session then
				runOnce(spec, session)
			end
			report(spec.text, canRun)
		end)
	end
end

return Shortcuts
