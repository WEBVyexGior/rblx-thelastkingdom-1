--!strict
--[[
	Net
	Central registry and factory for networking objects (RemoteEvents /
	RemoteFunctions). This is the single contract shared by client and server so
	remotes are never created ad-hoc or looked up by hard-coded path.

	How it works:
		- Remotes are DECLARED by name in the lists below.
		- On the server, the declared remotes are created under a single
		  ReplicatedStorage.Remotes folder at require time.
		- Client and server both fetch a remote via `Net.getEvent(name)` /
		  `Net.getFunction(name)`, which resolves it from that folder.

	Phase 1 declares ZERO remotes on purpose: nothing in the current architecture
	needs one yet, and we do not create unnecessary instances. Each later feature
	adds its remote name here (and only here), and the server validates every
	incoming call — clients send intent, the server decides.

	Location: ReplicatedStorage.Shared.Net
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

-- Declare remote names here as the architecture grows. Empty by design.
local EVENT_NAMES: { string } = {}
local FUNCTION_NAMES: { string } = {}

local Net = {}

local function getFolder(): Instance?
	if IS_SERVER then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:FindFirstChild(FOLDER_NAME)
end

-- Build declared remotes on the server. Skipped entirely when nothing is
-- declared, so Phase 1 creates no instances at all.
if IS_SERVER and (#EVENT_NAMES > 0 or #FUNCTION_NAMES > 0) then
	local folder = getFolder()
	if folder then
		for _, name in EVENT_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
		for _, name in FUNCTION_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteFunction")
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
end

function Net.getEvent(name: string): RemoteEvent
	local folder = getFolder()
	assert(folder, "Remotes folder is not available")
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "Missing RemoteEvent: " .. name)
	return remote
end

function Net.getFunction(name: string): RemoteFunction
	local folder = getFolder()
	assert(folder, "Remotes folder is not available")
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteFunction"), "Missing RemoteFunction: " .. name)
	return remote
end

return Net
