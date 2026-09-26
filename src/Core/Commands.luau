--!strict
-- Every edit to a clip goes through a command so it can be undone and redone.
-- Phase 1 task: implement the concrete commands (SetKeyframe, RemoveKeyframe,
-- MoveKeyframes, PastePose, MirrorPose) on top of this history.

export type Command = {
	name: string,
	apply: () -> (),
	revert: () -> (),
}

local History = {}
History.__index = History

export type History = typeof(setmetatable({} :: { _undo: { Command }, _redo: { Command }, _limit: number }, History))

function History.new(limit: number?): History
	return setmetatable({ _undo = {}, _redo = {}, _limit = limit or 200 }, History)
end

function History.execute(self: History, command: Command)
	command.apply()
	table.insert(self._undo, command)
	if #self._undo > self._limit then
		table.remove(self._undo, 1)
	end
	table.clear(self._redo)
end

function History.undo(self: History): Command?
	local command = table.remove(self._undo)
	if command then
		command.revert()
		table.insert(self._redo, command)
	end
	return command
end

function History.redo(self: History): Command?
	local command = table.remove(self._redo)
	if command then
		command.apply()
		table.insert(self._undo, command)
	end
	return command
end

function History.canUndo(self: History): boolean
	return #self._undo > 0
end

function History.canRedo(self: History): boolean
	return #self._redo > 0
end

return {
	History = History,
}
