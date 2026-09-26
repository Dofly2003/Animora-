--!strict
-- Saves Animora projects inside the place (ServerStorage.AnimoraSaves) so they
-- travel with the .rbxl and Team Create. Phase 2 task: serialize Clip to
-- attributes / StringValue JSON and load it back.

local ServerStorage = game:GetService("ServerStorage")

local Storage = {}

Storage.FOLDER_NAME = "AnimoraSaves"

function Storage.getFolder(): Folder
	local folder = ServerStorage:FindFirstChild(Storage.FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Storage.FOLDER_NAME
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

return Storage
