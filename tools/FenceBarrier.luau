--[[
	FenceBarrier — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE.

	SELECT THE FENCE FIRST, then paste and run. With nothing selected it finds
	every model with "fence" in its name and does them all.

	--------------------------------------------------------------------------
	WHAT IT DOES, AND WHAT THE LAST ATTEMPT GOT WRONG

	It puts a `Barrier` part INSIDE the fence model — a child, not a sibling —
	measured from the fence's own bounding box and rotated to the fence's own
	orientation.

	The version before this built the barrier as a separate part at a world
	angle it worked out for itself. Two things were wrong with that and both
	matter:

	  1. It CROSSED the fence instead of lying along it. The fence ran one way,
	     the barrier ran another, and they made a cross.

	  2. It was not part of the model, so rotating the fence in Studio left the
	     barrier behind. Every fence would have to be fixed twice, by hand,
	     forever.

	A child, in the model's own frame, solves both. Rotate the fence, drag it,
	copy it — the barrier goes with it because it IS the fence.

	--------------------------------------------------------------------------
	THE MEASUREMENTS ARE THE FENCE'S OWN

	`Model:GetBoundingBox()` returns an ORIENTED box: a CFrame in the model's
	own frame and a size in that frame. So the barrier takes the fence's exact
	footprint in x and z, sits with its bottom on the fence's bottom, and rises
	to BARRIER_H. Nothing is guessed and nothing is rounded.

	Re-run it any time. It replaces the barrier rather than stacking another.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- How high a fence has to be to stop a Roblox character.
--
-- A jump clears about 7 studs and a fence is 5, so the fence alone is
-- decoration. 26 is above anything anyone can stack, stand on or climb in
-- this map, with room to spare.
local BARRIER_H = 26

-- A hair wider than the fence in both directions, so there is no seam to slip
-- through where two fences meet end to end.
local OVERSIZE = 0.6

--==========================================================================
local Selection = game:GetService("Selection")

local function isFence(instance: Instance): boolean
	return instance:IsA("Model") and string.find(string.lower(instance.Name), "fence") ~= nil
end

local targets: { Model } = {}

for _, selected in ipairs(Selection:Get()) do
	if selected:IsA("Model") then
		table.insert(targets, selected)
	end
end

if #targets == 0 then
	for _, d in ipairs(workspace:GetDescendants()) do
		if isFence(d) then
			table.insert(targets, d :: Model)
		end
	end
end

print("")
print("========================= FENCE BARRIER ======================")

if #targets == 0 then
	warn("  Nothing selected, and no model with 'fence' in its name.")
	warn("  Select the fence in the Explorer and run this again.")
	return
end

--==========================================================================
for _, fence in ipairs(targets) do
	-- Replace, never stack. Running this twice must not leave two barriers.
	local existing = fence:FindFirstChild("Barrier")
	if existing then
		existing:Destroy()
	end

	--[[
		The ORIENTED bounding box.

		This is the whole point of the tool. GetBoundingBox gives a CFrame in
		the model's own frame and a Size measured along that frame's axes — so
		a fence lying at 37 degrees reports its own length and thickness, not
		the size of the world-aligned box around it. Build in that frame and
		the barrier can only ever lie along the fence.
	]]
	local cf, size = fence:GetBoundingBox()

	local barrier = Instance.new("Part")
	barrier.Name = "Barrier"
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.CanQuery = true -- enemy pathfinding has to see it too
	barrier.CanTouch = false
	barrier.CastShadow = false
	barrier.Transparency = 1
	barrier.Material = Enum.Material.SmoothPlastic
	barrier.Color = Color3.fromRGB(120, 60, 60) -- only ever seen in Studio

	--[[
		The footprint is the fence's. The height is ours, and it grows UPWARD
		from the fence's own base — so a fence sunk into a slope keeps its feet
		on the ground and the barrier still reaches full height above it.
	]]
	barrier.Size = Vector3.new(size.X + OVERSIZE, BARRIER_H, size.Z + OVERSIZE)
	barrier.CFrame = cf * CFrame.new(0, -size.Y / 2 + BARRIER_H / 2, 0)

	barrier.Parent = fence

	print(("  %s"):format(fence:GetFullName()))
	print(("     fence   %.1f x %.1f x %.1f"):format(size.X, size.Y, size.Z))
	print(("     barrier %.1f x %.1f x %.1f, bottom flush with the fence"):format(
		barrier.Size.X,
		barrier.Size.Y,
		barrier.Size.Z
	))
end

--==========================================================================
print("")
print(("  %d fence(s) done."):format(#targets))
print("")
print("  The barrier is a CHILD of the fence and built in the fence's own")
print("  frame. Rotate it, drag it, copy it — the barrier follows, because it")
print("  is part of the fence rather than a part next to it.")
print("")
print("  To adjust the height, change BARRIER_H at the top and run it again;")
print("  it replaces the barrier instead of adding a second one.")
print("=========================== END ==============================")
