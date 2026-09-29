--!strict
-- Keeps Animora work inside the place so it travels with the .rbxl and Team Create:
--   ServerStorage.AnimoraSaves.Rigs.<rig name>  Folder per rig with an ObjectValue
--                                               "Rig" (points at the rig, survives
--                                               renames) and a StringValue "Clip" (JSON)
--   ServerStorage.RBX_ANIMSAVES.<rig name>      exported KeyframeSequences; the built-in
--                                               Animation Editor lists and publishes them

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Model = require(script.Parent.Parent.Core.Model)
local Serialize = require(script.Parent.Parent.Core.Serialize)

local Storage = {}

Storage.FOLDER_NAME = "AnimoraSaves"
Storage.ANIMATION_EDITOR_FOLDER = "RBX_ANIMSAVES"

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder :: Folder
end

function Storage.getFolder(): Folder
	return getOrCreateFolder(ServerStorage, Storage.FOLDER_NAME)
end

-- ServerStorage.AnimoraSaves.Exports: used by the week-1 spike export button.
function Storage.getExportsFolder(): Folder
	return getOrCreateFolder(Storage.getFolder(), "Exports")
end

-- The save folder whose "Rig" ObjectValue points at `rig`.
local function findRigSave(rig: Model): Folder?
	local saves = ServerStorage:FindFirstChild(Storage.FOLDER_NAME)
	local rigs = saves and saves:FindFirstChild("Rigs")
	if not rigs then
		return nil
	end
	for _, child in rigs:GetChildren() do
		local link = child:FindFirstChild("Rig")
		if child:IsA("Folder") and link and link:IsA("ObjectValue") and link.Value == rig then
			return child
		end
	end
	return nil
end

-- Writes the rig's clip as JSON (creating its save folder on first save).
function Storage.saveClip(rig: Model, clip: Model.Clip)
	local save = findRigSave(rig)
	if not save then
		local newSave = Instance.new("Folder")
		newSave.Name = rig.Name
		local link = Instance.new("ObjectValue")
		link.Name = "Rig"
		link.Value = rig
		link.Parent = newSave
		newSave.Parent = getOrCreateFolder(Storage.getFolder(), "Rigs")
		save = newSave
	end
	local folder = save :: Folder
	local value = folder:FindFirstChild("Clip") :: StringValue?
	if not value then
		local newValue = Instance.new("StringValue")
		newValue.Name = "Clip"
		newValue.Parent = folder
		value = newValue
	end
	local json = HttpService:JSONEncode(Serialize.encodeClip(clip));
	(value :: StringValue).Value = json
end

-- The saved clip for `rig`, or nil when there is none (or it cannot be read).
function Storage.loadClip(rig: Model): Model.Clip?
	local save = findRigSave(rig)
	local value = save and save:FindFirstChild("Clip")
	if not (value and value:IsA("StringValue") and value.Value ~= "") then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok then
		warn("[Animora] Could not read the saved clip for " .. rig.Name .. ": " .. tostring(data))
		return nil
	end
	return Serialize.decodeClip(data)
end

-- Puts an exported KeyframeSequence where the Animation Editor finds it
-- (RBX_ANIMSAVES.<rig name>), replacing an older export with the same name.
function Storage.placeExport(rig: Model, sequence: KeyframeSequence): string
	local animSaves = getOrCreateFolder(ServerStorage, Storage.ANIMATION_EDITOR_FOLDER)
	local rigFolder = getOrCreateFolder(animSaves, rig.Name)
	local existing = rigFolder:FindFirstChild(sequence.Name)
	if existing and existing:IsA("KeyframeSequence") then
		existing:Destroy()
	end
	sequence.Parent = rigFolder
	return string.format("ServerStorage > %s > %s > %s", Storage.ANIMATION_EDITOR_FOLDER, rig.Name, sequence.Name)
end

return Storage
