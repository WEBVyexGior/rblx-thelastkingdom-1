--!strict
--[[
	Markers
	Turns a place in the world into a position, whether the config wrote it as
	raw coordinates or as the name of something in the map.

	WHY THIS EXISTS: the Chapter 1 slice hard-coded Vector3s, which was fine for
	three objectives around the origin and is unworkable for a real map. Every
	time a designer nudges a spawn or a landmark, someone has to read numbers off
	the screen and edit a config to match — and the two drift apart the first
	time anyone forgets.

	So a config may now say where something is BY NAME:

		position   = "Area2.Objectives.SurvivorCamp"
		spawnPoint = "Area2.Spawns.North"

	resolved against `workspace.Gameplay`. Place a part, name it, drag it
	anywhere: the game follows it. Level design becomes mouse work rather than
	arithmetic.

	Vector3s still work exactly as before, so nothing that exists breaks and the
	two styles can be mixed while a map is being converted.

	Location: ReplicatedStorage.Shared.World.Markers
]]

local Markers = {}

Markers.ROOT = "Gameplay"

local function pathToInstance(path: string): Instance?
	local root = workspace:FindFirstChild(Markers.ROOT)
	if not root then
		return nil
	end

	local node: Instance? = root
	for segment in string.gmatch(path, "[^%.]+") do
		if not node then
			return nil
		end
		node = node:FindFirstChild(segment)
	end
	return node
end

-- The world position of a marker instance: a part's centre, a model's pivot.
local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	return nil
end

--[[
	Resolves `where` to a position.

	Accepts a Vector3 (used as-is), or a dotted path under `workspace.Gameplay`.
	Returns nil if a named marker is missing, rather than guessing: a spawn that
	silently falls back to the origin drops enemies in the wrong place and looks
	like a gameplay bug rather than a missing part.
]]
function Markers.resolve(where: any): Vector3?
	if typeof(where) == "Vector3" then
		return where
	end
	if type(where) ~= "string" then
		return nil
	end

	local instance = pathToInstance(where)
	if not instance then
		return nil
	end
	return positionOf(instance)
end

-- Same, but with a stated fallback for callers that would rather carry on than
-- stop. Use it only where being slightly wrong is better than not running.
function Markers.resolveOr(where: any, fallback: Vector3): Vector3
	return Markers.resolve(where) or fallback
end

-- The instance itself, for callers that need more than a position — a gate to
-- open, a zone to size a trigger from.
function Markers.find(path: string): Instance?
	return pathToInstance(path)
end

return Markers
