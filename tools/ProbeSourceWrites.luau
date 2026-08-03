--[[
	ProbeSourceWrites — run in the Studio Command Bar, in EDIT MODE.
	Select the whole file (Ctrl+A), copy, paste, Enter.

	--------------------------------------------------------------------------
	THE QUESTION

	CheckSync has established, three runs running, that a NEW file synced into
	this place while five EDITED files did not. So the plugin is connected —
	nothing else would have created ProjectileService — and yet Rojo's writes
	to existing scripts are not sticking.

	There are two very different explanations and they need opposite fixes:

	  A. STUDIO is refusing the writes. Team Create holds scripts as drafts
	     and blocks outside edits until they are committed; an open editor tab
	     overwrites a write with its own buffer. Reconnecting Rojo forever
	     will not help.

	  B. ROJO is not sending them. Studio would accept the write; the patch
	     never arrives. Then reconnecting IS the fix.

	This tells them apart by simply trying it.

	--------------------------------------------------------------------------
	SAFETY

	The second probe writes to a REAL script and puts it back. It:
	  - records the original Source first,
	  - appends one comment line at the end and nothing else,
	  - restores the original immediately,
	  - verifies byte-for-byte that the restore worked, and shouts if it did
	    not.

	The target is deliberately a file that is ALREADY stale, so even a total
	failure loses nothing that is not already wrong and recoverable from disk.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local ServerStorage = game:GetService("ServerStorage")

local function line(s: string)
	print(s)
end

line("")
line("===================== SOURCE WRITE PROBE =====================")

--==========================================================================
-- PROBE 1 — can this session write Source AT ALL?
--
-- On a brand new instance nobody else has a claim on. If even this fails,
-- the session has no script-write permission and nothing else matters.
--==========================================================================
line("")
line("--- 1. writing to a NEW instance ----------------------------")

local canWriteAtAll = false
do
	local probe = Instance.new("ModuleScript")
	probe.Name = "TLK_SourceProbe"
	probe.Parent = ServerStorage

	local marker = "-- probe " .. tostring(os.clock())
	local ok, err = pcall(function()
		probe.Source = marker
	end)

	if not ok then
		line("  FAILED to assign Source: " .. tostring(err))
	else
		local readBack = probe.Source
		if readBack == marker then
			canWriteAtAll = true
			line("  OK — a new ModuleScript accepted a Source write and read it back.")
		else
			line("  WROTE but READ BACK DIFFERENT. Something is rewriting Source.")
			line(("     wrote %d chars, read %d"):format(#marker, #readBack))
		end
	end

	probe:Destroy()
end

--==========================================================================
-- PROBE 2 — can an EXISTING, Rojo-managed script be written?
--
-- This is the one that matters. Target is already stale, so the blast
-- radius is nil.
--==========================================================================
line("")
line("--- 2. writing to an EXISTING synced script -----------------")

do
	local target = game:GetService("ServerScriptService")
		:FindFirstChild("Server")
	target = target and target:FindFirstChild("Domain")
	target = target and target:FindFirstChild("AI")
	target = target and target:FindFirstChild("EnemyBrain")

	if not target or not target:IsA("LuaSourceContainer") then
		line("  SKIPPED — could not find ServerScriptService.Server.Domain.AI.EnemyBrain")
	else
		local original = (target :: any).Source
		line(("  target: %s (%d chars)"):format(target:GetFullName(), #original))

		local marker = "\n-- TLK probe " .. tostring(os.clock()) .. "\n"
		local wrote, writeErr = pcall(function()
			(target :: any).Source = original .. marker
		end)

		if not wrote then
			line("  FAILED to assign: " .. tostring(writeErr))
			line("  -> STUDIO is refusing the write. This is cause A.")
		else
			local after = (target :: any).Source
			if string.find(after, "TLK probe", 1, true) then
				line("  OK — the write landed and read back.")
				-- Put it back exactly as it was.
				local restored = pcall(function()
					(target :: any).Source = original
				end)
				local final = (target :: any).Source
				if restored and final == original then
					line("  restored cleanly (verified byte-for-byte).")
				else
					line("  *** RESTORE FAILED — the script now differs from what it was.")
					line("  *** Recover it by re-syncing from disk; the file there is correct.")
				end
			else
				line("  WROTE but the marker is NOT there — something reverted it instantly.")
				line("  -> This is the open-editor-tab / Team Create draft behaviour.")
			end
		end
	end
end

--==========================================================================
-- What the place thinks it is
--==========================================================================
line("")
line("--- CONTEXT --------------------------------------------------")
line(("  PlaceId  %d"):format(game.PlaceId))
line(("  GameId   %d"):format(game.GameId))
line(("  Name     %s"):format(game.Name))

do
	-- A Team Create place has collaborators; a local file does not. There is no
	-- clean public API for this, so report what can be read and let the reader
	-- judge rather than asserting something that might be wrong.
	local ok, count = pcall(function()
		return #game:GetService("Players"):GetPlayers()
	end)
	line(("  players in this session: %s"):format(if ok then tostring(count) else "unknown"))
end

--==========================================================================
line("")
line("--- WHAT THIS MEANS ------------------------------------------")
if not canWriteAtAll then
	line("  This session cannot write script Source at all. Nothing Rojo does")
	line("  will land. Check Team Create, and that the place is not read-only.")
else
	line("  Source writes DO work from this session (probe 1 passed).")
	line("  Read probe 2 above:")
	line("    assign failed          -> Studio is blocking that script specifically")
	line("    wrote then reverted    -> an editor tab or draft is holding it")
	line("    wrote and restored OK  -> Studio is fine; ROJO is not sending the")
	line("                              patch. Disconnect, Connect, and if that")
	line("                              still fails, stop and restart rojo serve.")
end
line("")
line("=========================== END ==============================")
