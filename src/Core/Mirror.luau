--!strict
-- Left/right mirroring of joint transforms across the rig's YZ plane.

local Mirror = {}

-- Returns the opposite-side joint name ("LeftUpperArm" <-> "RightUpperArm",
-- "Left Arm" <-> "Right Arm"), or the same name for center joints like "Head".
function Mirror.oppositeJoint(jointName: string): string
	if string.find(jointName, "Left") then
		return (string.gsub(jointName, "Left", "Right"))
	elseif string.find(jointName, "Right") then
		return (string.gsub(jointName, "Right", "Left"))
	end
	return jointName
end

-- Mirrors a joint transform across the X axis (negate X position, negate Y/Z rotation).
function Mirror.mirrorTransform(transform: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = transform:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Mirrors a joint Transform onto the opposite joint. Left and right joints can have
-- different rest orientations (R6 shoulders are turned +/-90 degrees), so the
-- transform is moved into the parent part's space, mirrored there, and moved into
-- the opposite joint's space. `fromRest` / `toRest` are the joints' rest C0s.
function Mirror.mirrorJointTransform(transform: CFrame, fromRest: CFrame, toRest: CFrame): CFrame
	local fromRotation = fromRest.Rotation
	local toRotation = toRest.Rotation
	local inParent = fromRotation * transform * fromRotation:Inverse()
	return toRotation:Inverse() * Mirror.mirrorTransform(inParent) * toRotation
end

return Mirror
