-- Dealership display cars (PR98). Static, anchored copies of Exotic cockpits and modules,
-- built from ServerStorage.Assets.Vehicles.Categories.EXOTIC. Run in Edit mode (Command Bar or execute_luau).
-- Replaces the five placed "FBX - Bruiser 02 Test" / "FBx - Test Base Vehicle v3" models in
-- Workspace["Test + WIP Assets"] (the three hidden copies under the baseplate at the origin are left alone).
-- Re-running rebuilds the five display cars in place. No scripts, attributes, tags or attachments are copied.

local PLACE_ID = 103397770260610
assert(game.PlaceId == PLACE_ID, "wrong place")
assert(game:GetService("RunService"):IsEdit(), "Edit mode only")

local HOVER_CLEARANCE = 0.9
local PREFIX = "Display - Exotic "

-- trims: 1 standard, 2 GT / Lightweight, 3 EVO / Power. Each part is {kit, trim}.
-- x, z, yaw: centre and heading. Showroom cars sit on the plinth ring (radius 91 about 854, -1748) facing inwards;
-- the test models stood about 3 studs inside it. ground: surface height under the car.
local BUILDS = {
	{
		name = "Rosso", cockpit = 5, x = 819.18, z = -1832.07, yaw = -157.5, ground = 105,
		parts = { front = {5, 3}, rear = {5, 3}, wing = {5, 3}, engine = {5, 3}, engineB = {5, 3}, stab = {5, 3}, boost = {5, 3} },
		primary = "b3121a", secondary = "101114", detail = "22252b", neon = "ffe9b0", thrust = "ffd9a0", neonOn = true,
	},
	{
		name = "Seraph", cockpit = 6, x = 769.93, z = -1713.18, yaw = -67.5, ground = 105,
		parts = { front = {6, 2}, rear = {6, 2}, wing = {6, 2}, engine = {6, 2}, engineB = {6, 2}, stab = {6, 2}, boost = {6, 2} },
		primary = "0f6b5a", secondary = "cfe01e", detail = "22252b", neon = "e4ff6a", thrust = "e4ff6a", neonOn = true,
	},
	{
		name = "Stinger", cockpit = 1, x = 769.93, z = -1782.82, yaw = -112.5, ground = 105,
		parts = { front = {1, 1}, rear = {1, 1}, wing = {1, 1}, engine = {1, 1}, engineB = {1, 1}, stab = {1, 1}, boost = {1, 1} },
		primary = "eeeeea", secondary = "2a2d33", detail = "22252b", neon = "ffffff", thrust = "bfe8ff", neonOn = false,
	},
	{
		name = "Aurora", cockpit = 3, x = 888.82, z = -1832.07, yaw = 157.5, ground = 105,
		parts = { front = {4, 2}, rear = {3, 3}, wing = {5, 2}, engine = {3, 2}, engineB = {4, 3}, stab = {6, 1}, boost = {3, 3} },
		primary = "f26a12", secondary = "101114", detail = "22252b", neon = "fff2c0", thrust = "ffc070", neonOn = true,
	},
	{
		name = "Zephyr", cockpit = 2, x = 685.16, z = -1731.40, yaw = 95, ground = 100.55,
		parts = { front = {2, 2}, rear = {2, 1}, wing = {1, 3}, engine = {2, 1}, engineB = {2, 2}, stab = {2, 1}, boost = {1, 2} },
		primary = "f2b705", secondary = "17181c", detail = "22252b", neon = "fff2c0", thrust = "fff2c0", neonOn = false,
	},
}

local exotic = game.ServerStorage.Assets.Vehicles.Categories.EXOTIC
local modules = exotic.MODULES_InterchangeableWithinCategory
local CORE = { "STANDARD", "LIGHTWEIGHT", "POWER" }
local BODY = { "", "_GT", "_EVO" }

local function source(slot, kit, trim)
	local n = string.format("%02d", kit)
	if slot == "cockpit" then
		return exotic.COCKPITS_ReplaceAssetsHere["COCKPIT_EXOTIC_" .. n].ASSET_ReplaceWithYourCockpitModel
	elseif slot == "front" then
		return modules.FrontBodies["MODULE_FRONTBODY_EXOTIC_" .. n .. BODY[trim]]
	elseif slot == "rear" then
		return modules.RearBodies["MODULE_REARBODY_EXOTIC_" .. n .. BODY[trim]]
	elseif slot == "wing" then
		return modules.RearSpoilers["MODULE_REARSPOILER_EXOTIC_" .. n .. BODY[trim]]
	elseif slot == "engine" then
		return modules.Engines["Exotic_" .. n]["MODULE_ENGINE_EXOTIC_" .. n .. "_" .. CORE[trim]]
	elseif slot == "engineB" then
		return modules.Engines_B["Exotic_" .. n]["MODULE_ENGINE_B_EXOTIC_" .. n .. "_" .. CORE[trim]]
	elseif slot == "stab" then
		return modules.Stabilisers["Exotic_" .. n]["MODULE_STABILISER_EXOTIC_" .. n .. "_" .. CORE[trim]]
	elseif slot == "boost" then
		return modules.Boost["Exotic_" .. n]["MODULE_BOOST_EXOTIC_" .. n .. "_" .. CORE[trim]]
	end
	error("unknown slot " .. slot)
end

local function addParts(model, build, slot, from)
	for _, d in from:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local channel = d:GetAttribute("PaintChannel")
			local p = d:Clone()
			for _, c in p:GetChildren() do
				if not c:IsA("SurfaceAppearance") then c:Destroy() end
			end
			for k in p:GetAttributes() do p:SetAttribute(k, nil) end
			for _, t in p:GetTags() do p:RemoveTag(t) end
			p.Name = slot .. " " .. string.lower(tostring(channel or "part"))
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
			if channel == "Primary" then
				p.Color = Color3.fromHex(build.primary)
			elseif channel == "Secondary" then
				p.Color = Color3.fromHex(build.secondary)
			elseif channel == "Detail" then
				p.Color = Color3.fromHex(build.detail)
			elseif channel == "ThrustColor" then
				p.Color = Color3.fromHex(build.thrust)
			elseif channel == "Neon" then
				if build.neonOn then
					p.Color = Color3.fromHex(build.neon)
				else
					p.Material = Enum.Material.Plastic
					p.Color = Color3.fromHex(build.detail)
				end
			end
			p.Parent = model
		end
	end
end

local folder = workspace["Test + WIP Assets"]
local recording = game:GetService("ChangeHistoryService"):TryBeginRecording("Dealership display cars")
local report = {}

for _, m in folder:GetChildren() do
	local old = m.Name == "FBX - Bruiser 02 Test" or m.Name == "FBx - Test Base Vehicle v3"
	if (old and m:GetBoundingBox().Y > 0) or (m:IsA("Model") and string.sub(m.Name, 1, #PREFIX) == PREFIX) then
		table.insert(report, "removed " .. m.Name)
		m:Destroy()
	end
end

for _, build in BUILDS do
	local model = Instance.new("Model")
	model.Name = PREFIX .. build.name
	addParts(model, build, "cockpit", source("cockpit", build.cockpit))
	for slot, pick in build.parts do
		addParts(model, build, slot, source(slot, pick[1], pick[2]))
	end
	model.WorldPivot = CFrame.new()
	local centre, size = model:GetBoundingBox()
	local rot = CFrame.Angles(0, math.rad(build.yaw), 0)
	local offset = rot * Vector3.new(centre.X, 0, centre.Z)
	local y = build.ground + HOVER_CLEARANCE - (centre.Y - size.Y / 2)
	model:PivotTo(CFrame.new(build.x - offset.X, y, build.z - offset.Z) * rot)
	model.Parent = folder
	table.insert(report, string.format("built %s: %d parts, %.1f x %.1f x %.1f", model.Name, #model:GetChildren(), size.X, size.Y, size.Z))
end

if recording then
	game:GetService("ChangeHistoryService"):FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return table.concat(report, "\n")
