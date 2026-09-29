--!strict
-- Keeps preview poses out of play tests. While editing, Animora offsets joints (Motor6D
-- C0 / Attachment0 CFrame) to show poses and stores each rest value in an
-- "AnimoraRestC0" attribute. If a play test started with those offsets, animations would
-- be applied on top of the preview pose (a doubled pose). This module:
--   * restores every offset joint when the plugin loads inside a running game (Play F5
--     copies the edit place, offsets included), and
--   * in edit mode, releases the edited rig when Run (F8) starts and cleans up again
--     when it stops.

local RunService = game:GetService("RunService")

local REST_ATTRIBUTE = "AnimoraRestC0"

local RunGuard = {}

-- Puts every joint Animora offset back to its rest value. Returns how many were fixed.
function RunGuard.restoreAll(): number
	local fixed = 0
	for _, descendant in workspace:GetDescendants() do
		local rest = descendant:GetAttribute(REST_ATTRIBUTE)
		if typeof(rest) == "CFrame" then
			if descendant:IsA("Motor6D") then
				descendant.C0 = rest
			elseif descendant:IsA("Attachment") then
				descendant.CFrame = rest
			end
			descendant:SetAttribute(REST_ATTRIBUTE, nil)
			fixed += 1
		end
	end
	return fixed
end

function RunGuard.isRunning(): boolean
	return RunService:IsRunning()
end

-- Calls `onRunStart` when a Run (F8) session begins in this DataModel, and cleans up
-- leftover offsets when it ends. Returns a disconnect function.
function RunGuard.watch(onRunStart: () -> ()): () -> ()
	local wasRunning = RunService:IsRunning()
	local connection = RunService.Heartbeat:Connect(function()
		local running = RunService:IsRunning()
		if running == wasRunning then
			return
		end
		wasRunning = running
		if running then
			onRunStart()
		end
		RunGuard.restoreAll()
	end)
	return function()
		connection:Disconnect()
	end
end

return RunGuard
