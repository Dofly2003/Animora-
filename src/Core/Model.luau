--!strict
-- Pure data model for an Animora animation project. No Studio APIs here, so it
-- can be unit-tested outside Studio.

export type EasingStyle =
	"Linear"
	| "Constant"
	| "Sine"
	| "Quad"
	| "Cubic"
	| "Quart"
	| "Quint"
	| "Exponential"
	| "Circular"
	| "Back"
	| "Elastic"
	| "Bounce"

export type EasingDirection = "In" | "Out" | "InOut"

export type Keyframe = {
	time: number, -- seconds from the start of the clip
	value: CFrame, -- joint Transform relative to rest pose
	easingStyle: EasingStyle, -- easing used from this keyframe to the next one
	easingDirection: EasingDirection,
}

export type Track = {
	jointName: string, -- name of the joint's Part1 (e.g. "LeftUpperArm")
	keyframes: { Keyframe }, -- always sorted by time
}

export type Clip = {
	id: string?, -- stable id used to match the saved copy in the place
	name: string,
	length: number, -- seconds
	fps: number,
	looped: boolean,
	priority: Enum.AnimationPriority,
	tracks: { [string]: Track }, -- keyed by jointName
}

local Model = {}

function Model.newClip(name: string, fps: number?): Clip
	return {
		name = name,
		length = 2,
		fps = fps or 60,
		looped = false,
		priority = Enum.AnimationPriority.Action,
		tracks = {},
	}
end

function Model.newKeyframe(
	time: number,
	value: CFrame,
	easingStyle: EasingStyle?,
	easingDirection: EasingDirection?
): Keyframe
	return {
		time = time,
		value = value,
		easingStyle = easingStyle or "Linear",
		easingDirection = easingDirection or "In",
	}
end

function Model.getOrCreateTrack(clip: Clip, jointName: string): Track
	local track = clip.tracks[jointName]
	if not track then
		track = { jointName = jointName, keyframes = {} }
		clip.tracks[jointName] = track
	end
	return track
end

-- Inserts or replaces the keyframe at `keyframe.time`, keeping the list sorted.
function Model.setKeyframe(track: Track, keyframe: Keyframe)
	local keyframes = track.keyframes
	for index, existing in keyframes do
		if math.abs(existing.time - keyframe.time) < 1e-6 then
			keyframes[index] = keyframe
			return
		elseif existing.time > keyframe.time then
			table.insert(keyframes, index, keyframe)
			return
		end
	end
	table.insert(keyframes, keyframe)
end

function Model.removeKeyframe(track: Track, time: number): Keyframe?
	for index, existing in track.keyframes do
		if math.abs(existing.time - time) < 1e-6 then
			return table.remove(track.keyframes, index)
		end
	end
	return nil
end

-- Snaps a time in seconds to the nearest frame of the clip.
function Model.snapToFrame(clip: Clip, time: number): number
	return math.round(time * clip.fps) / clip.fps
end

return Model
