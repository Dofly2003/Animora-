--!strict
-- AnimoraCamera: plays camera shots exported by the Animora plugin. Copied into
-- ReplicatedStorage by Animora's Export; require it from a LocalScript.
--
--   local AnimoraCamera = require(game.ReplicatedStorage.AnimoraCamera)
--   local shot = require(game.ReplicatedStorage.AnimoraCameras.ColdOpen)
--   local playing = AnimoraCamera.play(shot)       -- returns a handle
--   playing:Wait()                                 -- yields until the shot ends
--
-- Options (all optional): AnimoraCamera.play(shot, {
--   origin = CFrame,      play the shot around this CFrame instead of where it was made
--                         (pass the character's HumanoidRootPart.CFrame, for example)
--   speed = 1,            playback speed
--   restore = true,       give the camera back to the player's character when it ends
--   onEnded = function,   called when the shot ends or is stopped
-- })
-- handle:Stop() ends a shot early (also needed for looped shots).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnimoraCamera = {}

local playCount = 0

export type Shot = {
	version: number,
	fps: number,
	length: number,
	looped: boolean,
	root: { number },
	frames: { { number } },
}

export type Options = {
	origin: CFrame?,
	speed: number?,
	restore: boolean?,
	onEnded: (() -> ())?,
}

export type Handle = {
	playing: boolean,
	Stop: (self: Handle) -> (),
	Wait: (self: Handle) -> (),
}

local function frameCFrame(frame: { number }): CFrame
	return CFrame.new(
		frame[1],
		frame[2],
		frame[3],
		frame[4],
		frame[5],
		frame[6],
		frame[7],
		frame[8],
		frame[9],
		frame[10],
		frame[11],
		frame[12]
	)
end

-- The camera CFrame and FOV of `shot` at `time` seconds (blending baked frames).
function AnimoraCamera.sample(shot: Shot, time: number): (CFrame, number)
	local frames = shot.frames
	local position = math.clamp(time, 0, shot.length) * shot.fps
	local index = math.min(math.floor(position) + 1, #frames)
	local nextIndex = math.min(index + 1, #frames)
	local alpha = position - math.floor(position)
	local from, to = frames[index], frames[nextIndex]
	local cframe = frameCFrame(from):Lerp(frameCFrame(to), alpha)
	local fov = from[13] + (to[13] - from[13]) * alpha
	return cframe, fov
end

-- The local player's Humanoid, waiting (up to 10 s) for the character to spawn: a shot
-- started before that would be overridden by Roblox's camera taking over the new body.
local function waitForHumanoid(): Humanoid?
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("Humanoid", 10) :: Humanoid?
end

function AnimoraCamera.play(shot: Shot, options: Options?): Handle
	assert(type(shot) == "table" and shot.frames and #shot.frames > 0, "AnimoraCamera.play: not an Animora camera shot")
	local settings: Options = options or {}
	local humanoid = waitForHumanoid()
	local camera = workspace.CurrentCamera
	local previousFov = camera.FieldOfView
	-- Re-centre the shot on `origin`: frames were made relative to the rig's root.
	local offset = if settings.origin then settings.origin * frameCFrame(shot.root):Inverse() else nil
	local speed = settings.speed or 1
	local elapsed = 0
	playCount += 1
	-- Runs right after Roblox's camera scripts each frame, so the shot always wins.
	local bindName = "AnimoraCamera" .. playCount

	local handle = { playing = true } :: Handle

	local function apply(time: number)
		local cframe, fov = AnimoraCamera.sample(shot, time)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = if offset then offset * cframe else cframe
		camera.FieldOfView = math.clamp(fov, 1, 120)
	end

	local function finish()
		if not handle.playing then
			return
		end
		handle.playing = false
		RunService:UnbindFromRenderStep(bindName)
		if settings.restore ~= false then
			-- Back to the normal player camera (not the state before the shot, which may be
			-- the Fixed camera Roblox uses before the character has spawned).
			camera.CameraType = Enum.CameraType.Custom
			if humanoid and humanoid.Parent then
				camera.CameraSubject = humanoid
			end
			camera.FieldOfView = previousFov
		end
		if settings.onEnded then
			task.spawn(settings.onEnded)
		end
	end

	function handle.Stop(_self: Handle)
		finish()
	end

	function handle.Wait(_self: Handle)
		while handle.playing do
			RunService.RenderStepped:Wait()
		end
	end

	apply(0)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
		elapsed += deltaTime * speed
		if elapsed >= shot.length and not shot.looped then
			apply(shot.length)
			finish()
		else
			apply(if shot.looped and shot.length > 0 then elapsed % shot.length else elapsed)
		end
	end)
	return handle
end

return AnimoraCamera
