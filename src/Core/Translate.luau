--!strict
-- Moving a joint in the viewport. Part1 = Part0 * rest0 * T * frame1:Inverse(), so moving
-- Part1 by a world-space delta `d` (rotation unchanged) means T' = Translation(v) * T with
-- v = d expressed in the rest frame on Part0: (Part0 * rest0).Rotation:Inverse() * d.

local Translate = {}

function Translate.apply(transform: CFrame, worldDelta: Vector3, part0: CFrame, rest0: CFrame): CFrame
	local inJointFrame = rest0:VectorToObjectSpace(part0:VectorToObjectSpace(worldDelta))
	return CFrame.new(inJointFrame) * transform
end

-- Rounds a drag distance to `step` studs (no rounding when step is 0 or less).
function Translate.snap(distance: number, step: number): number
	if step <= 0 then
		return distance
	end
	return math.round(distance / step) * step
end

return Translate
