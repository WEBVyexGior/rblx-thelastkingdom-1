--!strict
--[[
	Config: Waves
	GLOBAL tuning for the Wave System — defaults shared by all encounters. Per-encounter
	fields in `configs/Encounters.luau` override these. Specific encounter content lives
	there, not here.

	Read via: Config.get("Waves")
]]

local Waves = {
	-- Applied by the WaveService unless an encounter overrides them.
	Defaults = {
		RestBetweenWavesSeconds = 2, -- pause between sequential waves
	},
}

return table.freeze(Waves)
