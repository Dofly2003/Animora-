--!strict
-- Puts Animora edits in Studio's own undo history, so Studio's Ctrl+Z / Ctrl+Y (and
-- Edit > Undo) undo Animora edits in order with everything else.
--
-- Each edit is recorded as a Studio waypoint named "Animora: <edit>" that changes a
-- counter attribute on ServerStorage.AnimoraSaves. When Studio undoes or redoes a
-- waypoint with that prefix, App calls Session:undo()/redo() to match.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Storage = require(script.Parent.Storage)

local PREFIX = "Animora: "
local COUNTER_ATTRIBUTE = "EditCount"

local StudioUndo = {}

function StudioUndo.record(name: string)
	local waypoint = PREFIX .. name
	local recording = ChangeHistoryService:TryBeginRecording(waypoint, waypoint)
	local folder = Storage.getFolder()
	folder:SetAttribute(COUNTER_ATTRIBUTE, (tonumber(folder:GetAttribute(COUNTER_ATTRIBUTE)) or 0) + 1)
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

return StudioUndo
