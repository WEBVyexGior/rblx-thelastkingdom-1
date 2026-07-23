--!strict
--[[
	Bootstrap (Server)
	The single server entry point. Roblox runs this Script automatically; it then
	hands control to the shared Loader, which boots every Service through the
	Init -> Start lifecycle.

	It loads the shared Services folder plus whichever place-specific folder this
	place happens to contain ("Hub" in Kingdom Hub, "World" in Forgotten Lands).
	The same script therefore works unchanged in both games.

	Location: ServerScriptService.Server.Core.Bootstrap
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Framework.Loader)

-- Ensure the networking layer is initialised before services start (no-op while
-- no remotes are declared, but keeps ordering correct for later phases).
require(ReplicatedStorage.Shared.Net)

local serverRoot = ServerScriptService:WaitForChild("Server")

local roots: { Instance } = { serverRoot:WaitForChild("Services") }

-- Include the place-specific service folder if this place has one.
for _, placeFolderName in { "Hub", "World" } do
	local folder = serverRoot:FindFirstChild(placeFolderName)
	if folder then
		table.insert(roots, folder)
	end
end

Loader.boot(roots, "Server")
