--!strict
-- Minimal synchronous signal: handlers run in connection order when Fire is called.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal = typeof(setmetatable({} :: { _handlers: { (...any) -> () } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	table.insert(self._handlers, handler)
	local connection = {}
	function connection.Disconnect(_self: Connection)
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection :: Connection
end

function Signal.Fire(self: Signal, ...: any)
	-- Clone so handlers may disconnect themselves while firing.
	for _, handler in table.clone(self._handlers) do
		handler(...)
	end
end

function Signal.DisconnectAll(self: Signal)
	table.clear(self._handlers)
end

return Signal
