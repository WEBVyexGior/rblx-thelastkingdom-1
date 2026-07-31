--[[
	BuildWorldBase — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Lays the foundation you build the ruined kingdom on:

	  1. GROUND — a dirt corridor covering all five areas with room either side,
	     plus a wide apron beyond it so the edge is never in view.
	  2. LIGHT — permanent late sunset. No sun disc anywhere in the sky, heavy
	     haze, cold shadows. Neither day nor night; the hour before dark.

	Run it BEFORE building. Then sculpt, raise hills, cut the river — the ground
	is a starting slab, not a finished surface.

	Safe to re-run. It re-fills the same slab and re-applies the same lighting;
	anything you have sculpted inside the slab is flattened, so once you start
	shaping terrain, stop running section 1.

	ONE THING IT CANNOT DO: Lighting.Technology is not settable from a script.
	Set it by hand — Lighting → Technology → Future — or none of this looks right.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local Lighting = game:GetService("Lighting")

--==========================================================================
-- Tune these
--==========================================================================
local RUN_GROUND = true
local RUN_LIGHTING = true

-- The five areas sit at z = 0, -420, -840, -1260, -1680. The slab covers them
-- with generous margins so nothing is ever built against a hard edge.
local Z_FROM = 400 -- behind the arrival point
local Z_TO = -2100 -- past the castle
local X_HALF = 700 -- 1400 wide: room for the road and everything beside it
local GROUND_Y = 0
local DEPTH = 24 -- how thick the slab is
local TILE = 100

--==========================================================================
-- 1. Ground
--==========================================================================
if RUN_GROUND then
	local tiles = 0
	for x = -X_HALF, X_HALF - TILE, TILE do
		for z = Z_TO, Z_FROM - TILE, TILE do
			workspace.Terrain:FillBlock(
				CFrame.new(x + TILE / 2, GROUND_Y - DEPTH / 2, z + TILE / 2),
				Vector3.new(TILE, DEPTH, TILE),
				Enum.Material.Ground
			)
			tiles += 1
		end
		task.wait()
	end

	-- Dirt rather than the default green: this land has been dead for forty years.
	workspace.Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(96, 82, 64))
	workspace.Terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(74, 72, 70))
	workspace.Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(82, 78, 74))

	print(("[World] ground: %d tiles, %d x %d studs, top at y=%d"):format(
		tiles,
		X_HALF * 2,
		Z_FROM - Z_TO,
		GROUND_Y
	))
end

--==========================================================================
-- 2. Light
--==========================================================================
if RUN_LIGHTING then
	-- Late sunset held permanently. Not night — you must be able to read the
	-- land — and not day, because nothing here should feel safe.
	Lighting.ClockTime = 17.6
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 1.1
	Lighting.ExposureCompensation = -0.15
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.GlobalShadows = true

	-- Cold shadow, warm light: the contrast is what makes a sunset read as one.
	Lighting.Ambient = Color3.fromRGB(28, 26, 34)
	Lighting.OutdoorAmbient = Color3.fromRGB(74, 66, 74)
	Lighting.ColorShift_Top = Color3.fromRGB(126, 82, 52)
	Lighting.ColorShift_Bottom = Color3.fromRGB(28, 24, 32)

	-- Legacy fog off; Atmosphere does this far better and Future lighting expects it.
	Lighting.FogEnd = 100000

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	-- No sun, no moon, anywhere. A visible disc gives the player a direction and
	-- a time of day, and this place should have neither.
	sky.SunTextureId = ""
	sky.MoonTextureId = ""
	sky.SunAngularSize = 0
	sky.MoonAngularSize = 0
	sky.StarCount = 0
	sky.CelestialBodiesShown = false

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.42 -- the haze that hides the edge of the world
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(168, 148, 132)
	atmosphere.Decay = Color3.fromRGB(88, 72, 74)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 2.8

	local grade = Lighting:FindFirstChild("WorldGrade")
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "WorldGrade"
		grade.Parent = Lighting
	end
	grade.Brightness = -0.02
	grade.Contrast = 0.12
	grade.Saturation = -0.22 -- drained, not grey: some colour has to survive
	grade.TintColor = Color3.fromRGB(255, 238, 224)

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.1

	print("[World] lighting: permanent sunset, no sun disc, heavy haze")
	print("[World] REMINDER — set Lighting.Technology to Future by hand; a script cannot.")
end

print("[World] DONE. Build on top of this; stop running section 1 once you start sculpting.")
