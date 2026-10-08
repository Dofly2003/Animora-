local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local CameraPath = require(game:GetService("ReplicatedStorage").Animora.Core.CameraPath)

-- How far (in studs) the camera's view line passes from `point`.
local function missDistance(camera: CFrame, point: Vector3): number
	local offset = point - camera.Position
	return (offset - camera.LookVector * offset:Dot(camera.LookVector)).Magnitude
end

describe("CameraPath.blend", function()
	it("keeps looking at the character while orbiting around it", function()
		local focus = Vector3.new(0, 3, 0)
		local a = CFrame.lookAt(Vector3.new(0, 5, 12), focus)
		local b = CFrame.lookAt(Vector3.new(12, 5, 0), focus)
		for _, t in { 0.1, 0.25, 0.5, 0.75, 0.9 } do
			local camera = CameraPath.blend(a, b, t, focus)
			expect(missDistance(camera, focus) < 1e-3).toBe(true)
			-- Orbits at the same distance instead of cutting the corner.
			expect(math.abs((camera.Position - focus).Magnitude - (a.Position - focus).Magnitude) < 1e-3).toBe(true)
		end
	end)

	it("matches the keys at both ends", function()
		local focus = Vector3.new(0, 3, 0)
		local a = CFrame.lookAt(Vector3.new(0, 5, 12), focus)
		local b = CFrame.lookAt(Vector3.new(-8, 6, 6), focus)
		expect(CameraPath.blend(a, b, 0, focus):FuzzyEq(a, 1e-3)).toBe(true)
		expect(CameraPath.blend(a, b, 1, focus):FuzzyEq(b, 1e-3)).toBe(true)
	end)

	it("moves in a straight line for a strafe that does not turn", function()
		local focus = Vector3.new(0, 3, 0)
		local a = CFrame.new(0, 5, 12)
		local b = CFrame.new(6, 5, 12)
		local camera = CameraPath.blend(a, b, 0.5, focus)
		expect(camera:FuzzyEq(a:Lerp(b, 0.5), 1e-3)).toBe(true)
	end)

	it("falls back to a plain blend when the focus is behind the camera", function()
		local focus = Vector3.new(0, 0, 50)
		local a = CFrame.new(0, 5, 12)
		local b = CFrame.lookAt(Vector3.new(6, 5, 12), Vector3.new(6, 5, 0))
		expect(CameraPath.blend(a, b, 0.5, focus):FuzzyEq(a:Lerp(b, 0.5), 1e-4)).toBe(true)
	end)
end)
