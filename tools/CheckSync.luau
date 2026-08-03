--[[
	CheckSync — run in the Studio Command Bar, in EDIT MODE.
	Select the whole file (Ctrl+A), copy, paste, Enter. It CHANGES NOTHING.

	Answers one question: does the code INSIDE THIS PLACE match the code on
	disk?

	--------------------------------------------------------------------------
	WHY THIS EXISTS

	A test suite that reports the same number twice after a change is not
	telling you the change failed — it is telling you the change never
	arrived. The Rojo server can be healthy, serving the right project, with
	the right bytes in its tree, and the place can still be running last
	week's code because the Studio plugin quietly dropped its socket.

	Guessing which of those it is wastes a round trip every time. This reads
	the actual `Source` of the actual instances and says which.

	It looks for FINGERPRINTS: short strings that only exist in the current
	version of a file. Update the list below whenever you want to prove a new
	change landed.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
--[[
	Each entry: where the instance is, and a string that only appears in the
	CURRENT version of it.

	The path is a LIST of segments, not a dotted string. It has to be: the
	spec files are named `EnemyBrain.spec`, with a dot IN the name, and a
	dotted-path parser splits that into "EnemyBrain" then "spec" and reports a
	perfectly healthy file as missing. That is exactly what the first run of
	this tool did.
]]
local FINGERPRINTS = {
	{
		path = { "TestService", "Tests", "EnemyBrain.spec" },
		needle = "Reposition HOLDS inside the hysteresis band",
		why = "the 11 new ranged-AI specs",
	},
	{
		path = { "ServerScriptService", "Server", "Domain", "AI", "EnemyBrain" },
		needle = "BACKOFF_HYSTERESIS",
		why = "the Reposition state",
	},
	{
		path = { "ServerScriptService", "Server", "World", "ProjectileService" },
		needle = "traced, travelling projectile",
		why = "arrows that travel",
	},
	{
		path = { "ServerScriptService", "Server", "World", "EnemyAIService" },
		needle = "nearestHostile",
		why = "faction-based targeting",
	},
	{
		path = { "ReplicatedStorage", "Config", "Enemies" },
		needle = "undead_archer",
		why = "the undead roster",
	},
	{
		path = { "ReplicatedStorage", "Config", "Difficulty" },
		needle = "EnemyDamageMult",
		why = "the per-area curve",
	},
}

--==========================================================================
local function resolve(path: { string }): Instance?
	local node: Instance? = game
	for _, segment in ipairs(path) do
		if not node then
			return nil
		end
		node = node:FindFirstChild(segment)
	end
	return node
end

local function line(s: string)
	print(s)
end

line("")
line("========================= SYNC CHECK =========================")
line("Does this PLACE have the code that is on DISK?")
line("")

local missing, stale, fresh = 0, 0, 0

for _, entry in ipairs(FINGERPRINTS) do
	local node = resolve(entry.path)
	local shortName = entry.path[#entry.path]

	if not node then
		missing += 1
		line(("  MISSING   %-22s  the instance is not in this place at all"):format(shortName))
	elseif not node:IsA("LuaSourceContainer") then
		missing += 1
		line(("  WRONG     %-22s  found, but it is a %s"):format(shortName, node.ClassName))
	else
		--[[
			`Source` is readable from the command bar because that runs with
			plugin security. It is NOT readable from a normal script, which is
			why this is a tool and not a service.
		]]
		local ok, src = pcall(function()
			return (node :: any).Source
		end)
		if not ok or type(src) ~= "string" then
			line(("  ?         %-22s  could not read Source"):format(shortName))
		elseif string.find(src, entry.needle, 1, true) then
			fresh += 1
			line(("  OK        %-22s  has %s"):format(shortName, entry.why))
		else
			stale += 1
			line(("  STALE     %-22s  MISSING %s"):format(shortName, entry.why))
		end
	end
end

--==========================================================================
-- Duplicates. A place synced from two projects boots everything twice and
-- the TestRunner can end up requiring whichever copy it reaches first.
--==========================================================================
line("")
line("--- DUPLICATES ----------------------------------------------")
do
	local function countNamed(root: Instance, name: string): number
		local n = 0
		for _, d in ipairs(root:GetDescendants()) do
			if d.Name == name then
				n += 1
			end
		end
		return n
	end

	local checks = {
		{ root = game:GetService("TestService"), name = "TestRunner" },
		{ root = game:GetService("TestService"), name = "EnemyBrain.spec" },
		{ root = game:GetService("ServerScriptService"), name = "Server" },
		{ root = game:GetService("ServerScriptService"), name = "EnemyBrain" },
		{ root = game:GetService("ReplicatedStorage"), name = "Shared" },
	}
	local anyDupes = false
	for _, c in ipairs(checks) do
		local n = countNamed(c.root, c.name)
		if n > 1 then
			anyDupes = true
			line(("  %d copies of %s under %s  <- this is a problem"):format(n, c.name, c.root.Name))
		elseif n == 0 then
			line(("  0 copies of %s under %s  <- missing"):format(c.name, c.root.Name))
		end
	end
	if not anyDupes then
		line("  (no duplicates)")
	end
end

--==========================================================================
line("")
line("--- OPEN EDITOR TABS -----------------------------------------")
--[[
	The specific failure this tool was written to name.

	Rojo patches an existing script by writing its `Source`. Studio's script
	editor holds its own buffer for any script open in a tab, and that buffer
	WINS — the write lands and is immediately overwritten by what the editor
	thinks the file says. A brand new file has no tab, so it appears fine, and
	the result is the confusing signature of "new files sync, edited files do
	not".

	There is no API to list open tabs, so this cannot be detected directly. It
	can be INFERRED, and that is worth saying out loud rather than leaving the
	reader to guess.
]]
if fresh > 0 and stale > 0 then
	line("  Some files updated and others did not. The usual cause is that the")
	line("  stale ones are OPEN IN A SCRIPT TAB in Studio: the editor's buffer")
	line("  overwrites what Rojo just wrote. New files have no tab, which is why")
	line("  they land while edited ones do not.")
	line("")
	line("  Close EVERY script tab in Studio, then Disconnect and Connect.")
else
	line("  (not the pattern here)")
end

--==========================================================================
line("")
line("--- VERDICT --------------------------------------------------")
if missing == 0 and stale == 0 then
	line(("  IN SYNC. All %d checks match the disk."):format(fresh))
	line("  If a test count still looks wrong, the problem is the test, not the sync.")
elseif fresh == 0 then
	line("  NOTHING landed. The Studio plugin is not connected to the server.")
	line("  Plugins -> Rojo -> Disconnect (if offered), then Connect.")
else
	line(("  PARTIAL: %d fresh, %d stale, %d missing."):format(fresh, stale, missing))
	line("  See OPEN EDITOR TABS above — that is the likely cause.")
end
line("")
line("=========================== END ==============================")
