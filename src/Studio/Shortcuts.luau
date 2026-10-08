--!strict
-- Keyboard shortcuts as Studio Plugin Actions. Plugin panels do not receive key presses
-- directly, so each command is registered with Studio; users assign keys under
-- File > Customize Shortcuts (search "Animora"). Undo/redo need no action: Animora
-- edits are part of Studio's own Ctrl+Z / Ctrl+Y history (see StudioUndo).

local Session = require(script.Parent.Session)

local Shortcuts = {}

type ActionSpec = { id: string, text: string, tip: string, run: (session: Session.Session) -> () }

local ACTIONS: { ActionSpec } = {
	{
		id = "AnimoraPlayPause",
		text = "Animora: Play / Pause",
		tip = "Play or pause the animation",
		run = function(session)
			session:togglePlay()
		end,
	},
	{
		id = "AnimoraNextFrame",
		text = "Animora: Next frame",
		tip = "Move the playhead one frame forward",
		run = function(session)
			session:stepFrame(1)
		end,
	},
	{
		id = "AnimoraPreviousFrame",
		text = "Animora: Previous frame",
		tip = "Move the playhead one frame back",
		run = function(session)
			session:stepFrame(-1)
		end,
	},
	{
		id = "AnimoraNextKeyframe",
		text = "Animora: Next keyframe",
		tip = "Jump to the next keyframe",
		run = function(session)
			session:jumpToKey(1)
		end,
	},
	{
		id = "AnimoraPreviousKeyframe",
		text = "Animora: Previous keyframe",
		tip = "Jump to the previous keyframe",
		run = function(session)
			session:jumpToKey(-1)
		end,
	},
	{
		id = "AnimoraCopy",
		text = "Animora: Copy keyframes",
		tip = "Copy the selected keyframes (or the current pose)",
		run = function(session)
			session:copy()
		end,
	},
	{
		id = "AnimoraPaste",
		text = "Animora: Paste keyframes",
		tip = "Paste copied keyframes at the playhead",
		run = function(session)
			session:paste()
		end,
	},
	{
		id = "AnimoraDeleteKeyframes",
		text = "Animora: Delete keyframes",
		tip = "Delete the selected keyframes",
		run = function(session)
			session:deleteSelectedKeys()
		end,
	},
	{
		id = "AnimoraRotateMode",
		text = "Animora: Rotate mode",
		tip = "Show the rotate rings (R in the viewport)",
		run = function(session)
			session:setGizmoMode("rotate")
		end,
	},
	{
		id = "AnimoraMoveMode",
		text = "Animora: Move mode",
		tip = "Show the move arrows on the root joint (T in the viewport)",
		run = function(session)
			session:setGizmoMode("move")
		end,
	},
	{
		id = "AnimoraMirror",
		text = "Animora: Mirror pose",
		tip = "Mirror the selected joint (or the whole pose) left/right",
		run = function(session)
			session:mirror()
		end,
	},
}

-- Registers every action; they only act while the Animora panel is open. `report` is
-- told which shortcut fired and whether it ran, so the status bar can confirm it.
function Shortcuts.register(
	pluginRef: Plugin,
	widget: PluginGui,
	getSession: () -> Session.Session?,
	report: (text: string, ran: boolean) -> ()
)
	for _, spec in ACTIONS do
		local action = pluginRef:CreatePluginAction(spec.id, spec.text, spec.tip, "", true)
		action.Triggered:Connect(function()
			local session = getSession()
			local canRun = widget.Enabled and session ~= nil and session.rig ~= nil
			if canRun and session then
				spec.run(session)
			end
			report(spec.text, canRun)
		end)
	end
end

return Shortcuts
