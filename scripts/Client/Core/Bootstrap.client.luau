--!strict
--[[
	Bootstrap (Client)
	The single per-player client entry point (a LocalScript). Waits for the shared
	code to replicate, then hands control to the same Loader the server uses to
	boot every Controller through the Init -> Start lifecycle.

	Location: StarterPlayer.StarterPlayerScripts.Client.Core.Bootstrap
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Guard against a duplicated Client tree booting twice for the same player (a
-- mis-synced place). A clean place never trips this.
if _G.TLK_ClientBooted then
	warn("[Bootstrap] DUPLICATE Client copy detected — aborting the second boot.")
	return
end
_G.TLK_ClientBooted = true

-- Wait for shared code to replicate before requiring it.
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Framework = Shared:WaitForChild("Framework")
local Loader = require(Framework:WaitForChild("Loader"))

-- The "Client" folder is this script's ancestor (Client > Core > Bootstrap).
local clientRoot = script:FindFirstAncestor("Client")
assert(clientRoot, "Client root folder not found")

local roots: { Instance } = { clientRoot:WaitForChild("Controllers") }

Loader.boot(roots, "Client")
