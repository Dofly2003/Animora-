--!strict
-- Blends two camera keyframes so the camera keeps looking at what it was looking at.
--
-- A plain CFrame:Lerp moves the camera along a straight line and turns it separately,
-- so orbiting a character drifts off it mid-move and only "finds" it again at the end.
-- Here each key gets an aim point: the spot on its view line closest to `focus` (the
-- rig's root). The aim point is blended, the camera's offset from it is blended as a
-- direction (arc) plus a distance, and the camera looks at the blended aim point. Two
-- keys that both look at the character therefore keep it centred and orbit around it;
-- keys that look the same way (a dolly or a strafe) still move in a straight line.

local CameraPath = {}

local MIN_AIM_DISTANCE = 0.5 -- studs; closer (or behind the camera) falls back to Lerp

local function slerpDirection(a: Vector3, b: Vector3, t: number): Vector3
	local dot = math.clamp(a:Dot(b), -1, 1)
	local theta = math.acos(dot)
	if theta < 1e-4 or math.pi - theta < 1e-3 then
		local mixed = a:Lerp(b, t)
		return if mixed.Magnitude > 1e-6 then mixed.Unit else a
	end
	local sinTheta = math.sin(theta)
	return a * (math.sin((1 - t) * theta) / sinTheta) + b * (math.sin(t * theta) / sinTheta)
end

function CameraPath.blend(a: CFrame, b: CFrame, t: number, focus: Vector3?): CFrame
	if not focus then
		return a:Lerp(b, t)
	end
	local distanceA = (focus - a.Position):Dot(a.LookVector)
	local distanceB = (focus - b.Position):Dot(b.LookVector)
	if distanceA < MIN_AIM_DISTANCE or distanceB < MIN_AIM_DISTANCE then
		return a:Lerp(b, t)
	end

	local aimA = a.Position + a.LookVector * distanceA
	local aimB = b.Position + b.LookVector * distanceB
	local aim = aimA:Lerp(aimB, t)

	local offsetA, offsetB = a.Position - aimA, b.Position - aimB
	local length = distanceA + (distanceB - distanceA) * t
	local position = aim + slerpDirection(offsetA.Unit, offsetB.Unit, t) * length

	-- Keep the keys' roll by borrowing the up vector of the plain blend.
	local up = a:Lerp(b, t).UpVector
	local look = aim - position
	if look.Magnitude < 1e-6 or math.abs(look.Unit:Dot(up)) > 0.999 then
		return a:Lerp(b, t)
	end
	return CFrame.lookAt(position, aim, up)
end

return CameraPath
