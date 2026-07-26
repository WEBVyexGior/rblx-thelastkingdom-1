--!strict
--[[
	ChapterOneSliceFlow (domain)
	The PURE state-machine definition for the Chapter 1 vertical slice: the ordered
	states and their legal single-step transitions. No Roblox instances, no side
	effects — so it is unit-testable in isolation (see Tests.ChapterOneSliceFlow.spec).

	`ChapterOneSliceService` orchestrates the real systems; this module owns only the
	"what may follow what" rules it validates each transition against.

	Sequence: Intro -> Exploring -> Lore -> Objective -> Encounter -> Reward -> Ended

	Location: ServerScriptService.Server.Domain.ChapterOneSliceFlow
]]

local ChapterOneSliceFlow = {}

local STATES = {
	Intro = "Intro",
	Exploring = "Exploring",
	Lore = "Lore",
	Objective = "Objective",
	Encounter = "Encounter",
	Reward = "Reward",
	Ended = "Ended",
}

-- The linear slice sequence (source of the single-step transition table below).
local ORDER: { string } = {
	STATES.Intro,
	STATES.Exploring,
	STATES.Lore,
	STATES.Objective,
	STATES.Encounter,
	STATES.Reward,
	STATES.Ended,
}

-- Each state may advance only to the next state in ORDER; Ended has none (terminal).
local NEXT: { [string]: string? } = {}
for i, state in ORDER do
	NEXT[state] = ORDER[i + 1]
end

ChapterOneSliceFlow.States = STATES
ChapterOneSliceFlow.Order = ORDER

-- The state that legally follows `state`, or nil if terminal / unknown.
function ChapterOneSliceFlow.next(state: string): string?
	return NEXT[state]
end

-- True only for the single legal forward step `from` -> `to`.
function ChapterOneSliceFlow.canAdvance(from: string, to: string): boolean
	return NEXT[from] == to
end

function ChapterOneSliceFlow.isTerminal(state: string): boolean
	return state == STATES.Ended
end

return ChapterOneSliceFlow
