--!strict
--[[
	QuestService
	Server-authoritative owner of quest state: which quests a player has accepted,
	their progress, and completion/rewards. Quests span both places (accepted in
	the Hub, progressed in the Forgotten Lands), so state is server-side and
	persisted via DataService.

	Responsibilities (future phases):
	- Track accepted quests and objective progress per player.
	- Validate progress events coming from gameplay systems.
	- Grant rewards on completion (through Inventory/Economy).

	Place: shared.
	Phase: Quests / Progression. NO quest logic is implemented in Phase 1 by design.
	Status: skeleton.
]]

local QuestService = {}

QuestService.Name = "QuestService"

function QuestService.Init()
	-- Reserved. No logic in Phase 1.
end

function QuestService.Start()
	-- Reserved. No logic in Phase 1.
end

return QuestService
