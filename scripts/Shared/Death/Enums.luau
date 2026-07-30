--!strict
--[[
	Death.Enums
	Shared enum-like tables for the death system. String values so they are stable
	across the network and in state maps.

	Location: ReplicatedStorage.Shared.Death.Enums
]]

local Enums = {}

-- What a downed player can choose to do.
Enums.DeathChoice = table.freeze({
	Lobby = "Lobby", -- leave the run (back to the Kingdom Hub)
	Revive = "Revive", -- pay to revive (anti-P2W) at reduced health
	Wait = "Wait", -- stay down; a teammate may revive, else wait out the run
})

-- A run participant's death status (server-authoritative).
Enums.DeathStatus = table.freeze({
	Alive = "Alive", -- up and fighting
	Down = "Down", -- dead, deciding / spectating
	Waiting = "Waiting", -- chose Wait (eligible for teammate revive / re-formation)
	Left = "Left", -- chose Lobby (out of the run)
})

return table.freeze(Enums)
