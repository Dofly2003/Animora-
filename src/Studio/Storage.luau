--!strict
-- Keeps Animora work inside the place so it travels with the .rbxl and Team Create:
--   ServerStorage.AnimoraSaves.Rigs.<rig name>  Folder per rig with an ObjectValue
--                                               "Rig" (points at the rig, survives
--                                               renames) and an "Animations" folder
--                                               holding one StringValue (JSON) per
--                                               animation
--   ServerStorage.RBX_ANIMSAVES.<rig name>      exported KeyframeSequences; the built-in
--                                               Animation Editor lists and publishes them

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Model = require(script.Parent.Parent.Core.Model)
local Serialize = require(script.Parent.Parent.Core.Serialize)

local Storage = {}

Storage.FOLDER_NAME = "AnimoraSaves"
Storage.CAMERA_FOLDER = "AnimoraCameras" -- ReplicatedStorage folder of exported camera shots
Storage.CAMERA_PLAYER = "AnimoraCamera" -- ReplicatedStorage module that plays them
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

local ID_ATTRIBUTE = "AnimoraId"

-- The save folder for `rig`, created on demand.
local function getOrCreateRigSave(rig: Model): Folder
	local save = findRigSave(rig)
	if save then
		return save
	end
	local newSave = Instance.new("Folder")
	newSave.Name = rig.Name
	local link = Instance.new("ObjectValue")
	link.Name = "Rig"
	link.Value = rig
	link.Parent = newSave
	newSave.Parent = getOrCreateFolder(Storage.getFolder(), "Rigs")
	return newSave
end

-- Writes all of the rig's animations: one StringValue (JSON) per animation inside
-- <save>.Animations, named after the animation and matched by its id attribute.
-- Animations no longer in `clips` are removed.
function Storage.saveClips(rig: Model, clips: { Model.Clip })
	local save = getOrCreateRigSave(rig)
	local folder = getOrCreateFolder(save, "Animations")
	local existing: { [string]: StringValue } = {}
	for _, child in folder:GetChildren() do
		local id = child:GetAttribute(ID_ATTRIBUTE)
		if child:IsA("StringValue") and type(id) == "string" then
			existing[id] = child
		end
	end
	local kept: { [StringValue]: boolean } = {}
	for index, clip in clips do
		local id = clip.id or clip.name
		local value = existing[id]
		if not value then
			local newValue = Instance.new("StringValue")
			newValue:SetAttribute(ID_ATTRIBUTE, id)
			newValue.Parent = folder
			value = newValue
		end
		local stringValue = value :: StringValue
		stringValue.Name = clip.name
		stringValue:SetAttribute("Order", index)
		local json = HttpService:JSONEncode(Serialize.encodeClip(clip))
		if stringValue.Value ~= json then
			stringValue.Value = json
		end
		kept[stringValue] = true
	end
	for _, value in existing do
		if not kept[value] then
			value:Destroy()
		end
	end
	-- Older Animora versions kept a single "Clip" value; it now lives in Animations.
	local legacy = save:FindFirstChild("Clip")
	if legacy then
		legacy:Destroy()
	end
end

local function decodeValue(rig: Model, value: StringValue): Model.Clip?
	if value.Value == "" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok then
		warn("[Animora] Could not read saved animation " .. value.Name .. " of " .. rig.Name .. ": " .. tostring(data))
		return nil
	end
	return Serialize.decodeClip(data)
end

-- The rig's saved animations in list order (empty when there are none).
function Storage.loadClips(rig: Model): { Model.Clip }
	local clips: { Model.Clip } = {}
	local save = findRigSave(rig)
	if not save then
		return clips
	end
	local folder = save:FindFirstChild("Animations")
	if folder then
		local values: { StringValue } = {}
		for _, child in folder:GetChildren() do
			if child:IsA("StringValue") then
				table.insert(values, child)
			end
		end
		table.sort(values, function(a, b)
			return (tonumber(a:GetAttribute("Order")) or 0) < (tonumber(b:GetAttribute("Order")) or 0)
		end)
		for _, value in values do
			local clip = decodeValue(rig, value)
			if clip then
				local id = value:GetAttribute(ID_ATTRIBUTE)
				clip.id = if type(id) == "string" then id else clip.id
				table.insert(clips, clip)
			end
		end
	end
	-- Single clip saved by an older Animora version.
	local legacy = save:FindFirstChild("Clip")
	if #clips == 0 and legacy and legacy:IsA("StringValue") then
		local clip = decodeValue(rig, legacy)
		if clip then
			clip.name = "Animation"
			table.insert(clips, clip)
		end
	end
	return clips
end

-- Copies the AnimoraCamera player module into ReplicatedStorage, replacing an older copy.
function Storage.installCameraPlayer(): ModuleScript
	local template = script.Parent.Parent.Runtime.AnimoraCamera :: ModuleScript
	local existing = ReplicatedStorage:FindFirstChild(Storage.CAMERA_PLAYER)
	if existing and existing:IsA("ModuleScript") and existing.Source == template.Source then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local copy = template:Clone()
	copy.Name = Storage.CAMERA_PLAYER
	copy.Parent = ReplicatedStorage
	return copy
end

-- Writes an exported camera shot as ReplicatedStorage.AnimoraCameras.<name> (replacing
-- an older export with that name) and makes sure the player module is there too.
function Storage.placeCameraExport(name: string, source: string): (ModuleScript, string)
	local folder = getOrCreateFolder(ReplicatedStorage, Storage.CAMERA_FOLDER)
	local module = folder:FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then
		if module then
			module:Destroy()
		end
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Parent = folder
	end
	(module :: ModuleScript).Source = source
	Storage.installCameraPlayer()
	return module :: ModuleScript, string.format("ReplicatedStorage > %s > %s", Storage.CAMERA_FOLDER, name)
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
