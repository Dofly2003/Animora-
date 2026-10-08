local JestGlobals = require(game:GetService("ReplicatedStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Animora = game:GetService("ReplicatedStorage").Animora
local Session = require(Animora.Studio.Session)
local CameraPathView = require(Animora.Studio.CameraPathView)
local Model = require(Animora.Core.Model)

local function makeRig(): Model
	local model = Instance.new("Model")
	model.Name = "PathRig"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Parent = model
	local motor = Instance.new("Motor6D")
	motor.Part0 = root
	motor.Part1 = torso
	motor.Parent = root
	model.Parent = workspace
	return model
end

local function visible(folder: Instance, className: string): number
	local count = 0
	for _, item in folder:GetChildren() do
		if item:IsA(className) and (item :: any).Visible then
			count += 1
		end
	end
	return count
end

describe("CameraPathView", function()
	it("draws the path, one camera per key and the playhead dot", function()
		local rig = makeRig()
		local session = Session.new()
		session:setRig(rig)
		local view = CameraPathView.new(session)
		expect(visible(view.folder, "BoxHandleAdornment")).toBe(0) -- no camera keys yet

		session:setTime(0)
		session:commitJoint(Model.CAMERA_TRACK, CFrame.new(0, 5, 12))
		session:setTime(1)
		session:commitJoint(Model.CAMERA_TRACK, CFrame.new(8, 5, 12))

		expect(visible(view.folder, "BoxHandleAdornment")).toBe(2)
		expect(visible(view.folder, "CylinderHandleAdornment") > 2).toBe(true) -- path + lenses
		expect(visible(view.folder, "SphereHandleAdornment")).toBe(1)

		-- Looking through the camera hides the drawing.
		local camera = workspace.CurrentCamera
		local original, originalFov = camera.CFrame, camera.FieldOfView
		session:setCameraPreview(true)
		expect(visible(view.folder, "BoxHandleAdornment")).toBe(0)
		session:setCameraPreview(false)
		camera.CFrame, camera.FieldOfView = original, originalFov
		expect(visible(view.folder, "BoxHandleAdornment")).toBe(2)

		view:destroy()
		session:destroy()
		rig:Destroy()
	end)
end)
