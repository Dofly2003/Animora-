local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Animora = game:GetService("ReplicatedStorage").Animora
local CameraBake = require(Animora.Core.CameraBake)
local AnimoraCamera = require(Animora.Runtime.AnimoraCamera)

local function makeShot()
	return CameraBake.bake(function(time)
		return CFrame.new(time * 10, 5, 0) * CFrame.Angles(0, time, 0)
	end, function(time)
		return 70 - time * 20
	end, 1, 30, false, CFrame.new(0, 3, 0))
end

describe("CameraBake", function()
	it("bakes one frame per frame of the clip, both ends included", function()
		local shot = makeShot()
		expect(#shot.frames).toBe(31)
		expect(#shot.frames[1]).toBe(13) -- 12 CFrame components + FOV
		expect(shot.frames[31][1]).toBeCloseTo(10, 3)
		expect(shot.frames[31][13]).toBeCloseTo(50, 3)
	end)

	it("writes a module source that loads back to the same data", function()
		local shot = makeShot()
		local source = CameraBake.toSource(shot, "Test")
		local loaded = (loadstring(source) :: any)()
		expect(loaded.version).toBe(CameraBake.VERSION)
		expect(loaded.fps).toBe(30)
		expect(#loaded.frames).toBe(31)
		expect(loaded.frames[16][1]).toBeCloseTo(shot.frames[16][1], 3)
		expect(loaded.root[2]).toBeCloseTo(3, 3)
	end)
end)

describe("AnimoraCamera.sample", function()
	it("blends between baked frames and clamps to the shot", function()
		local shot = makeShot()
		local cframe, fov = AnimoraCamera.sample(shot, 0.5)
		expect(cframe.Position.X).toBeCloseTo(5, 2)
		expect(fov).toBeCloseTo(60, 2)
		local endFrame, endFov = AnimoraCamera.sample(shot, 5)
		expect(endFrame.Position.X).toBeCloseTo(10, 3)
		expect(endFov).toBeCloseTo(50, 3)
	end)
end)
