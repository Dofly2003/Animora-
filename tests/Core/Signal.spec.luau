local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Signal = require(game:GetService("ReplicatedStorage").Animora.Core.Signal)

describe("Signal", function()
	it("calls handlers with the fired arguments", function()
		local signal = Signal.new()
		local received = nil
		signal:Connect(function(value)
			received = value
		end)
		signal:Fire("time")
		expect(received).toBe("time")
	end)

	it("stops calling a disconnected handler", function()
		local signal = Signal.new()
		local count = 0
		local connection = signal:Connect(function()
			count += 1
		end)
		signal:Fire()
		connection:Disconnect()
		signal:Fire()
		expect(count).toBe(1)
	end)
end)
