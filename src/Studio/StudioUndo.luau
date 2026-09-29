--!strict
-- Puts Animora edits in Studio's own undo history, so Studio's Ctrl+Z / Ctrl+Y (and
-- Edit > Undo) undo Animora edits in order with everything else.
--
-- Each edit is recorded as a Studio waypoint named "Animora: <edit>" that also writes the
-- saved clip into the place. When Studio undoes or redoes a waypoint with that prefix,
-- App calls Session:undo()/redo() to match. Other plugin changes (like an export) must
-- use a different name so they are not mistaken for clip edits.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Storage = require(script.Parent.Storage)

local PREFIX = "Animora: "
local COUNTER_ATTRIBUTE = "EditCount"

local StudioUndo = {}

-- Records an Animora edit as one Studio waypoint. `save` writes the edit into the place
-- (the saved clip); without it a counter attribute is bumped so the waypoint is not empty.
function StudioUndo.record(name: string, save: (() -> ())?)
	local waypoint = PREFIX .. name
	local recording = ChangeHistoryService:TryBeginRecording(waypoint, waypoint)
	if save then
		save()
	else
		local folder = Storage.getFolder()
		folder:SetAttribute(COUNTER_ATTRIBUTE, (tonumber(folder:GetAttribute(COUNTER_ATTRIBUTE)) or 0) + 1)
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		-- Another recording is open (rare): fall back to a plain waypoint.
		ChangeHistoryService:SetWaypoint(waypoint)
	end
end

function StudioUndo.isAnimoraWaypoint(waypoint: string?): boolean
	return waypoint ~= nil and string.sub(waypoint, 1, #PREFIX) == PREFIX
end

-- Same as pressing Ctrl+Z / Ctrl+Y in Studio.
function StudioUndo.undo()
	ChangeHistoryService:Undo()
end

function StudioUndo.redo()
	ChangeHistoryService:Redo()
end

-- Wraps a change that is not a clip edit (e.g. exporting) in its own waypoint.
function StudioUndo.recordOther(name: string, change: () -> ())
	local recording = ChangeHistoryService:TryBeginRecording(name, name)
	change()
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		ChangeHistoryService:SetWaypoint(name)
	end
end

return StudioUndo
